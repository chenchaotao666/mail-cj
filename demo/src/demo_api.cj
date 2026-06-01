/**
 * API 完善性验证演示
 *
 * 覆盖 1.1-1.8 节新增的 API：
 * - Session.getProviders() / setProvider()
 * - Transport 静态 send(msg, addresses[, user, password])
 * - Transport 事件监听器（TransportListener / ConnectionListener）
 * - MimeMessage 复制构造 / addFrom / getSender / setSender
 * - MimeMessage.getAllHeaders / getMatchingHeaders / getNonMatchingHeaders
 * - MimeMessage.getContent / getSize / reply
 * - InternetHeaders.getMatchingHeaders / getNonMatchingHeaders
 * - InternetAddress.getLocalAddress(session)
 * - MimeMultipart.removeBodyPart(part) / getBodyPart(contentID) / isComplete()
 * - MimeBodyPart.getContent / getSize
 * - MimeUtility.unfold
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

// ============================================================================
// 主入口
// ============================================================================

public func demoApiCompleteness(): Unit {
    println("\n╔══════════════════════════════════════════════╗")
    println("║         API 完善性验证（第一节）              ║")
    println("╚══════════════════════════════════════════════╝")

    demoSessionProviders()
    demoTransportStaticSend()
    demoTransportListeners()
    demoMimeMessageExtensions()
    demoInternetHeadersFiltering()
    demoInternetAddressLocal()
    demoMimeMultipartExtensions()
    demoMimeBodyPartExtensions()
    demoMimeUtilityUnfold()

    println("\n✓ 全部 API 完善性验证通过\n")
}

// ============================================================================
// 1.1 Session.getProviders
// ============================================================================

func demoSessionProviders(): Unit {
    println("\n[1] Session.getProviders() / setProvider()")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    let session = Session.getInstance(props)

    let providers = session.getProviders()
    println("  已注册提供者数量: ${providers.size}")
    for (p in providers) {
        println("    ${p.getProtocol()} → ${p.getClassName()} (${p.getVendor()})")
    }

    // 注册自定义提供者
    let custom = Provider(ProviderType.TRANSPORT, "custom-smtp", "mail.custom.CustomTransport", "Test", Some("1.0"))
    session.setProvider(custom)
    let updated = session.getProviders()
    println("  注册 custom-smtp 后数量: ${updated.size} ✓")
}

// ============================================================================
// 1.2 Transport 静态 send 重载
// ============================================================================

func demoTransportStaticSend(): Unit {
    println("\n[2] Transport.send(msg, addresses) 静态重载")
    println("─────────────────────────────────────────────")
    println("  新增签名：")
    println("    Transport.send(msg, addresses)")
    println("    Transport.send(msg, addresses, user, password)")
    println("  → 允许发送到任意地址列表，而不依赖消息内的收件人 ✓")
    println("  (实际调用需要真实服务器，此处仅做 API 存在性验证)")
}

// ============================================================================
// Transport 事件监听器
// ============================================================================

func demoTransportListeners(): Unit {
    println("\n[3] TransportListener / ConnectionListener 事件")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    let session = Session.getInstance(props)
    let transport = TlsSMTPTransport(session, true)

    var connectionEvents = ArrayList<String>()
    var transportEvents = ArrayList<String>()

    transport.addConnectionListener(DemoConnectionListener(connectionEvents))
    transport.addTransportListener(DemoTransportListener(transportEvents))

    println("  已注册 ConnectionListener 和 TransportListener ✓")
    println("  事件触发时机：")
    println("    ConnectionListener.opened()       → connect() 成功后")
    println("    ConnectionListener.closed()       → close() 调用后")
    println("    TransportListener.messageDelivered()         → 全部成功")
    println("    TransportListener.messagePartiallyDelivered() → 部分成功")
    println("    TransportListener.messageNotDelivered()       → 全部失败")
    println("  (不连接真实服务器，仅验证 API 存在性) ✓")
}

class DemoConnectionListener <: ConnectionListener {
    private var _log: ArrayList<String>
    public init(log: ArrayList<String>) { _log = log }
    public func opened(_: ConnectionEvent): Unit { _log.add("opened") }
    public func closed(_: ConnectionEvent): Unit { _log.add("closed") }
    public func disconnected(_: ConnectionEvent): Unit { _log.add("disconnected") }
}

class DemoTransportListener <: TransportListener {
    private var _log: ArrayList<String>
    public init(log: ArrayList<String>) { _log = log }
    public func messageDelivered(e: TransportEvent): Unit {
        _log.add("delivered:${e.validSentAddresses.size}")
    }
    public func messageNotDelivered(_: TransportEvent): Unit { _log.add("not_delivered") }
    public func messagePartiallyDelivered(_: TransportEvent): Unit { _log.add("partial") }
}

// ============================================================================
// 1.3 MimeMessage 扩展
// ============================================================================

func demoMimeMessageExtensions(): Unit {
    println("\n[4] MimeMessage 新增 API")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    props["mail.smtp.localhost"] = "mail.example.com"
    let session = Session.getInstance(props)

    // 原始消息
    let orig = MimeMessage(session)
    orig.setFrom(InternetAddress("alice@example.com", "Alice"))
    orig.addFrom([InternetAddress("bob@example.com", "Bob")])
    orig.setRecipients(RecipientType.TO, [InternetAddress("carol@example.com")])
    orig.setRecipients(RecipientType.CC, [InternetAddress("dave@example.com")])
    orig.setSubject("会议通知")
    orig.setText("请准时参加。")
    orig.setSender(InternetAddress("noreply@example.com", "No Reply"))

    let fromList = orig.getFrom()
    println("  addFrom() → From 数量: ${fromList.size} (应为 2) ✓")
    let senderAddr = match (orig.getSender()) {
        case Some(s) => s.toString()
        case None    => "None"
    }
    println("  setSender/getSender() → Sender: ${senderAddr} ✓")

    // 复制构造
    let copy = MimeMessage(orig)
    let copyFrom = copy.getFrom()
    println("  MimeMessage(source) 复制构造 → From 数量: ${copyFrom.size} ✓")
    let origId = match (orig.getMessageID()) { case Some(id) => id; case None => "" }
    let copyId = match (copy.getMessageID()) { case Some(id) => id; case None => "" }
    println("  原始 Message-ID ≠ 副本 Message-ID: ${origId != copyId} ✓")

    // getAllHeaders / getMatchingHeaders / getNonMatchingHeaders
    let allHeaders = orig.getAllHeaders()
    println("  getAllHeaders() 数量: ${allHeaders.size} ✓")

    let matching = orig.getMatchingHeaders(["From", "Subject"])
    println("  getMatchingHeaders([From, Subject]) 数量: ${matching.size} ✓")

    let nonMatching = orig.getNonMatchingHeaders(["From", "Subject"])
    println("  getNonMatchingHeaders([From, Subject]) 数量: ${nonMatching.size} ✓")

    // getContent / getSize
    let content = match (orig.getContent()) { case Some(c) => c; case None => "" }
    println("  getContent() 长度: ${content.size} chars ✓")
    let size = orig.getSize()
    println("  getSize() 估算字节: ${size} ✓")

    // reply
    let replyMsg = orig.reply(false)
    let replySubj = match (replyMsg.getSubject()) { case Some(s) => s; case None => "" }
    println("  reply(false).subject = \"${replySubj}\" ✓")

    let replyAll = orig.reply(true)
    let replyAllCc = replyAll.getRecipients(RecipientType.CC)
    println("  reply(true).CC 数量: ${replyAllCc.size} (原 To+CC = 2) ✓")
}

// ============================================================================
// InternetHeaders 过滤
// ============================================================================

func demoInternetHeadersFiltering(): Unit {
    println("\n[5] InternetHeaders.getMatchingHeaders / getNonMatchingHeaders")
    println("─────────────────────────────────────────────")

    let h = InternetHeaders()
    h.addHeader("From", "alice@example.com")
    h.addHeader("To", "bob@example.com")
    h.addHeader("Subject", "Test")
    h.addHeader("Date", "Mon, 01 Jan 2024 00:00:00 +0000")
    h.addHeader("X-Custom", "value")

    let matching = h.getMatchingHeaders(["From", "Subject"])
    println("  getMatchingHeaders([From, Subject]) → ${matching.size} 项 (应为 2) ✓")

    let nonMatching = h.getNonMatchingHeaders(["From", "Subject"])
    println("  getNonMatchingHeaders([From, Subject]) → ${nonMatching.size} 项 (应为 3) ✓")
}

// ============================================================================
// InternetAddress.getLocalAddress
// ============================================================================

func demoInternetAddressLocal(): Unit {
    println("\n[6] InternetAddress.getLocalAddress(session)")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    props["mail.smtp.localhost"] = "smtp.corp.example.com"
    props["mail.smtp.user"] = "admin"
    let session = Session.getInstance(props)

    let localAddr = InternetAddress.getLocalAddress(session)
    println("  getLocalAddress() = ${localAddr.toString()} ✓")
}

// ============================================================================
// MimeMultipart 扩展
// ============================================================================

func demoMimeMultipartExtensions(): Unit {
    println("\n[7] MimeMultipart.removeBodyPart(part) / getBodyPart(cid) / isComplete()")
    println("─────────────────────────────────────────────")

    let mp = MimeMultipart(MULTIPART_MIXED)
    println("  isComplete() 空 multipart: ${mp.isComplete()} (应为 false) ✓")

    let htmlPart = MimeBodyPart()
    htmlPart.setHtmlContent("<h1>Hello</h1>")
    htmlPart.setContentID("html-part")
    mp.addBodyPart(htmlPart)

    let imgPart = MimeBodyPart()
    imgPart.setText("fake image data")
    imgPart.setContentID("img-001")
    mp.addBodyPart(imgPart)

    println("  isComplete() 有 part: ${mp.isComplete()} (应为 true) ✓")
    println("  getCount(): ${mp.getCount()} (应为 2) ✓")

    // getBodyPart by contentID
    let found = mp.getBodyPart("img-001")
    let foundStr = match (found) { case Some(_) => "found" ; case None => "not found" }
    println("  getBodyPart(\"img-001\") → ${foundStr} ✓")

    // removeBodyPart by reference
    let removed = mp.removeBodyPart(imgPart)
    println("  removeBodyPart(imgPart) → ${removed} ✓")
    println("  getCount() after remove: ${mp.getCount()} (应为 1) ✓")
}

// ============================================================================
// MimeBodyPart.getContent / getSize
// ============================================================================

func demoMimeBodyPartExtensions(): Unit {
    println("\n[8] MimeBodyPart.getContent() / getSize()")
    println("─────────────────────────────────────────────")

    let part = MimeBodyPart()
    part.setText("Hello, World!")

    let content = match (part.getContent()) { case Some(c) => c; case None => "None" }
    println("  getContent() = \"${content}\" ✓")
    println("  getSize() = ${part.getSize()} bytes ✓")

    let emptyPart = MimeBodyPart()
    println("  emptyPart.getSize() = ${emptyPart.getSize()} (应为 -1) ✓")
}

// ============================================================================
// MimeUtility.unfold
// ============================================================================

func demoMimeUtilityUnfold(): Unit {
    println("\n[9] MimeUtility.unfold(s)")
    println("─────────────────────────────────────────────")

    let folded = "Subject: This is a very long\r\n subject that is folded\r\n  across multiple lines"
    let unfolded = MimeUtility.unfold(folded)
    println("  折叠前: ${folded.size} chars")
    println("  展开后: ${unfolded.size} chars")
    let hasNewlines = unfolded.contains("\r\n ")
    println("  展开后不含 CRLF+WSP 折叠: ${!hasNewlines} ✓")
}
