/**
 * 企业级 Handler 邮件发送演示
 *
 * 仿照 Java angus-mail 的 Handler 类设计，展示：
 * - 单次连接发送多封邮件（高效模式）
 * - 非高效模式（每封邮件单独连接）
 * - 支持 TO/CC/BCC
 * - 失败重试机制
 * - 错误码处理
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.tls.*

// ============================================================================
// 连接测试
// ============================================================================

/**
 * 测试 Handler 连接
 *
 * 仅测试 SMTP 服务器连接，不发送邮件
 */
public func testConnectionWithHandler(): Unit {
    println("\n=== 测试 Handler 连接 ===")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true
    serverConfig.verifyCert = cfg.verifyCert

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)

    try {
        handler.connectTransport()
        println("✓ 连接测试成功！服务器可正常访问。")
    } catch (e: AuthenticationFailedException) {
        println("✗ 认证失败: ${e.message}")
        println("  错误码: ${EmailErrorCode.CONNECT_FAILED_AUTH_FAILED}")
    } catch (e: MailConnectException) {
        println("✗ 连接失败: ${e.message}")
        println("  错误码: ${EmailErrorCode.CONNECT_FAILED}")
    } catch (e: TlsException) {
        println("✗ TLS 错误: ${e.message}")
        println("  错误码: ${EmailErrorCode.CONNECT_FAILED_CERT_EXCEPTION}")
    } catch (e: Exception) {
        println("✗ 未知错误: ${e.message}")
        println("  错误码: ${EmailErrorCode.CONNECT_FAILED_UNKNOWN_ERROR}")
    } finally {
        handler.close()
    }
}

// ============================================================================
// 基础发送
// ============================================================================

/**
 * 使用企业级 Handler 发送邮件（仿 Java angus-mail Handler）
 *
 * 展示：
 * - 单次连接发送多封邮件
 * - 支持失败重试
 * - 详细错误码处理
 */
public func sendWithHandler(): Unit {
    println("\n=== 使用企业级 Handler 发送邮件 ===")

    let cfg = getConfig()

    // 创建服务器配置
    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true
    serverConfig.verifyCert = cfg.verifyCert

    // 创建 Handler
    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)
    handler.setRetryTimes(3)
    handler.setRetryInterval(1000)

    // 创建邮件信息
    let emailInfo = EmailInfo()
    emailInfo.addRecipient(cfg.mailTo)  // 单独发送
    emailInfo.subject = "企业级邮件发送测试"
    emailInfo.subjectPrefix = "[Cangjie Mail] "
    emailInfo.content = """
你好！

这是一封使用企业级 Handler 发送的测试邮件。

Handler 特性：
- 单次连接发送多封邮件（高效模式）
- 失败自动重试（默认 3 次）
- 详细错误码
- 支持 TO/CC/BCC

此致，
Cangjie Mail
"""
    emailInfo.signature = "Cangjie Mail Team"
    emailInfo.contentType = "text/plain"

    // 发送邮件
    let statusList = handler.sendEmail(emailInfo)

    // 打印结果
    println("\n发送结果：")
    for (status in statusList) {
        let recipient = anonymizeEmail(status.recipient)
        if (status.isSuccess()) {
            println("  ✓ ${recipient} - 发送成功")
        } else {
            println("  ✗ ${recipient} - 发送失败，错误码: ${status.status}")
        }
    }
}

// ============================================================================
// HTML 邮件
// ============================================================================

/**
 * 使用 Handler 发送 HTML 邮件
 */
public func sendHtmlWithHandler(): Unit {
    println("\n=== 使用 Handler 发送 HTML 邮件 ===")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)
    handler.setRetryTimes(3)

    let emailInfo = EmailInfo()
    emailInfo.addRecipient(cfg.mailTo)
    emailInfo.subject = "HTML 格式邮件测试"
    emailInfo.subjectPrefix = "[Cangjie Mail] "
    emailInfo.content = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Microsoft YaHei', Arial, sans-serif; background: #f5f5f5; padding: 20px; }
        .card { background: white; border-radius: 10px; padding: 30px; max-width: 600px; margin: 0 auto;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { color: #4CAF50; border-bottom: 2px solid #4CAF50; padding-bottom: 15px; }
        .feature { background: #e8f5e9; padding: 10px 15px; margin: 10px 0; border-radius: 5px; }
        .footer { color: #666; font-size: 12px; margin-top: 20px; padding-top: 15px; border-top: 1px solid #eee; }
    </style>
</head>
<body>
    <div class="card">
        <h1 class="header">企业级邮件发送测试</h1>
        <p>你好！</p>
        <p>这封邮件使用 <strong>EmailHandler</strong> 发送，展示企业级邮件功能：</p>
        <div class="feature">✓ 单次连接发送多封邮件</div>
        <div class="feature">✓ 失败自动重试（已配置 3 次）</div>
        <div class="feature">✓ 支持 TO/CC/BCC 多种收件人类型</div>
        <div class="feature">✓ 详细错误码反馈</div>
        <div class="footer">
            <p>由 Cangjie Mail Handler 发送</p>
        </div>
    </div>
</body>
</html>
"""
    emailInfo.contentType = "text/html"
    emailInfo.charset = "UTF-8"

    let statusList = handler.sendEmail(emailInfo)

    for (status in statusList) {
        let recipient = anonymizeEmail(status.recipient)
        if (status.isSuccess()) {
            println("✓ ${recipient} - HTML 邮件发送成功")
        } else {
            println("✗ ${recipient} - 发送失败，错误码: ${status.status}")
        }
    }
}

// ============================================================================
// 群发邮件
// ============================================================================

/**
 * 使用 Handler 群发邮件（带抄送）
 */
public func sendMassWithHandler(): Unit {
    println("\n=== 使用 Handler 群发邮件（带抄送） ===")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)

    // 创建群发邮件
    let emailInfo = EmailInfo()
    // 群发主送（一次发送给所有人）
    emailInfo.addMassRecipient(cfg.mailTo)
    // 如果有更多收件人可以添加：
    // emailInfo.addMassRecipient("recipient2@example.com")
    // emailInfo.addCcRecipient("cc@example.com")
    // emailInfo.addBccRecipient("bcc@example.com")

    emailInfo.subject = "群发邮件测试"
    emailInfo.subjectPrefix = "[通知] "
    emailInfo.content = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .notice { background: #e7f3fe; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <h2>群发邮件通知</h2>
    <div class="notice">
        <strong>重要提示：</strong> 这是一封使用 Cangjie Mail Handler 群发的测试邮件。
    </div>
    <p>功能特点：</p>
    <ul>
        <li>支持 TO（主送）、CC（抄送）、BCC（密送）</li>
        <li>单次连接群发所有收件人</li>
        <li>HTML 格式支持</li>
    </ul>
</body>
</html>
"""
    emailInfo.contentType = "text/html"

    let statusList = handler.sendEmail(emailInfo)

    println("\n群发结果：")
    var successCount = 0
    var failCount = 0
    for (status in statusList) {
        if (status.isSuccess()) {
            successCount += 1
        } else {
            failCount += 1
        }
    }
    println("  成功: ${successCount}, 失败: ${failCount}")
}

// ============================================================================
// 带附件邮件
// ============================================================================

/**
 * 使用 Handler 发送带附件的邮件
 */
public func sendWithAttachmentHandler(): Unit {
    println("\n=== 使用 Handler 发送带附件邮件 ===")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)

    let emailInfo = EmailInfo()
    emailInfo.addRecipient(cfg.mailTo)
    emailInfo.subject = "带附件的测试邮件"
    emailInfo.subjectPrefix = "[Cangjie Mail] "
    emailInfo.content = "请查看附件中的文件。"
    emailInfo.contentType = "text/plain"
    emailInfo.addAttachment(TEST_ATTACHMENT)

    let statusList = handler.sendEmail(emailInfo)

    for (status in statusList) {
        if (status.isSuccess()) {
            println("带附件邮件发送成功！")
        } else {
            println("发送失败，错误码: ${status.status}")
        }
    }
}

/**
 * 使用 Handler 发送复杂邮件（HTML + 附件）
 */
public func sendComplexWithHandler(): Unit {
    println("\n=== 使用 Handler 发送复杂邮件 (HTML + 附件) ===")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true
    serverConfig.verifyCert = cfg.verifyCert

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)
    handler.setRetryTimes(3)
    handler.setRetryInterval(2000)  // 2秒重试间隔

    let emailInfo = EmailInfo()
    emailInfo.addRecipient(cfg.mailTo)
    emailInfo.subject = "复杂邮件测试"
    emailInfo.subjectPrefix = "[报告] "
    emailInfo.subjectSuffix = " - 重要"
    emailInfo.content = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .alert { background: #fff3cd; border: 1px solid #ffc107; padding: 15px; border-radius: 5px; margin: 15px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background: #4CAF50; color: white; }
        tr:nth-child(even) { background: #f9f9f9; }
    </style>
</head>
<body>
    <h1>系统报告</h1>
    <div class="alert">
        <strong>提醒：</strong>请查看附件中的详细报告文件。
    </div>
    <h2>摘要</h2>
    <table>
        <tr><th>项目</th><th>状态</th><th>说明</th></tr>
        <tr><td>服务器连接</td><td>正常</td><td>TLS 加密</td></tr>
        <tr><td>认证状态</td><td>通过</td><td>SMTP AUTH</td></tr>
        <tr><td>邮件发送</td><td>成功</td><td>已发送到收件人</td></tr>
    </table>
    <p>此邮件由 Cangjie Mail Handler 自动生成。</p>
</body>
</html>
"""
    emailInfo.contentType = "text/html"
    emailInfo.signature = "Cangjie Mail 自动化系统"
    emailInfo.addAttachment(TEST_ATTACHMENT)

    let statusList = handler.sendEmail(emailInfo)

    println("\n发送结果统计：")
    var success = 0
    var failed = 0
    for (status in statusList) {
        if (status.isSuccess()) {
            success += 1
        } else {
            failed += 1
            println("  失败: ${anonymizeEmail(status.recipient)} - 错误码 ${status.status}")
        }
    }
    println("  总计: ${success + failed}, 成功: ${success}, 失败: ${failed}")
}

// ============================================================================
// 非高效模式
// ============================================================================

/**
 * 使用非高效模式发送邮件（每封邮件单独连接）
 *
 * 适用于需要隔离每封邮件发送状态的场景
 */
public func sendInefficientWithHandler(): Unit {
    println("\n=== 使用 Handler 非高效模式发送邮件 ===")
    println("（每封邮件单独建立连接，适用于需要隔离发送的场景）")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)
    handler.setRetryTimes(2)

    // 模拟发送给多个收件人
    let emailInfo = EmailInfo()
    emailInfo.addRecipient(cfg.mailTo)
    // 可以添加更多收件人：
    // emailInfo.addRecipient("user2@example.com")
    // emailInfo.addRecipient("user3@example.com")

    emailInfo.subject = "独立连接发送测试"
    emailInfo.subjectPrefix = "[Test] "
    emailInfo.content = """
你好！

这封邮件使用「非高效模式」发送。

在此模式下：
- 每封邮件都会单独建立 SMTP 连接
- 每封邮件的发送状态完全独立
- 适用于需要严格隔离的场景

虽然效率较低，但在某些企业场景下更加可靠。

此致，
Cangjie Mail
"""
    emailInfo.contentType = "text/plain"

    // 使用非高效模式发送
    let statusList = handler.sendEmailInefficient(emailInfo)

    println("\n发送结果：")
    for (status in statusList) {
        let recipient = anonymizeEmail(status.recipient)
        if (status.isSuccess()) {
            println("  ✓ ${recipient} - 成功")
        } else {
            println("  ✗ ${recipient} - 失败 (错误码: ${status.status})")
        }
    }
}

// ============================================================================
// 批量发送
// ============================================================================

/**
 * Handler 批量发送演示
 *
 * 展示如何高效地发送给多个收件人
 */
public func sendBatchWithHandler(): Unit {
    println("\n=== Handler 批量发送演示 ===")

    let cfg = getConfig()

    let serverConfig = EmailServerConfig(
        cfg.smtpHost,
        cfg.smtpPort,
        cfg.mailFrom,
        cfg.smtpUser,
        cfg.smtpPassword
    )
    serverConfig.useSSL = true

    let handler = EmailHandler(serverConfig)
    handler.setDebug(cfg.debug)
    handler.setRetryTimes(3)

    let emailInfo = EmailInfo()

    // 单独发送的收件人（每人收到独立邮件，看不到其他收件人）
    emailInfo.addRecipient(cfg.mailTo)

    // 群发主送（所有人能看到彼此）
    // emailInfo.addMassRecipient("group1@example.com")
    // emailInfo.addMassRecipient("group2@example.com")

    // 抄送
    // emailInfo.addCcRecipient("manager@example.com")

    // 密送（收件人不可见）
    // emailInfo.addBccRecipient("archive@example.com")

    emailInfo.subject = "批量发送测试"
    emailInfo.subjectPrefix = "[通知] "
    emailInfo.content = """
各位同事：

这是一封批量发送的测试邮件，演示 Cangjie Mail Handler 的批量发送功能。

发送模式说明：
1. 单独发送 (addRecipient): 每人收到独立邮件
2. 群发主送 (addMassRecipient): 所有人能看到彼此
3. 抄送 (addCcRecipient): 抄送收件人
4. 密送 (addBccRecipient): 隐藏的收件人

此致，
Cangjie Mail 系统
"""
    emailInfo.contentType = "text/plain"

    let statusList = handler.sendEmail(emailInfo)

    // 统计结果
    var successCount = 0
    var failedCount = 0
    let failedList = ArrayList<String>()

    for (status in statusList) {
        if (status.isSuccess()) {
            successCount += 1
        } else {
            failedCount += 1
            failedList.add("${anonymizeEmail(status.recipient)} (错误码: ${status.status})")
        }
    }

    println("\n批量发送结果：")
    println("  总计: ${successCount + failedCount} 封")
    println("  成功: ${successCount} 封")
    println("  失败: ${failedCount} 封")

    if (failedCount > 0) {
        println("\n失败详情：")
        for (info in failedList) {
            println("  - ${info}")
        }
    }
}

// ============================================================================
// API 演示（不发送邮件）
// ============================================================================

/**
 * Handler 演示：展示 API 用法（不实际发送）
 */
public func demoHandler(): Unit {
    println("\n=== EmailHandler API 演示 ===")

    // 创建服务器配置
    let serverConfig = EmailServerConfig()
    serverConfig.smtpServer = "smtp.example.com"
    serverConfig.port = 465
    serverConfig.sender = "sender@example.com"
    serverConfig.userName = "user@example.com"
    serverConfig.password = "password"
    serverConfig.useSSL = true
    serverConfig.verifyCert = true

    println("1. 服务器配置：")
    println("   - SMTP: ${serverConfig.smtpServer}:${serverConfig.port}")
    println("   - SSL: ${serverConfig.useSSL}")
    println("   - 证书验证: ${serverConfig.verifyCert}")

    // 创建邮件信息
    let emailInfo = EmailInfo()

    // 单独发送的收件人（逐个发送）
    emailInfo.addRecipient("user1@example.com")
    emailInfo.addRecipient("user2@example.com")

    // 群发收件人（一次发送）
    emailInfo.addMassRecipient("group1@example.com")
    emailInfo.addMassRecipient("group2@example.com")

    // 抄送
    emailInfo.addCcRecipient("cc@example.com")

    // 密送
    emailInfo.addBccRecipient("bcc@example.com")

    // 邮件内容
    emailInfo.subject = "测试邮件"
    emailInfo.subjectPrefix = "[通知] "
    emailInfo.subjectSuffix = " - 重要"
    emailInfo.content = "<h1>Hello</h1><p>This is a test email.</p>"
    emailInfo.contentType = "text/html"
    emailInfo.charset = "UTF-8"
    emailInfo.signature = "Best regards,<br>Cangjie Mail Team"

    // 附件
    emailInfo.addAttachment("report.pdf")
    emailInfo.addAttachment("data.xlsx")

    println("\n2. 邮件信息：")
    println("   - 完整主题: ${emailInfo.getFullSubject()}")
    println("   - 单发收件人: ${emailInfo.getRecipients().size} 人")
    println("   - 群发收件人: ${emailInfo.getMassRecipients().size} 人")
    println("   - 抄送: ${emailInfo.getCcRecipients().size} 人")
    println("   - 密送: ${emailInfo.getBccRecipients().size} 人")
    println("   - 附件数: ${emailInfo.getAttachments().size} 个")

    println("\n3. Handler 使用方式：")
    println("""
   // 创建 Handler
   let handler = EmailHandler(serverConfig)
   handler.setDebug(true)
   handler.setRetryTimes(3)

   // 高效模式：单次连接发送所有邮件
   let statusList = handler.sendEmail(emailInfo)

   // 或非高效模式：每封邮件单独连接
   let statusList = handler.sendEmailInefficient(emailInfo)

   // 检查结果
   for (status in statusList) {
       if (status.isSuccess()) {
           println("发送成功: \${status.recipient}")
       } else {
           println("发送失败: \${status.recipient}, 错误码: \${status.status}")
       }
   }
""")

    println("\n4. 错误码说明：")
    println("   - 0: 成功")
    println("   - 2xx: 连接错误")
    println("   - 3xx: 发送错误")
    println("   - 详见 EmailErrorCode 类")
}
