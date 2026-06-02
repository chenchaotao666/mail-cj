package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;

/**
 * 场景 8：Reply-To 与 reply() 回复邮件
 *
 * 演示两个子场景：
 * a. 设置自定义 Reply-To 地址（收件人点"回复"时发到 reply@ 而非 from@）
 * b. 用 MimeMessage.reply() 生成回复消息（自动加 Re: 前缀、In-Reply-To 头）
 *
 * 对标 mail-cj：
 *   msg.setReplyTo() / msg.reply(replyToAll)
 */
class SendReply {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        // ── 场景 a：自定义 Reply-To ────────────────────────────────
        MimeMessage original = new MimeMessage(session);
        original.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        original.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        // 回复地址指向不同的邮箱（如客服专用地址）
        original.setReplyTo(InternetAddress.parse("support@example.com"));
        original.setSubject("【mail-cj 对标】自定义 Reply-To", "UTF-8");
        original.setText("本邮件设置了 Reply-To: support@example.com\n"
            + "收件人点回复时，邮件将发往 support@example.com。", "UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(original, original.getAllRecipients());
        }
        System.out.println("✓ 自定义 Reply-To 邮件发送成功");

        // ── 场景 b：生成回复邮件 ────────────────────────────────────
        // reply(false) 会把 TO 设为原邮件的 Reply-To（support@example.com），
        // 覆盖为实际收件人才能收到
        original.saveChanges();
        MimeMessage reply = (MimeMessage) original.reply(false);
        reply.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        reply.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        reply.setText("这是对原始邮件的回复。\n\n在 angus-mail 中使用 reply(false) 生成。\n"
            + "注意：Subject 自动加了 Re: 前缀，且包含 In-Reply-To 头。", "UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(reply, reply.getAllRecipients());
        }
        System.out.println("✓ 回复邮件发送成功");
        System.out.println("  Subject    = " + reply.getSubject());
        System.out.println("  In-Reply-To= " + reply.getHeader("In-Reply-To", null));
    }
}
