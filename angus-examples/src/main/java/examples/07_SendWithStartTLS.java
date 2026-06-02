package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;

/**
 * 场景 7：STARTTLS 连接（端口 587）
 *
 * 对标 mail-cj：
 *   mail.smtp.starttls.enable=true
 *   SMTPTransport.startTLS() → TlsSocket.connectWithFd()
 */
class SendWithStartTLS {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        // 使用 STARTTLS（587）而非直连 SSL（465）
        Session session = Session.getInstance(cfg.starttlsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】STARTTLS 连接", "UTF-8");
        msg.setText("本邮件通过 STARTTLS（端口 587）发送：\n"
            + "1. 建立明文 TCP 连接\n"
            + "2. EHLO 握手，服务器声明 STARTTLS 扩展\n"
            + "3. 发送 STARTTLS 命令\n"
            + "4. 在现有连接上协商 TLS\n"
            + "5. 重新 EHLO → 认证 → 发送邮件", "UTF-8");

        try (Transport t = session.getTransport("smtp")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ STARTTLS 邮件发送成功（端口 587）");
    }
}
