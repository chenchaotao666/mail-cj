/**
 * 邮件访问认证类
 */
package mail.core

/**
 * 密码认证凭据
 * 对应：jakarta.mail.PasswordAuthentication
 */
public class PasswordAuthentication {
    private let _userName: String
    private let _password: String

    public init(userName: String, password: String) {
        _userName = userName
        _password = password
    }

    /**
     * 获取用户名
     */
    public func getUserName(): String {
        _userName
    }

    /**
     * 获取密码
     */
    public func getPassword(): String {
        _password
    }
}

/**
 * 抽象认证器类
 * 对应：jakarta.mail.Authenticator
 *
 * 子类应重写 getPasswordAuthentication() 来提供凭据
 */
public abstract class Authenticator {
    /**
     * 获取密码认证凭据
     * 子类实现此方法以提供认证信息
     */
    protected open func getPasswordAuthentication(): ?PasswordAuthentication {
        None
    }

    /**
     * 请求认证的内部方法
     */
    public func requestPasswordAuthentication(): ?PasswordAuthentication {
        getPasswordAuthentication()
    }
}

/**
 * 简单认证器，返回固定凭据
 */
public class SimpleAuthenticator <: Authenticator {
    private let _auth: PasswordAuthentication

    public init(userName: String, password: String) {
        _auth = PasswordAuthentication(userName, password)
    }

    protected override func getPasswordAuthentication(): ?PasswordAuthentication {
        Some(_auth)
    }
}
