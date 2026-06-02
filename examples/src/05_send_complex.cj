/**
 * 场景 5：复杂邮件（HTML + 内嵌图片 + 附件）
 *
 * 结构：
 *   multipart/mixed
 *     ├── multipart/related
 *     │     ├── text/html
 *     │     └── image/png  (inline, cid:logo)
 *     └── attachment
 *
 * 对标 angus-examples：SendComplex.java
 * 对标 mail-cj API：msg.setHtmlWithImagesAndAttachments()
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.activation.*
import mail.tls.*

public func sendComplex(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】复杂邮件 HTML+图片+附件", "UTF-8")

    // ── HTML 正文 ──────────────────────────────────────────────
    let htmlPart = MimeBodyPart()
    htmlPart.setHtmlContent("""
<html><body>
  <h2 style="color:#2c7be5;">复杂邮件示例</h2>
  <p>本邮件包含：</p>
  <ul>
    <li>HTML 正文</li>
    <li>内嵌图片 <img src="cid:logo" style="vertical-align:middle;" width="40"/></li>
    <li>附件</li>
  </ul>
</body></html>
""")

    // ── 内嵌图片 ──────────────────────────────────────────────
    let imgPart = MimeBodyPart()
    let ds = ByteArrayDataSource(createMinimalPng(), "image/png")
    imgPart.setDataHandler(DataHandler(ds))
    imgPart.setContentID("<logo>")
    imgPart.setDisposition(PART_INLINE)

    // ── multipart/related（HTML + 图片）────────────────────────
    let related = MimeMultipart(MULTIPART_RELATED)
    related.addBodyPart(htmlPart)
    related.addBodyPart(imgPart)
    let relatedPart = MimeBodyPart()
    relatedPart.setContentType("multipart/related")
    relatedPart.setDataHandler(DataHandler(createRelatedDataSource(related)))

    // ── 附件 ──────────────────────────────────────────────────
    let attachPart = MimeBodyPart()
    attachPart.attachFile(cfg.attachmentPath)
    attachPart.setFileName(MimeUtility.encodeText(cfg.attachmentPath, charset: "UTF-8", encoding: Some("B")))

    // ── 顶层 multipart/mixed ──────────────────────────────────
    let mixed = MimeMultipart(MULTIPART_MIXED)
    mixed.addBodyPart(relatedPart)
    mixed.addBodyPart(attachPart)
    msg.setContent(mixed)

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ 复杂邮件发送成功")
}

func createRelatedDataSource(mp: MimeMultipart): ByteArrayDataSource {
    let out = ByteArrayOutputStream()
    mp.writeTo(out)
    ByteArrayDataSource(out.toArray(), mp.getContentType())
}
