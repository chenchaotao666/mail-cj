/**
 * 场景 9：群发 / 批量发送（单连接，复制构造）
 *
 * 关键点：
 * - 建立一次 Transport 连接，循环发送多封
 * - 用 MimeMessage(source) 复制构造为每个收件人生成独立副本
 *   （避免多收件人之间 Message-ID 相同、headers 互相影响）
 *
 * 对标 angus-examples：SendBulk.java
 * 对标 mail-cj API：MimeMessage(source) / handler.cj sendBatchWithHandler()
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

public func sendBulk(): Unit {
    let cfg = getConfig()

    // 模拟收件人列表（实际场景从数据库或配置读取）
    let recipients = [cfg.mailTo, cfg.mailFrom]

    let session = Session.getInstance(cfg.smtpsProps())
    session.setDebug(cfg.debug)

    // 构建模板消息
    let template = MimeMessage(session)
    template.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    template.setSubject("【mail-cj 对标】群发邮件", "UTF-8")
    template.setText("您好！\n\n这是一封群发邮件。\n\n此邮件为单独发送，收件人之间互不可见。", "UTF-8")

    var success = 0
    var failure = 0

    // 单连接发送全部
    let t = TlsSMTPTransport(session, true)
    try {
        t.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)

        for (to in recipients) {
            try {
                // 复制构造：每封独立副本，独立 Message-ID
                let copy = MimeMessage(template)
                copy.setRecipients(RecipientType.TO, InternetAddress.parse(to))
                copy.saveChanges()
                t.sendMessage(copy, copy.getAllRecipients())
                println("  ✓ 发送成功 → ${to}")
                success += 1
            } catch (e: Exception) {
                println("  ✗ 发送失败 → ${to} : ${e.message}")
                failure += 1
            }
        }
    } finally {
        t.close()
    }

    println("✓ 群发完成：成功 ${success} / 失败 ${failure}")
}
