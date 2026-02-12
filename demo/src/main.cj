/**
 * Cangjie Mail 演示程序
 *
 * 本演示展示如何使用 Cangjie Mail 库通过 TLS 发送邮件。
 * 支持：文本邮件、HTML 邮件、附件、内嵌图片
 *
 * 使用前请先配置 .env 文件：
 *   cp .env.example .env
 *   # 编辑 .env 填写您的 SMTP 配置
 *
 * 文件结构：
 *   main.cj        - 主入口和命令行解析
 *   config.cj      - 配置加载器
 *   handler.cj     - 企业级邮件处理器（仿 Java angus-mail）
 *   demo_basic.cj  - 基础邮件发送演示
 *   demo_handler.cj- Handler 演示
 *   demo_utils.cj  - 工具函数和高级演示
 */
package mail_demo

// ============================================================================
// 常量定义
// ============================================================================

/**
 * 配置文件路径
 */
const ENV_FILE = ".env"

/**
 * 资源文件路径（相对于 demo 目录）
 */
public let TEST_ATTACHMENT = "assets/test.txt"
public let TEST_IMAGE = "assets/logo.jpg"

// ============================================================================
// 全局配置
// ============================================================================

/**
 * 全局配置（从 .env 加载）
 */
var config: ?MailConfig = None

/**
 * 获取配置（懒加载）
 */
public func getConfig(): MailConfig {
    match (config) {
        case Some(c) => c
        case None =>
            let c = MailConfig.load(ENV_FILE)
            config = Some(c)
            c
    }
}

// ============================================================================
// 帮助信息
// ============================================================================

/**
 * 打印帮助信息
 */
func printHelp(): Unit {
    println("""
用法: cjpm run [选项]

选项:
  --help, -h         显示帮助信息
  --config           显示当前配置
  --test-tls         测试 TLS 配置
  --demo             运行演示（不发送邮件）
  --demo-handler     Handler API 演示（不发送邮件）

基础发送（直接使用 TlsSMTPTransport）:
  --send-simple      发送简单文本邮件
  --send-html        发送 HTML 邮件
  --send-attach      发送带附件邮件
  --send-image       发送带内嵌图片邮件
  --send-complex     发送复杂邮件（HTML + 图片 + 附件）
  --send-secure      发送安全邮件（启用证书验证）
  --send-ca          发送使用自定义 CA 证书的邮件

企业级 Handler（仿 Java angus-mail）:
  --handler-test     测试 Handler 连接（不发送邮件）
  --handler          使用 Handler 发送文本邮件
  --handler-html     使用 Handler 发送 HTML 邮件
  --handler-mass     使用 Handler 群发邮件
  --handler-attach   使用 Handler 发送带附件邮件
  --handler-complex  使用 Handler 发送复杂邮件（HTML + 附件）
  --handler-batch    使用 Handler 批量发送
  --handler-slow     使用 Handler 非高效模式（每封独立连接）

配置:
  请先复制 .env.example 为 .env 并填写您的 SMTP 配置：
    cp .env.example .env

示例:
  cjpm run --run-args="--demo"            # 运行演示
  cjpm run --run-args="--demo-handler"    # Handler API 演示
  cjpm run --run-args="--handler-test"    # 测试连接
  cjpm run --run-args="--handler"         # 使用 Handler 发送
  cjpm run --run-args="--handler-html"    # 发送 HTML 邮件
  cjpm run --run-args="--handler-complex" # 发送复杂邮件
  cjpm run --run-args="--send-simple"     # 基础发送
  cjpm run --run-args="--config"          # 查看配置
""")
}

// ============================================================================
// 主入口
// ============================================================================

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
            // 帮助和配置
            case "--help" | "-h" =>
                printHelp()
                return 0

            case "--config" =>
                let cfg = getConfig()
                cfg.printInfo()
                return 0

            // 演示（不发送邮件）
            case "--test-tls" =>
                testTlsConfig()
                return 0

            case "--demo" =>
                demoAddressParsing()
                demoManualMultipart()
                return 0

            case "--demo-handler" =>
                demoHandler()
                return 0

            // 基础发送
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

            // Handler 相关
            case "--handler-test" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                cfg.printInfo()
                testConnectionWithHandler()
                return 0

            case "--handler" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendWithHandler()
                return 0

            case "--handler-html" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendHtmlWithHandler()
                return 0

            case "--handler-mass" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendMassWithHandler()
                return 0

            case "--handler-attach" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendWithAttachmentHandler()
                return 0

            case "--handler-complex" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendComplexWithHandler()
                return 0

            case "--handler-batch" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendBatchWithHandler()
                return 0

            case "--handler-slow" =>
                let cfg = getConfig()
                if (!cfg.validate()) { return 1 }
                sendInefficientWithHandler()
                return 0

            // 未知选项
            case _ =>
                println("未知选项: ${arg}")
                printHelp()
                return 1
        }
    }

    // 默认：显示帮助和运行演示
    printHelp()

    println("\n--- 运行演示 ---")
    runAllDemos()

    0
}
