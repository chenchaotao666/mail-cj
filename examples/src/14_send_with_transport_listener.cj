/**
 * 场景 14：TransportListener + ConnectionListener 事件监听
 *
 * 演示：
 * - TransportListener：messageDelivered / messageNotDelivered / messagePartiallyDelivered
 * - ConnectionListener：opened / closed / disconnected
 * - mail.smtps.sendpartial=true：部分收件人无效时继续发送其余有效地址
 *
 * 对标 angus-examples：SendWithTransportListener.java
 * 对标 mail-cj API：transport.addTransportListener / addConnectionListener
 */
package mail_demo

import mail.core.*
import mail.internet.*
import mail.tls.*

class LogConnectionListener <: ConnectionListener {
    public init() {}
    public func opened(_: ConnectionEvent): Unit {
        println("  [ConnectionEvent] OPENED → 连接建立")
    }
    public func closed(_: ConnectionEvent): Unit {
        println("  [ConnectionEvent] CLOSED → 连接关闭")
    }
    public func disconnected(_: ConnectionEvent): Unit {
        println("  [ConnectionEvent] DISCONNECTED → 连接断开")
    }
}

class LogTransportListener <: TransportListener {
    public init() {}
    public func messageDelivered(e: TransportEvent): Unit {
        println("  [TransportEvent] DELIVERED → 全部收件人发送成功")
        println("    validSent.length = ${e.validSentAddresses.size}")
    }
    public func messageNotDelivered(e: TransportEvent): Unit {
        println("  [TransportEvent] NOT_DELIVERED → 全部失败")
        println("    invalidAddresses = ${e.invalidAddresses.size}")
    }
    public func messagePartiallyDelivered(e: TransportEvent): Unit {
        println("  [TransportEvent] PARTIALLY_DELIVERED → 部分成功")
        println("    validSent = ${e.validSentAddresses.size} / invalid = ${e.invalidAddresses.size}")
    }
}

public func sendWithTransportListener(): Unit {
    let cfg = getConfig()

    let props = cfg.smtpsProps()
    // sendPartial=true：部分 RCPT TO 失败时继续发送其余地址
    props["mail.smtps.sendpartial"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    msg.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    msg.setSubject("【mail-cj 对标】Transport 事件监听", "UTF-8")
    msg.setText("本邮件演示 TransportListener 和 ConnectionListener 回调。", "UTF-8")

    let transport = TlsSMTPTransport(session, true)
    transport.addConnectionListener(LogConnectionListener())
    transport.addTransportListener(LogTransportListener())

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(msg, msg.getAllRecipients())
    } finally {
        transport.close()
    }

    println("✓ 事件监听发送完成")
}
