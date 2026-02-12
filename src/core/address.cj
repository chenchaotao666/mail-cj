/**
 * 邮件地址抽象类
 */
package mail.core

/**
 * 邮件地址的抽象基类
 * 对应：jakarta.mail.Address
 */
public abstract class Address <: ToString & Equatable<Address> {
    /**
     * 获取地址类型
     */
    public func getType(): String

    /**
     * 获取地址的字符串表示
     */
    public func toString(): String

    /**
     * 检查此地址是否等于另一个地址
     */
    public operator func ==(other: Address): Bool {
        this.toString() == other.toString()
    }

    /**
     * 检查此地址是否不等于另一个地址
     */
    public operator func !=(other: Address): Bool {
        !(this == other)
    }
}
