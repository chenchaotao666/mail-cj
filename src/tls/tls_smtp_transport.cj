/**
 * 支持 TLS 的 SMTP 传输实现
 *
 * 支持：
 * - SMTPS（直接 SSL/TLS，端口 465）
 * - STARTTLS（明文升级加密，端口 587）
 * - 连接/读/写超时
 * - 精细的部分失败处理
 */
package mail.tls

import mail.core.*
import mail.internet.*
import mail.util.*
import std.collection.*
import std.convert.*

/**
 * TLS SMTP 传输实现（兼容 SMTPTransport 全部公开 API）
 */
public class TlsSMTPTransport <: Transport {
    // 协议配置
    private var _name: String = "smtps"
    private var _defaultPort: Int64 = 465
    private var _useSSL: Bool = true

    // 连接状态
    private var _host: String = ""
    private var _port: Int64 = 465
    private var _tlsSocket: ?TlsSocket = None
    private var _tlsConfig: ?TlsConfig = None
    private var _rawFd: Int32 = -1  // 明文 TCP fd（STARTTLS 升级前）

    // ESMTP 扩展
    private var _extMap: HashMap<String, String> = HashMap<String, String>()
    private var _serverAuthMechanisms: ArrayList<String> = ArrayList<String>()

    // 配置选项
    private var _useStartTLS: Bool = false
    private var _requireStartTLS: Bool = false
    private var _localHost: ?String = None

    // 证书验证
    private var _verifyCert: Bool = false
    private var _caCertPath: ?String = None

    // 超时（毫秒，0 表示不设置）
    private var _connectTimeout: Int64 = 0
    private var _readTimeout: Int64 = 0
    private var _writeTimeout: Int64 = 0

    // 认证配置
    private var _authMechanisms: ?String = None
    private var _oauthToken: ?String = None
    private var _ntlmDomain: String = ""
    private var _authDisabledMechanisms: ArrayList<String> = ArrayList<String>()

    // 部分发送
    private var _sendPartial: Bool = false

    // SMTP 协议行为
    private var _quitWait: Bool = true
    private var _quitOnSessionReject: Bool = true
    private var _noAuthDebug: Bool = false
    private var _allow8bitMIME: Bool = false
    private var _chunkSize: Int64 = 65536          // BDAT 分块大小（64 KB）
    private var _useSmtpUtf8: Bool = false         // SMTPUTF8（RFC 6531）

    // 响应状态扩展
    private var _lastEnhancedStatus: String = ""

    // 响应状态
    private var _lastServerResponse: String = ""
    private var _lastReturnCode: Int64 = 0

    public init(session: Session, useSSL: Bool) {
        super(session)
        _useSSL = useSSL
        _name = if (useSSL) { "smtps" } else { "smtp" }
        _defaultPort = if (useSSL) { 465 } else { 587 }
        loadSessionConfig()
    }

    private func loadSessionConfig(): Unit {
        let prefix = "mail.${_name}."

        match (_session.getProperty("${prefix}starttls.enable")) {
            case Some("true") => _useStartTLS = true
            case _ => ()
        }
        match (_session.getProperty("${prefix}starttls.required")) {
            case Some("true") => _requireStartTLS = true
            case _ => ()
        }

        _localHost = _session.getProperty("${prefix}localhost")

        // 证书验证
        match (_session.getProperty("${prefix}ssl.checkserveridentity")) {
            case Some("true") => _verifyCert = true
            case _ => ()
        }
        match (_session.getProperty("${prefix}ssl.trust")) {
            case Some("*") => _verifyCert = false
            case Some(path) => _verifyCert = true; _caCertPath = Some(path)
            case None => ()
        }
        match (_session.getProperty("${prefix}ssl.caCert")) {
            case Some(path) => _verifyCert = true; _caCertPath = Some(path)
            case None => ()
        }

        // 超时配置
        match (_session.getProperty("${prefix}connectiontimeout")) {
            case Some(v) => _connectTimeout = try { Int64.parse(v) } catch (_: Exception) { 0 }
            case None => ()
        }
        match (_session.getProperty("${prefix}timeout")) {
            case Some(v) => _readTimeout = try { Int64.parse(v) } catch (_: Exception) { 0 }
            case None => ()
        }
        match (_session.getProperty("${prefix}writetimeout")) {
            case Some(v) => _writeTimeout = try { Int64.parse(v) } catch (_: Exception) { 0 }
            case None => ()
        }
        _authMechanisms = _session.getProperty("${prefix}auth.mechanisms")
        _oauthToken     = _session.getProperty("${prefix}auth.xoauth2.token")
        _ntlmDomain     = _session.getProperty("${prefix}auth.ntlm.domain", "")
        match (_session.getProperty("${prefix}sendpartial")) {
            case Some("true") => _sendPartial = true
            case _ => ()
        }
        match (_session.getProperty("${prefix}quitwait")) {
            case Some("false") => _quitWait = false
            case _ => ()
        }
        match (_session.getProperty("${prefix}quitonsessionreject")) {
            case Some("false") => _quitOnSessionReject = false
            case _ => ()
        }
        match (_session.getProperty("${prefix}noauthdebug")) {
            case Some("true") => _noAuthDebug = true
            case _ => ()
        }
        match (_session.getProperty("${prefix}allow8bitmime")) {
            case Some("true") => _allow8bitMIME = true
            case _ => ()
        }
        if (_session.getProperty("${prefix}auth.login.disable", "false") == "true") {
            _authDisabledMechanisms.add("LOGIN")
        }
        if (_session.getProperty("${prefix}auth.plain.disable", "false") == "true") {
            _authDisabledMechanisms.add("PLAIN")
        }
        if (_session.getProperty("${prefix}auth.ntlm.disable", "false") == "true") {
            _authDisabledMechanisms.add("NTLM")
        }
        if (_session.getProperty("${prefix}auth.xoauth2.disable", "false") == "true") {
            _authDisabledMechanisms.add("XOAUTH2")
        }
        if (_session.getProperty("${prefix}auth.digest-md5.disable", "false") == "true") {
            _authDisabledMechanisms.add("DIGEST-MD5")
        }
        match (_session.getProperty("${prefix}chunksize")) {
            case Some(v) => _chunkSize = try { Int64.parse(v) } catch (_: Exception) { 65536 }
            case None => ()
        }
        match (_session.getProperty("${prefix}smtputf8")) {
            case Some("true") => _useSmtpUtf8 = true
            case _ => ()
        }
    }

    public func setVerifyCert(verify: Bool): Unit {
        _verifyCert = verify
    }

    public func setCACertPath(path: String): Unit {
        _caCertPath = Some(path)
        _verifyCert = true
    }

    // -------------------------------------------------------------------------
    // 连接
    // -------------------------------------------------------------------------

    public override func connect(host: String, port: Int64, user: String, password: String): Unit {
        _host = host
        _port = if (port > 0) { port } else { _defaultPort }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 正在连接 ${_host}:${_port}")
        }

        if (!_useSSL && _useStartTLS) {
            connectStartTLS(user, password)
        } else {
            connectDirectTLS(user, password)
        }
    }

    /** 直接 TLS 连接（465 端口 SMTPS） */
    private func connectDirectTLS(user: String, password: String): Unit {
        let config = buildTlsConfig()
        config.initialize()
        if (_verifyCert) { config.loadCertificates() }
        _tlsConfig = Some(config)

        let tlsSocket = TlsSocket(config)
        applySocketTimeouts(tlsSocket)

        try {
            tlsSocket.connect(_host, UInt16(_port))
        } catch (e: TlsException) {
            try { config.close() } catch (_: Exception) {}
            _tlsConfig = None
            _connected = false
            throw MessagingException("TLS 连接失败: ${e.message}")
        }

        _tlsSocket = Some(tlsSocket)
        _connected = true
        notifyConnectionOpened()

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: TLS 握手成功")
        }

        doSmtpHandshake(user, password)
    }

    /** STARTTLS 连接：明文握手 → STARTTLS → 升级 TLS（587 端口） */
    private func connectStartTLS(user: String, password: String): Unit {
        _rawFd = createTcpConnection(_host, UInt16(_port))
        if (_rawFd < 0) {
            throw MailConnectException(_host, _port, _connectTimeout,
                Exception("无法建立 TCP 连接到 ${_host}:${_port}"))
        }

        if (_readTimeout > 0 || _writeTimeout > 0) {
            unsafe { setSocketTimeouts(_rawFd, _readTimeout, _writeTimeout) }
        }

        _connected = true
        notifyConnectionOpened()

        try {
            // 读取服务器问候语（明文）
            let greeting = readResponse()
            if (_lastReturnCode != 220) {
                throw MessagingException("SMTP 服务器拒绝连接: ${greeting}")
            }

            if (_session.getDebug()) {
                println("DEBUG TLS SMTP: 已连接（明文），问候语: ${greeting}")
            }

            // EHLO
            let localHost = match (_localHost) { case Some(h) => h; case None => "localhost" }
            if (!ehlo(localHost)) { helo(localHost) }

            // 检查 STARTTLS 支持
            if (!supportsExtension("STARTTLS")) {
                if (_requireStartTLS) {
                    throw MessagingException("需要 STARTTLS 但服务器不支持")
                }
            } else {
                // 发送 STARTTLS 命令
                sendCommand("STARTTLS")
                let stResp = readResponse()
                if (_lastReturnCode != 220) {
                    throw MessagingException("STARTTLS 失败: ${stResp}")
                }

                // 升级到 TLS
                let config = buildTlsConfig()
                config.initialize()
                if (_verifyCert) { config.loadCertificates() }
                _tlsConfig = Some(config)

                let tlsSocket = TlsSocket(config)
                applySocketTimeouts(tlsSocket)

                try {
                    tlsSocket.connectWithFd(_rawFd)
                } catch (e: TlsException) {
                    try { config.close() } catch (_: Exception) {}
                    _tlsConfig = None
                    throw MessagingException("STARTTLS TLS 握手失败: ${e.message}")
                }

                _tlsSocket = Some(tlsSocket)
                _rawFd = -1  // fd 所有权已转移到 TlsSocket

                if (_session.getDebug()) {
                    println("DEBUG TLS SMTP: STARTTLS 升级成功")
                }

                // RFC 要求 STARTTLS 后重新发送 EHLO
                _extMap.clear()
                _serverAuthMechanisms.clear()
                if (!ehlo(localHost)) { helo(localHost) }
            }

            // 认证
            if (!user.isEmpty() && !password.isEmpty()) {
                authenticate(user, password)
            } else {
                match (_session.getAuthenticator()) {
                    case Some(auth) =>
                        match (auth.requestPasswordAuthentication()) {
                            case Some(pa) => authenticate(pa.getUserName(), pa.getPassword())
                            case None => ()
                        }
                    case None => ()
                }
            }

        } catch (e: Exception) {
            _connected = false
            closeRawFd()
            match (_tlsSocket) {
                case Some(s) => try { s.close() } catch (_: Exception) {}
                case None => ()
            }
            match (_tlsConfig) {
                case Some(c) => try { c.close() } catch (_: Exception) {}
                case None => ()
            }
            _tlsSocket = None
            _tlsConfig = None
            throw e
        }
    }

    /** SMTPS 建立后的 EHLO + AUTH 握手 */
    private func doSmtpHandshake(user: String, password: String): Unit {
        let greeting = readResponse()
        if (_lastReturnCode != 220) {
            if (_quitOnSessionReject) {
                try { sendCommand("QUIT") } catch (_: Exception) {}
            }
            throw MessagingException("SMTP 服务器拒绝连接: ${greeting}")
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 已连接，问候语: ${greeting}")
        }

        let localHost = match (_localHost) { case Some(h) => h; case None => "localhost" }
        if (!ehlo(localHost)) { helo(localHost) }

        if (!user.isEmpty() && !password.isEmpty()) {
            authenticate(user, password)
        } else {
            match (_session.getAuthenticator()) {
                case Some(auth) =>
                    match (auth.requestPasswordAuthentication()) {
                        case Some(pa) => authenticate(pa.getUserName(), pa.getPassword())
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    private func buildTlsConfig(): TlsConfig {
        if (_verifyCert) {
            match (_caCertPath) {
                case Some(path) => createSecureClientConfig(path)
                case None => TlsConfig(TLS_1_2).setVerifyMode(VERIFY_PEER)
            }
        } else {
            createClientConfig()
        }
    }

    private func applySocketTimeouts(s: TlsSocket): Unit {
        if (_readTimeout > 0) { s.setReadTimeout(_readTimeout) }
        if (_writeTimeout > 0) { s.setWriteTimeout(_writeTimeout) }
    }

    // -------------------------------------------------------------------------
    // EHLO / HELO
    // -------------------------------------------------------------------------

    private func ehlo(domain: String): Bool {
        sendCommand("EHLO ${domain}")
        let response = readResponse()

        if (_lastReturnCode != 250) { return false }

        _extMap.clear()
        _serverAuthMechanisms.clear()

        let lines = response.split("\n")
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.size > 4) {
                let ext = trimmed[4..trimmed.size].trimAscii()
                match (ext.indexOf(" ")) {
                    case Some(spaceIndex) where spaceIndex > 0 =>
                        let name = ext[0..spaceIndex].toAsciiUpper()
                        let params = ext[(spaceIndex + 1)..ext.size]
                        _extMap[name] = params
                        if (name == "AUTH") {
                            let mechs = params.split(" ")
                            for (m in mechs) {
                                let mech = m.trimAscii().toAsciiUpper()
                                if (!mech.isEmpty()) { _serverAuthMechanisms.add(mech) }
                            }
                        }
                    case _ =>
                        _extMap[ext.toAsciiUpper()] = ""
                }
            }
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: EHLO 扩展: ${_extMap}")
        }

        true
    }

    private func helo(domain: String): Unit {
        sendCommand("HELO ${domain}")
        let response = readResponse()
        if (_lastReturnCode != 250) {
            throw MessagingException("HELO 失败: ${response}")
        }
    }

    // -------------------------------------------------------------------------
    // 认证
    // -------------------------------------------------------------------------

    private func authenticate(user: String, password: String): Bool {
        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 正在认证，用户: ${user}")
        }
        let effectiveMechs = ArrayList<String>()
        for (m in _serverAuthMechanisms) {
            if (!_authDisabledMechanisms.contains(m)) { effectiveMechs.add(m) }
        }
        let ctx = AuthContext(
            user, password, _oauthToken, _ntlmDomain, _host, _session.getDebug(),
            {cmd => sendCommand(cmd)},
            {=> readResponse()},
            {=> _lastReturnCode}
        )
        AuthMechanismSelector.authenticate(effectiveMechs, _authMechanisms, ctx)
    }

    // -------------------------------------------------------------------------
    // 发送邮件（精细的部分失败处理）
    // -------------------------------------------------------------------------

    public override func sendMessage(message: Message, addresses: Array<Address>): Unit {
        if (!_connected) {
            throw MessagingException("未连接到 SMTP 服务器")
        }
        if (addresses.isEmpty()) {
            throw MessagingException("未指定收件人")
        }

        message.saveChanges()

        let from = message.getFrom()
        if (from.isEmpty()) {
            throw MessagingException("未指定发件人地址")
        }

        let envelopeSender: Address = match (message) {
            case sm: SMTPMessage =>
                match (sm.getEnvelopeFrom()) {
                    case Some(ef) => InternetAddress(ef)
                    case None => from[0]
                }
            case _ => from[0]
        }
        let mailParams = buildTlsMailFromParams(message)
        let validSent = ArrayList<Address>()
        let invalidAddr = ArrayList<Address>()

        if (supportsExtension("PIPELINING") && !supportsExtension("CHUNKING")) {
            sendTlsMessagePipelined(message, envelopeSender, mailParams, addresses, validSent, invalidAddr)
        } else {
            mailFrom(envelopeSender, mailParams)
            let dsnParams = buildTlsRcptDsnParams(message)
            for (addr in addresses) {
                try {
                    rcptTo(addr, dsnParams)
                    validSent.add(addr)
                } catch (e: MessagingException) {
                    if (_session.getDebug()) {
                        println("DEBUG TLS SMTP: RCPT TO 失败: ${e.message}")
                    }
                    invalidAddr.add(addr)
                }
            }
            if (validSent.isEmpty()) {
                throw SendFailedException("没有有效的收件人",
                    Array<Address>(), Array<Address>(), invalidAddr.toArray())
            }
            sendData(message)
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 消息成功发送给 ${validSent.size} 个收件人")
        }

        // 事件通知
        notifyTransportListeners(message, validSent.toArray(), Array<Address>(), invalidAddr.toArray())

        let effectiveSendPartial = _sendPartial || match (message) {
            case sm: SMTPMessage => sm.isSendPartial()
            case _ => false
        }
        if (!effectiveSendPartial && !invalidAddr.isEmpty()) {
            throw SendFailedException(
                "部分收件人发送失败",
                validSent.toArray(),
                Array<Address>(),
                invalidAddr.toArray()
            )
        }
    }

    private func mailFrom(sender: Address, extraParams: String): Unit {
        let senderAddr = match (sender) {
            case ia: InternetAddress => ia.getAddress()
            case _ => sender.toString()
        }
        var cmd = "MAIL FROM:<${senderAddr}>"
        if (!extraParams.isEmpty()) { cmd += " ${extraParams}" }
        sendCommand(cmd)
        let response = readResponse()
        if (_lastReturnCode != 250) {
            throw MessagingException("MAIL FROM 失败 [${_lastReturnCode}]: ${response}")
        }
    }

    private func buildTlsMailFromParams(message: Message): String {
        var params = ""
        if (supportsExtension("SIZE")) {
            let msgSize = match (message) { case mm: MimeMessage => mm.getSize(); case _ => 0 }
            if (msgSize > 0) {
                match (getExtensionParameter("SIZE")) {
                    case Some(maxStr) =>
                        let maxSize = try { Int64.parse(maxStr.trimAscii()) } catch (_: Exception) { 0 }
                        if (maxSize > 0 && msgSize > maxSize) {
                            throw MessagingException("消息大小(${msgSize}B)超过服务器限制(${maxSize}B)")
                        }
                    case None => ()
                }
                params += " SIZE=${msgSize}"
            }
        }
        let allow8bit = _allow8bitMIME || match (message) {
            case sm: SMTPMessage => sm.isAllow8bitMIME()
            case _ => false
        }
        if (allow8bit && supportsExtension("8BITMIME")) {
            params += " BODY=8BITMIME"
        }

        // SMTPUTF8（RFC 6531）
        let needUtf8 = _useSmtpUtf8 || match (message) {
            case sm: SMTPMessage => sm.isSmtpUtf8()
            case _ => false
        }
        if (needUtf8 && supportsExtension("SMTPUTF8")) {
            params += " SMTPUTF8"
        }

        // DSN（RFC 1891）：RET= + ENVID=
        if (supportsExtension("DSN")) {
            match (message) {
                case sm: SMTPMessage =>
                    let ret = sm.getReturnOption()
                    if (ret == RETURN_FULL) { params += " RET=FULL" }
                    else if (ret == RETURN_HDRS) { params += " RET=HDRS" }
                    match (sm.getEnvelopeId()) {
                        case Some(id) => params += " ENVID=${id}"
                        case None => ()
                    }
                case _ => ()
            }
        }

        match (message) {
            case sm: SMTPMessage =>
                match (sm.getMailExtension()) {
                    case Some(ext) => params += " ${ext}"
                    case None => ()
                }
            case _ => ()
        }
        params.trimAscii()
    }

    private func buildTlsRcptDsnParams(message: Message): String {
        if (!supportsExtension("DSN")) { return "" }
        let notifyOpts = match (message) {
            case sm: SMTPMessage => sm.getNotifyOptions()
            case _ => NOTIFY_NEVER
        }
        if (notifyOpts == NOTIFY_NEVER) { return "" }
        var parts = ArrayList<String>()
        if ((notifyOpts & NOTIFY_SUCCESS) == NOTIFY_SUCCESS) { parts.add("SUCCESS") }
        if ((notifyOpts & NOTIFY_FAILURE) == NOTIFY_FAILURE) { parts.add("FAILURE") }
        if ((notifyOpts & NOTIFY_DELAY) == NOTIFY_DELAY)     { parts.add("DELAY") }
        if (parts.isEmpty()) { return "" }
        var result = "NOTIFY="
        for (i in 0..parts.size) {
            if (i > 0) { result += "," }
            result += parts[i]
        }
        result
    }

    private func parseTlsEnhancedStatus(response: String): String {
        let firstLine = match (response.indexOf("\n")) {
            case Some(idx) => response[0..idx].trimAscii()
            case None      => response.trimAscii()
        }
        if (firstLine.size < 5) { return "" }
        let text = firstLine[4..firstLine.size].trimAscii()
        if (text.isEmpty()) { return "" }
        let runes = text.toRuneArray()
        if (runes.size >= 5
            && runes[0] >= r'1' && runes[0] <= r'5'
            && runes[1] == r'.'
            && runes[2] >= r'0' && runes[2] <= r'9'
            && runes[3] == r'.') {
            var end = 4
            while (end < runes.size && runes[end] != r' ') { end++ }
            text[0..end]
        } else {
            ""
        }
    }

    private func rcptTo(recipient: Address, dsnParams: String): Unit {
        let recipientAddr = match (recipient) {
            case ia: InternetAddress => ia.getAddress()
            case _ => recipient.toString()
        }
        var cmd = "RCPT TO:<${recipientAddr}>"
        if (!dsnParams.isEmpty()) { cmd += " ${dsnParams}" }
        sendCommand(cmd)
        let response = readResponse()
        if (_lastReturnCode != 250 && _lastReturnCode != 251) {
            throw MessagingException("RCPT TO 失败 [${_lastReturnCode}]: ${response}")
        }
    }

    private func sendData(message: Message): Unit {
        if (supportsExtension("CHUNKING")) {
            sendDataBdat(message)
            return
        }
        sendCommand("DATA")
        let response = readResponse()
        if (_lastReturnCode != 354) {
            throw MessagingException("DATA 失败 [${_lastReturnCode}]: ${response}")
        }
        sendTlsDotStuffedBodyAndWait(message)
    }

    private func sendTlsDotStuffedBodyAndWait(message: Message): Unit {
        let content = match (message) {
            case mm: MimeMessage => mm.getMessageString(["Bcc"])
            case _ => throw MessagingException("不支持的消息类型")
        }
        let lines = content.split("\n")
        for (line in lines) {
            var lineToSend = line
            if (lineToSend.endsWith("\r")) { lineToSend = lineToSend[0..(lineToSend.size - 1)] }
            if (lineToSend.startsWith(".")) { lineToSend = "." + lineToSend }
            writeToSocket("${lineToSend}\r\n")
        }
        writeToSocket(".\r\n")
        let finalResp = readResponse()
        if (_lastReturnCode != 250) {
            throw MessagingException("DATA END 失败 [${_lastReturnCode}]: ${finalResp}")
        }
    }

    private func sendTlsMessagePipelined(
        message: Message,
        envelopeSender: Address,
        mailParams: String,
        addresses: Array<Address>,
        validSent: ArrayList<Address>,
        invalidAddr: ArrayList<Address>
    ): Unit {
        let senderAddr = match (envelopeSender) {
            case ia: InternetAddress => ia.getAddress()
            case _ => envelopeSender.toString()
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: [PIPELINING] 批量发送 ${1 + addresses.size + 1} 个命令")
        }

        // 阶段一：批量写出命令
        var mailCmd = "MAIL FROM:<${senderAddr}>"
        if (!mailParams.isEmpty()) { mailCmd += " ${mailParams}" }
        writeToSocket("${mailCmd}\r\n")

        let dsnParams = buildTlsRcptDsnParams(message)
        for (addr in addresses) {
            let recipientAddr = match (addr) {
                case ia: InternetAddress => ia.getAddress()
                case _ => addr.toString()
            }
            var rcptCmd = "RCPT TO:<${recipientAddr}>"
            if (!dsnParams.isEmpty()) { rcptCmd += " ${dsnParams}" }
            writeToSocket("${rcptCmd}\r\n")
        }
        writeToSocket("DATA\r\n")

        // 阶段二：读取 MAIL FROM
        let mailResp = readResponse()
        if (_lastReturnCode != 250) {
            for (_ in 0..(addresses.size + 1)) { try { readResponse() } catch (_: Exception) {} }
            throw MessagingException("MAIL FROM 失败 [${_lastReturnCode}]: ${mailResp}")
        }

        // 阶段三：读取各 RCPT TO
        for (addr in addresses) {
            readResponse()
            if (_lastReturnCode == 250 || _lastReturnCode == 251) {
                validSent.add(addr)
            } else {
                invalidAddr.add(addr)
            }
        }

        // 阶段四：读取 DATA 354
        let dataResp = readResponse()
        if (validSent.isEmpty()) {
            if (_lastReturnCode == 354) {
                writeToSocket(".\r\n")
                try { readResponse() } catch (_: Exception) {}
            }
            throw SendFailedException("没有有效的收件人",
                Array<Address>(), Array<Address>(), invalidAddr.toArray())
        }
        if (_lastReturnCode != 354) {
            throw MessagingException("DATA 失败 [${_lastReturnCode}]: ${dataResp}")
        }

        // 阶段五：发送正文
        if (_session.getDebug()) { println("DEBUG TLS SMTP: [PIPELINING] 发送邮件正文") }
        sendTlsDotStuffedBodyAndWait(message)
    }

    private func sendDataBdat(message: Message): Unit {
        let content = match (message) {
            case mm: MimeMessage => mm.getMessageString(["Bcc"])
            case _ => throw MessagingException("不支持的消息类型")
        }
        let bytes = content.toArray()
        let total = bytes.size

        if (total == 0) {
            writeToSocket("BDAT 0 LAST\r\n")
            let r = readResponse()
            if (_lastReturnCode != 250) {
                throw MessagingException("BDAT 失败 [${_lastReturnCode}]: ${r}")
            }
            return
        }

        var offset = 0
        while (offset < total) {
            let remaining = total - offset
            let chunkSize = if (remaining <= _chunkSize) { remaining } else { _chunkSize }
            let isLast = (offset + chunkSize >= total)
            let cmd = if (isLast) { "BDAT ${chunkSize} LAST\r\n" } else { "BDAT ${chunkSize}\r\n" }
            writeToSocket(cmd)

            let chunk = Array<Byte>(chunkSize, repeat: 0u8)
            for (i in 0..chunkSize) { chunk[i] = bytes[offset + i] }
            writeBytesToSocket(chunk)

            let r = readResponse()
            if (_lastReturnCode != 250) {
                throw MessagingException("BDAT 失败 [${_lastReturnCode}]: ${r}")
            }
            offset += chunkSize
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: BDAT 传输完成，共 ${total} 字节")
        }
    }

    // -------------------------------------------------------------------------
    // 关闭
    // -------------------------------------------------------------------------

    public override func close(): Unit {
        if (_connected) {
            try {
                sendCommand("QUIT")
                if (_quitWait) { readResponse() }
            } catch (_: Exception) {}
        }

        match (_tlsSocket) {
            case Some(s) => try { s.close() } catch (_: Exception) {}
            case None => ()
        }
        match (_tlsConfig) {
            case Some(c) => try { c.close() } catch (_: Exception) {}
            case None => ()
        }

        closeRawFd()

        _tlsSocket = None
        _tlsConfig = None
        _connected = false
        notifyConnectionClosed()
    }

    private func closeRawFd(): Unit {
        if (_rawFd >= 0) {
            closeFd(_rawFd)
            _rawFd = -1
        }
    }

    // -------------------------------------------------------------------------
    // 公开查询 API（与 SMTPTransport 对称）
    // -------------------------------------------------------------------------

    public func supportsExtension(ext: String): Bool {
        _extMap.contains(ext.toAsciiUpper())
    }

    public func getExtensionParameter(ext: String): ?String {
        _extMap.get(ext.toAsciiUpper())
    }

    public func getLastServerResponse(): String {
        _lastServerResponse
    }

    public func getLastReturnCode(): Int64 {
        _lastReturnCode
    }

    public func getLastEnhancedStatus(): String {
        _lastEnhancedStatus
    }

    public func noop(): Bool {
        if (!_connected) { return false }
        try {
            sendCommand("NOOP")
            readResponse()
            _lastReturnCode == 250
        } catch (_: Exception) { false }
    }

    public func reset(): Bool {
        if (!_connected) { return false }
        try {
            sendCommand("RSET")
            readResponse()
            _lastReturnCode == 250
        } catch (_: Exception) { false }
    }

    /**
     * 使用已有 socket fd 建立 TLS SMTP 会话（适用于代理场景）
     * 在现有 fd 上直接做 TLS 握手
     */
    public func connectWithFd(fd: Int32, user: String, password: String): Unit {
        if (_connected) { throw MessagingException("已经连接") }

        let config = buildTlsConfig()
        try {
            config.initialize()
            if (_verifyCert) { config.loadCertificates() }
        } catch (e: TlsException) {
            throw MessagingException("TLS 配置失败: ${e.message}")
        }
        _tlsConfig = Some(config)

        let tlsSocket = TlsSocket(config)
        applySocketTimeouts(tlsSocket)
        try {
            tlsSocket.connectWithFd(fd)
        } catch (e: TlsException) {
            try { config.close() } catch (_: Exception) {}
            _tlsConfig = None
            throw MessagingException("TLS 握手失败: ${e.message}")
        }

        _tlsSocket = Some(tlsSocket)
        _connected = true
        notifyConnectionOpened()

        try {
            doSmtpHandshake(user, password)
        } catch (e: Exception) {
            _connected = false
            close()
            throw e
        }
    }

    // -------------------------------------------------------------------------
    // 底层 I/O（路由：TLS socket → 原始 socket）
    // -------------------------------------------------------------------------

    private func sendCommand(cmd: String): Unit {
        if (_session.getDebug()) {
            let isAuth = cmd.startsWith("AUTH") || cmd.startsWith("auth")
            if (isAuth && _noAuthDebug) {
                // noauthdebug=true: 不输出认证命令
            } else if (isAuth && cmd.size > 20) {
                println("DEBUG TLS SMTP: C: AUTH ***")
            } else {
                println("DEBUG TLS SMTP: C: ${cmd}")
            }
        }
        writeToSocket("${cmd}\r\n")
    }

    private func writeToSocket(data: String): Unit {
        match (_tlsSocket) {
            case Some(s) => s.write(data.toArray())
            case None =>
                if (_rawFd >= 0) {
                    rawSocketWrite(_rawFd, data.toArray())
                } else {
                    throw MessagingException("未连接")
                }
        }
    }

    private func writeBytesToSocket(data: Array<Byte>): Unit {
        match (_tlsSocket) {
            case Some(s) => s.write(data)
            case None =>
                if (_rawFd >= 0) {
                    rawSocketWrite(_rawFd, data)
                } else {
                    throw MessagingException("未连接")
                }
        }
    }

    private func readResponse(): String {
        var response = ""
        var continuing = true

        while (continuing) {
            let line = readLine()
            response += line + "\n"

            if (line.size >= 3) {
                let codeStr = line[0..3]
                _lastReturnCode = try {
                    Int64.parse(codeStr)
                } catch (_: Exception) {
                    0
                }
                continuing = line.size > 3 && line[3..4] == "-"
            } else {
                continuing = false
            }
        }

        _lastServerResponse = response.trimAscii()
        _lastEnhancedStatus = parseTlsEnhancedStatus(_lastServerResponse)

        if (_session.getDebug()) {
            for (line in _lastServerResponse.split("\n")) {
                println("DEBUG TLS SMTP: S: ${line}")
            }
        }

        _lastServerResponse
    }

    private func readLine(): String {
        match (_tlsSocket) {
            case Some(s) => s.readLine()
            case None =>
                if (_rawFd >= 0) {
                    rawReadLineFromFd()
                } else {
                    throw MessagingException("未连接")
                }
        }
    }

    /** 从原始 TCP socket fd 读取一行（STARTTLS 升级前的明文阶段） */
    private func rawReadLineFromFd(): String {
        var result = ""
        while (true) {
            let b = rawSocketReadByte(_rawFd)
            if (b < 0) { break }
            let ch = Rune(UInt8(b))
            if (ch == r'\n') { break }
            else if (ch != r'\r') { result += ch.toString() }
        }
        result
    }
}
