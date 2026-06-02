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
 * 对标 angus-examples：SendWithXOAuth2.java
 * 对标 mail-cj API：XOAuth2Mechanism / mail.smtps.auth.xoauth2.token
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendWithXOAuth2(): Unit {
    let cfg = getConfig()

    let token = cfg.oauth2Token
    if (token.isEmpty()) {
        println("跳过：未配置 OAUTH2_TOKEN（在 .env 中设置）")
        return
    }

    let props = HashMap<String, String>()
    props["mail.smtps.host"]               = cfg.smtpHost
    props["mail.smtps.port"]               = "465"
    props["mail.smtps.auth"]               = "true"
    props["mail.smtps.auth.mechanisms"]    = "XOAUTH2"
    props["mail.smtps.auth.xoauth2.token"] = token
    props["mail.smtps.ssl.checkserveridentity"] = "false"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】XOAUTH2 认证", "UTF-8")
    msg.setText("本邮件通过 OAuth2 Bearer Token 认证发送，无需明文密码。", "UTF-8")

    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, token)
        t.sendMessage(msg, msg.getAllRecipients())
    } finally {
        t.close()
    }

    println("✓ XOAUTH2 邮件发送成功")
}
