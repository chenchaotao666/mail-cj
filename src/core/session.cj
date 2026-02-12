/**
 * 邮件会话管理
 */
package mail.core

import std.collection.*
import std.sync.*

/**
 * Transport 工厂函数类型
 * 用于打破 core 和 smtp 模块之间的循环依赖
 */
public type TransportFactory = (Session, Bool) -> Transport

/**
 * 邮件会话
 * 对应：jakarta.mail.Session
 */
public class Session {
    private var _properties: HashMap<String, String>
    private var _authenticator: ?Authenticator
    private var _debug: Bool = false
    private var _providers: HashMap<String, Provider> = HashMap<String, Provider>()

    // 用于创建 Transport 实例的工厂
    private static var _transportFactory: ?TransportFactory = None
    private static let _factoryLock = Mutex()

    // getDefaultInstance() 的默认实例
    private static var _defaultInstance: ?Session = None
    private static let _lock = Mutex()

    /**
     * 私有构造函数
     */
    private init(properties: HashMap<String, String>, authenticator: ?Authenticator) {
        _properties = properties
        _authenticator = authenticator
        registerDefaultProviders()
    }

    /**
     * 注册 Transport 工厂（在 smtp 模块初始化时调用）
     */
    public static func registerTransportFactory(factory: TransportFactory): Unit {
        synchronized(_factoryLock) {
            _transportFactory = Some(factory)
        }
    }

    /**
     * 注册默认提供者
     */
    private func registerDefaultProviders(): Unit {
        // 注册 SMTP 提供者
        let smtpProvider = Provider(
            ProviderType.TRANSPORT,
            "smtp",
            "mail.smtp.SMTPTransport",
            "Cangjie Mail",
            Some("0.1.0")
        )
        _providers["smtp"] = smtpProvider

        // 注册 SMTPS 提供者
        let smtpsProvider = Provider(
            ProviderType.TRANSPORT,
            "smtps",
            "mail.smtp.SMTPSSLTransport",
            "Cangjie Mail",
            Some("0.1.0")
        )
        _providers["smtps"] = smtpsProvider
    }

    /**
     * 获取新的会话实例
     */
    public static func getInstance(properties: HashMap<String, String>): Session {
        Session(properties, None)
    }

    /**
     * 获取带认证器的新会话实例
     */
    public static func getInstance(
        properties: HashMap<String, String>,
        authenticator: Authenticator
    ): Session {
        Session(properties, Some(authenticator))
    }

    /**
     * 获取默认会话实例（单例）
     */
    public static func getDefaultInstance(properties: HashMap<String, String>): Session {
        synchronized(_lock) {
            match (_defaultInstance) {
                case Some(s) => s
                case None =>
                    let session = Session(properties, None)
                    _defaultInstance = Some(session)
                    session
            }
        }
    }

    /**
     * 获取带认证器的默认会话实例（单例）
     */
    public static func getDefaultInstance(
        properties: HashMap<String, String>,
        authenticator: Authenticator
    ): Session {
        synchronized(_lock) {
            match (_defaultInstance) {
                case Some(s) => s
                case None =>
                    let session = Session(properties, Some(authenticator))
                    _defaultInstance = Some(session)
                    session
            }
        }
    }

    /**
     * 获取所有属性
     */
    public func getProperties(): HashMap<String, String> {
        _properties
    }

    /**
     * 获取属性值
     */
    public func getProperty(name: String): ?String {
        _properties.get(name)
    }

    /**
     * 获取属性值（带默认值）
     */
    public func getProperty(name: String, defaultValue: String): String {
        match (_properties.get(name)) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    /**
     * 设置属性值
     */
    public func setProperty(name: String, value: String): Unit {
        _properties[name] = value
    }

    /**
     * 获取认证器
     */
    public func getAuthenticator(): ?Authenticator {
        _authenticator
    }

    /**
     * 获取调试模式
     */
    public func getDebug(): Bool {
        _debug
    }

    /**
     * 设置调试模式
     */
    public func setDebug(debug: Bool): Unit {
        _debug = debug
    }

    /**
     * 添加提供者
     */
    public func addProvider(provider: Provider): Unit {
        _providers[provider.getProtocol()] = provider
    }

    /**
     * 根据协议获取提供者
     */
    public func getProvider(protocol: String): ?Provider {
        _providers.get(protocol)
    }

    /**
     * 获取默认协议（smtp）的传输器
     */
    public func getTransport(): Transport {
        getTransport("smtp")
    }

    /**
     * 获取指定协议的传输器
     * 注意：这会创建一个新的 SMTPTransport 实例
     */
    public func getTransport(protocol: String): Transport {
        // 使用已注册的 Transport 工厂
        synchronized(_factoryLock) {
            match (_transportFactory) {
                case Some(factory) =>
                    match (protocol) {
                        case "smtp" => factory(this, false)
                        case "smtps" => factory(this, true)
                        case _ => throw MessagingException("未知协议: ${protocol}")
                    }
                case None =>
                    throw MessagingException("Transport 工厂未注册，请先导入 mail.smtp 模块")
            }
        }
    }
}
