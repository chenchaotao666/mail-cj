/**
 * mail-cj 邮件发送示例入口
 *
 * 用法：
 *   cjpm run --run-args="<场景>"
 *
 * 场景与 angus-examples 一一对标，验证 mail-cj API 与 Jakarta Mail 的行为一致性。
 */
package mail_demo

const ENV_FILE = ".env"
public let TEST_ATTACHMENT = "assets/test.txt"
public let TEST_IMAGE = "assets/logo.jpg"

var _config: ?MailConfig = None

public func getConfig(): MailConfig {
    match (_config) {
        case Some(c) => c
        case None =>
            let c = MailConfig.load(ENV_FILE)
            _config = Some(c)
            c
    }
}

func printHelp(): Unit {
    println("""
用法: cjpm run --run-args="<场景编号>"

场景列表：
  --01   纯文本邮件（SMTPS 465）
  --02   HTML 邮件
  --03   带附件邮件（multipart/mixed）
  --04   HTML + 内嵌图片（multipart/related）
  --05   复杂邮件（HTML + 图片 + 附件）
  --06   多收件人（TO / CC / BCC）
  --07   STARTTLS 连接（端口 587）
  --08   Reply-To 与 reply() 回复
  --09   群发（单连接复制构造）
  --10   自定义邮件头 + Sender 代发
  --11   multipart/alternative 文本/HTML 兼容
  --12   从 InputStream 加载模板并转发
  --13   SMTPMessage 信封 From + DSN 通知
  --14   TransportListener + ConnectionListener
  --15   长连接保活（isConnected 心跳）
  --16   XOAUTH2 OAuth2 认证

配置：
  cp .env.example .env
  # 编辑 .env 填写 SMTP 配置后运行

快速开始：
  cjpm run --run-args="--01"
""")
}

main(args: Array<String>): Int64 {
    if (!envFileExists(ENV_FILE)) {
        println("警告：未找到配置文件 .env，请先执行：cp .env.example .env")
    }

    if (args.size == 0) {
        printHelp()
        return 0
    }

    let cfg = getConfig()
    if (cfg.smtpUser.isEmpty() || cfg.mailTo.isEmpty()) {
        println("错误：请在 .env 中配置 SMTP_USER 和 MAIL_TO")
        return 1
    }

    match (args[0]) {
        case "--01" => sendSimple()
        case "--02" => sendHtml()
        case "--03" => sendWithAttachment()
        case "--04" => sendWithInlineImage()
        case "--05" => sendComplex()
        case "--06" => sendCcBcc()
        case "--07" => sendWithStartTLS()
        case "--08" => sendReply()
        case "--09" => sendBulk()
        case "--10" => sendWithCustomHeaders()
        case "--11" => sendAlternative()
        case "--12" => sendFromInputStream()
        case "--13" => sendWithSMTPMessage()
        case "--14" => sendWithTransportListener()
        case "--15" => sendWithConnectionPool()
        case "--16" => sendWithXOAuth2()
        case _ =>
            println("未知场景: ${args[0]}")
            printHelp()
            return 1
    }

    0
}
