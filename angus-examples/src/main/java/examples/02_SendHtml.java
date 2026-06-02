package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;

/**
 * 场景 2：HTML 邮件
 *
 * 对标 mail-cj：
 *   sendHtmlEmail() / msg.setHtmlContent()
 */
class SendHtml {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】HTML 邮件", "UTF-8");
        msg.setContent("""
                <html>
                <body>
                  <h1 style="color:#2c7be5;">Hello from angus-mail</h1>
                  <p>这是一封 <strong>HTML</strong> 邮件。</p>
                  <ul>
                    <li>支持富文本格式</li>
                    <li>支持 CSS 样式</li>
                    <li>支持超链接：<a href="https://github.com">GitHub</a></li>
                  </ul>
                </body>
                </html>
                """, "text/html; charset=UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ HTML 邮件发送成功");
    }
}
