/**
 * 场景 8：Reply-To 与 reply() 回复邮件
 *
 * 演示两个子场景：
 * a. 设置自定义 Reply-To 地址
 * b. 用 MimeMessage.reply() 生成回复消息（自动加 Re: 前缀、In-Reply-To 头）
 *
 * 对标 angus-examples：SendReply.java
 * 对标 mail-cj API：msg.setReplyTo() / msg.reply(replyToAll)
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendReply(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    // ── 场景 a：自定义 Reply-To ────────────────────────────────
    let original = MimeMessage(session)
    original.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    original.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    // 回复地址指向不同的邮箱（如客服专用地址）
    original.setReplyTo(InternetAddress.parse("support@example.com"))
    original.setSubject("【mail-cj 对标】自定义 Reply-To", "UTF-8")
    original.setText("本邮件设置了 Reply-To: support@example.com\n"
        + "收件人点回复时，邮件将发往 support@example.com。", "UTF-8")

    let t1 = TlsSMTPTransport(session, true)
    try {
        t1.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t1.sendMessage(original, original.getAllRecipients())
    } finally {
        t1.close()
    }
    println("✓ 自定义 Reply-To 邮件发送成功")

    // ── 场景 b：生成回复邮件 ────────────────────────────────────
    // reply(false) 会把 TO 设为原邮件的 Reply-To（support@example.com），
    // 覆盖为实际收件人才能收到
    original.saveChanges()
    let reply = original.reply(false)
    reply.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    reply.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    reply.setText("这是对原始邮件的回复。\n\n在 mail-cj 中使用 reply(false) 生成。\n"
        + "注意：Subject 自动加了 Re: 前缀，且包含 In-Reply-To 头。", "UTF-8")

    let t2 = TlsSMTPTransport(session, true)
    try {
        t2.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t2.sendMessage(reply, reply.getAllRecipients())
    } finally {
        t2.close()
    }
    println("✓ 回复邮件发送成功")
    println("  Subject    = ${reply.getSubject() ?? "(null)"}")
    println("  In-Reply-To= ${reply.getHeader("In-Reply-To") ?? "(null)"}")
}
