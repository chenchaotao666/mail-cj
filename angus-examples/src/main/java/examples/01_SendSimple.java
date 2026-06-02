package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;

/**
 * 场景 1：纯文本邮件（SMTPS 465）
 *
 * 对标 mail-cj：
 *   sendSimpleEmail() in demo_basic.cj
 */
class SendSimple {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();
        cfg.printInfo();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】纯文本邮件", "UTF-8");
        msg.setText("Hello！\n\n这是一封通过 angus-mail 发送的纯文本邮件。\n\n发送成功即表示 SMTP 连接正常。", "UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ 纯文本邮件发送成功");
    }
}
