/**
 * 演示工具和高级功能
 *
 * 包含：
 * - TLS 配置测试
 * - 地址解析演示
 * - 手动构建 Multipart 邮件
 */
package mail_demo

import std.collection.*
import mail.core.*
import mail.internet.*
import mail.activation.*
import mail.tls.*

// ============================================================================
// TLS 测试
// ============================================================================

/**
 * 测试 TLS 配置初始化
 */
public func testTlsConfig(): Unit {
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

// ============================================================================
// 地址解析演示
// ============================================================================

/**
 * 演示：解析和验证邮箱地址
 */
public func demoAddressParsing(): Unit {
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

// ============================================================================
// Multipart 邮件演示
// ============================================================================

/**
 * 演示：手动构建 Multipart 邮件
 */
public func demoManualMultipart(): Unit {
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

// ============================================================================
// 综合演示
// ============================================================================

/**
 * 运行所有演示（不发送邮件）
 */
public func runAllDemos(): Unit {
    println("\n" + "=".repeat(50))
    println("  Cangjie Mail 综合演示")
    println("=".repeat(50))

    testTlsConfig()
    demoAddressParsing()
    demoManualMultipart()

    println("\n" + "=".repeat(50))
    println("  演示完成！")
    println("=".repeat(50))
}

/**
 * 重复字符串辅助函数
 */
extend String {
    func repeat(n: Int64): String {
        var result = ""
        for (_ in 0..n) {
            result += this
        }
        result
    }
}
