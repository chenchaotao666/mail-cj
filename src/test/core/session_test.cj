package mail.test.core

import mail.core.*
import mail.smtp.*
import std.collection.*

// ─── helpers ────────────────────────────────────────────────────────────────

func props(pairs: Array<(String, String)>): HashMap<String, String> {
    let m = HashMap<String, String>()
    for ((k, v) in pairs) { m[k] = v }
    m
}

func emptySession(): Session { Session.getInstance(HashMap<String, String>()) }

// ─── property read/write ────────────────────────────────────────────────────

@Test
public class SessionPropertyTest {

    @TestCase
    func getExistingProperty(): Unit {
        let s = Session.getInstance(props([
            ("mail.smtp.host", "smtp.example.com"),
            ("mail.smtp.port", "587")
        ]))
        @Expect(s.getProperty("mail.smtp.host"), Some("smtp.example.com"))
        @Expect(s.getProperty("mail.smtp.port"), Some("587"))
    }

    @TestCase
    func getMissingPropertyReturnsNone(): Unit {
        @Expect(emptySession().getProperty("mail.smtp.nonexist"), None)
    }

    @TestCase
    func getMissingPropertyWithDefaultReturnsDefault(): Unit {
        @Expect(emptySession().getProperty("mail.smtp.nonexist", "fallback"), "fallback")
    }

    @TestCase
    func setPropertyOverridesInitialValue(): Unit {
        let s = Session.getInstance(props([("mail.smtp.port", "25")]))
        s.setProperty("mail.smtp.port", "587")
        @Expect(s.getProperty("mail.smtp.port"), Some("587"))
    }

    @TestCase
    func setPropertyAddsNewKey(): Unit {
        let s = emptySession()
        s.setProperty("mail.smtp.host", "smtp.new.com")
        @Expect(s.getProperty("mail.smtp.host"), Some("smtp.new.com"))
    }

    @TestCase
    func emptyPropsSessionCreatesSuccessfully(): Unit {
        @Assert(emptySession().getProperty("anything").isNone())
    }
}

// ─── debug mode ─────────────────────────────────────────────────────────────

@Test
public class SessionDebugTest {

    @TestCase
    func debugOffByDefault(): Unit {
        @Assert(!emptySession().getDebug())
    }

    @TestCase
    func setDebugTrue(): Unit {
        let s = emptySession()
        s.setDebug(true)
        @Assert(s.getDebug())
    }

    @TestCase
    func setDebugFalseAfterTrue(): Unit {
        let s = emptySession()
        s.setDebug(true)
        s.setDebug(false)
        @Assert(!s.getDebug())
    }
}

// ─── singleton ──────────────────────────────────────────────────────────────

@Test
public class SessionSingletonTest {

    @TestCase
    func getDefaultInstanceReturnsFunctionalSession(): Unit {
        let s1 = Session.getDefaultInstance(props([("mail.smtp.host", "a.com")]))
        let s2 = Session.getDefaultInstance(props([("mail.smtp.host", "a.com")]))
        @Assert(s1.getProperty("mail.smtp.host").isSome())
        @Assert(s2.getProperty("mail.smtp.host").isSome())
    }
}

// ─── transport factory ──────────────────────────────────────────────────────

@Test
public class SessionTransportTest {

    @TestCase
    func getTransportReturnsInstance(): Unit {
        initSMTPModule()
        let s = Session.getInstance(props([("mail.smtp.host", "smtp.example.com")]))
        let t = s.getTransport()
        @Assert(!t.isConnected())
    }

    @TestCase
    func getTransportByProtocol(): Unit {
        initSMTPModule()
        let s = emptySession()
        let t = s.getTransport("smtp")
        @Assert(!t.isConnected())
    }

    @TestCase
    func getTransportUnknownProtocolThrows(): Unit {
        let s = emptySession()
        var threw = false
        try {
            s.getTransport("nonexistent-protocol")
        } catch (_: MessagingException) {
            threw = true
        }
        @Assert(threw)
    }

    @TestCase
    func getTransportWithAuthenticator(): Unit {
        initSMTPModule()
        let auth = SimpleAuthenticator("user@example.com", "secret")
        let s = Session.getInstance(HashMap<String, String>(), auth)
        @Assert(s.getAuthenticator().isSome())
    }
}
