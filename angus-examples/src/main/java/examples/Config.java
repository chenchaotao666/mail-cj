package examples;

import io.github.cdimascio.dotenv.Dotenv;
import java.util.Properties;

/**
 * 从 .env 文件加载 SMTP 配置。
 */
public class Config {

    private final Dotenv env;

    public Config() {
        this.env = Dotenv.configure().ignoreIfMissing().load();
    }

    public String smtpHost()     { return get("SMTP_HOST", "smtp.example.com"); }
    public int    smtpPort()     { return Integer.parseInt(get("SMTP_PORT", "465")); }
    public String smtpUser()     { return get("SMTP_USER", ""); }
    public String smtpPassword() { return get("SMTP_PASSWORD", ""); }
    public String mailFrom()     { return get("MAIL_FROM", smtpUser()); }
    public String mailFromName() { return get("MAIL_FROM_NAME", "Mail Example"); }
    public String mailTo()       { return get("MAIL_TO", ""); }
    public String mailCc()       { return get("MAIL_CC", ""); }
    public String mailBcc()      { return get("MAIL_BCC", ""); }
    public String oauth2Token()  { return get("OAUTH2_TOKEN", ""); }
    public String attachmentPath(){ return get("ATTACHMENT_PATH", "src/main/resources/sample.pdf"); }
    public boolean debug()       { return "true".equalsIgnoreCase(get("DEBUG", "false")); }

    /** 构造发送用 Session Properties（SMTPS 465 直连 SSL）。 */
    public Properties smtpsProps() {
        Properties p = new Properties();
        p.put("mail.smtps.host",                   smtpHost());
        p.put("mail.smtps.port",                   String.valueOf(smtpPort()));
        p.put("mail.smtps.auth",                   "true");
        p.put("mail.smtps.ssl.checkserveridentity","false");
        p.put("mail.debug",                        String.valueOf(debug()));
        return p;
    }

    /** 构造 STARTTLS 587 端口用 Properties。 */
    public Properties starttlsProps() {
        Properties p = new Properties();
        p.put("mail.smtp.host",              smtpHost());
        p.put("mail.smtp.port",              "587");
        p.put("mail.smtp.auth",              "true");
        p.put("mail.smtp.starttls.enable",   "true");
        p.put("mail.smtp.starttls.required", "true");
        p.put("mail.debug",                  String.valueOf(debug()));
        return p;
    }

    public void printInfo() {
        System.out.println("SMTP Host : " + smtpHost() + ":" + smtpPort());
        System.out.println("SMTP User : " + smtpUser());
        System.out.println("From      : " + mailFromName() + " <" + mailFrom() + ">");
        System.out.println("To        : " + mailTo());
        if (!mailCc().isEmpty())  System.out.println("CC        : " + mailCc());
        if (!mailBcc().isEmpty()) System.out.println("BCC       : " + mailBcc());
    }

    private String get(String key, String defaultValue) {
        String v = env.get(key);
        return (v == null || v.isEmpty()) ? defaultValue : v;
    }
}
