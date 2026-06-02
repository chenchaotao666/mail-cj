/**
 * 场景 7：STARTTLS 连接（端口 587）
 *
 * 对标 angus-examples：SendWithStartTLS.java
 * 对标 mail-cj API：mail.smtp.starttls.enable=true / TlsSMTPTransport(session, false)
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendWithStartTLS(): Unit {
    let cfg = getConfig()

    // 使用 STARTTLS（587）而非直连 SSL（465）
    let session = Session.getInstance(cfg.starttlsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】STARTTLS 连接", "UTF-8")
    msg.setText("本邮件通过 STARTTLS（端口 587）发送：\n"
        + "1. 建立明文 TCP 连接\n"
        + "2. EHLO 握手，服务器声明 STARTTLS 扩展\n"
        + "3. 发送 STARTTLS 命令\n"
        + "4. 在现有连接上协商 TLS\n"
        + "5. 重新 EHLO → 认证 → 发送邮件", "UTF-8")

    let t = TlsSMTPTransport(session, false)
    try {
        t.connect(cfg.smtpHost, 587, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ STARTTLS 邮件发送成功（端口 587）")
}
