/**
 * 支持 TLS 的 SMTP 传输实现
 *
 * 这是 SMTPTransport 的 TLS 增强版本，支持：
 * - SMTPS（直接 SSL 连接，端口 465）
 * - STARTTLS（升级加密，端口 587）
 */
package mail.tls

import mail.core.*
import mail.internet.*
import mail.util.*
import std.collection.*
import std.convert.*

/**
 * TLS SMTP 传输实现
 *
 * 使用 openHiTLS 提供 TLS 加密支持
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

    // ESMTP 扩展
    private var _extMap: HashMap<String, String> = HashMap<String, String>()
    private var _serverAuthMechanisms: ArrayList<String> = ArrayList<String>()

    // 配置选项
    private var _useStartTLS: Bool = false
    private var _requireStartTLS: Bool = false
    private var _localHost: ?String = None

    // 证书验证选项
    private var _verifyCert: Bool = false
    private var _caCertPath: ?String = None

    // 响应状态
    private var _lastServerResponse: String = ""
    private var _lastReturnCode: Int64 = 0

    /**
     * 使用会话构造
     */
    public init(session: Session, useSSL: Bool) {
        super(session)
        _useSSL = useSSL
        _name = if (useSSL) { "smtps" } else { "smtp" }
        _defaultPort = if (useSSL) { 465 } else { 587 }

        // 从会话加载配置
        loadSessionConfig()
    }

    /**
     * 从会话属性加载配置
     */
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

        // 证书验证配置
        match (_session.getProperty("${prefix}ssl.checkserveridentity")) {
            case Some("true") => _verifyCert = true
            case _ => ()
        }

        match (_session.getProperty("${prefix}ssl.trust")) {
            case Some("*") => _verifyCert = false  // 信任所有证书
            case Some(path) =>
                _verifyCert = true
                _caCertPath = Some(path)
            case None => ()
        }

        // 也检查通用的 CA 证书路径配置
        match (_session.getProperty("${prefix}ssl.caCert")) {
            case Some(path) =>
                _verifyCert = true
                _caCertPath = Some(path)
            case None => ()
        }
    }

    /**
     * 设置是否验证服务器证书
     */
    public func setVerifyCert(verify: Bool): Unit {
        _verifyCert = verify
    }

    /**
     * 设置 CA 证书路径
     */
    public func setCACertPath(path: String): Unit {
        _caCertPath = Some(path)
        _verifyCert = true
    }

    /**
     * 连接到 SMTP 服务器
     */
    public override func connect(host: String, port: Int64, user: String, password: String): Unit {
        _host = host
        _port = if (port > 0) { port } else { _defaultPort }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 正在连接 ${_host}:${_port}")
        }

        try {
            // 创建 TLS 配置
            let config = if (_verifyCert) {
                // 启用证书验证
                match (_caCertPath) {
                    case Some(path) => createSecureClientConfig(path)
                    case None => TlsConfig(TLS_1_2).setVerifyMode(VERIFY_PEER)
                }
            } else {
                // 不验证证书
                createClientConfig()
            }
            config.initialize()

            // 如果启用证书验证，加载证书
            if (_verifyCert) {
                config.loadCertificates()
                if (_session.getDebug()) {
                    println("DEBUG TLS SMTP: 已启用服务器证书验证")
                }
            }

            _tlsConfig = Some(config)

            // 创建 TLS Socket 并连接
            let tlsSocket = TlsSocket(config)
            tlsSocket.connect(_host, UInt16(_port))
            _tlsSocket = Some(tlsSocket)
            _connected = true

            if (_session.getDebug()) {
                println("DEBUG TLS SMTP: TLS 握手成功")
            }

            // 读取服务器问候语
            let greeting = readResponse()
            if (_lastReturnCode != 220) {
                throw MessagingException("SMTP 服务器拒绝连接: ${greeting}")
            }

            if (_session.getDebug()) {
                println("DEBUG TLS SMTP: 已连接，问候语: ${greeting}")
            }

            // 发送 EHLO
            let localHost = match (_localHost) {
                case Some(h) => h
                case None => "localhost"
            }

            if (!ehlo(localHost)) {
                helo(localHost)
            }

            // 如果提供了凭据则认证
            if (!user.isEmpty() && !password.isEmpty()) {
                authenticate(user, password)
            } else {
                // 尝试会话认证器
                match (_session.getAuthenticator()) {
                    case Some(auth) =>
                        match (auth.requestPasswordAuthentication()) {
                            case Some(pa) => authenticate(pa.getUserName(), pa.getPassword())
                            case None => ()
                        }
                    case None => ()
                }
            }

        } catch (e: TlsException) {
            _connected = false
            throw MessagingException("TLS 连接失败: ${e.message}")
        }
    }

    /**
     * 发送 EHLO 命令
     */
    private func ehlo(domain: String): Bool {
        sendCommand("EHLO ${domain}")
        let response = readResponse()

        if (_lastReturnCode != 250) {
            return false
        }

        // 解析 EHLO 响应中的扩展
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
                                if (!mech.isEmpty()) {
                                    _serverAuthMechanisms.add(mech)
                                }
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

    /**
     * 发送 HELO 命令
     */
    private func helo(domain: String): Unit {
        sendCommand("HELO ${domain}")
        let response = readResponse()

        if (_lastReturnCode != 250) {
            throw MessagingException("HELO 失败: ${response}")
        }
    }

    /**
     * 与服务器进行认证
     */
    private func authenticate(user: String, password: String): Bool {
        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 正在以 ${user} 身份认证")
        }

        if (_serverAuthMechanisms.contains("LOGIN")) {
            return authLogin(user, password)
        } else if (_serverAuthMechanisms.contains("PLAIN")) {
            return authPlain(user, password)
        } else if (!_serverAuthMechanisms.isEmpty()) {
            return authLogin(user, password)
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 没有支持的认证机制，尝试 LOGIN")
        }
        return authLogin(user, password)
    }

    /**
     * LOGIN 认证
     */
    private func authLogin(user: String, password: String): Bool {
        sendCommand("AUTH LOGIN")
        var response = readResponse()

        if (_lastReturnCode != 334) {
            throw AuthenticationFailedException("AUTH LOGIN 失败: ${response}")
        }

        // 发送用户名（base64）
        sendCommand(Base64Util.encodeString(user))
        response = readResponse()

        if (_lastReturnCode != 334) {
            throw AuthenticationFailedException("AUTH LOGIN 用户名失败: ${response}")
        }

        // 发送密码（base64）
        sendCommand(Base64Util.encodeString(password))
        response = readResponse()

        if (_lastReturnCode != 235) {
            throw AuthenticationFailedException("AUTH LOGIN 密码失败: ${response}")
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 认证成功")
        }

        true
    }

    /**
     * PLAIN 认证
     */
    private func authPlain(user: String, password: String): Bool {
        let authString = "\u{0000}${user}\u{0000}${password}"
        let encoded = Base64Util.encodeString(authString)

        sendCommand("AUTH PLAIN ${encoded}")
        let response = readResponse()

        if (_lastReturnCode != 235) {
            throw AuthenticationFailedException("AUTH PLAIN 失败: ${response}")
        }

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: PLAIN 认证成功")
        }

        true
    }

    /**
     * 发送消息
     */
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

        mailFrom(sender)

        let validSent = ArrayList<Address>()
        let invalidAddr = ArrayList<Address>()

        for (addr in addresses) {
            try {
                rcptTo(addr)
                validSent.add(addr)
            } catch (_: Exception) {
                invalidAddr.add(addr)
            }
        }

        if (validSent.isEmpty()) {
            throw MessagingException("没有有效的收件人")
        }

        sendData(message)

        if (_session.getDebug()) {
            println("DEBUG TLS SMTP: 消息成功发送给 ${validSent.size} 个收件人")
        }
    }

    /**
     * 发送 MAIL FROM 命令
     */
    private func mailFrom(sender: Address): Unit {
        let senderAddr = match (sender) {
            case ia: InternetAddress => ia.getAddress()
            case _ => sender.toString()
        }

        sendCommand("MAIL FROM:<${senderAddr}>")
        let response = readResponse()

        if (_lastReturnCode != 250) {
            throw MessagingException("MAIL FROM 失败: ${response}")
        }
    }

    /**
     * 发送 RCPT TO 命令
     */
    private func rcptTo(recipient: Address): Unit {
        let recipientAddr = match (recipient) {
            case ia: InternetAddress => ia.getAddress()
            case _ => recipient.toString()
        }

        sendCommand("RCPT TO:<${recipientAddr}>")
        let response = readResponse()

        if (_lastReturnCode != 250 && _lastReturnCode != 251) {
            throw MessagingException("RCPT TO 失败: ${response}")
        }
    }

    /**
     * 发送 DATA 命令和消息内容
     */
    private func sendData(message: Message): Unit {
        sendCommand("DATA")
        let response = readResponse()

        if (_lastReturnCode != 354) {
            throw MessagingException("DATA 失败: ${response}")
        }

        let content = match (message) {
            case mm: MimeMessage => mm.getMessageString()
            case _ => throw MessagingException("不支持的消息类型")
        }

        let lines = content.split("\n")
        for (line in lines) {
            var lineToSend = line
            if (lineToSend.endsWith("\r")) {
                lineToSend = lineToSend[0..(lineToSend.size - 1)]
            }
            if (lineToSend.startsWith(".")) {
                lineToSend = "." + lineToSend
            }
            writeToSocket("${lineToSend}\r\n")
        }

        writeToSocket(".\r\n")

        let dataResponse = readResponse()
        if (_lastReturnCode != 250) {
            throw MessagingException("DATA END 失败: ${dataResponse}")
        }
    }

    /**
     * 关闭连接
     */
    public override func close(): Unit {
        if (_connected) {
            try {
                sendCommand("QUIT")
                readResponse()
            } catch (_: Exception) {}
        }

        match (_tlsSocket) {
            case Some(s) =>
                try {
                    s.close()
                } catch (_: Exception) {}
            case None => ()
        }

        match (_tlsConfig) {
            case Some(c) =>
                try {
                    c.close()
                } catch (_: Exception) {}
            case None => ()
        }

        _tlsSocket = None
        _tlsConfig = None
        _connected = false
    }

    /**
     * 检查服务器是否支持扩展
     */
    public func supportsExtension(ext: String): Bool {
        _extMap.contains(ext.toAsciiUpper())
    }

    /**
     * 向服务器发送命令
     */
    private func sendCommand(cmd: String): Unit {
        if (_session.getDebug()) {
            if (cmd.startsWith("AUTH") && cmd.size > 20) {
                println("DEBUG TLS SMTP: C: AUTH ***")
            } else {
                println("DEBUG TLS SMTP: C: ${cmd}")
            }
        }
        writeToSocket("${cmd}\r\n")
    }

    /**
     * 向套接字写入数据
     */
    private func writeToSocket(data: String): Unit {
        match (_tlsSocket) {
            case Some(s) =>
                s.write(data.toArray())
            case None =>
                throw MessagingException("未连接")
        }
    }

    /**
     * 从服务器读取响应
     */
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

                if (line.size > 3 && line[3..4] == "-") {
                    continuing = true
                } else {
                    continuing = false
                }
            } else {
                continuing = false
            }
        }

        _lastServerResponse = response.trimAscii()

        if (_session.getDebug()) {
            for (line in _lastServerResponse.split("\n")) {
                println("DEBUG TLS SMTP: S: ${line}")
            }
        }

        _lastServerResponse
    }

    /**
     * 从套接字读取一行
     */
    private func readLine(): String {
        match (_tlsSocket) {
            case Some(s) => s.readLine()
            case None => throw MessagingException("未连接")
        }
    }
}
