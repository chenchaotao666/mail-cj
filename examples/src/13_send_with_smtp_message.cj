/**
 * 场景 13：SMTPMessage — 信封 From 分离 + DSN 通知
 *
 * 演示：
 * - setEnvelopeFrom：MAIL FROM 地址与 From 头分离（退信回到专用地址）
 * - setNotifyOptions：DSN 投递状态通知（SUCCESS / FAILURE / DELAY）
 * - setReturnOption：DSN 退信内容（FULL / HDRS）
 * - setAllow8bitMIME：MAIL FROM 声明 BODY=8BITMIME
 *
 * 对标 angus-examples：SendWithSMTPMessage.java
 * 对标 mail-cj API：SMTPMessage.setEnvelopeFrom / setNotifyOptions / setReturnOption
 */
package mail_demo

import std.time.*
import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendWithSMTPMessage(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    // SMTPMessage 是 MimeMessage 的子类，增加了信封级控制
    let msg = SMTPMessage(session)

    // 邮件头 From（用户看到的发件人）
    msg.setFrom(InternetAddress(cfg.mailFrom, "营销系统"))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】SMTPMessage 信封扩展", "UTF-8")
    msg.setText("本邮件演示 SMTPMessage 的信封级控制：\n"
        + "1. 退信地址：bounce@example.com（MAIL FROM）\n"
        + "2. 显示发件人：营销系统（From 头）\n"
        + "3. DSN 通知：服务器在成功/失败时发送通知\n"
        + "4. 8BITMIME：无需 Base64 编码", "UTF-8")

    // MAIL FROM 信封地址（退信回到专用地址，与 From 头无关）
    let ts = DateTime.now().toUnixTimeStamp().toMilliseconds()
    msg.setEnvelopeFrom("bounce-${ts}@example.com")

    // DSN：投递失败时通知，只返回邮件头（节省带宽）
    msg.setNotifyOptions(NOTIFY_FAILURE | NOTIFY_DELAY)
    msg.setReturnOption(RETURN_HDRS)

    // 8BITMIME：服务器支持时声明，纯文本内容无需 Base64
    msg.setAllow8bitMIME(true)

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ SMTPMessage 信封扩展邮件发送成功")
    println("  EnvelopeFrom = ${msg.getEnvelopeFrom() ?? "(null)"}")
    println("  NotifyOptions= ${msg.getNotifyOptions()}")
    println("  ReturnOption = ${msg.getReturnOption()}")
}
