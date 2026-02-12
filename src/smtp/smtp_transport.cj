/**
 * SMTP 传输实现
 */
package mail.smtp

import mail.core.*
import mail.internet.*
import mail.util.*
import std.net.*
import std.io.*
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
    private var _socket: ?TcpSocket = None
    private var _reader: ?StringReader<TcpSocket> = None

    // ESMTP 扩展
    private var _extMap: HashMap<String, String> = HashMap<String, String>()
    private var _serverAuthMechanisms: ArrayList<String> = ArrayList<String>()

    // 配置选项
    private var _useStartTLS: Bool = false
    private var _requireStartTLS: Bool = false
    private var _localHost: ?String = None

    // 响应状态
    private var _lastServerResponse: String = ""
    private var _lastReturnCode: Int64 = 0

    /**
     * 使用会话构造
     */
    public init(session: Session, isSSL: Bool) {
        super(session)
        _isSSL = isSSL
        _name = if (isSSL) { "smtps" } else { "smtp" }
        _defaultPort = if (isSSL) { 465 } else { 25 }

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
    }

    /**
     * 连接到 SMTP 服务器
     */
    public override func connect(host: String, port: Int64, user: String, password: String): Unit {
        _host = host
        _port = if (port > 0) { port } else { _defaultPort }

        if (_session.getDebug()) {
            println("DEBUG SMTP: 正在连接 ${_host}:${_port}")
        }

        try {
            // 创建套接字连接
            let socket = TcpSocket(_host, UInt16(_port))
            socket.connect()
            _socket = Some(socket)
            _reader = Some(StringReader<TcpSocket>(socket))
            _connected = true

            // 读取服务器问候语
            let greeting = readResponse()
            if (_lastReturnCode != 220) {
                throw MessagingException("SMTP 服务器拒绝连接: ${greeting}")
            }

            if (_session.getDebug()) {
                println("DEBUG SMTP: 已连接，问候语: ${greeting}")
            }

            // 发送 EHLO
            let localHost = match (_localHost) {
                case Some(h) => h
                case None => "localhost"
            }

            if (!ehlo(localHost)) {
                // 如果 EHLO 失败，尝试 HELO
                helo(localHost)
            }

            // 如果启用且可用，启动 TLS
            if (_useStartTLS && supportsExtension("STARTTLS")) {
                startTLS()
                // STARTTLS 后重新发送 EHLO
                if (!ehlo(localHost)) {
                    helo(localHost)
                }
            } else if (_requireStartTLS && !_isSSL) {
                throw MessagingException("需要 STARTTLS 但服务器不支持")
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

        } catch (e: SocketException) {
            _connected = false
            throw MailConnectException(_host, _port, -1, e)
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

                        // 解析 AUTH 机制
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
            println("DEBUG SMTP: EHLO 扩展: ${_extMap}")
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
     * 启动 TLS
     */
    private func startTLS(): Unit {
        sendCommand("STARTTLS")
        let response = readResponse()

        if (_lastReturnCode != 220) {
            throw MessagingException("STARTTLS 失败: ${response}")
        }

        // 注意：TLS 升级需要 SSL 套接字升级
        // 这是简化实现
        if (_session.getDebug()) {
            println("DEBUG SMTP: STARTTLS 已启动（简化版）")
        }
    }

    /**
     * 与服务器进行认证
     */
    private func authenticate(user: String, password: String): Bool {
        if (_session.getDebug()) {
            println("DEBUG SMTP: 正在以 ${user} 身份认证")
        }

        // 先尝试 LOGIN，然后 PLAIN
        if (_serverAuthMechanisms.contains("LOGIN")) {
            return authLogin(user, password)
        } else if (_serverAuthMechanisms.contains("PLAIN")) {
            return authPlain(user, password)
        } else if (!_serverAuthMechanisms.isEmpty()) {
            // 默认尝试 LOGIN
            return authLogin(user, password)
        }

        if (_session.getDebug()) {
            println("DEBUG SMTP: 没有支持的认证机制，尝试 LOGIN")
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
            println("DEBUG SMTP: 认证成功")
        }

        true
    }

    /**
     * PLAIN 认证
     */
    private func authPlain(user: String, password: String): Bool {
        // PLAIN 认证：\0username\0password（base64 编码）
        let authString = "\u{0000}${user}\u{0000}${password}"
        let encoded = Base64Util.encodeString(authString)

        sendCommand("AUTH PLAIN ${encoded}")
        let response = readResponse()

        if (_lastReturnCode != 235) {
            throw AuthenticationFailedException("AUTH PLAIN 失败: ${response}")
        }

        if (_session.getDebug()) {
            println("DEBUG SMTP: PLAIN 认证成功")
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

        // 确保消息已保存
        message.saveChanges()

        // 获取发件人
        let from = message.getFrom()
        if (from.isEmpty()) {
            throw MessagingException("未指定发件人地址")
        }
        let sender = from[0]

        // MAIL FROM
        mailFrom(sender)

        // 为每个收件人发送 RCPT TO
        let validSent = ArrayList<Address>()
        let invalidAddr = ArrayList<Address>()

        for (addr in addresses) {
            try {
                rcptTo(addr)
                validSent.add(addr)
            } catch (e: SMTPAddressFailedException) {
                invalidAddr.add(addr)
            }
        }

        if (validSent.isEmpty()) {
            throw SMTPSendFailedException(
                "RCPT",
                _lastReturnCode,
                "没有有效的收件人",
                Array<Address>(),
                Array<Address>(),
                invalidAddr.toArray()
            )
        }

        // DATA
        sendData(message)

        if (_session.getDebug()) {
            println("DEBUG SMTP: 消息成功发送给 ${validSent.size} 个收件人")
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
            throw SMTPSenderFailedException(
                InternetAddress(senderAddr),
                "MAIL FROM",
                _lastReturnCode,
                response
            )
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
            throw SMTPAddressFailedException(
                InternetAddress(recipientAddr),
                "RCPT TO",
                _lastReturnCode,
                response
            )
        }
    }

    /**
     * 发送 DATA 命令和消息内容
     */
    private func sendData(message: Message): Unit {
        sendCommand("DATA")
        let response = readResponse()

        if (_lastReturnCode != 354) {
            throw SMTPSendFailedException(
                "DATA",
                _lastReturnCode,
                response,
                Array<Address>(),
                message.getAllRecipients(),
                Array<Address>()
            )
        }

        // 获取消息内容
        let content = match (message) {
            case mm: MimeMessage => mm.getMessageString()
            case _ => throw MessagingException("不支持的消息类型")
        }

        // 发送消息内容（带点填充）
        let lines = content.split("\n")
        for (line in lines) {
            var lineToSend = line
            // 移除尾部的 \r
            if (lineToSend.endsWith("\r")) {
                lineToSend = lineToSend[0..(lineToSend.size - 1)]
            }
            // 点填充：如果行以 '.' 开头，前面再加一个 '.'
            if (lineToSend.startsWith(".")) {
                lineToSend = "." + lineToSend
            }
            writeToSocket("${lineToSend}\r\n")
        }

        // 发送数据结束标记
        writeToSocket(".\r\n")

        // 检查响应
        let dataResponse = readResponse()
        if (_lastReturnCode != 250) {
            throw SMTPSendFailedException(
                "DATA END",
                _lastReturnCode,
                dataResponse,
                Array<Address>(),
                message.getAllRecipients(),
                Array<Address>()
            )
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
            } catch (_: Exception) {
                // 关闭时忽略错误
            }
        }

        match (_socket) {
            case Some(s) =>
                try {
                    s.close()
                } catch (_: Exception) {}
            case None => ()
        }

        _socket = None
        _reader = None
        _connected = false
    }

    /**
     * 检查服务器是否支持扩展
     */
    public func supportsExtension(ext: String): Bool {
        _extMap.contains(ext.toAsciiUpper())
    }

    /**
     * 获取扩展参数
     */
    public func getExtensionParameter(ext: String): ?String {
        _extMap.get(ext.toAsciiUpper())
    }

    /**
     * 获取最后的服务器响应
     */
    public func getLastServerResponse(): String {
        _lastServerResponse
    }

    /**
     * 获取最后的返回码
     */
    public func getLastReturnCode(): Int64 {
        _lastReturnCode
    }

    /**
     * 向服务器发送命令
     */
    private func sendCommand(cmd: String): Unit {
        if (_session.getDebug()) {
            // 不记录密码
            if (cmd.startsWith("AUTH") && cmd.size > 20) {
                println("DEBUG SMTP: C: AUTH ***")
            } else {
                println("DEBUG SMTP: C: ${cmd}")
            }
        }
        writeToSocket("${cmd}\r\n")
    }

    /**
     * 向套接字写入数据
     */
    private func writeToSocket(data: String): Unit {
        match (_socket) {
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
                // 解析响应码
                let codeStr = line[0..3]
                _lastReturnCode = try {
                    Int64.parse(codeStr)
                } catch (_: Exception) {
                    0
                }

                // 检查是否是续行（响应码后跟 '-'）
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
                println("DEBUG SMTP: S: ${line}")
            }
        }

        _lastServerResponse
    }

    /**
     * 从套接字读取一行
     */
    private func readLine(): String {
        match (_socket) {
            case Some(s) =>
                var line = ""
                let buffer = Array<Byte>(1, repeat: 0)

                while (true) {
                    let n = s.read(buffer)
                    if (n <= 0) {
                        break
                    }

                    let ch = Rune(buffer[0])
                    if (ch == r'\n') {
                        break
                    } else if (ch != r'\r') {
                        line += ch.toString()
                    }
                }

                line
            case None =>
                throw MessagingException("未连接")
        }
    }
}
