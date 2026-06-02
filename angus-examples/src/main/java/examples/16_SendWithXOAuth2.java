package examples;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.util.Properties;

/**
 * 场景 16：XOAUTH2 认证（Gmail / Office 365 现代认证）
 *
 * 使用 Bearer Token 替代密码，适用于：
 * - Gmail（需开启 OAuth2，关闭"不安全应用访问"）
 * - Office 365 / Microsoft Exchange Online
 *
 * 流程：
 *   AUTH XOAUTH2 base64("user=USER\x01auth=Bearer TOKEN\x01\x01")
 *
 * 对标 mail-cj：
 *   XOAuth2Mechanism / mail.smtps.auth.xoauth2.token
 */
class SendWithXOAuth2 {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        String token = cfg.oauth2Token();
        if (token.isEmpty()) {
            System.out.println("跳过：未配置 OAUTH2_TOKEN（在 .env 中设置）");
            return;
        }

        Properties props = new Properties();
        props.put("mail.smtps.host",               cfg.smtpHost());
        props.put("mail.smtps.port",               "465");
        props.put("mail.smtps.auth",               "true");
        props.put("mail.smtps.auth.mechanisms",    "XOAUTH2");
        props.put("mail.smtps.auth.xoauth2.token", token);
        props.put("mail.smtps.ssl.checkserveridentity", "false");
        props.put("mail.debug", String.valueOf(cfg.debug()));

        Session session = Session.getInstance(props);

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】XOAUTH2 认证", "UTF-8");
        msg.setText("本邮件通过 OAuth2 Bearer Token 认证发送，无需明文密码。", "UTF-8");

        try (Transport t = session.getTransport("smtps")) {
            t.connect(cfg.smtpHost(), cfg.smtpUser(), token);
            t.sendMessage(msg, msg.getAllRecipients());
        }

        System.out.println("✓ XOAUTH2 邮件发送成功");
    }
}
