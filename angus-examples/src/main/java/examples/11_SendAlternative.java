package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;

/**
 * 场景 11：multipart/alternative（纯文本 + HTML 兼容）
 *
 * 当收件方邮件客户端不支持 HTML 时，自动回退到纯文本。
 * RFC 2046 规定：客户端应显示最后一个它支持的 part，
 * 因此 HTML part 放在 text/plain 之后。
 *
 * 对标 mail-cj：
 *   MimeMultipart("alternative")
 */
class SendAlternative {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】multipart/alternative", "UTF-8");

        // 纯文本版本（兜底）
        MimeBodyPart textPart = new MimeBodyPart();
        textPart.setText("您好！\n\n这是纯文本版本。如果您的邮件客户端不支持 HTML，将显示此内容。\n\n查看详情：https://example.com", "UTF-8");

        // HTML 版本（优先显示）
        MimeBodyPart htmlPart = new MimeBodyPart();
        htmlPart.setContent("""
                <html><body>
                  <p>您好！</p>
                  <p>这是 <strong>HTML</strong> 版本。支持富文本的客户端将显示此内容。</p>
                  <p><a href="https://example.com" style="color:#2c7be5;">查看详情</a></p>
                </body></html>
                """, "text/html; charset=UTF-8");

        // alternative：text/plain 在前，text/html 在后
        MimeMultipart alternative = new MimeMultipart("alternative");
        alternative.addBodyPart(textPart);
        alternative.addBodyPart(htmlPart);
        msg.setContent(alternative);

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ multipart/alternative 邮件发送成功");
    }
}
