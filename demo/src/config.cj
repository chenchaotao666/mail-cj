/**
 * 环境配置加载器
 *
 * 从 .env 文件加载配置，支持以下格式：
 * - KEY=value
 * - KEY="value with spaces"
 * - # 注释行
 */
package mail_demo

import std.fs.*
import std.collection.*
import std.convert.*

/**
 * 邮件配置
 */
public class MailConfig {
    // SMTP 服务器配置
    public var smtpHost: String = "smtp.example.com"
    public var smtpPort: Int64 = 465
    public var smtpUser: String = ""
    public var smtpPassword: String = ""

    // 邮件地址配置
    public var mailFrom: String = ""
    public var mailTo: String = ""
    public var mailFromName: String = "Cangjie Mail"

    // 安全配置
    public var verifyCert: Bool = false
    public var caCertPath: ?String = None

    // 调试配置
    public var debug: Bool = true

    /**
     * 从 .env 文件加载配置
     */
    public static func load(envPath: String): MailConfig {
        let config = MailConfig()
        let envMap = loadEnvFile(envPath)

        // SMTP 配置
        match (envMap.get("SMTP_HOST")) {
            case Some(v) => config.smtpHost = v
            case None => ()
        }
        match (envMap.get("SMTP_PORT")) {
            case Some(v) =>
                try {
                    config.smtpPort = Int64.parse(v)
                } catch (_: Exception) {}
            case None => ()
        }
        match (envMap.get("SMTP_USER")) {
            case Some(v) => config.smtpUser = v
            case None => ()
        }
        match (envMap.get("SMTP_PASSWORD")) {
            case Some(v) => config.smtpPassword = v
            case None => ()
        }

        // 邮件地址配置
        match (envMap.get("MAIL_FROM")) {
            case Some(v) => config.mailFrom = v
            case None => ()
        }
        match (envMap.get("MAIL_TO")) {
            case Some(v) => config.mailTo = v
            case None => ()
        }
        match (envMap.get("MAIL_FROM_NAME")) {
            case Some(v) => config.mailFromName = v
            case None => ()
        }

        // 安全配置
        match (envMap.get("VERIFY_CERT")) {
            case Some("true") => config.verifyCert = true
            case Some("false") => config.verifyCert = false
            case _ => ()
        }
        match (envMap.get("CA_CERT_PATH")) {
            case Some(v) where !v.isEmpty() => config.caCertPath = Some(v)
            case _ => ()
        }

        // 调试配置
        match (envMap.get("DEBUG")) {
            case Some("true") => config.debug = true
            case Some("false") => config.debug = false
            case _ => ()
        }

        config
    }

    /**
     * 验证配置是否完整
     */
    public func validate(): Bool {
        if (smtpHost.isEmpty()) {
            println("错误：SMTP_HOST 未配置")
            return false
        }
        if (smtpUser.isEmpty()) {
            println("错误：SMTP_USER 未配置")
            return false
        }
        if (smtpPassword.isEmpty()) {
            println("错误：SMTP_PASSWORD 未配置")
            return false
        }
        if (mailFrom.isEmpty()) {
            println("错误：MAIL_FROM 未配置")
            return false
        }
        if (mailTo.isEmpty()) {
            println("错误：MAIL_TO 未配置")
            return false
        }
        true
    }

    /**
     * 打印配置信息（隐藏敏感信息）
     */
    public func printInfo(): Unit {
        println("当前配置：")
        println("  SMTP 服务器: ${smtpHost}:${smtpPort}")
        println("  SMTP 用户: ${smtpUser}")
        println("  SMTP 密码: ${maskPassword(smtpPassword)}")
        println("  发件人: ${mailFromName} <${mailFrom}>")
        println("  收件人: ${mailTo}")
        println("  证书验证: ${if (verifyCert) { "启用" } else { "禁用" }}")
        match (caCertPath) {
            case Some(path) => println("  CA 证书: ${path}")
            case None => ()
        }
        println("  调试模式: ${if (debug) { "开启" } else { "关闭" }}")
    }
}

/**
 * 加载 .env 文件
 */
func loadEnvFile(path: String): HashMap<String, String> {
    let result = HashMap<String, String>()

    try {
        let bytes = File.readFrom(path)
        let content = String.fromUtf8(bytes)

        for (line in content.split("\n")) {
            let trimmed = line.trimAscii()

            // 跳过空行和注释
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                continue
            }

            // 解析 KEY=value
            match (trimmed.indexOf("=")) {
                case Some(eqIndex) where eqIndex > 0 =>
                    let key = trimmed[0..eqIndex].trimAscii()
                    var value = trimmed[(eqIndex + 1)..trimmed.size].trimAscii()

                    // 去除引号
                    if (value.size >= 2) {
                        if ((value.startsWith("\"") && value.endsWith("\"")) ||
                            (value.startsWith("'") && value.endsWith("'"))) {
                            value = value[1..(value.size - 1)]
                        }
                    }

                    result[key] = value
                case _ => ()
            }
        }
    } catch (e: Exception) {
        println("警告：无法加载配置文件 ${path}: ${e.message}")
    }

    result
}

/**
 * 隐藏密码（只显示前后各2个字符）
 */
func maskPassword(password: String): String {
    if (password.size <= 4) {
        return "****"
    }
    let prefix = password[0..2]
    let suffix = password[(password.size - 2)..password.size]
    "${prefix}****${suffix}"
}

/**
 * 检查 .env 文件是否存在
 */
public func envFileExists(path: String): Bool {
    try {
        let file = File(path, OpenMode.Read)
        file.close()
        true
    } catch (_: Exception) {
        false
    }
}
