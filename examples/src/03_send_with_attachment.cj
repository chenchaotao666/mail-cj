/**
 * 场景 3：带附件邮件（multipart/mixed）
 *
 * 对标 angus-examples：SendWithAttachment.java
 * 对标 mail-cj API：MimeMultipart("mixed") / MimeBodyPart.attachFile()
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendWithAttachment(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】带附件邮件", "UTF-8")

    // 正文部分
    let textPart = MimeBodyPart()
    textPart.setText("您好，\n\n请查收附件。", "UTF-8")

    // 附件部分
    let attachPart = MimeBodyPart()
    attachPart.attachFile(cfg.attachmentPath)
    attachPart.setFileName(MimeUtility.encodeText(cfg.attachmentPath, charset: "UTF-8", encoding: Some("B")))

    let mp = MimeMultipart(MULTIPART_MIXED)
    mp.addBodyPart(textPart)
    mp.addBodyPart(attachPart)
    msg.setContent(mp)

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ 带附件邮件发送成功，附件：${cfg.attachmentPath}")
}
