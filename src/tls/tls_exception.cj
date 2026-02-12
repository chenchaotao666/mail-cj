/**
 * TLS 异常定义
 */
package mail.tls

/**
 * TLS 相关异常
 */
public open class TlsException <: Exception {
    private let _errorCode: Int32

    /**
     * 使用错误消息构造
     */
    public init(message: String) {
        super(message)
        _errorCode = -1
    }

    /**
     * 使用错误消息和错误码构造
     */
    public init(message: String, errorCode: Int32) {
        super("${message} (错误码: ${errorCode})")
        _errorCode = errorCode
    }

    /**
     * 获取错误码
     */
    public func getErrorCode(): Int32 {
        _errorCode
    }
}

/**
 * TLS 握手异常
 */
public class TlsHandshakeException <: TlsException {
    public init(message: String) {
        super(message)
    }

    public init(message: String, errorCode: Int32) {
        super(message, errorCode)
    }
}

/**
 * TLS 证书异常
 */
public class TlsCertificateException <: TlsException {
    public init(message: String) {
        super(message)
    }

    public init(message: String, errorCode: Int32) {
        super(message, errorCode)
    }
}
