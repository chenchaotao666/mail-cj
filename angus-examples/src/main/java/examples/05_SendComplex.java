package examples;

import jakarta.activation.*;
import jakarta.mail.*;
import jakarta.mail.internet.*;
import jakarta.mail.util.ByteArrayDataSource;
import java.io.File;

/**
 * 场景 5：复杂邮件（HTML + 内嵌图片 + 附件）
 *
 * 结构：
 *   multipart/mixed
 *     ├── multipart/related
 *     │     ├── text/html
 *     │     └── image/png  (inline, cid:logo)
 *     └── application/pdf  (attachment)
 *
 * 对标 mail-cj：
 *   sendComplexEmail() / msg.setHtmlWithImagesAndAttachments()
 */
class SendComplex {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】复杂邮件 HTML+图片+附件", "UTF-8");

        // ── HTML 正文 ──────────────────────────────────────────────
        MimeBodyPart htmlPart = new MimeBodyPart();
        htmlPart.setContent("""
                <html><body>
                  <h2 style="color:#2c7be5;">复杂邮件示例</h2>
                  <p>本邮件包含：</p>
                  <ul>
                    <li>HTML 正文</li>
                    <li>内嵌图片 <img src="cid:logo" style="vertical-align:middle;" width="40"/></li>
                    <li>PDF 附件</li>
                  </ul>
                </body></html>
                """, "text/html; charset=UTF-8");

        // ── 内嵌图片 ──────────────────────────────────────────────
        MimeBodyPart imgPart = new MimeBodyPart();
        imgPart.setDataHandler(new DataHandler(
            new ByteArrayDataSource(createMinimalPng(), "image/png")));
        imgPart.setContentID("<logo>");
        imgPart.setDisposition(MimePart.INLINE);

        // ── multipart/related（HTML + 图片）────────────────────────
        MimeMultipart related = new MimeMultipart("related");
        related.addBodyPart(htmlPart);
        related.addBodyPart(imgPart);
        MimeBodyPart relatedPart = new MimeBodyPart();
        relatedPart.setContent(related);

        // ── 附件 ──────────────────────────────────────────────────
        MimeBodyPart attachPart = new MimeBodyPart();
        File file = new File(cfg.attachmentPath());
        if (!file.exists()) {
            file = File.createTempFile("report", ".txt");
            file.deleteOnExit();
            java.nio.file.Files.writeString(file.toPath(), "测试报告内容\n生成时间：" + java.time.LocalDateTime.now());
        }
        attachPart.attachFile(file);
        attachPart.setFileName(MimeUtility.encodeText(file.getName(), "UTF-8", "B"));

        // ── 顶层 multipart/mixed ──────────────────────────────────
        MimeMultipart mixed = new MimeMultipart("mixed");
        mixed.addBodyPart(relatedPart);
        mixed.addBodyPart(attachPart);
        msg.setContent(mixed);

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ 复杂邮件发送成功");
    }

    private static byte[] createMinimalPng() {
        return new byte[]{
            (byte)0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,
            0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,
            0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,
            0x08,0x02,0x00,0x00,0x00,(byte)0x90,0x77,0x53,(byte)0xDE,
            0x00,0x00,0x00,0x0C,0x49,0x44,0x41,0x54,
            0x08,(byte)0xD7,0x63,(byte)0xF8,(byte)0xCF,(byte)0xC0,0x00,0x00,
            0x00,0x02,0x00,0x01,(byte)0xE2,0x21,(byte)0xBC,0x33,
            0x00,0x00,0x00,0x00,0x49,0x45,0x4E,0x44,
            (byte)0xAE,0x42,0x60,(byte)0x82
        };
    }
}
