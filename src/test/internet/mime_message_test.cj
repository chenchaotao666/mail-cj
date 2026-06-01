package mail.test.internet

import mail.core.*
import mail.internet.*
import mail.util.*
import std.collection.*
import std.io.*
import std.time.*

// ─── helpers ─────────────────────────────────────────────────────────────────

func makeSession(): Session { Session.getInstance(HashMap<String, String>()) }

func basicMsg(session: Session): MimeMessage {
    let m = MimeMessage(session)
    m.setFrom(InternetAddress("sender@example.com", "Sender"))
    m.setRecipients(RecipientType.TO, [InternetAddress("to@example.com")])
    m.setSubject("Test Subject")
    m.setText("Test body.")
    m
}

class StringInputStream <: InputStream {
    private var _bytes: Array<Byte>
    private var _pos: Int64

    public init(s: String) { _bytes = s.toArray(); _pos = 0 }

    public override func read(buf: Array<Byte>): Int64 {
        let n = if ((_bytes.size - _pos) < buf.size) { _bytes.size - _pos } else { buf.size }
        if (n <= 0) { return 0 }
        for (i in 0..n) { buf[i] = _bytes[_pos + i] }
        _pos += n
        n
    }
}

class ByteBuffer <: OutputStream {
    var _data: ArrayList<Byte> = ArrayList<Byte>()
    public override func write(d: Array<Byte>): Unit { for (b in d) { _data.add(b) } }
    public override func flush(): Unit {}
    public func toString(): String {
        try { String.fromUtf8(_data.toArray()) } catch (_: Exception) { "" }
    }
}

// ─── construction ────────────────────────────────────────────────────────────

@Test
public class MimeMessageConstructionTest {

    @TestCase
    func defaultFieldsAreEmpty(): Unit {
        let m = MimeMessage(makeSession())
        @Assert(m.getFrom().isEmpty())
        @Expect(m.getSubject(), None)
        @Assert(m.getAllRecipients().isEmpty())
    }

    @TestCase
    func copyConstructorPreservesSubjectAndBody(): Unit {
        let s = makeSession()
        let orig = MimeMessage(s)
        orig.setSubject("Hello"); orig.setText("Body")
        let copy = MimeMessage(orig)
        @Expect(copy.getSubject(), Some("Hello"))
        @Expect(copy.getContent(), Some("Body"))
    }

    @TestCase
    func copyConstructorGeneratesNewMessageId(): Unit {
        let s = makeSession()
        let orig = MimeMessage(s)
        let copy = MimeMessage(orig)
        @Assert(orig.getMessageID() != copy.getMessageID())
    }

    @TestCase
    func copyConstructorIndependentRecipientLists(): Unit {
        let s = makeSession()
        let orig = MimeMessage(s)
        orig.setRecipients(RecipientType.TO, [InternetAddress("a@x.com")])
        let copy = MimeMessage(orig)
        copy.setRecipients(RecipientType.TO, [InternetAddress("b@x.com")])
        @Expect(orig.getRecipients(RecipientType.TO).size, 1)
    }
}

// ─── from / sender ───────────────────────────────────────────────────────────

@Test
public class MimeMessageFromTest {

    @TestCase
    func setFromStoresAddress(): Unit {
        let m = MimeMessage(makeSession())
        m.setFrom(InternetAddress("a@b.com"))
        @Expect(m.getFrom().size, 1)
        match (m.getFrom()[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "a@b.com")
            case _ => @Assert(false)
        }
    }

    @TestCase
    func addFromAccumulatesAddresses(): Unit {
        let m = MimeMessage(makeSession())
        m.setFrom(InternetAddress("a@b.com"))
        m.addFrom([InternetAddress("b@c.com"), InternetAddress("d@e.com")])
        @Expect(m.getFrom().size, 3)
    }

    @TestCase
    func senderWrittenToHeaderAfterSaveChanges(): Unit {
        let m = basicMsg(makeSession())
        m.setSender(InternetAddress("proxy@example.com"))
        m.saveChanges()
        let raw = m.getMessageString()
        @Assert(raw.contains("Sender:"))
        @Assert(raw.contains("proxy@example.com"))
    }

    @TestCase
    func getSenderBeforeSetReturnsNone(): Unit {
        @Expect(MimeMessage(makeSession()).getSender(), None)
    }
}

// ─── recipients ──────────────────────────────────────────────────────────────

@Test
public class MimeMessageRecipientsTest {

    @TestCase
    func setRecipientsByType(): Unit {
        let m = MimeMessage(makeSession())
        m.setRecipients(RecipientType.TO,  [InternetAddress("to@x.com")])
        m.setRecipients(RecipientType.CC,  [InternetAddress("cc@x.com")])
        m.setRecipients(RecipientType.BCC, [InternetAddress("bcc@x.com")])
        @Expect(m.getRecipients(RecipientType.TO).size,  1)
        @Expect(m.getRecipients(RecipientType.CC).size,  1)
        @Expect(m.getRecipients(RecipientType.BCC).size, 1)
    }

    @TestCase
    func addRecipientsCumulative(): Unit {
        let m = MimeMessage(makeSession())
        m.setRecipients(RecipientType.TO, [InternetAddress("a@x.com")])
        m.addRecipients(RecipientType.TO, [InternetAddress("b@x.com")])
        @Expect(m.getRecipients(RecipientType.TO).size, 2)
    }

    @TestCase
    func getAllRecipientsMergesToCcBcc(): Unit {
        let m = MimeMessage(makeSession())
        m.setRecipients(RecipientType.TO,  [InternetAddress("to@x.com")])
        m.setRecipients(RecipientType.CC,  [InternetAddress("cc@x.com")])
        m.setRecipients(RecipientType.BCC, [InternetAddress("bcc@x.com")])
        @Expect(m.getAllRecipients().size, 3)
    }

    @TestCase
    func setRecipientsReplacesExisting(): Unit {
        let m = MimeMessage(makeSession())
        m.setRecipients(RecipientType.TO, [InternetAddress("old@x.com")])
        m.setRecipients(RecipientType.TO, [InternetAddress("new@x.com")])
        @Expect(m.getRecipients(RecipientType.TO).size, 1)
        match (m.getRecipients(RecipientType.TO)[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "new@x.com")
            case _ => @Assert(false)
        }
    }
}

// ─── reply-to ────────────────────────────────────────────────────────────────

@Test
public class MimeMessageReplyToTest {

    @TestCase
    func replyToDefaultsToFrom(): Unit {
        let m = MimeMessage(makeSession())
        m.setFrom(InternetAddress("sender@x.com"))
        @Expect(m.getReplyTo().size, 1)
        match (m.getReplyTo()[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "sender@x.com")
            case _ => @Assert(false)
        }
    }

    @TestCase
    func setReplyToOverridesDefault(): Unit {
        let m = MimeMessage(makeSession())
        m.setFrom(InternetAddress("from@x.com"))
        m.setReplyTo([InternetAddress("reply@x.com")])
        match (m.getReplyTo()[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "reply@x.com")
            case _ => @Assert(false)
        }
    }
}

// ─── subject & date ──────────────────────────────────────────────────────────

@Test
public class MimeMessageSubjectTest {

    @TestCase
    func subjectRoundTrips(): Unit {
        let m = MimeMessage(makeSession())
        m.setSubject("Hello World")
        @Expect(m.getSubject(), Some("Hello World"))
    }

    @TestCase
    func chineseSubjectStored(): Unit {
        let m = MimeMessage(makeSession())
        m.setSubject("你好世界")
        @Expect(m.getSubject(), Some("你好世界"))
    }

    @TestCase
    func saveChangesAutoFillsDate(): Unit {
        let m = basicMsg(makeSession())
        m.saveChanges()
        @Assert(m.getSentDate().isSome())
    }

    @TestCase
    func setSentDatePreserved(): Unit {
        let m = MimeMessage(makeSession())
        let now = DateTime.now()
        m.setSentDate(now)
        @Assert(m.getSentDate().isSome())
    }
}

// ─── content ─────────────────────────────────────────────────────────────────

@Test
public class MimeMessageContentTest {

    @TestCase
    func setTextPlain(): Unit {
        let m = MimeMessage(makeSession())
        m.setText("Hello World")
        @Expect(m.getContent(), Some("Hello World"))
        @Assert(m.getContentType().startsWith("text/plain"))
    }

    @TestCase
    func setTextWithCharset(): Unit {
        let m = MimeMessage(makeSession())
        m.setText("你好", "UTF-8")
        @Assert(m.getContentType().contains("charset=UTF-8"))
    }

    @TestCase
    func setHtmlContent(): Unit {
        let m = MimeMessage(makeSession())
        m.setHtmlContent("<b>Hi</b>")
        @Assert(m.getContentType().startsWith("text/html"))
        @Expect(m.getContent(), Some("<b>Hi</b>"))
    }

    @TestCase
    func setContentMultipart(): Unit {
        let m = MimeMessage(makeSession())
        let mp = MimeMultipart(MULTIPART_MIXED)
        mp.addBodyPart(MimeBodyPart())
        m.setContent(mp)
        @Assert(m.isMultipart())
    }

    @TestCase
    func isMultipartFalseForTextMessage(): Unit {
        let m = MimeMessage(makeSession())
        m.setText("plain")
        @Assert(!m.isMultipart())
    }
}

// ─── headers ─────────────────────────────────────────────────────────────────

@Test
public class MimeMessageHeaderTest {

    @TestCase
    func setGetHeader(): Unit {
        let m = MimeMessage(makeSession())
        m.setHeader("X-Custom", "value1")
        @Expect(m.getHeader("X-Custom"), Some("value1"))
    }

    @TestCase
    func setHeaderReplaces(): Unit {
        let m = MimeMessage(makeSession())
        m.setHeader("X-H", "v1")
        m.setHeader("X-H", "v2")
        @Expect(m.getHeader("X-H"), Some("v2"))
    }

    @TestCase
    func removeHeaderClearsValue(): Unit {
        let m = MimeMessage(makeSession())
        m.setHeader("X-H", "v")
        m.removeHeader("X-H")
        @Expect(m.getHeader("X-H"), None)
    }

    @TestCase
    func messageIdAutoGeneratedOnConstruction(): Unit {
        let id = MimeMessage(makeSession()).getMessageID()
        @Assert(id.isSome())
        let s = id.getOrThrow()
        @Assert(s.startsWith("<") && s.endsWith(">") && s.contains("@"))
    }

    @TestCase
    func getAllHeadersIncludesStandardHeadersAfterSave(): Unit {
        let m = basicMsg(makeSession())
        let all = m.getAllHeaders()
        var hasDate = false; var hasMsgId = false
        for (h in all) {
            let n = h.getName().toAsciiLower()
            if (n == "date") { hasDate = true }
            if (n == "message-id") { hasMsgId = true }
        }
        @Assert(hasDate)
        @Assert(hasMsgId)
    }

    @TestCase
    func getMatchingHeadersCaseInsensitive(): Unit {
        let m = basicMsg(makeSession())
        m.saveChanges()
        let matched = m.getMatchingHeaders(["subject", "FROM"])
        var hasSubject = false; var hasFrom = false
        for (h in matched) {
            let n = h.getName().toAsciiLower()
            if (n == "subject") { hasSubject = true }
            if (n == "from")    { hasFrom    = true }
        }
        @Assert(hasSubject)
        @Assert(hasFrom)
    }

    @TestCase
    func getNonMatchingHeadersExcludesGivenNames(): Unit {
        let m = basicMsg(makeSession())
        m.saveChanges()
        for (h in m.getNonMatchingHeaders(["Subject"])) {
            @Assert(h.getName().toAsciiLower() != "subject")
        }
    }
}

// ─── serialization ───────────────────────────────────────────────────────────

@Test
public class MimeMessageSerializationTest {

    @TestCase
    func bccFilteredFromMessageString(): Unit {
        let m = basicMsg(makeSession())
        m.setRecipients(RecipientType.BCC, [InternetAddress("bcc@secret.com")])
        m.saveChanges()
        @Assert(!m.getMessageString(["Bcc"]).contains("bcc@secret.com"))
    }

    @TestCase
    func writeToContainsSubjectAndBody(): Unit {
        let m = basicMsg(makeSession())
        let buf = ByteBuffer()
        m.writeTo(buf)
        let s = buf.toString()
        @Assert(s.contains("Subject: Test Subject"))
        @Assert(s.contains("Test body."))
    }

    @TestCase
    func writeToIgnoreHeadersFilters(): Unit {
        let m = basicMsg(makeSession())
        m.setHeader("X-Secret", "hidden")
        let buf = ByteBuffer()
        m.writeTo(buf, ["X-Secret"])
        @Assert(!buf.toString().contains("X-Secret"))
    }

    @TestCase
    func getSizePositiveAfterSave(): Unit {
        let m = basicMsg(makeSession())
        m.saveChanges()
        @Assert(m.getSize() > 0)
    }
}

// ─── reply ───────────────────────────────────────────────────────────────────

@Test
public class MimeMessageReplyTest {

    @TestCase
    func replyAddressesSenderAndPrefixesSubject(): Unit {
        let s = makeSession()
        let orig = MimeMessage(s)
        orig.setFrom(InternetAddress("alice@x.com"))
        orig.setSubject("Hello")
        orig.setText("Original")
        orig.saveChanges()
        let reply = orig.reply(false)
        @Expect(reply.getSubject(), Some("Re: Hello"))
        match (reply.getRecipients(RecipientType.TO)[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "alice@x.com")
            case _ => @Assert(false)
        }
        @Assert(reply.getHeader("In-Reply-To").isSome())
    }

    @TestCase
    func replyDoesNotDuplicateRePrefix(): Unit {
        let s = makeSession()
        let orig = MimeMessage(s)
        orig.setFrom(InternetAddress("b@x.com"))
        orig.setSubject("Re: Original")
        orig.setText("r")
        @Expect(orig.reply(false).getSubject(), Some("Re: Original"))
    }

    @TestCase
    func replyAllPreservesOriginalCc(): Unit {
        let s = makeSession()
        let orig = MimeMessage(s)
        orig.setFrom(InternetAddress("alice@x.com"))
        orig.setRecipients(RecipientType.TO, [InternetAddress("bob@x.com")])
        orig.setRecipients(RecipientType.CC, [InternetAddress("carol@x.com")])
        orig.setSubject("T"); orig.setText("B")
        let reply = orig.reply(true)
        var hasCarol = false
        for (a in reply.getRecipients(RecipientType.CC)) {
            match (a) {
                case ia: InternetAddress =>
                    if (ia.getAddress() == "carol@x.com") { hasCarol = true }
                case _ => ()
            }
        }
        @Assert(hasCarol)
    }
}

// ─── InputStream constructor ──────────────────────────────────────────────────

@Test
public class MimeMessageInputStreamTest {

    @TestCase
    func parsesStandardHeaders(): Unit {
        let raw =
            "From: sender@example.com\r\n" +
            "To: to@example.com\r\n" +
            "Subject: Load Test\r\n" +
            "Message-ID: <abc@host.example.com>\r\n" +
            "Content-Type: text/plain; charset=UTF-8\r\n" +
            "\r\n" +
            "Body content here."
        let m = MimeMessage(makeSession(), StringInputStream(raw))
        match (m.getFrom()[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "sender@example.com")
            case _ => @Assert(false)
        }
        match (m.getRecipients(RecipientType.TO)[0]) {
            case ia: InternetAddress => @Expect(ia.getAddress(), "to@example.com")
            case _ => @Assert(false)
        }
        @Expect(m.getSubject(), Some("Load Test"))
        @Assert(m.getMessageID().getOrThrow().contains("abc@host"))
        @Assert(m.getContent().getOrThrow().contains("Body content"))
    }

    @TestCase
    func unfoldsFoldedHeaders(): Unit {
        let raw =
            "Subject: Very Long\r\n Subject Continuation\r\n" +
            "From: a@b.com\r\n" +
            "\r\n" +
            "Body"
        let m = MimeMessage(makeSession(), StringInputStream(raw))
        let subj = m.getSubject().getOrThrow()
        @Assert(subj.contains("Long"))
        @Assert(subj.contains("Continuation"))
    }

    @TestCase
    func parsesMultipartMixed(): Unit {
        let raw =
            "From: s@x.com\r\n" +
            "Content-Type: multipart/mixed; boundary=\"----b\"\r\n" +
            "\r\n" +
            "------b\r\n" +
            "Content-Type: text/plain\r\n" +
            "\r\n" +
            "Part 1\r\n" +
            "------b\r\n" +
            "Content-Type: text/html\r\n" +
            "\r\n" +
            "<b>Part 2</b>\r\n" +
            "------b--\r\n"
        let m = MimeMessage(makeSession(), StringInputStream(raw))
        @Assert(m.isMultipart())
        @Expect(m.getMultipart().getOrThrow().getCount(), 2)
    }

    @TestCase
    func decodesBase64Body(): Unit {
        let encoded = Base64Util.encodeString("Hello from Base64")
        let raw =
            "From: a@b.com\r\n" +
            "Content-Type: text/plain; charset=UTF-8\r\n" +
            "Content-Transfer-Encoding: base64\r\n" +
            "\r\n" + encoded
        let m = MimeMessage(makeSession(), StringInputStream(raw))
        @Assert(m.getContent().getOrThrow().contains("Hello from Base64"))
    }
}
