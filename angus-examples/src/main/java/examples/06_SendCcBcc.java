package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;

/**
 * 场景 6：多收件人（TO / CC / BCC）
 *
 * 对标 mail-cj：
 *   msg.setRecipients(TO/CC/BCC, ...)
 *   BCC 不出现在邮件头（安全性保证）
 */
class SendCcBcc {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));

        // TO：主收件人
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));

        // CC：抄送（邮件头中可见）
        String ccList = cfg.mailCc();
        if (!ccList.isEmpty()) {
            msg.setRecipients(Message.RecipientType.CC,
                InternetAddress.parse(ccList));
        }

        // BCC：密送（邮件头中不可见，服务器单独投递）
        String bccList = cfg.mailBcc();
        if (!bccList.isEmpty()) {
            msg.setRecipients(Message.RecipientType.BCC,
                InternetAddress.parse(bccList));
        }

        msg.setSubject("【mail-cj 对标】CC / BCC 测试", "UTF-8");
        msg.setText("TO、CC、BCC 多收件人发送示例。\nBCC 收件人不会出现在邮件头中。", "UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            // 使用 getAllRecipients() 确保 BCC 也被投递
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ CC/BCC 邮件发送成功");
        System.out.println("  TO  = " + cfg.mailTo());
        System.out.println("  CC  = " + (ccList.isEmpty() ? "(未配置)" : ccList));
        System.out.println("  BCC = " + (bccList.isEmpty() ? "(未配置)" : bccList));
    }
}
