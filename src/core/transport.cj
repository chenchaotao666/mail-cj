/**
 * 邮件发送传输抽象类
 */
package mail.core

import std.convert.*
import std.collection.*

/**
 * 邮件传输的抽象基类
 * 对应：jakarta.mail.Transport
 */
public abstract class Transport {
    protected var _session: Session
    protected var _connected: Bool = false

    private var _transportListeners: ArrayList<TransportListener> = ArrayList<TransportListener>()
    private var _connectionListeners: ArrayList<ConnectionListener> = ArrayList<ConnectionListener>()

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

    /**
     * 发送消息给指定地址（静态）
     */
    public static func send(message: Message, addresses: Array<Address>): Unit {
        let session = message.getSession()
        let transport = session.getTransport()
        try {
            transport.connect()
            transport.sendMessage(message, addresses)
        } finally {
            transport.close()
        }
    }

    /**
     * 发送消息给指定地址（静态，带认证）
     */
    public static func send(message: Message, addresses: Array<Address>, user: String, password: String): Unit {
        let session = message.getSession()
        let host = session.getProperty("mail.smtp.host", "localhost")
        let transport = session.getTransport()
        try {
            transport.connect(host, user, password)
            transport.sendMessage(message, addresses)
        } finally {
            transport.close()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 事件监听器
    // ─────────────────────────────────────────────────────────────────────────

    public func addTransportListener(l: TransportListener): Unit {
        _transportListeners.add(l)
    }

    public func addConnectionListener(l: ConnectionListener): Unit {
        _connectionListeners.add(l)
    }

    /**
     * 通知 Transport 事件（由子类在发送后调用）
     */
    protected func notifyTransportListeners(
        message: Message,
        validSent: Array<Address>,
        validUnsent: Array<Address>,
        invalid: Array<Address>
    ): Unit {
        if (_transportListeners.isEmpty()) { return }

        let eventType = if (invalid.isEmpty() && validUnsent.isEmpty()) {
            TransportEventType.DELIVERED
        } else if (validSent.isEmpty()) {
            TransportEventType.NOT_DELIVERED
        } else {
            TransportEventType.PARTIALLY_DELIVERED
        }

        let event = TransportEvent(eventType, message, validSent, validUnsent, invalid)
        for (l in _transportListeners) {
            match (eventType) {
                case DELIVERED          => l.messageDelivered(event)
                case NOT_DELIVERED      => l.messageNotDelivered(event)
                case PARTIALLY_DELIVERED => l.messagePartiallyDelivered(event)
            }
        }
    }

    /**
     * 通知连接已建立（由子类在 connect 成功后调用）
     */
    protected func notifyConnectionOpened(): Unit {
        if (_connectionListeners.isEmpty()) { return }
        let event = ConnectionEvent(ConnectionEventType.OPENED)
        for (l in _connectionListeners) { l.opened(event) }
    }

    /**
     * 通知连接已关闭（由子类在 close 后调用）
     */
    protected func notifyConnectionClosed(): Unit {
        if (_connectionListeners.isEmpty()) { return }
        let event = ConnectionEvent(ConnectionEventType.CLOSED)
        for (l in _connectionListeners) { l.closed(event) }
    }
}
