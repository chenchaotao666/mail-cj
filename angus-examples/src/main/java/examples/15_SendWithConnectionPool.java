package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.util.List;

/**
 * 场景 15：长连接保活 + NOOP 心跳
 *
 * 演示：
 * - 单连接发送多封邮件（复用连接，避免反复握手）
 * - NOOP 命令检测连接是否存活
 * - 连接断开时自动重连
 *
 * 对标 mail-cj：
 *   transport.noop() / handler.cj 的高效模式
 */
class SendWithConnectionPool {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        List<String[]> emails = List.of(
            new String[]{"第1封：纯文本邮件", "这是第 1 封测试邮件。"},
            new String[]{"第2封：HTML 通知",  "<b>这是第 2 封 HTML 邮件。</b>"},
            new String[]{"第3封：系统报警",    "系统告警：CPU 使用率超过 90%，请及时处理！"}
        );

        Session session = Session.getInstance(cfg.smtpsProps());

        int success = 0;
        Transport transport = null;

        try {
            transport = session.getTransport("smtps");
            transport.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
            System.out.println("连接建立成功");

            for (String[] item : emails) {
                // NOOP 心跳：检测连接是否仍然存活
                if (!transport.isConnected()) {
                    System.out.println("  连接断开，重新连接...");
                    transport.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
                }

                MimeMessage msg = new MimeMessage(session);
                msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
                msg.setRecipient(Message.RecipientType.TO,
                    new InternetAddress(cfg.mailTo()));
                msg.setSubject("【mail-cj 对标】" + item[0], "UTF-8");

                if (item[1].startsWith("<")) {
                    msg.setContent(item[1], "text/html; charset=UTF-8");
                } else {
                    msg.setText(item[1], "UTF-8");
                }

                transport.sendMessage(msg, msg.getAllRecipients());
                System.out.println("  ✓ 发送成功：" + item[0]);
                success++;

                // 模拟业务处理间隔（真实场景可能几秒到几分钟）
                Thread.sleep(200);
            }

        } finally {
            if (transport != null && transport.isConnected()) {
                transport.close();
                System.out.println("连接已关闭");
            }
        }

        System.out.printf("✓ 连接池模式发送完成：%d/%d 成功%n", success, emails.size());
    }
}
