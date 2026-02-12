/**
 * 邮件发送传输抽象类
 */
package mail.core

import std.convert.*

/**
 * 邮件传输的抽象基类
 * 对应：jakarta.mail.Transport
 */
public abstract class Transport {
    protected var _session: Session
    protected var _connected: Bool = false

    /**
     * 使用会话构造
     */
    protected init(session: Session) {
        _session = session
    }

    /**
     * 获取会话
     */
    public func getSession(): Session {
        _session
    }

    /**
     * 使用会话属性连接邮件服务器
     */
    public func connect(): Unit {
        let host = _session.getProperty("mail.smtp.host", "localhost")
        let portStr = _session.getProperty("mail.smtp.port", "25")
        let port = try {
            Int64.parse(portStr)
        } catch (_: Exception) {
            25
        }
        let user = _session.getProperty("mail.smtp.user", "")
        let password = _session.getProperty("mail.smtp.password", "")

        connect(host, port, user, password)
    }

    /**
     * 连接邮件服务器
     */
    public func connect(host: String, user: String, password: String): Unit {
        let portStr = _session.getProperty("mail.smtp.port", "25")
        let port = try {
            Int64.parse(portStr)
        } catch (_: Exception) {
            25
        }
        connect(host, port, user, password)
    }

    /**
     * 连接邮件服务器（指定端口）
     */
    public func connect(host: String, port: Int64, user: String, password: String): Unit

    /**
     * 发送消息给所有收件人
     */
    public func sendMessage(message: Message, addresses: Array<Address>): Unit

    /**
     * 关闭连接
     */
    public func close(): Unit

    /**
     * 检查是否已连接
     */
    public func isConnected(): Bool {
        _connected
    }

    /**
     * 发送消息的静态方法
     */
    public static func send(message: Message): Unit {
        let session = message.getSession()
        let transport = session.getTransport()
        try {
            transport.connect()
            transport.sendMessage(message, message.getAllRecipients())
        } finally {
            transport.close()
        }
    }

    /**
     * 带认证发送消息的静态方法
     */
    public static func send(message: Message, user: String, password: String): Unit {
        let session = message.getSession()
        let host = session.getProperty("mail.smtp.host", "localhost")
        let transport = session.getTransport()
        try {
            transport.connect(host, user, password)
            transport.sendMessage(message, message.getAllRecipients())
        } finally {
            transport.close()
        }
    }
}
