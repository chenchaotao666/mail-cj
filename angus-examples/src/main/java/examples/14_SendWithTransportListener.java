package examples;

import jakarta.mail.*;
import jakarta.mail.event.*;
import jakarta.mail.internet.*;

/**
 * 场景 14：TransportListener + ConnectionListener 事件监听
 *
 * 演示：
 * - TransportListener：messageDelivered / messageNotDelivered / messagePartiallyDelivered
 * - ConnectionListener：opened / closed / disconnected
 * - sendPartial：部分收件人无效时继续发送其余有效地址
 *
 * 对标 mail-cj：
 *   Transport.addTransportListener / addConnectionListener
 *   mail.smtp.sendpartial=true
 */
class SendWithTransportListener {

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();

        java.util.Properties props = cfg.smtpsProps();
        // sendPartial=true：部分 RCPT TO 失败时继续发送其余地址
        props.put("mail.smtps.sendpartial", "true");

        Session session = Session.getInstance(props);

        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(cfg.mailFrom(), cfg.mailFromName()));
        msg.setRecipient(Message.RecipientType.TO, new InternetAddress(cfg.mailTo()));
        msg.setSubject("【mail-cj 对标】Transport 事件监听", "UTF-8");
        msg.setText("本邮件演示 TransportListener 和 ConnectionListener 回调。", "UTF-8");

        Transport transport = session.getTransport("smtps");

        // ConnectionListener：连接生命周期事件
        transport.addConnectionListener(new ConnectionListener() {
            @Override public void opened(ConnectionEvent e) {
                System.out.println("  [ConnectionEvent] OPENED → 连接建立");
            }
            @Override public void closed(ConnectionEvent e) {
                System.out.println("  [ConnectionEvent] CLOSED → 连接关闭");
            }
            @Override public void disconnected(ConnectionEvent e) {
                System.out.println("  [ConnectionEvent] DISCONNECTED → 连接断开");
            }
        });

        // TransportListener：发送结果事件
        transport.addTransportListener(new TransportListener() {
            @Override public void messageDelivered(TransportEvent e) {
                System.out.println("  [TransportEvent] DELIVERED → 全部收件人发送成功");
                System.out.println("    validSent.length = " + e.getValidSentAddresses().length);
            }
            @Override public void messageNotDelivered(TransportEvent e) {
                System.out.println("  [TransportEvent] NOT_DELIVERED → 全部失败");
                System.out.println("    invalidAddresses = " + e.getInvalidAddresses().length);
            }
            @Override public void messagePartiallyDelivered(TransportEvent e) {
                System.out.println("  [TransportEvent] PARTIALLY_DELIVERED → 部分成功");
                System.out.println("    validSent = " + e.getValidSentAddresses().length
                    + " / invalid = " + e.getInvalidAddresses().length);
            }
        });

        transport.connect(cfg.smtpHost(), cfg.smtpUser(), cfg.smtpPassword());
        transport.sendMessage(msg, msg.getAllRecipients());
        transport.close();

        System.out.println("✓ 事件监听发送完成");
    }
}
