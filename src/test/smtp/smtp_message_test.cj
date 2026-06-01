package mail.test.smtp

import mail.core.*
import mail.internet.*
import std.collection.*

func smtpSession(): Session { Session.getInstance(HashMap<String, String>()) }

// ─── envelope From ───────────────────────────────────────────────────────────

@Test
public class SMTPMessageEnvelopeTest {

    @TestCase
    func envelopeFromStoredSeparatelyFromFromHeader(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setFrom(InternetAddress("header@corp.com"))
        m.setEnvelopeFrom("bounce@corp.com")
        @Expect(m.getEnvelopeFrom(), Some("bounce@corp.com"))
        @Assert(m.getFrom()[0].toString().contains("header@corp.com"))
    }

    @TestCase
    func envelopeFromClearedByEmptyString(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setEnvelopeFrom("bounce@corp.com")
        m.setEnvelopeFrom("")
        @Expect(m.getEnvelopeFrom(), None)
    }

    @TestCase
    func envelopeFromDefaultsToNone(): Unit {
        @Expect(SMTPMessage(smtpSession()).getEnvelopeFrom(), None)
    }
}

// ─── DSN options ─────────────────────────────────────────────────────────────

@Test
public class SMTPMessageDsnTest {

    @TestCase
    func notifyOptionsDefaultToNever(): Unit {
        @Expect(SMTPMessage(smtpSession()).getNotifyOptions(), NOTIFY_NEVER)
    }

    @TestCase
    func notifySuccessAndFailureBitMask(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setNotifyOptions(NOTIFY_SUCCESS | NOTIFY_FAILURE)
        let opts = m.getNotifyOptions()
        @Assert((opts & NOTIFY_SUCCESS) == NOTIFY_SUCCESS)
        @Assert((opts & NOTIFY_FAILURE) == NOTIFY_FAILURE)
        @Assert((opts & NOTIFY_DELAY) != NOTIFY_DELAY)
    }

    @TestCase
    func notifyAllThreeBitsSet(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setNotifyOptions(NOTIFY_SUCCESS | NOTIFY_FAILURE | NOTIFY_DELAY)
        @Expect(m.getNotifyOptions(), Int32(7))
    }

    @TestCase
    func returnOptionDefaultsFull(): Unit {
        @Expect(SMTPMessage(smtpSession()).getReturnOption(), RETURN_FULL)
    }

    @TestCase
    func returnOptionHdrs(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setReturnOption(RETURN_HDRS)
        @Expect(m.getReturnOption(), RETURN_HDRS)
    }

    @TestCase
    func envelopeIdRoundTrips(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setEnvelopeId("TXID-20260601-001")
        @Expect(m.getEnvelopeId(), Some("TXID-20260601-001"))
    }

    @TestCase
    func envelopeIdClearedByEmptyString(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setEnvelopeId("some-id")
        m.setEnvelopeId("")
        @Expect(m.getEnvelopeId(), None)
    }
}

// ─── transport flags ─────────────────────────────────────────────────────────

@Test
public class SMTPMessageFlagsTest {

    @TestCase
    func allow8bitMimeDefaultFalse(): Unit {
        @Assert(!SMTPMessage(smtpSession()).isAllow8bitMIME())
    }

    @TestCase
    func allow8bitMimeToggle(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setAllow8bitMIME(true)
        @Assert(m.isAllow8bitMIME())
        m.setAllow8bitMIME(false)
        @Assert(!m.isAllow8bitMIME())
    }

    @TestCase
    func smtpUtf8DefaultFalse(): Unit {
        @Assert(!SMTPMessage(smtpSession()).isSmtpUtf8())
    }

    @TestCase
    func smtpUtf8Toggle(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setSmtpUtf8(true)
        @Assert(m.isSmtpUtf8())
    }

    @TestCase
    func sendPartialDefaultFalse(): Unit {
        @Assert(!SMTPMessage(smtpSession()).isSendPartial())
    }

    @TestCase
    func sendPartialToggle(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setSendPartial(true)
        @Assert(m.isSendPartial())
    }

    @TestCase
    func mailExtensionDefaultNone(): Unit {
        @Expect(SMTPMessage(smtpSession()).getMailExtension(), None)
    }

    @TestCase
    func mailExtensionRoundTrips(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setMailExtension("SIZE=12345")
        @Expect(m.getMailExtension(), Some("SIZE=12345"))
    }

    @TestCase
    func mailExtensionClearedByEmpty(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setMailExtension("X")
        m.setMailExtension("")
        @Expect(m.getMailExtension(), None)
    }
}

// ─── copy construction ────────────────────────────────────────────────────────

@Test
public class SMTPMessageCopyTest {

    @TestCase
    func fromMimeMessagePreservesSubjectAndBody(): Unit {
        let s = smtpSession()
        let mime = MimeMessage(s)
        mime.setSubject("Base Subject")
        mime.setText("Base body")
        mime.setFrom(InternetAddress("base@x.com"))
        let smtp = SMTPMessage(mime)
        @Expect(smtp.getSubject(), Some("Base Subject"))
        @Expect(smtp.getContent(), Some("Base body"))
    }

    @TestCase
    func fromMimeMessageGetsNewMessageId(): Unit {
        let s = smtpSession()
        let mime = MimeMessage(s)
        let smtp = SMTPMessage(mime)
        @Assert(smtp.getMessageID() != mime.getMessageID())
    }

    @TestCase
    func smtpFlagsDefaultAfterCopy(): Unit {
        let s = smtpSession()
        let mime = MimeMessage(s)
        let smtp = SMTPMessage(mime)
        // SMTPMessage-specific flags default to off
        @Assert(!smtp.isAllow8bitMIME())
        @Assert(!smtp.isSmtpUtf8())
        @Assert(!smtp.isSendPartial())
    }
}

// ─── DSN combination ─────────────────────────────────────────────────────────

@Test
public class SMTPMessageDsnCombinationTest {

    @TestCase
    func fullDsnConfiguration(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setReturnOption(RETURN_HDRS)
        m.setEnvelopeId("ORDER-001")
        m.setNotifyOptions(NOTIFY_SUCCESS | NOTIFY_FAILURE | NOTIFY_DELAY)
        m.setSmtpUtf8(true)
        @Expect(m.getReturnOption(), RETURN_HDRS)
        @Expect(m.getEnvelopeId(), Some("ORDER-001"))
        @Expect(m.getNotifyOptions(), Int32(7))
        @Assert(m.isSmtpUtf8())
    }

    @TestCase
    func failureOnlyDsnConfiguration(): Unit {
        let m = SMTPMessage(smtpSession())
        m.setNotifyOptions(NOTIFY_FAILURE)
        m.setReturnOption(RETURN_FULL)
        let opts = m.getNotifyOptions()
        @Assert((opts & NOTIFY_FAILURE) == NOTIFY_FAILURE)
        @Assert((opts & NOTIFY_SUCCESS) != NOTIFY_SUCCESS)
        @Expect(m.getReturnOption(), RETURN_FULL)
    }
}
