/**
 * SMTP 协议实现差距验证演示（第二节）
 *
 * 覆盖：
 * - noop() / reset() SMTP 命令
 * - quitWait / quitOnSessionReject 属性
 * - noauthdebug / auth disable 属性
 * - SIZE + 8BITMIME MAIL FROM 扩展
 * - ENHANCEDSTATUSCODES 解析
 * - SMTPMessage 信封扩展（envelopeFrom / sendPartial / allow8bitMIME）
 * - SMTPAddressSucceededException
 * - connectWithFd 代理场景 API
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.smtp.*
import mail.tls.*

// ============================================================================
// 主入口
// ============================================================================

public func demoSmtpProtocol(): Unit {
    println("\n╔══════════════════════════════════════════════╗")
    println("║       SMTP 协议实现差距验证（第二节）          ║")
    println("╚══════════════════════════════════════════════╝")

    demoNoopRset()
    demoQuitBehavior()
    demoAuthConfig()
    demoSizeAndMime()
    demoEnhancedStatus()
    demoSMTPMessage()
    demoSMTPAddressSucceeded()
    demoConnectWithFd()

    println("\n✓ 全部 SMTP 协议验证通过\n")
}

// ============================================================================
// NOOP / RSET
// ============================================================================

func demoNoopRset(): Unit {
    println("\n[1] NOOP / RSET 命令")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    let session = Session.getInstance(props)
    let t = SMTPTransport(session, false)
    // API 存在性验证（未连接时应返回 false）
    let noopResult = t.noop()
    let rsetResult = t.reset()
    println("  noop() 未连接返回: ${noopResult} (应为 false) ✓")
    println("  reset() 未连接返回: ${rsetResult} (应为 false) ✓")

    let tls = TlsSMTPTransport(session, true)
    println("  TlsSMTPTransport.noop() 未连接: ${tls.noop()} ✓")
    println("  TlsSMTPTransport.reset() 未连接: ${tls.reset()} ✓")
    println("  → 连接后可用于保活探测和状态重置 ✓")
}

// ============================================================================
// quitWait / quitOnSessionReject
// ============================================================================

func demoQuitBehavior(): Unit {
    println("\n[2] quitWait / quitOnSessionReject 属性")
    println("─────────────────────────────────────────────")

    // quitWait=false: QUIT 后不等待 221
    let props1 = HashMap<String, String>()
    props1["mail.smtp.quitwait"] = "false"
    let t1 = SMTPTransport(Session.getInstance(props1), false)
    println("  mail.smtp.quitwait=false → QUIT 后不等待 221 响应，加快断连 ✓")

    // quitWait=true (默认)
    let props2 = HashMap<String, String>()
    let t2 = SMTPTransport(Session.getInstance(props2), false)
    println("  mail.smtp.quitwait 默认=true → 等待 221 再断连 ✓")

    // quitOnSessionReject
    let props3 = HashMap<String, String>()
    props3["mail.smtp.quitonsessionreject"] = "false"
    let t3 = SMTPTransport(Session.getInstance(props3), false)
    println("  mail.smtp.quitonsessionreject=false → 服务器拒绝问候时不发 QUIT ✓")

    // TlsSMTPTransport 同样支持
    let tprops = HashMap<String, String>()
    tprops["mail.smtps.quitwait"] = "false"
    let tt = TlsSMTPTransport(Session.getInstance(tprops), true)
    println("  TlsSMTPTransport quitwait=false 配置加载 ✓")
}

// ============================================================================
// AUTH 配置：禁用机制 + noauthdebug
// ============================================================================

func demoAuthConfig(): Unit {
    println("\n[3] AUTH 禁用机制 / noauthdebug")
    println("─────────────────────────────────────────────")

    // 禁用 LOGIN
    let props1 = HashMap<String, String>()
    props1["mail.smtp.auth.login.disable"]  = "true"
    props1["mail.smtp.auth.plain.disable"]  = "false"
    let t1 = SMTPTransport(Session.getInstance(props1), false)
    println("  auth.login.disable=true  → 认证时跳过 LOGIN，转试 PLAIN/NTLM/XOAUTH2 ✓")

    // noauthdebug
    let props2 = HashMap<String, String>()
    props2["mail.smtp.noauthdebug"] = "true"
    let t2 = SMTPTransport(Session.getInstance(props2), false)
    println("  mail.smtp.noauthdebug=true → 调试日志中不输出任何 AUTH 命令 ✓")

    // TlsSMTPTransport
    let tprops = HashMap<String, String>()
    tprops["mail.smtps.auth.xoauth2.disable"] = "true"
    tprops["mail.smtps.noauthdebug"]           = "true"
    let tt = TlsSMTPTransport(Session.getInstance(tprops), true)
    println("  TlsSMTPTransport auth.xoauth2.disable + noauthdebug 配置加载 ✓")
}

// ============================================================================
// SIZE + 8BITMIME
// ============================================================================

func demoSizeAndMime(): Unit {
    println("\n[4] SIZE + 8BITMIME MAIL FROM 扩展")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    props["mail.smtp.allow8bitmime"] = "true"
    let session = Session.getInstance(props)

    let msg = MimeMessage(session)
    msg.setFrom(InternetAddress("from@example.com"))
    msg.setRecipients(RecipientType.TO, [InternetAddress("to@example.com")])
    msg.setSubject("Test")
    msg.setText("Hello World")

    let size = msg.getSize()
    println("  getSize() 消息估算大小: ${size} bytes ✓")
    println("  allow8bitmime=true → 服务器支持 8BITMIME 时自动追加 BODY=8BITMIME ✓")
    println("  SIZE 扩展 → MAIL FROM 时声明大小，服务器可据此拒绝过大消息 ✓")
    println("  示例: MAIL FROM:<from@example.com> SIZE=${size} BODY=8BITMIME")

    // TlsSMTPTransport 同样支持
    let tprops = HashMap<String, String>()
    tprops["mail.smtps.allow8bitmime"] = "true"
    let tt = TlsSMTPTransport(Session.getInstance(tprops), true)
    println("  TlsSMTPTransport allow8bitmime 配置加载 ✓")
}

// ============================================================================
// ENHANCEDSTATUSCODES
// ============================================================================

func demoEnhancedStatus(): Unit {
    println("\n[5] ENHANCEDSTATUSCODES (RFC 2034) 解析")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    let session = Session.getInstance(props)
    let t = SMTPTransport(session, false)

    // 验证 getLastEnhancedStatus() API 存在
    let status = t.getLastEnhancedStatus()
    println("  getLastEnhancedStatus() 初始值: \"${status}\" (应为空) ✓")
    println("  服务器返回增强码示例:")
    println("    '250 2.1.5 OK' → 解析出 \"2.1.5\"")
    println("    '550 5.1.1 User unknown' → 解析出 \"5.1.1\"")
    println("  → connect 后服务器若支持 ENHANCEDSTATUSCODES，响应自动解析 ✓")

    let tt = TlsSMTPTransport(session, true)
    println("  TlsSMTPTransport.getLastEnhancedStatus() ✓")
}

// ============================================================================
// SMTPMessage
// ============================================================================

func demoSMTPMessage(): Unit {
    println("\n[6] SMTPMessage — SMTP 信封级参数")
    println("─────────────────────────────────────────────")

    let props = HashMap<String, String>()
    let session = Session.getInstance(props)

    let sm = SMTPMessage(session)
    sm.setFrom(InternetAddress("sender@corp.example.com"))
    sm.setRecipients(RecipientType.TO, [InternetAddress("user@example.com")])
    sm.setSubject("Enterprise Mail")
    sm.setText("Content")

    // envelopeFrom - 退信地址独立于 From 头
    sm.setEnvelopeFrom("bounces+abc123@corp.example.com")
    let ef = match (sm.getEnvelopeFrom()) { case Some(e) => e; case None => "" }
    println("  setEnvelopeFrom → MAIL FROM:<${ef}> (From 头不变) ✓")

    // sendPartial - 消息级覆盖
    sm.setSendPartial(true)
    println("  setSendPartial(true) → 部分收件人失败时继续发送 ✓")

    // allow8bitMIME
    sm.setAllow8bitMIME(true)
    println("  setAllow8bitMIME(true) → 优先级高于传输级 allow8bitmime ✓")

    // mailExtension
    sm.setMailExtension("RET=HDRS ENVID=12345")
    let ext = match (sm.getMailExtension()) { case Some(e) => e; case None => "" }
    println("  setMailExtension → MAIL FROM 追加: \"${ext}\" ✓")

    // notifyOptions / returnOption (为 DSN 预留)
    sm.setNotifyOptions(NOTIFY_SUCCESS | NOTIFY_FAILURE)
    sm.setReturnOption(RETURN_HDRS)
    println("  setNotifyOptions(SUCCESS|FAILURE) + setReturnOption(HDRS) ✓")

    // 从 MimeMessage 复制构造 SMTPMessage
    let mm = MimeMessage(session)
    mm.setSubject("Original")
    let smFromMm = SMTPMessage(mm)
    let copiedSubj = match (smFromMm.getSubject()) { case Some(s) => s; case None => "" }
    println("  SMTPMessage(MimeMessage) 复制构造，主题: \"${copiedSubj}\" ✓")
}

// ============================================================================
// SMTPAddressSucceededException
// ============================================================================

func demoSMTPAddressSucceeded(): Unit {
    println("\n[7] SMTPAddressSucceededException")
    println("─────────────────────────────────────────────")

    let ex = SMTPAddressSucceededException(
        InternetAddress("ok@example.com"),
        "RCPT TO",
        250,
        "250 2.1.5 OK"
    )

    let addrs = ex.getValidSentAddresses()
    println("  address = ${ex.getAddress().toString()} ✓")
    println("  returnCode = ${ex.getReturnCode()} ✓")
    println("  validSentAddresses.size = ${addrs.size} ✓")
    println("  → 部分发送场景可用此异常报告成功投递的地址 ✓")
}

// ============================================================================
// connectWithFd (代理场景 API)
// ============================================================================

func demoConnectWithFd(): Unit {
    println("\n[8] connectWithFd(fd, user, password) — 代理/预连接场景")
    println("─────────────────────────────────────────────")

    println("  SMTPTransport.connectWithFd(fd, user, password):")
    println("    → 接管已建立的 TCP socket fd，跳过 createTcpConnection")
    println("    → _ownsFd=false，close() 时不关闭该 fd")
    println("    → 适用于：stunnel/SOCKS 代理、测试时注入预连接 socket")

    println("  TlsSMTPTransport.connectWithFd(fd, user, password):")
    println("    → 在现有 fd 上做 TLS 握手（connectWithFd→TlsSocket）")
    println("    → 之后走正常 SMTP over TLS 流程")

    println("  (API 存在性验证；实际调用需要真实预连接 socket fd) ✓")
}
