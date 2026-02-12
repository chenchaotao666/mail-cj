/**
 * 邮件消息抽象类
 */
package mail.core

import std.time.*
import std.io.*

/**
 * 收件人类型枚举
 * 对应：jakarta.mail.Message.RecipientType
 */
public enum RecipientType <: ToString {
    | TO      // 主要收件人
    | CC      // 抄送收件人
    | BCC     // 密送收件人

    public func toString(): String {
        match (this) {
            case TO => "To"
            case CC => "Cc"
            case BCC => "Bcc"
        }
    }
}

/**
 * 邮件消息的抽象基类
 * 对应：jakarta.mail.Message
 */
public abstract class Message {
    protected var _session: Session

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
     * 获取发件人地址
     */
    public func getFrom(): Array<Address>

    /**
     * 设置发件人地址
     */
    public func setFrom(address: Address): Unit

    /**
     * 获取指定类型的收件人
     */
    public func getRecipients(recipientType: RecipientType): Array<Address>

    /**
     * 设置指定类型的收件人
     */
    public func setRecipients(recipientType: RecipientType, addresses: Array<Address>): Unit

    /**
     * 添加指定类型的收件人
     */
    public func addRecipients(recipientType: RecipientType, addresses: Array<Address>): Unit

    /**
     * 获取所有收件人
     */
    public func getAllRecipients(): Array<Address>

    /**
     * 获取主题
     */
    public func getSubject(): ?String

    /**
     * 设置主题
     */
    public func setSubject(subject: String): Unit

    /**
     * 设置主题（指定字符集）
     */
    public func setSubject(subject: String, charset: String): Unit

    /**
     * 获取发送日期
     */
    public func getSentDate(): ?DateTime

    /**
     * 设置发送日期
     */
    public func setSentDate(date: DateTime): Unit

    /**
     * 获取回复地址
     */
    public func getReplyTo(): Array<Address>

    /**
     * 设置回复地址
     */
    public func setReplyTo(addresses: Array<Address>): Unit

    /**
     * 设置文本内容
     */
    public func setText(text: String): Unit

    /**
     * 设置文本内容（指定字符集）
     */
    public func setText(text: String, charset: String): Unit

    /**
     * 保存消息更改
     */
    public func saveChanges(): Unit

    /**
     * 将消息写入输出流
     */
    public func writeTo(output: OutputStream): Unit
}
