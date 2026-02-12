/**
 * Cangjie Mail 演示程序
 *
 * 本演示展示如何使用 Cangjie Mail 库通过 TLS 发送邮件。
 * 支持：文本邮件、HTML 邮件、附件、内嵌图片
 *
 * 使用前请先配置 .env 文件：
 *   cp .env.example .env
 *   # 编辑 .env 填写您的 SMTP 配置
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.activation.*
import mail.tls.*

/**
 * 配置文件路径
 */
const ENV_FILE = ".env"

/**
 * 资源文件路径（相对于 demo 目录）
 */
const ASSETS_DIR = "assets"
const TEST_ATTACHMENT = "assets/test.txt"
const TEST_IMAGE = "assets/logo.jpg"

/**
 * 全局配置（从 .env 加载）
 */
var config: ?MailConfig = None

/**
 * 获取配置（懒加载）
 */
func getConfig(): MailConfig {
    match (config) {
        case Some(c) => c
        case None =>
            let c = MailConfig.load(ENV_FILE)
            config = Some(c)
            c
    }
}

/**
 * 发送简单文本邮件（通过 TLS，不验证证书）
 */
func sendSimpleEmail(): Unit {
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
 *
 * 使用系统 CA 证书验证 SMTP 服务器的身份
 */
func sendEmailWithCertVerification(): Unit {
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
 *
 * 适用于企业内部 SMTP 服务器使用自签名证书的场景
 */
func sendEmailWithCustomCACert(): Unit {
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
func sendHtmlEmail(): Unit {
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
func sendEmailWithAttachment(): Unit {
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
func sendEmailWithInlineImage(): Unit {
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
func sendComplexEmail(): Unit {
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

/**
 * 演示：手动构建 Multipart 邮件
 */
func demoManualMultipart(): Unit {
    println("\n=== 手动构建 Multipart 邮件演示 ===")

    let props = HashMap<String, String>()
    let session = Session.getInstance(props)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress("sender@example.com"))
    message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
    message.setSubject("手动构建的 Multipart 邮件")

    // 创建 multipart/mixed 容器
    let multipart = MimeMultipart(MULTIPART_MIXED)

    // 添加文本部分
    let textPart = MimeBodyPart()
    textPart.setText("这是邮件的文本内容。")
    multipart.addBodyPart(textPart)

    // 添加 HTML 部分
    let htmlPart = MimeBodyPart()
    htmlPart.setHtmlContent("<h1>HTML 标题</h1><p>这是 HTML 内容。</p>")
    multipart.addBodyPart(htmlPart)

    // 使用 ByteArrayDataSource 添加内存中的附件
    let jsonData = "{\"name\": \"Cangjie Mail\", \"version\": \"1.0.0\", \"features\": [\"SMTP\", \"TLS\", \"MIME\"]}"
    let jsonDataSource = createJsonDataSource(jsonData, name: "config.json")
    let jsonPart = createAttachmentBodyPartFromDataSource(jsonDataSource)
    multipart.addBodyPart(jsonPart)

    // 设置 multipart 内容
    message.setContent(multipart)

    // 打印邮件结构（用于调试）
    println("邮件结构：")
    println("- Content-Type: ${message.getContentType()}")
    println("- 部分数量: ${multipart.getCount()}")
    for (i in 0..multipart.getCount()) {
        let part = multipart.getBodyPart(i)
        println("  Part ${i + 1}: ${part.getContentType()}")
    }

    // 输出邮件内容预览
    println("\n邮件内容预览（前 500 字符）：")
    let msgStr = message.getMessageString()
    if (msgStr.size > 500) {
        println(msgStr[0..500])
        println("...")
    } else {
        println(msgStr)
    }
}

/**
 * 演示：解析和验证邮箱地址
 */
func demoAddressParsing(): Unit {
    println("\n=== 地址解析演示 ===")

    let addresses = InternetAddress.parse("alice@example.com, \"Bob Smith\" <bob@example.com>, charlie@test.org")

    println("解析了 ${addresses.size} 个地址：")
    for (addr in addresses) {
        match (addr) {
            case ia: InternetAddress =>
                println("  - 地址：${ia.getAddress()}")
                match (ia.getPersonal()) {
                    case Some(name) => println("    姓名：${name}")
                    case None => ()
                }
                println("    完整：${ia.toString()}")
            case _ => ()
        }
    }

    let testAddr = InternetAddress("invalid-email")
    try {
        testAddr.validate()
        println("地址有效")
    } catch (e: AddressException) {
        println("地址验证失败：${e.message}")
    }
}

/**
 * 测试 TLS 配置初始化
 */
func testTlsConfig(): Unit {
    println("\n=== 测试 TLS 配置 ===")
    println("TLS 模式: ${getTlsModeDescription()}")

    try {
        let tlsConfig = TlsConfig(TLS_1_2)
            .setVerifyMode(VERIFY_NONE)
        println("TLS 配置对象创建成功")

        tlsConfig.initialize()
        println("TLS 配置初始化成功！")

        tlsConfig.close()
        println("TLS 配置关闭成功")
    } catch (e: TlsException) {
        println("TLS 配置测试失败: ${e.message}")
    } catch (e: Exception) {
        println("TLS 测试异常: ${e.message}")
    }
}

/**
 * 打印帮助信息
 */
func printHelp(): Unit {
    println("""
用法: cjpm run [选项]

选项:
  --help, -h      显示帮助信息
  --config        显示当前配置
  --test-tls      测试 TLS 配置
  --demo          运行演示（不发送邮件）
  --send-simple   发送简单文本邮件
  --send-html     发送 HTML 邮件
  --send-attach   发送带附件邮件
  --send-image    发送带内嵌图片邮件
  --send-complex  发送复杂邮件（HTML + 图片 + 附件）
  --send-secure   发送安全邮件（启用证书验证）
  --send-ca       发送使用自定义 CA 证书的邮件

配置:
  请先复制 .env.example 为 .env 并填写您的 SMTP 配置：
    cp .env.example .env

示例:
  cjpm run --run-args="--demo"          # 运行演示
  cjpm run --run-args="--send-simple"   # 发送简单邮件
  cjpm run --run-args="--config"        # 查看配置
""")
}

/**
 * 主入口点
 */
main(args: Array<String>): Int64 {
    println("======================================")
    println("   Cangjie Mail TLS 演示程序")
    println("======================================")

    // 检查 .env 文件
    if (!envFileExists(ENV_FILE)) {
        println("\n警告：未找到配置文件 .env")
        println("请先创建配置文件：")
        println("  cp .env.example .env")
        println("  # 然后编辑 .env 填写您的 SMTP 配置\n")
    }

    // 解析命令行参数
    if (args.size > 0) {
        let arg = args[0]
        match (arg) {
            case "--help" | "-h" =>
                printHelp()
                return 0
            case "--config" =>
                let cfg = getConfig()
                cfg.printInfo()
                return 0
            case "--test-tls" =>
                testTlsConfig()
                return 0
            case "--demo" =>
                demoAddressParsing()
                demoManualMultipart()
                return 0
            case "--send-simple" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                cfg.printInfo()
                sendSimpleEmail()
                return 0
            case "--send-html" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendHtmlEmail()
                return 0
            case "--send-attach" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendEmailWithAttachment()
                return 0
            case "--send-image" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendEmailWithInlineImage()
                return 0
            case "--send-complex" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendComplexEmail()
                return 0
            case "--send-secure" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendEmailWithCertVerification()
                return 0
            case "--send-ca" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendEmailWithCustomCACert()
                return 0
            case _ =>
                println("未知选项: ${arg}")
                printHelp()
                return 1
        }
    }

    // 默认：显示帮助和运行演示
    printHelp()

    println("\n--- 运行演示 ---")
    testTlsConfig()
    demoAddressParsing()
    demoManualMultipart()

    println("\n======================================")
    println("     演示完成！")
    println("======================================")

    0
}
