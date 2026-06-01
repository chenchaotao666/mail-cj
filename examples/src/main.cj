package mail_demo

const ENV_FILE = ".env"

public let TEST_ATTACHMENT = "assets/test.txt"
public let TEST_IMAGE = "assets/logo.jpg"

var config: ?MailConfig = None

public func getConfig(): MailConfig {
    match (config) {
        case Some(c) => c
        case None =>
            let c = MailConfig.load(ENV_FILE)
            config = Some(c)
            c
    }
}

func printHelp(): Unit {
    println("""
用法: cjpm run --run-args="<选项>"

基础发送（直接使用 TlsSMTPTransport）:
  --send-simple      发送简单文本邮件
  --send-html        发送 HTML 邮件
  --send-attach      发送带附件邮件
  --send-image       发送带内嵌图片邮件
  --send-complex     发送复杂邮件（HTML + 图片 + 附件）
  --send-secure      发送安全邮件（启用证书验证）
  --send-ca          发送使用自定义 CA 证书的邮件

企业级 Handler（仿 Java angus-mail）:
  --handler-test     测试连接（不发送邮件）
  --handler          使用 Handler 发送文本邮件
  --handler-html     使用 Handler 发送 HTML 邮件
  --handler-mass     使用 Handler 群发邮件
  --handler-attach   使用 Handler 发送带附件邮件
  --handler-complex  使用 Handler 发送复杂邮件（HTML + 附件）
  --handler-batch    使用 Handler 批量发送
  --handler-slow     使用 Handler 非高效模式（每封独立连接）

其他:
  --help, -h         显示帮助信息
  --config           显示当前配置

配置:
  cp .env.example .env
  # 编辑 .env 填写 SMTP 配置
""")
}

main(args: Array<String>): Int64 {
    println("======================================")
    println("   Cangjie Mail 发送示例")
    println("======================================")

    if (!envFileExists(ENV_FILE)) {
        println("\n警告：未找到配置文件 .env")
        println("请先执行：")
        println("  cp .env.example .env")
        println("  # 编辑 .env 填写您的 SMTP 配置\n")
    }

    if (args.size > 0) {
        let arg = args[0]
        match (arg) {
            case "--help" | "-h" =>
                printHelp()
                return 0

            case "--config" =>
                getConfig().printInfo()
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

            case _ =>
                println("未知选项: ${arg}")
                printHelp()
                return 1
        }
    }

    printHelp()
    0
}
