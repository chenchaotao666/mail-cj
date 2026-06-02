/**
 * 场景 12：从 InputStream 加载邮件模板后转发
 *
 * 演示：
 * - MimeMessage(session, InputStream) 构造解析 RFC 2822 原始邮件
 * - 修改部分字段（收件人、Subject 加前缀）后转发
 *
 * 对标 angus-examples：SendFromInputStream.java
 * 对标 mail-cj API：MimeMessage(session, input: InputStream)
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.activation.*
import mail.tls.*

// 模拟一封原始 RFC 2822 格式邮件（通常来自文件、数据库或消息队列）
let RAW_EMAIL = "From: template@example.com\r\n"
    + "To: placeholder@example.com\r\n"
    + "Subject: 月度报告模板\r\n"
    + "Content-Type: text/plain; charset=UTF-8\r\n"
    + "MIME-Version: 1.0\r\n"
    + "\r\n"
    + "尊敬的用户，\r\n"
    + "\r\n"
    + "请查收本月报告。\r\n"
    + "\r\n"
    + "此邮件由系统自动发送。\r\n"

public func sendFromInputStream(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    // 从 InputStream 解析原始邮件
    let rawBytes = RAW_EMAIL.toArray()
    let loaded = MimeMessage(session, ByteArrayInputStream(rawBytes))

    println("已加载模板邮件：")
    println("  原 Subject = ${loaded.getSubject() ?? "(null)"}")
    println("  原 From    = ${loaded.getFrom()[0]}")

    // 修改为真实收件人（复制构造，保持模板不变）
    let toSend = MimeMessage(loaded)
    toSend.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    toSend.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    let origSubject = loaded.getSubject() ?? "模板邮件"
    toSend.setSubject("【转发】${origSubject}", "UTF-8")
    toSend.saveChanges()

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(toSend, toSend.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ 模板加载并转发成功")
    println("  发送 Subject = ${toSend.getSubject() ?? "(null)"}")
    println("  发送 To      = ${cfg.mailTo}")
}
