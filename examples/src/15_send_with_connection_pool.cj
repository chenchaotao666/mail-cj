/**
 * 场景 15：长连接保活 + NOOP 心跳
 *
 * 演示：
 * - 单连接发送多封邮件（复用连接，避免反复握手）
 * - isConnected() 检测连接是否存活
 * - 连接断开时自动重连
 *
 * 对标 angus-examples：SendWithConnectionPool.java
 * 对标 mail-cj API：transport.isConnected() / TlsSMTPTransport.noop()
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendWithConnectionPool(): Unit {
    let cfg = getConfig()

    let emails: Array<(String, String)> = [
        ("第1封：纯文本邮件", "这是第 1 封测试邮件。"),
        ("第2封：HTML 通知",  "<b>这是第 2 封 HTML 邮件。</b>"),
        ("第3封：系统报警",   "系统告警：CPU 使用率超过 90%，请及时处理！")
    ]

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    var success = 0
    let transport = TlsSMTPTransport(session, true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        println("连接建立成功")

        for ((subject, body) in emails) {
            // 检测连接是否仍然存活
            if (!transport.isConnected()) {
                println("  连接断开，重新连接...")
                transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
            }

            let msg = MimeMessage(session)
            msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
            msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
            msg.setSubject("【mail-cj 对标】${subject}", "UTF-8")

            if (body.startsWith("<")) {
                msg.setHtmlContent(body, "UTF-8")
            } else {
                msg.setText(body, "UTF-8")
            }

            transport.sendMessage(msg, msg.getAllRecipients())
            println("  ✓ 发送成功：${subject}")
            success += 1
        }
    } finally {
        if (transport.isConnected()) {
            transport.close()
            println("连接已关闭")
        }
    }

    println("✓ 连接池模式发送完成：${success}/${emails.size} 成功")
}
