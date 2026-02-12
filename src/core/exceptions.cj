/**
 * 邮件库核心异常类
 */
package mail.core

/**
 * 所有邮件异常的基类
 * 对应：jakarta.mail.MessagingException
 */
public open class MessagingException <: Exception {
    private var _nextException: ?Exception = None

    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }

    public init(message: String, cause: Exception) {
        super(message)
        this._nextException = Some(cause)
    }

    /**
     * 获取链式异常中的下一个异常
     */
    public func getNextException(): ?Exception {
        _nextException
    }

    /**
     * 设置链式异常中的下一个异常
     * 成功设置返回 true
     */
    public func setNextException(ex: Exception): Bool {
        if (_nextException.isNone()) {
            _nextException = Some(ex)
            return true
        }
        // 简化处理，如果已有下一个异常则返回 false
        false
    }
}

/**
 * 邮件地址无效时抛出的异常
 * 对应：jakarta.mail.internet.AddressException
 */
public class AddressException <: MessagingException {
    private let _ref: ?String    // 引用的地址字符串
    private let _pos: Int64      // 错误位置

    public init() {
        super()
        _ref = None
        _pos = -1
    }

    public init(message: String) {
        super(message)
        _ref = None
        _pos = -1
    }

    public init(message: String, ref: String) {
        super(message)
        _ref = Some(ref)
        _pos = -1
    }

    public init(message: String, ref: String, pos: Int64) {
        super(message)
        _ref = Some(ref)
        _pos = pos
    }

    /**
     * 获取引用的地址字符串
     */
    public func getRef(): ?String {
        _ref
    }

    /**
     * 获取地址字符串中的错误位置
     */
    public func getPos(): Int64 {
        _pos
    }
}

/**
 * 认证失败时抛出的异常
 * 对应：jakarta.mail.AuthenticationFailedException
 */
public class AuthenticationFailedException <: MessagingException {
    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }

    public init(message: String, cause: Exception) {
        super(message, cause)
    }
}

/**
 * 发送邮件失败时抛出的异常
 * 对应：jakarta.mail.SendFailedException
 */
public open class SendFailedException <: MessagingException {
    protected var _validSentAddresses: Array<Address> = Array<Address>()
    protected var _validUnsentAddresses: Array<Address> = Array<Address>()
    protected var _invalidAddresses: Array<Address> = Array<Address>()

    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }

    public init(message: String, cause: Exception) {
        super(message, cause)
    }

    public init(
        message: String,
        validSent: Array<Address>,
        validUnsent: Array<Address>,
        invalid: Array<Address>
    ) {
        super(message)
        _validSentAddresses = validSent
        _validUnsentAddresses = validUnsent
        _invalidAddresses = invalid
    }

    /**
     * 获取邮件成功发送的地址
     */
    public func getValidSentAddresses(): Array<Address> {
        _validSentAddresses
    }

    /**
     * 获取有效但未发送的地址
     */
    public func getValidUnsentAddresses(): Array<Address> {
        _validUnsentAddresses
    }

    /**
     * 获取无效地址
     */
    public func getInvalidAddresses(): Array<Address> {
        _invalidAddresses
    }
}

/**
 * 解析失败时抛出的异常
 * 对应：jakarta.mail.internet.ParseException
 */
public class ParseException <: MessagingException {
    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }
}

/**
 * 连接邮件服务器失败时抛出的异常
 * 对应：org.eclipse.angus.mail.util.MailConnectException
 */
public class MailConnectException <: MessagingException {
    private let _host: String
    private let _port: Int64
    private let _connectionTimeout: Int64

    public init(host: String, port: Int64, connectionTimeout: Int64, cause: Exception) {
        super("无法连接到主机 '${host}' 端口 ${port}", cause)
        _host = host
        _port = port
        _connectionTimeout = connectionTimeout
    }

    public func getHost(): String {
        _host
    }

    public func getPort(): Int64 {
        _port
    }

    public func getConnectionTimeout(): Int64 {
        _connectionTimeout
    }
}

// 注意：Address 类定义在同一包的 address.cj 文件中
