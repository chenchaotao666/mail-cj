/**
 * 场景 1：纯文本邮件（SMTPS 465）
 *
 * 对标 angus-examples：SendSimple.java
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendSimple(): Unit {
    let cfg = getConfig()
    cfg.printInfo()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】纯文本邮件", "UTF-8")
    msg.setText("Hello！\n\n这是一封通过 mail-cj 发送的纯文本邮件。\n\n发送成功即表示 SMTP 连接正常。", "UTF-8")

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ 纯文本邮件发送成功")
}
