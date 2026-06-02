package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import org.eclipse.angus.mail.smtp.SMTPMessage;

/**
 * 场景 13：SMTPMessage — 信封 From 分离 + DSN 通知
 *
 * 演示：
 * - setEnvelopeFrom：MAIL FROM 地址与 From 头分离（退信回到专用地址）
 * - setNotifyOptions：DSN 投递状态通知（SUCCESS / FAILURE / DELAY）
 * - setReturnOption：DSN 退信内容（FULL / HDRS）
 * - setAllow8bitMIME：MAIL FROM 声明 BODY=8BITMIME
 *
 * 对标 mail-cj：
 *   SMTPMessage.setEnvelopeFrom / setNotifyOptions / setReturnOption
 */
class SendWithSMTPMessage {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        // SMTPMessage 是 MimeMessage 的子类，增加了信封级控制
        SMTPMessage msg = new SMTPMessage(session);

        // 邮件头 From（用户看到的发件人）
        msg.setFrom(new InternetAddress(cfg.mailFrom(), "营销系统"));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】SMTPMessage 信封扩展", "UTF-8");
        msg.setText("本邮件演示 SMTPMessage 的信封级控制：\n"
            + "1. 退信地址：bounce@example.com（MAIL FROM）\n"
            + "2. 显示发件人：营销系统（From 头）\n"
            + "3. DSN 通知：服务器在成功/失败时发送通知\n"
            + "4. 8BITMIME：无需 Base64 编码", "UTF-8");

        // MAIL FROM 信封地址（退信回到专用地址，与 From 头无关）
        msg.setEnvelopeFrom("bounce-" + System.currentTimeMillis() + "@example.com");

        // DSN：投递失败时通知，只返回邮件头（节省带宽）
        msg.setNotifyOptions(SMTPMessage.NOTIFY_FAILURE | SMTPMessage.NOTIFY_DELAY);
        msg.setReturnOption(SMTPMessage.RETURN_HDRS);

        // 8BITMIME：服务器支持时声明，纯文本内容无需 Base64
        msg.setAllow8bitMIME(true);

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ SMTPMessage 信封扩展邮件发送成功");
        System.out.println("  EnvelopeFrom = " + msg.getEnvelopeFrom());
        System.out.println("  NotifyOptions= " + msg.getNotifyOptions());
        System.out.println("  ReturnOption = " + msg.getReturnOption());
    }
}
