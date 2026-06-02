package examples;

/**
 * angus-mail 邮件发送示例入口
 *
 * 用法：
 *   mvn package -q
 *   java -jar target/angus-mail-examples-1.0.0.jar <场景>
 *
 * 或直接用 Maven 运行：
 *   mvn exec:java -Dexec.mainClass=examples.<ClassName>
 */
public class Main {

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            printHelp();
            return;
        }

        switch (args[0]) {
            case "--01" -> SendSimple.main(args);
            case "--02" -> SendHtml.main(args);
            case "--03" -> SendWithAttachment.main(args);
            case "--04" -> SendWithInlineImage.main(args);
            case "--05" -> SendComplex.main(args);
            case "--06" -> SendCcBcc.main(args);
            case "--07" -> SendWithStartTLS.main(args);
            case "--08" -> SendReply.main(args);
            case "--09" -> SendBulk.main(args);
            case "--10" -> SendWithCustomHeaders.main(args);
            case "--11" -> SendAlternative.main(args);
            case "--12" -> SendFromInputStream.main(args);
            case "--13" -> SendWithSMTPMessage.main(args);
            case "--14" -> SendWithTransportListener.main(args);
            case "--15" -> SendWithConnectionPool.main(args);
            case "--16" -> SendWithXOAuth2.main(args);
            default -> {
                System.out.println("未知场景: " + args[0]);
                printHelp();
            }
        }
    }

    private static void printHelp() {
        System.out.println("""
                用法: java -jar target/angus-mail-examples-1.0.0.jar <场景>

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
                  --15   长连接保活（NOOP 心跳）
                  --16   XOAUTH2 OAuth2 认证

                配置：
                  cp .env.example .env
                  # 编辑 .env 填写 SMTP 配置后运行

                快速开始：
                  mvn package -q && java -jar target/angus-mail-examples-1.0.0.jar --01
                """);
    }
}
