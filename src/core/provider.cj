/**
 * 协议提供者类
 */
package mail.core

/**
 * 提供者类型枚举
 */
public enum ProviderType {
    | STORE      // 邮件存储（接收）
    | TRANSPORT  // 邮件传输（发送）
}

/**
 * 协议提供者
 * 对应：jakarta.mail.Provider
 */
public class Provider {
    private let _providerType: ProviderType
    private let _protocol: String
    private let _className: String
    private let _vendor: String
    private let _version: ?String

    public init(
        providerType: ProviderType,
        protocol: String,
        className: String,
        vendor: String,
        version: ?String
    ) {
        _providerType = providerType
        _protocol = protocol
        _className = className
        _vendor = vendor
        _version = version
    }

    public func getType(): ProviderType {
        _providerType
    }

    public func getProtocol(): String {
        _protocol
    }

    public func getClassName(): String {
        _className
    }

    public func getVendor(): String {
        _vendor
    }

    public func getVersion(): ?String {
        _version
    }
}
