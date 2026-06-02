package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.util.Date;

/**
 * 场景 10：自定义邮件头 + Sender 代发
 *
 * 演示：
 * - X-* 自定义头（业务追踪、优先级标记）
 * - Sender 头（代发人，区别于 From）
 * - Importance / X-Priority 优先级标记
 * - List-Unsubscribe（营销邮件退订链接）
 *
 * 对标 mail-cj：
 *   msg.setHeader() / msg.addHeader() / msg.setSender()
 */
class SendWithCustomHeaders {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        Session session = Session.getInstance(cfg.smtpsProps());

        MimeMessage msg = new MimeMessage(session);

        // From：显示发件人（市场部）
        msg.setFrom(new InternetAddress(cfg.mailFrom(), "市场部"));

        // Sender：实际代发人（邮件系统服务账号）
        msg.setSender(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));

        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】自定义邮件头", "UTF-8");
        msg.setSentDate(new Date());

        // 邮件优先级
        msg.setHeader("Importance",  "High");
        msg.setHeader("X-Priority",  "1");

        // 业务追踪 ID（对应 SMTPMessage.setEnvelopeId）
        msg.setHeader("X-Transaction-ID", "TXN-20260601-001");
        msg.setHeader("X-Campaign-ID",    "CAMPAIGN-2026-Q2");

        // 营销退订头（RFC 2369）
        msg.setHeader("List-Unsubscribe",
            "<mailto:unsubscribe@example.com?subject=unsubscribe>, "
            + "<https://example.com/unsubscribe>");
        msg.setHeader("List-Unsubscribe-Post", "List-Unsubscribe=One-Click");

        msg.setText("本邮件包含多个自定义邮件头：\n"
            + "- Importance: High（高优先级）\n"
            + "- X-Transaction-ID：业务追踪 ID\n"
            + "- List-Unsubscribe：退订链接\n"
            + "- Sender：代发人地址", "UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ 自定义头邮件发送成功");
        System.out.println("  Sender = " + msg.getSender());
        System.out.println("  X-Transaction-ID = " + msg.getHeader("X-Transaction-ID", null));
    }
}
