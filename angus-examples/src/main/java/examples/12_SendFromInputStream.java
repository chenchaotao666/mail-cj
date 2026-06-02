package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;

/**
 * 场景 12：从 InputStream 加载邮件模板后转发
 *
 * 演示：
 * - MimeMessage(Session, InputStream) 构造解析 RFC 2822 原始邮件
 * - 修改部分字段（收件人、Subject 加前缀）后转发
 *
 * 对标 mail-cj：
 *   MimeMessage(session, input: InputStream)
 */
class SendFromInputStream {

    // 模拟一封原始 RFC 2822 格式邮件（通常来自文件、数据库或消息队列）
    private static final String RAW_EMAIL = """
            From: template@example.com
            To: placeholder@example.com
            Subject: 月度报告模板
            Content-Type: text/plain; charset=UTF-8
            MIME-Version: 1.0

            尊敬的用户，

            请查收本月报告。

            此邮件由系统自动发送。
            """;

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        // 从 InputStream 解析原始邮件
        byte[] rawBytes = RAW_EMAIL.getBytes(StandardCharsets.UTF_8);
        MimeMessage loaded = new MimeMessage(session,
            new ByteArrayInputStream(rawBytes));

        System.out.println("已加载模板邮件：");
        System.out.println("  原 Subject = " + loaded.getSubject());
        System.out.println("  原 From    = " + loaded.getFrom()[0]);

        // 修改为真实收件人（复制构造，保持模板不变）
        MimeMessage toSend = new MimeMessage(loaded);
        toSend.setRecipient(Message.RecipientType.TO,
            new InternetAddress(cfg.mailTo()));
        toSend.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        toSend.setSubject("【转发】" + loaded.getSubject(), "UTF-8");
        toSend.saveChanges();

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(toSend, toSend.getAllRecipients());
        }

        System.out.println("✓ 模板加载并转发成功");
        System.out.println("  发送 Subject = " + toSend.getSubject());
        System.out.println("  发送 To      = " + cfg.mailTo());
    }
}
