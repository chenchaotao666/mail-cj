/**
 * SMTP 信封级消息扩展
 * 允许在消息对象上设置 SMTP 信封参数（独立于邮件头）
 * 对应：org.eclipse.angus.mail.smtp.SMTPMessage
 */
package mail.internet

import mail.core.*

/**
 * DSN 通知选项常量
 */
public let NOTIFY_NEVER:   Int32 = 0x00
public let NOTIFY_SUCCESS: Int32 = 0x01
public let NOTIFY_FAILURE: Int32 = 0x02
public let NOTIFY_DELAY:   Int32 = 0x04

/**
 * DSN 返回内容选项
 */
public let RETURN_FULL: Int32 = 1
public let RETURN_HDRS: Int32 = 2

/**
 * SMTP 信封级消息
 *
 * 扩展 MimeMessage，增加 SMTP 信封参数：
 * - 独立于 From 头的 MAIL FROM 地址（退信地址）
 * - 消息级 sendPartial 控制
 * - 8BITMIME 声明
 * - MAIL FROM 自定义扩展参数
 * - DSN 通知选项（供未来支持）
 */
public class SMTPMessage <: MimeMessage {
    private var _envelopeFrom: ?String = None
    private var _sendPartial: Bool = false
    private var _allow8bitMIME: Bool = false
    private var _mailExtension: ?String = None
    private var _notifyOptions: Int32 = NOTIFY_NEVER
    private var _returnOption: Int32 = RETURN_FULL
    private var _envelopeId: ?String = None   // DSN ENVID= 参数
    private var _smtpUtf8: Bool = false        // 声明 SMTPUTF8 扩展

    public init(session: Session) {
        super(session)
    }

    public init(source: MimeMessage) {
        super(source)
    }

    /**
     * 设置 MAIL FROM 信封地址（独立于邮件头 From）
     * 用于退信地址（Return-Path）分离场景
     */
    public func setEnvelopeFrom(address: String): Unit {
        _envelopeFrom = if (address.isEmpty()) { None } else { Some(address) }
    }

    public func getEnvelopeFrom(): ?String {
        _envelopeFrom
    }

    /**
     * 消息级 sendPartial：部分收件人无效时仍发送
     * 优先级高于 mail.smtp.sendpartial 会话属性
     */
    public func setSendPartial(partial: Bool): Unit {
        _sendPartial = partial
    }

    public func isSendPartial(): Bool {
        _sendPartial
    }

    /**
     * 允许在 MAIL FROM 中声明 BODY=8BITMIME
     */
    public func setAllow8bitMIME(allow: Bool): Unit {
        _allow8bitMIME = allow
    }

    public func isAllow8bitMIME(): Bool {
        _allow8bitMIME
    }

    /**
     * 向 MAIL FROM 命令追加自定义扩展参数
     * 例如：setMailExtension("RET=HDRS ENVID=12345")
     */
    public func setMailExtension(ext: String): Unit {
        _mailExtension = if (ext.isEmpty()) { None } else { Some(ext) }
    }

    public func getMailExtension(): ?String {
        _mailExtension
    }

    /**
     * 设置 DSN 通知选项（NOTIFY_SUCCESS | NOTIFY_FAILURE | NOTIFY_DELAY）
     * 需服务器支持 DSN ESMTP 扩展
     */
    public func setNotifyOptions(options: Int32): Unit {
        _notifyOptions = options
    }

    public func getNotifyOptions(): Int32 {
        _notifyOptions
    }

    /**
     * 设置 DSN 返回内容（RETURN_FULL | RETURN_HDRS）
     */
    public func setReturnOption(option: Int32): Unit {
        _returnOption = option
    }

    public func getReturnOption(): Int32 {
        _returnOption
    }

    /**
     * 设置 DSN 信封 ID（MAIL FROM 的 ENVID= 参数，RFC 1891）
     * 用于将 DSN 通知与原始邮件关联
     */
    public func setEnvelopeId(id: String): Unit {
        _envelopeId = if (id.isEmpty()) { None } else { Some(id) }
    }

    public func getEnvelopeId(): ?String {
        _envelopeId
    }

    /**
     * 声明该消息需要 SMTPUTF8 扩展（RFC 6531）
     * 允许 MAIL FROM / RCPT TO 中使用 UTF-8 地址
     */
    public func setSmtpUtf8(enable: Bool): Unit {
        _smtpUtf8 = enable
    }

    public func isSmtpUtf8(): Bool {
        _smtpUtf8
    }
}
