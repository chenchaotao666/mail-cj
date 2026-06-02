package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.util.List;

/**
 * 场景 9：群发 / 批量发送（单连接，复制构造）
 *
 * 关键点：
 * - 建立一次 Transport 连接，循环发送多封
 * - 用 MimeMessage(source) 复制构造为每个收件人生成独立副本
 *   （避免多收件人之间 Message-ID 相同、headers 互相影响）
 *
 * 对标 mail-cj：
 *   handler.cj sendBatchWithHandler() / MimeMessage(source)
 */
class SendBulk {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        // 模拟收件人列表（实际场景从数据库或配置读取）
        List<String> recipients = List.of(
            cfg.mailTo()
            // "user2@example.com",
            // "user3@example.com"
        );

        Session session = Session.getInstance(cfg.smtpsProps());

        // 构建模板消息
        MimeMessage template = new MimeMessage(session);
        template.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        template.setSubject("【mail-cj 对标】群发邮件", "UTF-8");
        template.setText("您好！\n\n这是一封群发邮件。\n\n此邮件为单独发送，收件人之间互不可见。", "UTF-8");

        int success = 0;
        int failure = 0;

        // 单连接发送全部
        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());

            for (String to : recipients) {
                try {
                    // 复制构造：每封独立副本，独立 Message-ID
                    MimeMessage copy = new MimeMessage(template);
                    copy.setRecipient(Message.RecipientType.TO, new InternetAddress(to));
                    copy.saveChanges();
                    t.sendMessage(copy, copy.getAllRecipients());
                    System.out.println("  ✓ 发送成功 → " + to);
                    success++;
                } catch (MessagingException e) {
                    System.out.println("  ✗ 发送失败 → " + to + " : " + e.getMessage());
                    failure++;
                }
            }
        }

        System.out.printf("✓ 群发完成：成功 %d / 失败 %d%n", success, failure);
    }
}
