/**
 * 场景 6：多收件人（TO / CC / BCC）
 *
 * 对标 angus-examples：SendCcBcc.java
 * 对标 mail-cj API：msg.setRecipients(TO/CC/BCC, ...)
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendCcBcc(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))

    // TO：主收件人
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))

    // CC：抄送（邮件头中可见）
    if (!cfg.mailCc.isEmpty()) {
        msg.setRecipients(RecipientType.CC, InternetAddress.parse(cfg.mailCc))
    }

    // BCC：密送（邮件头中不可见，服务器单独投递）
    if (!cfg.mailBcc.isEmpty()) {
        msg.setRecipients(RecipientType.BCC, InternetAddress.parse(cfg.mailBcc))
    }

    msg.setSubject("【mail-cj 对标】CC / BCC 测试", "UTF-8")
    msg.setText("TO、CC、BCC 多收件人发送示例。\nBCC 收件人不会出现在邮件头中。", "UTF-8")

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        // 使用 getAllRecipients() 确保 BCC 也被投递
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ CC/BCC 邮件发送成功")
    println("  TO  = ${cfg.mailTo}")
    println("  CC  = ${if (cfg.mailCc.isEmpty()) { "(未配置)" } else { cfg.mailCc }}")
    println("  BCC = ${if (cfg.mailBcc.isEmpty()) { "(未配置)" } else { cfg.mailBcc }}")
}
