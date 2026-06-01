/**
 * 基础邮件发送演示
 *
 * 包含：
 * - 简单文本邮件
 * - HTML 邮件
 * - 带附件邮件
 * - 带内嵌图片邮件
 * - 复杂邮件（HTML + 图片 + 附件）
 * - 证书验证相关
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

/**
 * 发送简单文本邮件（通过 TLS，不验证证书）
 */
public func sendSimpleEmail(): Unit {
    println("\n=== 发送简单文本邮件 (TLS, 不验证证书) ===")

    let cfg = getConfig()

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("来自 Cangjie Mail 的测试邮件 (TLS)")
    message.setText("你好！\n\n这是一封使用 Cangjie Mail 库通过 TLS 加密发送的测试邮件。\n\n此致，\nCangjie Mail")

    let transport = TlsSMTPTransport(session, true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("简单文本邮件发送成功！")
    } catch (e: TlsException) {
        println("TLS 错误: ${e.message}")
    } catch (e: Exception) {
        println("邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}

/**
 * 发送邮件（通过 TLS，启用证书验证）
 */
public func sendEmailWithCertVerification(): Unit {
    println("\n=== 发送邮件 (TLS + 证书验证) ===")

    let cfg = getConfig()

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"
    props["mail.smtps.ssl.checkserveridentity"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("安全邮件 - 启用证书验证 (Cangjie Mail)")
    message.setText("你好！\n\n这封邮件使用 TLS 加密并验证了服务器证书，确保通信安全。\n\n安全特性：\n- TLS 1.2 加密\n- 服务器证书验证\n- 防止中间人攻击\n\n此致，\nCangjie Mail")

    let transport = TlsSMTPTransport(session, true)
    transport.setVerifyCert(true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("安全邮件发送成功（已验证服务器证书）！")
    } catch (e: TlsException) {
        println("TLS 错误（证书验证可能失败）: ${e.message}")
    } catch (e: Exception) {
        println("邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}

/**
 * 发送邮件（通过 TLS，使用自定义 CA 证书）
 */
public func sendEmailWithCustomCACert(): Unit {
    println("\n=== 发送邮件 (TLS + 自定义 CA 证书) ===")

    let cfg = getConfig()

    let caCertPath = match (cfg.caCertPath) {
        case Some(path) => path
        case None =>
            println("未配置 CA_CERT_PATH，使用系统默认证书")
            "/etc/ssl/certs/ca-certificates.crt"
    }
    println("CA 证书路径: ${caCertPath}")

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("使用自定义 CA 证书的安全邮件")
    message.setText("这封邮件使用自定义 CA 证书验证服务器身份。")

    let transport = TlsSMTPTransport(session, true)
    transport.setCACertPath(caCertPath)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("邮件发送成功（使用自定义 CA 证书）！")
    } catch (e: TlsException) {
        println("TLS 错误: ${e.message}")
    } catch (e: Exception) {
        println("邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}

/**
 * 发送 HTML 邮件（通过 TLS）
 */
public func sendHtmlEmail(): Unit {
    println("\n=== 发送 HTML 邮件 (TLS) ===")

    let cfg = getConfig()

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("来自 Cangjie Mail 的 HTML 邮件 (TLS)")

    let html = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .footer { background-color: #f1f1f1; padding: 10px; text-align: center; font-size: 12px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Welcome to Cangjie Mail!</h1>
    </div>
    <div class="content">
        <p>Hello,</p>
        <p>This is an <strong>HTML email</strong> sent using the Cangjie Mail library with TLS encryption.</p>
        <p>Features:</p>
        <ul>
            <li>Simple API similar to Jakarta Mail</li>
            <li>Native TLS support via openHiTLS</li>
            <li>SMTPS (port 465) support</li>
            <li>Multiple authentication methods</li>
        </ul>
    </div>
    <div class="footer">
        <p>Sent by Cangjie Mail Library (TLS Encrypted)</p>
    </div>
</body>
</html>
"""
    message.setHtmlContent(html)

    let transport = TlsSMTPTransport(session, true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("HTML 邮件发送成功！")
    } catch (e: TlsException) {
        println("TLS 错误: ${e.message}")
    } catch (e: Exception) {
        println("HTML 邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}

/**
 * 发送带附件的邮件（通过 TLS）
 */
public func sendEmailWithAttachment(): Unit {
    println("\n=== 发送带附件邮件 (TLS) ===")

    let cfg = getConfig()

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("带附件的测试邮件 - Cangjie Mail")

    message.setTextWithAttachments(
        "你好！\n\n这封邮件包含一个附件，请查收。\n\n此致，\nCangjie Mail",
        [TEST_ATTACHMENT]
    )

    let transport = TlsSMTPTransport(session, true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("带附件邮件发送成功！")
    } catch (e: TlsException) {
        println("TLS 错误: ${e.message}")
    } catch (e: Exception) {
        println("邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}

/**
 * 发送带内嵌图片的 HTML 邮件（通过 TLS）
 */
public func sendEmailWithInlineImage(): Unit {
    println("\n=== 发送带内嵌图片的 HTML 邮件 (TLS) ===")

    let cfg = getConfig()

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("带内嵌图片的 HTML 邮件 - Cangjie Mail")

    let html = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                  color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { padding: 30px; background: #f9f9f9; }
        .image-container { text-align: center; margin: 20px 0; }
        .footer { background: #333; color: #aaa; padding: 15px; text-align: center;
                  font-size: 12px; border-radius: 0 0 10px 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Cangjie Mail</h1>
            <p>支持内嵌图片的 HTML 邮件</p>
        </div>
        <div class="content">
            <p>你好！</p>
            <p>这封邮件展示了如何在 HTML 中嵌入图片。下面是一张内嵌图片：</p>
            <div class="image-container">
                <img src="cid:test-image" alt="测试图片" style="border: 2px solid #ddd; border-radius: 5px;">
                <p><em>通过 Content-ID 引用的内嵌图片</em></p>
            </div>
            <p>内嵌图片的优势：</p>
            <ul>
                <li>图片直接嵌入邮件，无需网络加载</li>
                <li>收件人可以离线查看完整邮件</li>
                <li>不依赖外部图片服务器</li>
            </ul>
        </div>
        <div class="footer">
            <p>由 Cangjie Mail 库发送 | TLS 加密传输</p>
        </div>
    </div>
</body>
</html>
"""

    message.setHtmlWithInlineImages(html, [("test-image", TEST_IMAGE)])

    let transport = TlsSMTPTransport(session, true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("带内嵌图片的 HTML 邮件发送成功！")
    } catch (e: TlsException) {
        println("TLS 错误: ${e.message}")
    } catch (e: Exception) {
        println("邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}

/**
 * 发送复杂邮件：HTML + 内嵌图片 + 附件
 */
public func sendComplexEmail(): Unit {
    println("\n=== 发送复杂邮件 (HTML + 内嵌图片 + 附件) ===")

    let cfg = getConfig()

    let props = HashMap<String, String>()
    props["mail.smtps.host"] = cfg.smtpHost
    props["mail.smtps.port"] = cfg.smtpPort.toString()
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(cfg.debug)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress(cfg.mailFrom, cfg.mailFromName))
    message.setRecipients(RecipientType.TO, InternetAddress.parse(cfg.mailTo))
    message.setSubject("复杂邮件测试 - Cangjie Mail")

    let html = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background: #f0f2f5; }
        .email-container { max-width: 600px; margin: 20px auto; background: white; border-radius: 10px;
                           box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        .header { background: #4CAF50; color: white; padding: 25px; text-align: center; }
        .header img { width: 50px; height: 50px; border-radius: 50%; background: white; padding: 5px; }
        .header h1 { margin: 15px 0 5px; }
        .content { padding: 30px; }
        .attachment-notice { background: #fff3cd; border: 1px solid #ffc107; border-radius: 5px;
                             padding: 15px; margin: 20px 0; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="header">
            <img src="cid:logo" alt="Logo">
            <h1>Cangjie Mail</h1>
            <p>完整功能演示</p>
        </div>
        <div class="content">
            <h2>你好！</h2>
            <p>这封邮件展示了 Cangjie Mail 库的完整功能：</p>
            <ul>
                <li>精美的 HTML 格式</li>
                <li>内嵌图片（上方的 Logo）</li>
                <li>文件附件</li>
                <li>TLS 加密传输</li>
            </ul>
            <div class="attachment-notice">
                <strong>附件说明</strong><br>
                本邮件包含一个测试报告文件，请在附件中查看。
            </div>
            <p>感谢您使用 Cangjie Mail！</p>
        </div>
        <div class="footer">
            <p>Cangjie Mail - 仓颉语言邮件库</p>
            <p>安全 · 高效 · 易用</p>
        </div>
    </div>
</body>
</html>
"""

    message.setHtmlWithImagesAndAttachments(
        html,
        [("logo", TEST_IMAGE)],
        [TEST_ATTACHMENT]
    )

    let transport = TlsSMTPTransport(session, true)

    try {
        transport.connect(cfg.smtpHost, cfg.smtpPort, cfg.smtpUser, cfg.smtpPassword)
        transport.sendMessage(message, message.getAllRecipients())
        println("复杂邮件发送成功！")
    } catch (e: TlsException) {
        println("TLS 错误: ${e.message}")
    } catch (e: Exception) {
        println("邮件发送失败：${e.message}")
    } finally {
        transport.close()
    }
}
