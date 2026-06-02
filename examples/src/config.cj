package mail_demo

import std.collection.*
import std.convert.*
import std.fs.*

public class MailConfig {
    public var smtpHost: String = "smtp.example.com"
    public var smtpPort: Int64 = 465
    public var smtpUser: String = ""
    public var smtpPassword: String = ""
    public var mailFrom: String = ""
    public var mailFromName: String = "Mail Example"
    public var mailTo: String = ""
    public var mailCc: String = ""
    public var mailBcc: String = ""
    public var oauth2Token: String = ""
    public var attachmentPath: String = "assets/test.txt"
    public var debug: Bool = false

    public func smtpsProps(): HashMap<String, String> {
        let p = HashMap<String, String>()
        p["mail.smtps.host"]                    = smtpHost
        p["mail.smtps.port"]                    = smtpPort.toString()
        p["mail.smtps.auth"]                    = "true"
        p["mail.smtps.ssl.checkserveridentity"] = "false"
        p["mail.smtps.auth.mechanisms"]         = "LOGIN PLAIN"
        p
    }

    public func starttlsProps(): HashMap<String, String> {
        let p = HashMap<String, String>()
        p["mail.smtp.host"]              = smtpHost
        p["mail.smtp.port"]              = "587"
        p["mail.smtp.auth"]              = "true"
        p["mail.smtp.starttls.enable"]   = "true"
        p["mail.smtp.starttls.required"] = "true"
        p["mail.smtp.auth.mechanisms"]   = "LOGIN PLAIN"
        p
    }

    public func printInfo(): Unit {
        println("SMTP Host : ${smtpHost}:${smtpPort}")
        println("SMTP User : ${smtpUser}")
        println("From      : ${mailFromName} <${mailFrom}>")
        println("To        : ${mailTo}")
        if (!mailCc.isEmpty())  { println("CC        : ${mailCc}") }
        if (!mailBcc.isEmpty()) { println("BCC       : ${mailBcc}") }
    }

    public static func load(envPath: String): MailConfig {
        let cfg = MailConfig()
        let env = loadEnvFile(envPath)

        ifSet(env, "SMTP_HOST")     { v => cfg.smtpHost = v }
        ifSet(env, "SMTP_PORT")     { v => try { cfg.smtpPort = Int64.parse(v) } catch (_: Exception) {} }
        ifSet(env, "SMTP_USER")     { v => cfg.smtpUser = v }
        ifSet(env, "SMTP_PASSWORD") { v => cfg.smtpPassword = v }
        ifSet(env, "MAIL_FROM")     { v => cfg.mailFrom = v }
        ifSet(env, "MAIL_FROM_NAME"){ v => cfg.mailFromName = v }
        ifSet(env, "MAIL_TO")       { v => cfg.mailTo = v }
        ifSet(env, "MAIL_CC")       { v => cfg.mailCc = v }
        ifSet(env, "MAIL_BCC")      { v => cfg.mailBcc = v }
        ifSet(env, "OAUTH2_TOKEN")  { v => cfg.oauth2Token = v }
        ifSet(env, "ATTACHMENT_PATH"){ v => cfg.attachmentPath = v }
        match (env.get("DEBUG")) {
            case Some("true")  => cfg.debug = true
            case Some("false") => cfg.debug = false
            case _ => ()
        }
        if (cfg.mailFrom.isEmpty()) { cfg.mailFrom = cfg.smtpUser }
        cfg
    }
}

func ifSet(env: HashMap<String, String>, key: String, action: (String) -> Unit): Unit {
    match (env.get(key)) {
        case Some(v) where !v.isEmpty() => action(v)
        case _ => ()
    }
}

func loadEnvFile(path: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    try {
        let content = String.fromUtf8(File.readFrom(path))
        for (line in content.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) { continue }
            match (trimmed.indexOf("=")) {
                case Some(eq) where eq > 0 =>
                    let key = trimmed[0..eq].trimAscii()
                    var val = trimmed[(eq + 1)..trimmed.size].trimAscii()
                    if (val.size >= 2 &&
                        ((val.startsWith("\"") && val.endsWith("\"")) ||
                         (val.startsWith("'")  && val.endsWith("'")))) {
                        val = val[1..(val.size - 1)]
                    }
                    result[key] = val
                case _ => ()
            }
        }
    } catch (e: Exception) {
        println("警告：无法加载配置文件 ${path}: ${e.message}")
    }
    result
}

public func envFileExists(path: String): Bool {
    try {
        File(path, OpenMode.Read).close()
        true
    } catch (_: Exception) {
        false
    }
}
