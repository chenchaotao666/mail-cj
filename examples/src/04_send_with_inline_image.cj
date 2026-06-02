/**
 * 场景 4：HTML + 内嵌图片（multipart/related）
 *
 * 对标 angus-examples：SendWithInlineImage.java
 * 对标 mail-cj API：msg.setHtmlWithInlineImages() / MimeMultipart("related")
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.activation.*
import mail.tls.*

public func sendWithInlineImage(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】内嵌图片邮件", "UTF-8")

    // HTML 正文（用 cid: 引用内嵌图片）
    let htmlPart = MimeBodyPart()
    htmlPart.setHtmlContent("""
<html><body>
  <h2>内嵌图片示例</h2>
  <p>下方是内嵌的 Logo 图片：</p>
  <img src="cid:logo_cid" alt="Logo" width="200"/>
  <p>图片通过 Content-ID 内嵌在邮件中，无需外部链接。</p>
</body></html>
""")

    // 内嵌图片 part
    let imagePart = MimeBodyPart()
    let imgFile = "../" + cfg.attachmentPath.replace("test.txt", "logo.jpg")
    try {
        imagePart.attachFile(imgFile)
    } catch (_: Exception) {
        // 图片不存在时用最小 PNG 占位
        let ds = ByteArrayDataSource(createMinimalPng(), "image/png")
        imagePart.setDataHandler(DataHandler(ds))
    }
    imagePart.setContentID("<logo_cid>")
    imagePart.setDisposition(PART_INLINE)

    // multipart/related 包裹 HTML + 图片
    let related = MimeMultipart(MULTIPART_RELATED)
    related.addBodyPart(htmlPart)
    related.addBodyPart(imagePart)
    msg.setContent(related)

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ 内嵌图片邮件发送成功")
}

func createMinimalPng(): Array<Byte> {
    [
        0x89u8, 0x50u8, 0x4Eu8, 0x47u8, 0x0Du8, 0x0Au8, 0x1Au8, 0x0Au8,
        0x00u8, 0x00u8, 0x00u8, 0x0Du8, 0x49u8, 0x48u8, 0x44u8, 0x52u8,
        0x00u8, 0x00u8, 0x00u8, 0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x01u8,
        0x08u8, 0x02u8, 0x00u8, 0x00u8, 0x00u8, 0x90u8, 0x77u8, 0x53u8, 0xDEu8,
        0x00u8, 0x00u8, 0x00u8, 0x0Cu8, 0x49u8, 0x44u8, 0x41u8, 0x54u8,
        0x08u8, 0xD7u8, 0x63u8, 0xF8u8, 0xCFu8, 0xC0u8, 0x00u8, 0x00u8,
        0x00u8, 0x02u8, 0x00u8, 0x01u8, 0xE2u8, 0x21u8, 0xBCu8, 0x33u8,
        0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x49u8, 0x45u8, 0x4Eu8, 0x44u8,
        0xAEu8, 0x42u8, 0x60u8, 0x82u8
    ]
}
