/**
 * SMTP 传输实现
 *
 * 使用原始 socket（FFI）实现连接，支持：
 * - 连接/读/写超时（SO_RCVTIMEO / SO_SNDTIMEO）
 * - 真正的 STARTTLS socket 升级（明文 → TLS）
 */
package mail.smtp

import mail.core.*
import mail.internet.*
import mail.util.*
import mail.tls.*
import std.collection.*
import std.convert.*

/**
 * SMTP 传输实现
 * 对应：org.eclipse.angus.mail.smtp.SMTPTransport
 */
public class SMTPTransport <: Transport {
    // 协议配置
    private var _name: String = "smtp"
    private var _defaultPort: Int64 = 25
    private var _isSSL: Bool = false

    // 连接状态
    private var _host: String = ""
    private var _port: Int64 = 25
    private var _rawFd: Int32 = -1         // 明文 TCP fd
    private var _tlsSocket: ?TlsSocket = None  // STARTTLS 升级后的 TLS socket
    private var _tlsConfig: ?TlsConfig = None

    // ESMTP 扩展
    private var _extMap: HashMap<String, String> = HashMap<String, String>()
    private var _serverAuthMechanisms: ArrayList<String> = ArrayList<String>()

    // 配置选项
    private var _useStartTLS: Bool = false
    private var _requireStartTLS: Bool = false
    private var _localHost: ?String = None

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
    private var _quitWait: Bool = true             // 等待 QUIT 的 221 响应
    private var _quitOnSessionReject: Bool = true  // 服务器拒绝问候时发 QUIT
    private var _noAuthDebug: Bool = false         // 不记录认证命令调试日志
    private var _allow8bitMIME: Bool = false       // MAIL FROM 声明 BODY=8BITMIME
    private var _ownsFd: Bool = true               // 是否负责关闭 _rawFd
    private var _chunkSize: Int64 = 65536          // BDAT 分块大小（64 KB）
    private var _useSmtpUtf8: Bool = false         // SMTPUTF8（RFC 6531）

    // 响应状态
    private var _lastServerResponse: String = ""
    private var _lastReturnCode: Int64 = 0
    private var _lastEnhancedStatus: String = ""  // RFC 2034 增强状态码（N.N.N）

    public init(session: Session, isSSL: Bool) {
        super(session)
        _isSSL = isSSL
        _name = if (isSSL) { "smtps" } else { "smtp" }
        _defaultPort = if (isSSL) { 465 } else { 25 }
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
        _oauthToken = _session.getProperty("${prefix}auth.xoauth2.token")
        _ntlmDomain = _session.getProperty("${prefix}auth.ntlm.domain", "")
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
        // 单独禁用特定认证机制
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

    // -------------------------------------------------------------------------
    // 连接
    // -------------------------------------------------------------------------

    public override func connect(host: String, port: Int64, user: String, password: String): Unit {
        _host = host
        _port = if (port > 0) { port } else { _defaultPort }

        if (_session.getDebug()) {
            println("DEBUG SMTP: 正在连接 ${_host}:${_port}")
        }

        _rawFd = createTcpConnection(_host, UInt16(_port))
        if (_rawFd < 0) {
            throw MailConnectException(_host, _port, _connectTimeout,
                Exception("无法建立 TCP 连接到 ${_host}:${_port}"))
        }

        // 应用 I/O 超时
        if (_readTimeout > 0 || _writeTimeout > 0) {
            unsafe { setSocketTimeouts(_rawFd, _readTimeout, _writeTimeout) }
        }

        _connected = true
        notifyConnectionOpened()

        try {
            // 读取服务器问候语
            let greeting = readResponse()
            if (_lastReturnCode != 220) {
                if (_quitOnSessionReject) {
                    try { sendCommand("QUIT") } catch (_: Exception) {}
                }
                throw MessagingException("SMTP 服务器拒绝连接: ${greeting}")
            }

            if (_session.getDebug()) {
                println("DEBUG SMTP: 已连接，问候语: ${greeting}")
            }

            let localHost = match (_localHost) { case Some(h) => h; case None => "localhost" }
            if (!ehlo(localHost)) { helo(localHost) }

            // STARTTLS 升级
            if (_useStartTLS && supportsExtension("STARTTLS")) {
                startTLS(localHost)
            } else if (_requireStartTLS && !_isSSL) {
                throw MessagingException("需要 STARTTLS 但服务器不支持")
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
            cleanupConnections()
            throw e
        }
    }

    /**
     * 完成 STARTTLS 升级：发送 STARTTLS 命令 → TLS 握手 → 替换 I/O 路径
     */
    private func startTLS(localHost: String): Unit {
        sendCommand("STARTTLS")
        let response = readResponse()
        if (_lastReturnCode != 220) {
            throw MessagingException("STARTTLS 失败: ${response}")
        }

        // 在现有 TCP 连接上建立 TLS
        let config = createClientConfig()
        try {
            config.initialize()
        } catch (e: TlsException) {
            throw MessagingException("STARTTLS TLS 配置失败: ${e.message}")
        }
        _tlsConfig = Some(config)

        let tlsSocket = TlsSocket(config)
        if (_readTimeout > 0) { tlsSocket.setReadTimeout(_readTimeout) }
        if (_writeTimeout > 0) { tlsSocket.setWriteTimeout(_writeTimeout) }

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
            println("DEBUG SMTP: STARTTLS 升级完成")
        }

        // RFC 要求 STARTTLS 后重新 EHLO（扩展列表已重置）
        _extMap.clear()
        _serverAuthMechanisms.clear()
        if (!ehlo(localHost)) { helo(localHost) }
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
            println("DEBUG SMTP: EHLO 扩展: ${_extMap}")
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
            println("DEBUG SMTP: 正在认证，用户: ${user}")
        }
        // 过滤禁用的认证机制
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
    // 发送邮件
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
        let sender = from[0]

        // SMTPMessage: 优先使用信封 From
        let envelopeSender: Address = match (message) {
            case sm: SMTPMessage =>
                match (sm.getEnvelopeFrom()) {
                    case Some(ef) => InternetAddress(ef)
                    case None => sender
                }
            case _ => sender
        }

        // 构造 MAIL FROM 扩展参数
        let mailParams = buildMailFromParams(message)
        let validSent = ArrayList<Address>()
        let invalidAddr = ArrayList<Address>()

        // PIPELINING（RFC 2920）：服务器支持且不使用 BDAT 时批量发送命令
        if (supportsExtension("PIPELINING") && !supportsExtension("CHUNKING")) {
            sendMessagePipelined(message, envelopeSender, mailParams, addresses, validSent, invalidAddr)
        } else {
            mailFrom(envelopeSender, mailParams)
            let dsnParams = buildRcptDsnParams(message)
            for (addr in addresses) {
                try {
                    rcptTo(addr, dsnParams)
                    validSent.add(addr)
                } catch (e: SMTPAddressFailedException) {
                    invalidAddr.add(addr)
                }
            }
            if (validSent.isEmpty()) {
                throw SMTPSendFailedException(
                    "RCPT", _lastReturnCode, "没有有效的收件人",
                    Array<Address>(), Array<Address>(), invalidAddr.toArray()
                )
            }
            sendData(message)
        }

        if (_session.getDebug()) {
            println("DEBUG SMTP: 消息成功发送给 ${validSent.size} 个收件人")
        }

        // 事件通知
        notifyTransportListeners(message, validSent.toArray(), Array<Address>(), invalidAddr.toArray())

        // sendPartial：消息级优先，其次传输级配置
        let effectiveSendPartial = _sendPartial || match (message) {
            case sm: SMTPMessage => sm.isSendPartial()
            case _ => false
        }

        if (!effectiveSendPartial && !invalidAddr.isEmpty()) {
            throw SMTPSendFailedException(
                "RCPT",
                _lastReturnCode,
                "部分收件人无效",
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
            throw SMTPSenderFailedException(
                InternetAddress(senderAddr),
                "MAIL FROM",
                _lastReturnCode,
                response
            )
        }
    }

    private func buildMailFromParams(message: Message): String {
        var params = ""

        // SIZE 扩展：声明消息大小并检查服务器上限
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

        // 8BITMIME 扩展
        let allow8bit = _allow8bitMIME || match (message) {
            case sm: SMTPMessage => sm.isAllow8bitMIME()
            case _ => false
        }
        if (allow8bit && supportsExtension("8BITMIME")) {
            params += " BODY=8BITMIME"
        }

        // SMTPUTF8（RFC 6531）：允许 UTF-8 邮件地址
        let needUtf8 = _useSmtpUtf8 || match (message) {
            case sm: SMTPMessage => sm.isSmtpUtf8()
            case _ => false
        }
        if (needUtf8 && supportsExtension("SMTPUTF8")) {
            params += " SMTPUTF8"
        }

        // DSN（RFC 1891）：RET= 返回类型 + ENVID= 信封 ID
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

        // SMTPMessage 自定义扩展参数
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

    private func buildRcptDsnParams(message: Message): String {
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
            throw SMTPAddressFailedException(
                InternetAddress(recipientAddr),
                "RCPT TO",
                _lastReturnCode,
                response
            )
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
            throw SMTPSendFailedException("DATA", _lastReturnCode, response,
                Array<Address>(), message.getAllRecipients(), Array<Address>())
        }
        sendDotStuffedBodyAndWait(message)
    }

    private func sendDotStuffedBodyAndWait(message: Message): Unit {
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
            throw SMTPSendFailedException("DATA END", _lastReturnCode, finalResp,
                Array<Address>(), message.getAllRecipients(), Array<Address>())
        }
    }

    private func sendMessagePipelined(
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
            println("DEBUG SMTP: [PIPELINING] 批量发送 ${1 + addresses.size + 1} 个命令")
        }

        // 阶段一：批量写出命令，不读响应
        var mailCmd = "MAIL FROM:<${senderAddr}>"
        if (!mailParams.isEmpty()) { mailCmd += " ${mailParams}" }
        writeToSocket("${mailCmd}\r\n")

        let dsnParams = buildRcptDsnParams(message)
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

        // 阶段二：按顺序读取 MAIL FROM 响应
        let mailResp = readResponse()
        if (_lastReturnCode != 250) {
            for (_ in 0..(addresses.size + 1)) { try { readResponse() } catch (_: Exception) {} }
            throw SMTPSenderFailedException(
                InternetAddress(senderAddr), "MAIL FROM", _lastReturnCode, mailResp)
        }

        // 阶段三：读取各 RCPT TO 响应
        for (addr in addresses) {
            readResponse()
            if (_lastReturnCode == 250 || _lastReturnCode == 251) {
                validSent.add(addr)
            } else {
                invalidAddr.add(addr)
                if (_session.getDebug()) {
                    println("DEBUG SMTP: [PIPELINING] RCPT 失败 [${_lastReturnCode}]")
                }
            }
        }

        // 阶段四：读取 DATA 354
        let dataResp = readResponse()
        if (validSent.isEmpty()) {
            if (_lastReturnCode == 354) {
                writeToSocket(".\r\n")
                try { readResponse() } catch (_: Exception) {}
            }
            throw SMTPSendFailedException("RCPT", _lastReturnCode, "没有有效的收件人",
                Array<Address>(), Array<Address>(), invalidAddr.toArray())
        }
        if (_lastReturnCode != 354) {
            throw SMTPSendFailedException("DATA", _lastReturnCode, dataResp,
                Array<Address>(), message.getAllRecipients(), Array<Address>())
        }

        // 阶段五：发送邮件正文
        if (_session.getDebug()) { println("DEBUG SMTP: [PIPELINING] 发送邮件正文") }
        sendDotStuffedBodyAndWait(message)
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
                throw SMTPSendFailedException("BDAT", _lastReturnCode, r,
                    Array<Address>(), message.getAllRecipients(), Array<Address>())
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
                throw SMTPSendFailedException("BDAT", _lastReturnCode, r,
                    Array<Address>(), message.getAllRecipients(), Array<Address>())
            }
            offset += chunkSize
        }

        if (_session.getDebug()) {
            println("DEBUG SMTP: BDAT 传输完成，共 ${total} 字节")
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

        if (_rawFd >= 0) {
            if (_ownsFd) { closeFd(_rawFd) }
            _rawFd = -1
        }

        _tlsSocket = None
        _tlsConfig = None
        _connected = false
        notifyConnectionClosed()
    }

    private func cleanupConnections(): Unit {
        match (_tlsSocket) {
            case Some(s) => try { s.close() } catch (_: Exception) {}
            case None => ()
        }
        match (_tlsConfig) {
            case Some(c) => try { c.close() } catch (_: Exception) {}
            case None => ()
        }
        if (_rawFd >= 0) {
            closeFd(_rawFd)
            _rawFd = -1
        }
        _tlsSocket = None
        _tlsConfig = None
    }

    // -------------------------------------------------------------------------
    // 公开查询 API
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

    /**
     * 获取最后响应的 RFC 2034 增强状态码（如 "2.1.5"）
     */
    public func getLastEnhancedStatus(): String {
        _lastEnhancedStatus
    }

    /**
     * 发送 NOOP 命令（连接保活探测）
     * 对应：angus-mail SMTPTransport.noop
     */
    public func noop(): Bool {
        if (!_connected) { return false }
        try {
            sendCommand("NOOP")
            readResponse()
            _lastReturnCode == 250
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 发送 RSET 命令（重置 SMTP 状态机）
     * 对应：angus-mail SMTPTransport.rset
     */
    public func reset(): Bool {
        if (!_connected) { return false }
        try {
            sendCommand("RSET")
            readResponse()
            _lastReturnCode == 250
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 使用已有 socket 文件描述符建立 SMTP 会话（不创建新连接）
     * 适用于通过代理/stunnel 预先建立的连接
     */
    public func connectWithFd(fd: Int32, user: String, password: String): Unit {
        if (_connected) { throw MessagingException("已经连接") }

        _rawFd  = fd
        _ownsFd = false  // 不拥有 fd，由调用方负责关闭

        if (_readTimeout > 0 || _writeTimeout > 0) {
            unsafe { setSocketTimeouts(_rawFd, _readTimeout, _writeTimeout) }
        }

        _connected = true
        notifyConnectionOpened()

        try {
            let greeting = readResponse()
            if (_lastReturnCode != 220) {
                if (_quitOnSessionReject) {
                    try { sendCommand("QUIT") } catch (_: Exception) {}
                }
                throw MessagingException("SMTP 服务器拒绝连接: ${greeting}")
            }

            let localHost = match (_localHost) { case Some(h) => h; case None => "localhost" }
            if (!ehlo(localHost)) { helo(localHost) }

            if (_useStartTLS && supportsExtension("STARTTLS")) {
                startTLS(localHost)
            } else if (_requireStartTLS && !_isSSL) {
                throw MessagingException("需要 STARTTLS 但服务器不支持")
            }

            if (!user.isEmpty() && !password.isEmpty()) {
                authenticate(user, password)
            }

        } catch (e: Exception) {
            _connected = false
            _rawFd = -1
            throw e
        }
    }

    // -------------------------------------------------------------------------
    // 底层 I/O（路由：TLS socket → 原始 TCP socket）
    // -------------------------------------------------------------------------

    private func sendCommand(cmd: String): Unit {
        if (_session.getDebug()) {
            let isAuth = cmd.startsWith("AUTH") || cmd.startsWith("auth")
            if (isAuth && _noAuthDebug) {
                // noauthdebug=true: 不输出任何认证命令
            } else if (isAuth && cmd.size > 20) {
                println("DEBUG SMTP: C: AUTH ***")
            } else {
                println("DEBUG SMTP: C: ${cmd}")
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

        // 解析 RFC 2034 增强状态码（N.N.N，如 "2.1.5"）
        _lastEnhancedStatus = parseEnhancedStatus(_lastServerResponse)

        if (_session.getDebug()) {
            for (line in _lastServerResponse.split("\n")) {
                println("DEBUG SMTP: S: ${line}")
            }
        }

        _lastServerResponse
    }

    private func parseEnhancedStatus(response: String): String {
        // 取第一行，跳过 3 位状态码和分隔符
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

    private func readLine(): String {
        match (_tlsSocket) {
            case Some(s) => s.readLine()
            case None =>
                if (_rawFd >= 0) {
                    rawReadLineFromFd(_rawFd)
                } else {
                    throw MessagingException("未连接")
                }
        }
    }

    private func rawReadLineFromFd(fd: Int32): String {
        var result = ""
        while (true) {
            let b = rawSocketReadByte(fd)
            if (b < 0) { break }
            let ch = Rune(UInt8(b))
            if (ch == r'\n') { break }
            else if (ch != r'\r') { result += ch.toString() }
        }
        result
    }
}
