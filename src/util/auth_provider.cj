/**
 * SMTP 可插拔认证机制
 *
 * 支持：LOGIN、PLAIN、XOAUTH2、NTLM
 * 通过 mail.smtp.auth.mechanisms 属性配置优先级
 */
package mail.util

import mail.core.*
import std.collection.*
import std.time.*

// ─────────────────────────────────────────────────────────────────────────────
// 认证上下文（由 Transport 传入）
// ─────────────────────────────────────────────────────────────────────────────

public class AuthContext {
    public let user: String
    public let password: String
    public let oauthToken: ?String
    public let domain: String
    public let host: String
    public let debug: Bool
    public let sendCommand: (String) -> Unit
    public let readResponse: () -> String
    public let getLastCode: () -> Int64

    public init(
        user: String,
        password: String,
        oauthToken: ?String,
        domain: String,
        host: String,
        debug: Bool,
        sendCommand: (String) -> Unit,
        readResponse: () -> String,
        getLastCode: () -> Int64
    ) {
        this.user = user
        this.password = password
        this.oauthToken = oauthToken
        this.domain = domain
        this.host = host
        this.debug = debug
        this.sendCommand = sendCommand
        this.readResponse = readResponse
        this.getLastCode = getLastCode
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 认证机制接口
// ─────────────────────────────────────────────────────────────────────────────

public interface SmtpAuthMechanism {
    func getName(): String
    func execute(ctx: AuthContext): Bool
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN
// ─────────────────────────────────────────────────────────────────────────────

public class LoginMechanism <: SmtpAuthMechanism {
    public func getName(): String { "LOGIN" }

    public func execute(ctx: AuthContext): Bool {
        ctx.sendCommand("AUTH LOGIN")
        var resp = ctx.readResponse()
        if (ctx.getLastCode() != 334) {
            throw AuthenticationFailedException("AUTH LOGIN 失败: ${resp}")
        }

        ctx.sendCommand(Base64Util.encodeString(ctx.user))
        resp = ctx.readResponse()
        if (ctx.getLastCode() != 334) {
            throw AuthenticationFailedException("AUTH LOGIN 用户名失败")
        }

        ctx.sendCommand(Base64Util.encodeString(ctx.password))
        resp = ctx.readResponse()
        if (ctx.getLastCode() != 235) {
            throw AuthenticationFailedException("AUTH LOGIN 密码失败: ${resp}")
        }
        true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAIN
// ─────────────────────────────────────────────────────────────────────────────

public class PlainMechanism <: SmtpAuthMechanism {
    public func getName(): String { "PLAIN" }

    public func execute(ctx: AuthContext): Bool {
        let authStr = "\u{0000}${ctx.user}\u{0000}${ctx.password}"
        ctx.sendCommand("AUTH PLAIN ${Base64Util.encodeString(authStr)}")
        let resp = ctx.readResponse()
        if (ctx.getLastCode() != 235) {
            throw AuthenticationFailedException("AUTH PLAIN 失败: ${resp}")
        }
        true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// XOAUTH2 (OAuth2 Bearer Token)
// RFC 6750 / Google XOAUTH2
// ─────────────────────────────────────────────────────────────────────────────

public class XOAuth2Mechanism <: SmtpAuthMechanism {
    public func getName(): String { "XOAUTH2" }

    public func execute(ctx: AuthContext): Bool {
        let token = match (ctx.oauthToken) {
            case Some(t) => t
            case None    => ctx.password  // 允许将 token 作为 password 传入
        }

        // XOAUTH2 格式：user=<user>\x01auth=Bearer <token>\x01\x01
        let oauthStr = "user=${ctx.user}\u{0001}auth=Bearer ${token}\u{0001}\u{0001}"
        ctx.sendCommand("AUTH XOAUTH2 ${Base64Util.encodeString(oauthStr)}")
        var resp = ctx.readResponse()

        // 334 表示认证失败的 JSON 错误，发空响应使服务器返回 535
        if (ctx.getLastCode() == 334) {
            ctx.sendCommand("")
            resp = ctx.readResponse()
        }

        if (ctx.getLastCode() != 235) {
            throw AuthenticationFailedException("XOAUTH2 认证失败: ${resp}")
        }
        if (ctx.debug) {
            println("DEBUG SMTP: XOAUTH2 认证成功")
        }
        true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// NTLM (NTLMv2，MS-NLMP)
// ─────────────────────────────────────────────────────────────────────────────

public class NtlmMechanism <: SmtpAuthMechanism {
    public func getName(): String { "NTLM" }

    public func execute(ctx: AuthContext): Bool {
        // Step 1: 发送 AUTH NTLM，服务器可能直接返回 334 要求 Type1
        ctx.sendCommand("AUTH NTLM")
        var resp = ctx.readResponse()
        var code = ctx.getLastCode()

        // 部分服务器在 AUTH NTLM 后直接回 334（空挑战）
        // 发送 Type 1 消息
        let type1 = buildType1()
        ctx.sendCommand(Base64Util.encode(type1))
        resp = ctx.readResponse()
        code = ctx.getLastCode()

        if (code != 334) {
            throw AuthenticationFailedException("NTLM Type1 失败: ${resp}")
        }

        // Step 2: 解析服务器 Type 2 挑战（334 后跟 base64 数据）
        let challengeB64 = resp.trimAscii()
        let type2 = Base64Util.decode(challengeB64)
        let serverChallenge = extractType2Challenge(type2)

        // Step 3: 构造 Type 3 并发送
        let type3 = buildType3(ctx.user, ctx.password, ctx.domain, serverChallenge)
        ctx.sendCommand(Base64Util.encode(type3))
        resp = ctx.readResponse()
        code = ctx.getLastCode()

        if (code != 235) {
            throw AuthenticationFailedException("NTLM 认证失败: ${resp}")
        }
        if (ctx.debug) {
            println("DEBUG SMTP: NTLM 认证成功")
        }
        true
    }

    // NTLM Type 1 — Negotiate（固定消息，空域名/工作站）
    private func buildType1(): Array<Byte> {
        let msg = Array<Byte>(32, repeat: 0u8)
        // Signature "NTLMSSP\0"
        let sig = [0x4Eu8,0x54u8,0x4Cu8,0x4Du8,0x53u8,0x53u8,0x50u8,0x00u8]
        for (i in 0..8) { msg[i] = sig[i] }
        // MessageType = 1 (LE)
        msg[8] = 1u8
        // NegotiateFlags = 0x0000B707 (UNICODE|OEM|REQUEST_TARGET|NTLM|ALWAYS_SIGN)
        msg[12] = 0x07u8; msg[13] = 0xB7u8; msg[14] = 0x00u8; msg[15] = 0x00u8
        // DomainName security buffer: len=0, maxLen=0, offset=32
        msg[20] = 0x20u8
        // WorkstationName security buffer: len=0, maxLen=0, offset=32
        msg[28] = 0x20u8
        msg
    }

    // 从 Type 2 消息中提取 8 字节服务器 nonce
    private func extractType2Challenge(type2: Array<Byte>): Array<Byte> {
        let challenge = Array<Byte>(8, repeat: 0u8)
        // Type 2 格式：signature(8) + type(4) + TargetName(8) + flags(4) + challenge(8) + ...
        // challenge starts at offset 24
        if (type2.size >= 32) {
            for (i in 0..8) { challenge[i] = type2[24 + i] }
        }
        challenge
    }

    // NTLM Type 3 — Authenticate（NTLMv2）
    private func buildType3(
        user: String,
        password: String,
        domain: String,
        serverChallenge: Array<Byte>
    ): Array<Byte> {
        // ① NT hash = MD4(UTF-16LE(password))
        let ntHash = CryptoUtil.md4(CryptoUtil.toUtf16LE(password))

        // ② NTLMv2 hash = HMAC-MD5(ntHash, UTF-16LE(upper(user) + domain))
        let userDomain = CryptoUtil.toUtf16LE(user.toAsciiUpper() + domain)
        let ntlmv2Hash = CryptoUtil.hmacMd5(ntHash, userDomain)

        // ③ 构造 Blob（NTLMv2 客户端挑战结构）
        let clientNonce = CryptoUtil.randomBytes(8)
        let now = DateTime.now().toUnixTimeStamp().toNanoseconds() / 100  // 100-ns units
        // FILETIME offset from 1601-01-01: 11644473600 seconds = 116444736000000000 * 100ns
        let fileTime = now + 116444736000000000
        let blob = buildBlob(fileTime, clientNonce)

        // ④ NTProofStr = HMAC-MD5(ntlmv2Hash, serverChallenge + blob)
        var scBlob = ArrayList<Byte>()
        for (b in serverChallenge) { scBlob.add(b) }
        for (b in blob) { scBlob.add(b) }
        let ntProofStr = CryptoUtil.hmacMd5(ntlmv2Hash, scBlob.toArray())

        // ⑤ NT response = NTProofStr + blob
        var ntResponse = ArrayList<Byte>()
        for (b in ntProofStr) { ntResponse.add(b) }
        for (b in blob) { ntResponse.add(b) }
        let ntResp = ntResponse.toArray()

        // ⑥ 序列化用户名、域名（UTF-16LE）
        let userBytes   = CryptoUtil.toUtf16LE(user)
        let domainBytes = CryptoUtil.toUtf16LE(domain)
        let wsBytes     = CryptoUtil.toUtf16LE("WORKSTATION")

        // ⑦ 计算各字段偏移（固定头 72 字节）
        let fixedSize = 72
        var offset = fixedSize
        let lmOff = offset; let lmLen = 24; offset += lmLen
        let ntOff = offset; let ntLen = ntResp.size; offset += ntLen
        let domOff = offset; let domLen = domainBytes.size; offset += domLen
        let usrOff = offset; let usrLen = userBytes.size; offset += usrLen
        let wsOff  = offset; let wsLen  = wsBytes.size; offset += wsLen

        let total = offset
        let msg = Array<Byte>(total, repeat: 0u8)

        // Signature
        let sig = [0x4Eu8,0x54u8,0x4Cu8,0x4Du8,0x53u8,0x53u8,0x50u8,0x00u8]
        for (i in 0..8) { msg[i] = sig[i] }
        // MessageType = 3
        msg[8] = 3u8
        // LM security buffer
        putSecBuf(msg, 12, 24, lmOff)
        // NT security buffer
        putSecBuf(msg, 20, ntLen, ntOff)
        // Domain
        putSecBuf(msg, 28, domLen, domOff)
        // User
        putSecBuf(msg, 36, usrLen, usrOff)
        // Workstation
        putSecBuf(msg, 44, wsLen, wsOff)
        // EncryptedRandomSessionKey (empty)
        putSecBuf(msg, 52, 0, total)
        // NegotiateFlags
        msg[60] = 0x07u8; msg[61] = 0xB7u8; msg[62] = 0x00u8; msg[63] = 0x00u8
        // Version (8 bytes, optional, set to zeros)
        // MIC (16 bytes at 72, zeros)

        // LM response: 24 zeros (NTLMv2 sends empty LM)
        // NT response
        for (i in 0..ntLen) { msg[ntOff + i] = ntResp[i] }
        // Domain
        for (i in 0..domLen) { msg[domOff + i] = domainBytes[i] }
        // User
        for (i in 0..usrLen) { msg[usrOff + i] = userBytes[i] }
        // Workstation
        for (i in 0..wsLen) { msg[wsOff + i] = wsBytes[i] }

        msg
    }

    // NTLMv2 Blob（不含 target_info，兼容基本场景）
    private func buildBlob(fileTime: Int64, clientNonce: Array<Byte>): Array<Byte> {
        let blob = Array<Byte>(32, repeat: 0u8)
        // Signature 0x01010000
        blob[0] = 0x01u8; blob[1] = 0x01u8
        // Reserved
        // Timestamp (8 bytes LE)
        for (i in 0..8) { blob[8 + i] = UInt8((fileTime >> (i * 8)) & 0xFF) }
        // Client nonce (8 bytes)
        for (i in 0..8) { blob[16 + i] = clientNonce[i] }
        // Unknown 4 bytes (zeros)
        // Target info terminator MsvAvEOL (4 zero bytes, already zero)
        blob
    }

    // 写入 NTLM 安全缓冲区（length/maxLen/offset）
    private func putSecBuf(msg: Array<Byte>, off: Int64, len: Int64, dataOff: Int64): Unit {
        // length (2 bytes LE)
        msg[off]     = UInt8(len & 0xFF)
        msg[off + 1] = UInt8((len >> 8) & 0xFF)
        // maxLen (2 bytes LE)
        msg[off + 2] = UInt8(len & 0xFF)
        msg[off + 3] = UInt8((len >> 8) & 0xFF)
        // offset (4 bytes LE)
        msg[off + 4] = UInt8(dataOff & 0xFF)
        msg[off + 5] = UInt8((dataOff >> 8) & 0xFF)
        msg[off + 6] = UInt8((dataOff >> 16) & 0xFF)
        msg[off + 7] = UInt8((dataOff >> 24) & 0xFF)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIGEST-MD5 (RFC 2831) — 挑战-响应认证
// ─────────────────────────────────────────────────────────────────────────────

public class DigestMd5Mechanism <: SmtpAuthMechanism {
    public func getName(): String { "DIGEST-MD5" }

    public func execute(ctx: AuthContext): Bool {
        ctx.sendCommand("AUTH DIGEST-MD5")
        let challengeResp = ctx.readResponse()
        if (ctx.getLastCode() != 334) {
            throw AuthenticationFailedException("DIGEST-MD5 握手失败: ${challengeResp}")
        }

        // 提取 base64 挑战（跳过 "334 " 前缀）
        let b64Challenge = extractB64(challengeResp)
        let challenge = Base64Util.decodeToString(b64Challenge)

        let params = parseDigestParams(challenge)

        let realm = getParam(params, "realm")
        let nonce = match (params.get("nonce")) {
            case Some(n) => n
            case None    => throw AuthenticationFailedException("DIGEST-MD5 服务器挑战缺少 nonce")
        }
        let algorithm = getParam(params, "algorithm").toAsciiLower()
        // 始终使用 qop=auth（不支持 auth-int）
        let qop = "auth"

        // 客户端随机数
        let cnonce = Base64Util.encode(CryptoUtil.randomBytes(16))
        let nc = "00000001"

        // digest-uri = smtp/<服务器主机名>
        let serviceHost = if (!ctx.host.isEmpty()) { ctx.host } else { "localhost" }
        let digestUri = "smtp/${serviceHost}"

        // 计算 HA1
        let ha1: String
        if (algorithm != "md5") {
            // algorithm=md5-sess（默认）: A1 = MD5(user:realm:password) || ":" || nonce || ":" || cnonce
            let prefixHash = CryptoUtil.md5("${ctx.user}:${realm}:${ctx.password}".toArray())
            var a1Bytes = ArrayList<Byte>()
            for (bv in prefixHash) { a1Bytes.add(bv) }
            for (bv in ":${nonce}:${cnonce}".toArray()) { a1Bytes.add(bv) }
            ha1 = CryptoUtil.hexEncode(CryptoUtil.md5(a1Bytes.toArray()))
        } else {
            // algorithm=md5: A1 = user:realm:password
            ha1 = CryptoUtil.hexEncode(CryptoUtil.md5("${ctx.user}:${realm}:${ctx.password}".toArray()))
        }

        // HA2 = HEX(MD5("AUTHENTICATE:" + digestUri))
        let ha2 = CryptoUtil.hexEncode(CryptoUtil.md5("AUTHENTICATE:${digestUri}".toArray()))

        // response = HEX(MD5(HA1:nonce:nc:cnonce:qop:HA2))
        let responseHex = CryptoUtil.hexEncode(
            CryptoUtil.md5("${ha1}:${nonce}:${nc}:${cnonce}:${qop}:${ha2}".toArray())
        )

        // 构建并发送响应
        var responseStr = "charset=utf-8,username=\"${ctx.user}\""
        if (!realm.isEmpty()) { responseStr += ",realm=\"${realm}\"" }
        responseStr += ",nonce=\"${nonce}\",cnonce=\"${cnonce}\",nc=${nc}"
        responseStr += ",digest-uri=\"${digestUri}\",response=${responseHex},qop=${qop}"

        ctx.sendCommand(Base64Util.encodeString(responseStr))
        var resp = ctx.readResponse()

        // 服务器可能返回 334 rspauth（互认证），发送空响应确认
        if (ctx.getLastCode() == 334) {
            ctx.sendCommand("")
            resp = ctx.readResponse()
        }

        if (ctx.getLastCode() != 235) {
            throw AuthenticationFailedException("DIGEST-MD5 认证失败: ${resp}")
        }
        if (ctx.debug) {
            println("DEBUG SMTP: DIGEST-MD5 认证成功")
        }
        true
    }

    private func extractB64(resp: String): String {
        match (resp.indexOf(" ")) {
            case Some(idx) => resp[(idx + 1)..resp.size].trimAscii()
            case None      => resp.trimAscii()
        }
    }

    private func parseDigestParams(challenge: String): HashMap<String, String> {
        let params = HashMap<String, String>()
        var rest = challenge.trimAscii()

        while (!rest.isEmpty()) {
            rest = rest.trimAscii()
            if (rest.isEmpty()) { break }

            match (rest.indexOf("=")) {
                case Some(eqIdx) =>
                    let key = rest[0..eqIdx].trimAscii()
                    rest = rest[(eqIdx + 1)..rest.size].trimAscii()

                    let value: String
                    if (rest.startsWith("\"")) {
                        rest = rest[1..rest.size]
                        match (rest.indexOf("\"")) {
                            case Some(qIdx) =>
                                value = rest[0..qIdx]
                                rest = rest[(qIdx + 1)..rest.size]
                            case None =>
                                value = rest
                                rest = ""
                        }
                    } else {
                        match (rest.indexOf(",")) {
                            case Some(cIdx) =>
                                value = rest[0..cIdx].trimAscii()
                                rest = rest[(cIdx + 1)..rest.size]
                            case None =>
                                value = rest.trimAscii()
                                rest = ""
                        }
                    }
                    if (!key.isEmpty()) { params[key] = value }

                case None => break
            }

            rest = rest.trimAscii()
            if (rest.startsWith(",")) { rest = rest[1..rest.size] }
        }
        params
    }

    private func getParam(params: HashMap<String, String>, key: String): String {
        match (params.get(key)) {
            case Some(v) => v
            case None    => ""
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthMechanismSelector — 读取配置，按优先级选择机制
// ─────────────────────────────────────────────────────────────────────────────

public class AuthMechanismSelector {
    // 默认优先级（可通过 mail.smtp.auth.mechanisms 覆盖）
    private static let DEFAULT_PRIORITY = ["XOAUTH2", "NTLM", "DIGEST-MD5", "LOGIN", "PLAIN"]

    /**
     * 执行认证
     *
     * @param serverMechs   服务器 EHLO 中声明的 AUTH 机制列表
     * @param configMechs   mail.smtp.auth.mechanisms 属性（空格分隔，可为 None）
     * @param ctx           认证上下文
     */
    public static func authenticate(
        serverMechs: ArrayList<String>,
        configMechs: ?String,
        ctx: AuthContext
    ): Bool {
        // 构造候选列表（按优先级）
        let priority = match (configMechs) {
            case Some(s) =>
                let parts = s.split(" ")
                let list = ArrayList<String>()
                for (p in parts) {
                    let t = p.trimAscii().toAsciiUpper()
                    if (!t.isEmpty()) { list.add(t) }
                }
                list
            case None =>
                let list = ArrayList<String>()
                for (m in DEFAULT_PRIORITY) { list.add(m) }
                list
        }

        // 选择第一个服务器支持且客户端实现的机制
        // 若 serverMechs 为空（服务器未声明），尝试全部
        let tryAll = serverMechs.isEmpty()

        for (name in priority) {
            let supported = tryAll || serverMechs.contains(name)
            if (!supported) { continue }

            // 跳过需要 token 但没有 token 的 XOAUTH2
            if (name == "XOAUTH2" && ctx.oauthToken.isNone() && ctx.password.isEmpty()) {
                continue
            }

            let mech = getMechanism(name)
            match (mech) {
                case Some(m) =>
                    if (ctx.debug) {
                        println("DEBUG SMTP: 尝试认证机制: ${name}")
                    }
                    return m.execute(ctx)
                case None => ()
            }
        }

        throw AuthenticationFailedException("无可用的认证机制，服务器支持: ${serverMechs}")
    }

    private static func getMechanism(name: String): ?SmtpAuthMechanism {
        match (name) {
            case "LOGIN"      => Some(LoginMechanism())
            case "PLAIN"      => Some(PlainMechanism())
            case "XOAUTH2"    => Some(XOAuth2Mechanism())
            case "NTLM"       => Some(NtlmMechanism())
            case "DIGEST-MD5" => Some(DigestMd5Mechanism())
            case _            => None
        }
    }
}
