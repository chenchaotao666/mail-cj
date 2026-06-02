package examples;

import jakarta.activation.*;
import jakarta.mail.*;
import jakarta.mail.internet.*;
import jakarta.mail.util.ByteArrayDataSource;

/**
 * 场景 4：HTML + 内嵌图片（multipart/related）
 *
 * 对标 mail-cj：
 *   sendEmailWithInlineImage() / msg.setHtmlWithInlineImages()
 */
class SendWithInlineImage {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】内嵌图片邮件", "UTF-8");

        // HTML 正文（用 cid: 引用内嵌图片）
        MimeBodyPart htmlPart = new MimeBodyPart();
        htmlPart.setContent("""
                <html><body>
                  <h2>内嵌图片示例</h2>
                  <p>下方是内嵌的 Logo 图片：</p>
                  <img src="cid:logo_cid" alt="Logo" width="200"/>
                  <p>图片通过 Content-ID 内嵌在邮件中，无需外部链接。</p>
                </body></html>
                """, "text/html; charset=UTF-8");

        // 内嵌图片 part
        MimeBodyPart imagePart = new MimeBodyPart();
        java.io.File imgFile = new java.io.File(cfg.imagePath());
        if (imgFile.exists()) {
            imagePart.attachFile(imgFile);
        } else {
            // 用纯色 PNG 占位（避免文件不存在时报错）
            byte[] pngBytes = createMinimalPng();
            imagePart.setDataHandler(new DataHandler(new ByteArrayDataSource(pngBytes, "image/png")));
        }
        imagePart.setContentID("<logo_cid>");
        imagePart.setDisposition(MimePart.INLINE);

        // multipart/related 包裹 HTML + 图片
        MimeMultipart related = new MimeMultipart("related");
        related.addBodyPart(htmlPart);
        related.addBodyPart(imagePart);
        msg.setContent(related);

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ 内嵌图片邮件发送成功");
    }

    /** 生成一个 1×1 像素的最小合法 PNG 字节数组（测试占位用）。 */
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
