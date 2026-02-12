/**
 * 企业级邮件发送处理器
 *
 * 仿照 Java angus-mail 的 Handler 类设计，提供：
 * - 连接管理（单次连接发送多封邮件）
 * - 单发和群发支持
 * - TO/CC/BCC 支持
 * - 失败重试机制
 * - 错误码处理
 *
 * 对应 Java 类：com.huawei.bsp.rnservice.business.email.Handler
 */
package mail_demo

import std.collection.*
import std.time.*
import mail.core.*
import mail.internet.*
import mail.smtp.*
import mail.tls.*

// ============================================================================
// 错误码定义（对应 Java EmailErrorCode）
// ============================================================================

/**
 * 邮件错误码
 */
public struct EmailErrorCode {
    public static const SUCCESS: Int64 = 0

    // 连接错误 (2xx)
    public static const CONNECT_FAILED: Int64 = 200
    public static const CONNECT_FAILED_CERT_EXCEPTION: Int64 = 203
    public static const CONNECT_FAILED_AUTH_FAILED: Int64 = 204
    public static const CONNECT_FAILED_UNKNOWN_ERROR: Int64 = 299

    // 发送错误 (3xx)
    public static const SEND_FAILED: Int64 = 300
    public static const SEND_FAILED_PART_FAILED: Int64 = 301
    public static const SEND_FAILED_MIME_INVALID: Int64 = 302
    public static const SEND_FAILED_ADDRESS_INVALID: Int64 = 303
    public static const SEND_FAILED_IO_EXCEPTION: Int64 = 304
    public static const SEND_FAILED_STARTTLS_CERT_INVALID: Int64 = 305
    public static const SEND_FAILED_TOO_MUCH_RECIPIENT: Int64 = 306
    public static const SEND_FAILED_ERROR_AUTH_REQUIRED: Int64 = 307
    public static const SEND_FAILED_SERVER_SEND_RIGHTS: Int64 = 308
    public static const SEND_FAILED_CLIENT_IP_NOTIN_WHITELIST: Int64 = 309
    public static const SEND_FAILED_UNKNOWN_ERROR: Int64 = 399
}

// ============================================================================
// 发送状态（对应 Java RNSendStatus）
// ============================================================================

/**
 * 邮件发送状态
 */
public class SendStatus {
    private var _recipient: String = ""
    private var _sendTime: Int64 = 0
    private var _status: Int64 = EmailErrorCode.SUCCESS

    public init() {}

    public mut prop recipient: String {
        get() { _recipient }
        set(value) { _recipient = value }
    }

    public mut prop sendTime: Int64 {
        get() { _sendTime }
        set(value) { _sendTime = value }
    }

    public mut prop status: Int64 {
        get() { _status }
        set(value) { _status = value }
    }

    public func isSuccess(): Bool {
        _status == EmailErrorCode.SUCCESS
    }

    public func toString(): String {
        "SendStatus(recipient=${_recipient}, status=${_status}, time=${_sendTime})"
    }
}

// ============================================================================
// 邮件信息（对应 Java EmailInfoEx）
// ============================================================================

/**
 * 邮件信息
 */
public class EmailInfo {
    // 单个收件人列表（逐个发送）
    private var _recipients: ArrayList<String> = ArrayList<String>()
    // 群发主送
    private var _massRecipients: ArrayList<String> = ArrayList<String>()
    // 抄送
    private var _ccRecipients: ArrayList<String> = ArrayList<String>()
    // 密送
    private var _bccRecipients: ArrayList<String> = ArrayList<String>()

    // 邮件内容
    private var _subject: String = ""
    private var _content: String = ""
    private var _contentType: String = "text/plain"
    private var _charset: String = "UTF-8"

    // 签名和前后缀
    private var _subjectPrefix: String = ""
    private var _subjectSuffix: String = ""
    private var _signature: String = ""

    // 附件
    private var _attachments: ArrayList<String> = ArrayList<String>()

    public init() {}

    /**
     * 添加单个收件人（会逐个发送）
     */
    public func addRecipient(recipient: String): Unit {
        _recipients.add(recipient)
    }

    /**
     * 添加群发收件人（一次性发送）
     */
    public func addMassRecipient(recipient: String): Unit {
        _massRecipients.add(recipient)
    }

    /**
     * 添加抄送
     */
    public func addCcRecipient(recipient: String): Unit {
        _ccRecipients.add(recipient)
    }

    /**
     * 添加密送
     */
    public func addBccRecipient(recipient: String): Unit {
        _bccRecipients.add(recipient)
    }

    /**
     * 添加附件
     */
    public func addAttachment(path: String): Unit {
        _attachments.add(path)
    }

    // Getters
    public func getRecipients(): ArrayList<String> { _recipients }
    public func getMassRecipients(): ArrayList<String> { _massRecipients }
    public func getCcRecipients(): ArrayList<String> { _ccRecipients }
    public func getBccRecipients(): ArrayList<String> { _bccRecipients }
    public func getAttachments(): ArrayList<String> { _attachments }

    /**
     * 获取所有群发收件人（不含单独发送的）
     */
    public func getAllWithoutSingleRecipients(): ArrayList<String> {
        let all = ArrayList<String>()
        for (r in _massRecipients) { all.add(r) }
        for (r in _ccRecipients) { all.add(r) }
        for (r in _bccRecipients) { all.add(r) }
        all
    }

    // Properties
    public mut prop subject: String {
        get() { _subject }
        set(value) { _subject = value }
    }

    public mut prop content: String {
        get() { _content }
        set(value) { _content = value }
    }

    public mut prop contentType: String {
        get() { _contentType }
        set(value) { _contentType = value }
    }

    public mut prop charset: String {
        get() { _charset }
        set(value) { _charset = value }
    }

    public mut prop subjectPrefix: String {
        get() { _subjectPrefix }
        set(value) { _subjectPrefix = value }
    }

    public mut prop subjectSuffix: String {
        get() { _subjectSuffix }
        set(value) { _subjectSuffix = value }
    }

    public mut prop signature: String {
        get() { _signature }
        set(value) { _signature = value }
    }

    /**
     * 获取完整主题（含前后缀）
     */
    public func getFullSubject(): String {
        "${_subjectPrefix}${_subject}${_subjectSuffix}"
    }

    /**
     * 获取完整内容（含签名）
     */
    public func getFullContent(): String {
        if (_signature.isEmpty()) {
            return _content
        }

        if (_contentType.contains("html")) {
            "${_content}<br/><br/><br/>________________________<br/><br/>${_signature}"
        } else {
            "${_content}\n\n\n________________________\n\n${_signature}"
        }
    }
}

// ============================================================================
// 邮件服务器配置（对应 Java EmailServerEx）
// ============================================================================

/**
 * 邮件服务器配置
 */
public class EmailServerConfig {
    public var smtpServer: String = ""
    public var port: Int64 = 465
    public var sender: String = ""
    public var userName: String = ""
    public var password: String = ""
    public var useSSL: Bool = true
    public var verifyCert: Bool = false
    public var caCertPath: ?String = None

    public init() {}

    public init(
        smtpServer: String,
        port: Int64,
        sender: String,
        userName: String,
        password: String
    ) {
        this.smtpServer = smtpServer
        this.port = port
        this.sender = sender
        this.userName = userName
        this.password = password
    }
}

// ============================================================================
// 邮件发送处理器（对应 Java Handler）
// ============================================================================

/**
 * 企业级邮件发送处理器
 *
 * 功能：
 * - 单次连接发送多封邮件（高效模式）
 * - 支持单发、群发、抄送、密送
 * - 失败自动重试
 * - 详细错误码
 */
public class EmailHandler {
    private var _mailSender: String
    private var _serverConfig: EmailServerConfig
    private var _transport: ?TlsSMTPTransport = None
    private var _session: Session
    private var _isTest: Bool = false
    private var _debug: Bool = false

    // 重试配置
    private var _retryTimes: Int64 = 3
    private var _retryInterval: Int64 = 1000  // 毫秒

    /**
     * 构造函数
     *
     * @param serverConfig 邮件服务器配置
     */
    public init(serverConfig: EmailServerConfig) {
        _serverConfig = serverConfig
        _mailSender = serverConfig.sender

        // 配置 Session 属性
        let props = HashMap<String, String>()
        let protocol = if (serverConfig.useSSL) { "smtps" } else { "smtp" }
        props["mail.${protocol}.host"] = serverConfig.smtpServer
        props["mail.${protocol}.port"] = serverConfig.port.toString()
        props["mail.${protocol}.auth"] = "true"

        _session = Session.getInstance(props)
    }

    /**
     * 设置调试模式
     */
    public func setDebug(debug: Bool): Unit {
        _debug = debug
        _session.setDebug(debug)
    }

    /**
     * 设置测试模式
     */
    public func setIsTest(isTest: Bool): Unit {
        _isTest = isTest
    }

    /**
     * 设置重试次数
     */
    public func setRetryTimes(times: Int64): Unit {
        _retryTimes = times
    }

    /**
     * 设置重试间隔（毫秒）
     */
    public func setRetryInterval(interval: Int64): Unit {
        _retryInterval = interval
    }

    /**
     * 连接邮箱服务器
     */
    public func connectTransport(): Unit {
        if (_mailSender.isEmpty()) {
            println("[WARN] mailSender is null, transport connect failed!")
            throw MessagingException("mailSender is null")
        }

        let transport = TlsSMTPTransport(_session, _serverConfig.useSSL)

        // 配置证书验证
        if (_serverConfig.verifyCert) {
            transport.setVerifyCert(true)
            match (_serverConfig.caCertPath) {
                case Some(path) => transport.setCACertPath(path)
                case None => ()
            }
        }

        try {
            if (_debug) {
                println("[DEBUG] try to connect to server: ${_serverConfig.smtpServer}:${_serverConfig.port}")
            }

            let userName = if (_serverConfig.userName.isEmpty()) { "" } else { _serverConfig.userName }
            let password = if (_serverConfig.password.isEmpty()) { "" } else { _serverConfig.password }

            transport.connect(
                _serverConfig.smtpServer,
                _serverConfig.port,
                userName,
                password
            )

            _transport = Some(transport)
            println("[INFO] transport connect success!")

        } catch (e: AuthenticationFailedException) {
            println("[ERROR] Authentication failed: ${e.message}")
            transport.close()
            throw e
        } catch (e: MailConnectException) {
            println("[ERROR] Connect failed: ${e.message}")
            transport.close()
            throw e
        } catch (e: TlsException) {
            println("[ERROR] TLS error: ${e.message}")
            transport.close()
            throw e
        } catch (e: Exception) {
            println("[ERROR] Unknown error: ${e.message}")
            transport.close()
            throw MessagingException("连接失败: ${e.message}")
        }
    }

    /**
     * 发送邮件（高效模式：单次连接发送所有邮件）
     *
     * @param emailInfo 邮件信息
     * @return 发送状态列表
     */
    public func sendEmail(emailInfo: EmailInfo): ArrayList<SendStatus> {
        try {
            return traverseSend(emailInfo)
        } finally {
            close()
        }
    }

    /**
     * 发送邮件（非高效模式：每封邮件单独连接）
     *
     * @param emailInfo 邮件信息
     * @return 发送状态列表
     */
    public func sendEmailInefficient(emailInfo: EmailInfo): ArrayList<SendStatus> {
        return traverseSendInefficient(emailInfo)
    }

    /**
     * 遍历发送（高效模式）
     */
    private func traverseSend(emailInfo: EmailInfo): ArrayList<SendStatus> {
        connectTransport()

        let statusList = ArrayList<SendStatus>()

        // 逐个发送单独收件人
        for (recipient in emailInfo.getRecipients()) {
            let status = SendStatus()
            var result = EmailErrorCode.SUCCESS

            try {
                sendOneByOne(emailInfo, recipient)
            } catch (e: Exception) {
                println("[ERROR] Send email error: ${e.message}")
                result = handleSendException(e, emailInfo, recipient)
            }

            status.recipient = recipient
            status.sendTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
            status.status = result
            statusList.add(status)
        }

        // 群发（主送 + 抄送 + 密送）
        if (!emailInfo.getAllWithoutSingleRecipients().isEmpty()) {
            let massStatusList = massSend(emailInfo, false)
            for (s in massStatusList) {
                statusList.add(s)
            }
        }

        statusList
    }

    /**
     * 遍历发送（非高效模式）
     */
    private func traverseSendInefficient(emailInfo: EmailInfo): ArrayList<SendStatus> {
        let statusList = ArrayList<SendStatus>()

        for (recipient in emailInfo.getRecipients()) {
            let status = SendStatus()
            var result = EmailErrorCode.SUCCESS

            try {
                connectTransport()
                sendOneByOne(emailInfo, recipient)
            } catch (e: Exception) {
                println("[ERROR] Send email error: ${e.message}")
                if (!sendOneRetry(emailInfo, recipient)) {
                    result = EmailErrorCode.SEND_FAILED
                }
            } finally {
                status.recipient = recipient
                status.sendTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
                status.status = result
                close()
            }

            statusList.add(status)
        }

        // 群发需要重新连接
        if (!emailInfo.getAllWithoutSingleRecipients().isEmpty()) {
            let massStatusList = massSend(emailInfo, true)
            for (s in massStatusList) {
                statusList.add(s)
            }
        }

        statusList
    }

    /**
     * 群发邮件
     */
    private func massSend(emailInfo: EmailInfo, needConnect: Bool): ArrayList<SendStatus> {
        let statusList = ArrayList<SendStatus>()
        var result = EmailErrorCode.SUCCESS

        try {
            if (needConnect) {
                connectTransport()
            }
            sendAllOnce(emailInfo)
        } catch (e: Exception) {
            println("[ERROR] Mass send error: ${e.message}")
            result = handleSendException(e, emailInfo, "")

            if (result == EmailErrorCode.SEND_FAILED_UNKNOWN_ERROR) {
                if (!sendAllOnceRetry(emailInfo)) {
                    result = getSendExceptionCode(e)
                } else {
                    result = EmailErrorCode.SUCCESS
                }
            }
        } finally {
            let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
            for (recipient in emailInfo.getAllWithoutSingleRecipients()) {
                let status = SendStatus()
                status.recipient = recipient
                status.sendTime = now
                status.status = result
                statusList.add(status)
            }

            if (needConnect) {
                close()
            }
        }

        statusList
    }

    /**
     * 处理发送异常，返回错误码
     */
    private func handleSendException(e: Exception, emailInfo: EmailInfo, recipient: String): Int64 {
        let message = e.message

        if (message.contains("STARTTLS is required")) {
            return EmailErrorCode.SEND_FAILED_STARTTLS_CERT_INVALID
        }
        if (message.contains("too much recipient")) {
            return EmailErrorCode.SEND_FAILED_TOO_MUCH_RECIPIENT
        }
        if (message.contains("535 5.7.0 ERR.AUTH.REQUIRED")) {
            return EmailErrorCode.SEND_FAILED_ERROR_AUTH_REQUIRED
        }
        if (message.contains("550 5.7.1 Unable to relay")) {
            return EmailErrorCode.SEND_FAILED_SERVER_SEND_RIGHTS
        }
        if (message.contains("530 5.7.57 Client was not authenticated")) {
            return EmailErrorCode.SEND_FAILED_CLIENT_IP_NOTIN_WHITELIST
        }

        // 尝试重试
        if (!sendOneRetry(emailInfo, recipient)) {
            return getSendExceptionCode(e)
        }

        EmailErrorCode.SUCCESS
    }

    /**
     * 根据异常获取错误码
     */
    private func getSendExceptionCode(e: Exception): Int64 {
        match (e) {
            case _: SMTPSendFailedException =>
                EmailErrorCode.SEND_FAILED_PART_FAILED
            case me: MessagingException =>
                let message = me.message
                if (message.contains("RFC822")) {
                    EmailErrorCode.SEND_FAILED_MIME_INVALID
                } else if (message.contains("address") || message.contains("Address")) {
                    EmailErrorCode.SEND_FAILED_ADDRESS_INVALID
                } else if (message.contains("IO")) {
                    EmailErrorCode.SEND_FAILED_IO_EXCEPTION
                } else {
                    EmailErrorCode.SEND_FAILED_UNKNOWN_ERROR
                }
            case _ =>
                EmailErrorCode.SEND_FAILED_UNKNOWN_ERROR
        }
    }

    /**
     * 单发重试
     */
    private func sendOneRetry(emailInfo: EmailInfo, recipient: String): Bool {
        for (i in 0.._retryTimes) {
            try {
                retrySendOneByOne(emailInfo, recipient)
                println("[INFO] Retry-Send-Email: retry send email success.")
                return true
            } catch (e: Exception) {
                sleep(_retryInterval)
                println("[WARN] Retry-Send-Email: for the ${i + 1} time, wait for ${_retryInterval} ms.")
            }
        }
        false
    }

    /**
     * 群发重试
     */
    private func sendAllOnceRetry(emailInfo: EmailInfo): Bool {
        for (i in 0.._retryTimes) {
            try {
                sendAllOnce(emailInfo)
                println("[INFO] Retry-Send-Email: retry send all email success.")
                return true
            } catch (e: Exception) {
                sleep(_retryInterval)
                println("[WARN] Retry-Send-ALL-Email: for the ${i + 1} time, wait for ${_retryInterval} ms.")
            }
        }
        false
    }

    /**
     * 发送单封邮件
     */
    private func sendOneByOne(emailInfo: EmailInfo, recipient: String): Unit {
        let message = prepareMessage(emailInfo)
        message.setRecipients(RecipientType.TO, [InternetAddress(recipient)])

        match (_transport) {
            case Some(t) =>
                t.sendMessage(message, message.getAllRecipients())
            case None =>
                throw MessagingException("Transport is not connected")
        }
    }

    /**
     * 重试发送（不打印堆栈）
     */
    private func retrySendOneByOne(emailInfo: EmailInfo, recipient: String): Unit {
        let message = prepareMessage(emailInfo)
        message.setRecipients(RecipientType.TO, [InternetAddress(recipient)])

        match (_transport) {
            case Some(t) =>
                t.sendMessage(message, message.getAllRecipients())
            case None =>
                throw MessagingException("Transport is not connected")
        }
    }

    /**
     * 群发一次
     */
    private func sendAllOnce(emailInfo: EmailInfo): Unit {
        let message = prepareMessage(emailInfo)
        setEmailRecipients(emailInfo, message)

        match (_transport) {
            case Some(t) =>
                t.sendMessage(message, message.getAllRecipients())
            case None =>
                throw MessagingException("Transport is not connected")
        }
    }

    /**
     * 设置收件人（主送、抄送、密送）
     */
    private func setEmailRecipients(emailInfo: EmailInfo, message: MimeMessage): Unit {
        // 主送
        let toList = emailInfo.getMassRecipients()
        if (!toList.isEmpty()) {
            message.setRecipients(RecipientType.TO, convertToAddresses(toList))
        }

        // 抄送
        let ccList = emailInfo.getCcRecipients()
        if (!ccList.isEmpty()) {
            message.setRecipients(RecipientType.CC, convertToAddresses(ccList))
        }

        // 密送
        let bccList = emailInfo.getBccRecipients()
        if (!bccList.isEmpty()) {
            message.setRecipients(RecipientType.BCC, convertToAddresses(bccList))
        }
    }

    /**
     * 转换地址列表
     */
    private func convertToAddresses(list: ArrayList<String>): Array<Address> {
        let addresses = ArrayList<Address>()
        for (email in list) {
            addresses.add(InternetAddress(email))
        }
        addresses.toArray()
    }

    /**
     * 准备邮件消息
     */
    private func prepareMessage(emailInfo: EmailInfo): MimeMessage {
        let message = MimeMessage(_session)

        // 发件人
        message.setFrom(InternetAddress(_mailSender))

        // 主题（含前后缀）
        message.setSubject(emailInfo.getFullSubject(), emailInfo.charset)

        // 内容
        let content = emailInfo.getFullContent()
        let attachments = emailInfo.getAttachments()

        if (attachments.isEmpty()) {
            // 无附件
            if (emailInfo.contentType.contains("html")) {
                message.setHtmlContent(content, emailInfo.charset)
            } else {
                message.setText(content, emailInfo.charset)
            }
        } else {
            // 有附件
            let attachmentPaths = ArrayList<String>()
            for (path in attachments) {
                attachmentPaths.add(path)
            }

            if (emailInfo.contentType.contains("html")) {
                message.setHtmlWithAttachments(content, attachmentPaths.toArray())
            } else {
                message.setTextWithAttachments(content, attachmentPaths.toArray())
            }
        }

        // 设置 8bit 编码
        message.setHeader("Content-Transfer-Encoding", "8bit")

        message
    }

    /**
     * 关闭连接
     */
    public func close(): Unit {
        println("[INFO] Close the EmailSender.")
        match (_transport) {
            case Some(t) =>
                try {
                    t.close()
                } catch (e: Exception) {
                    println("[ERROR] Failed to close the EmailSender: ${e.message}")
                }
                _transport = None
            case None => ()
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/**
 * 简单的睡眠函数
 */
func sleep(milliseconds: Int64): Unit {
    // 简化实现：使用循环等待
    let start = DateTime.now().toUnixTimeStamp().toMilliseconds()
    while (DateTime.now().toUnixTimeStamp().toMilliseconds() - start < milliseconds) {
        // busy wait
    }
}

/**
 * 匿名化邮件地址（用于日志）
 */
public func anonymizeEmail(email: String): String {
    match (email.indexOf("@")) {
        case Some(idx) where idx > 2 =>
            "${email[0..2]}***${email[idx..email.size]}"
        case _ =>
            "***"
    }
}
