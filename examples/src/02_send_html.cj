/**
 * 场景 2：HTML 邮件
 *
 * 对标 angus-examples：SendHtml.java
 * 对标 mail-cj API：msg.setHtmlContent()
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendHtml(): Unit {
    let cfg = getConfig()

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】HTML 邮件", "UTF-8")
    msg.setHtmlContent("""
<html>
<body>
  <h1 style="color:#2c7be5;">Hello from mail-cj</h1>
  <p>这是一封 <strong>HTML</strong> 邮件。</p>
  <ul>
    <li>支持富文本格式</li>
    <li>支持 CSS 样式</li>
    <li>支持超链接：<a href="https://github.com">GitHub</a></li>
  </ul>
</body>
</html>
""", "UTF-8")

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ HTML 邮件发送成功")
}
