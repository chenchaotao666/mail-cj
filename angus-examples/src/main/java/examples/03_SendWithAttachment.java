package examples;

import jakarta.activation.*;
import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.io.File;

/**
 * 场景 3：带附件邮件（multipart/mixed）
 *
 * 对标 mail-cj：
 *   sendEmailWithAttachment() / msg.addAttachment()
 */
class SendWithAttachment {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】带附件邮件", "UTF-8");

        // 正文部分
        MimeBodyPart textPart = new MimeBodyPart();
        textPart.setText("您好，\n\n请查收附件。", "UTF-8");

        // 附件部分
        MimeBodyPart attachPart = new MimeBodyPart();
        File file = new File(cfg.attachmentPath());
        attachPart.attachFile(file);
        // 中文文件名 RFC 2047 编码
        attachPart.setFileName(MimeUtility.encodeText(file.getName(), "UTF-8", "B"));

        MimeMultipart mp = new MimeMultipart("mixed");
        mp.addBodyPart(textPart);
        mp.addBodyPart(attachPart);
        msg.setContent(mp);

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ 带附件邮件发送成功，附件：" + file.getName());
    }
}
