package mail.test.util

import mail.util.*
import mail.core.*
import std.collection.*

// ─── Mock SMTP session ────────────────────────────────────────────────────────

class MockSession {
    var commands:  ArrayList<String> = ArrayList<String>()
    var responses: ArrayList<String> = ArrayList<String>()
    var codes:     ArrayList<Int64>  = ArrayList<Int64>()
    var idx:       Int64 = 0

    public func push(code: Int64, line: String): Unit {
        responses.add("${code} ${line}")
        codes.add(code)
    }

    public func makeCtx(
        user: String, password: String,
        oauthToken: ?String, domain: String
    ): AuthContext {
        let self = this
        AuthContext(
            user, password, oauthToken, domain, "smtp.example.com", false,
            { cmd => self.commands.add(cmd) },
            { =>
                let r = if (self.idx < self.responses.size) { self.responses[self.idx] } else { "235 OK" }
                self.idx++
                r
            },
            { =>
                let i = self.idx - 1
                if (i >= 0 && i < self.codes.size) { self.codes[i] } else { 235 }
            }
        )
    }
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────

@Test
public class LoginMechanismTest {

    @TestCase
    func successPathSendsCorrectCommands(): Unit {
        let m = MockSession()
        m.push(334, "dXNlcm5hbWU6")
        m.push(334, "UGFzc3dvcmQ6")
        m.push(235, "Authentication successful")
        let ok = LoginMechanism().execute(m.makeCtx("user@example.com", "secret", None, ""))
        @Assert(ok)
        @Expect(m.commands[0], "AUTH LOGIN")
        @Expect(m.commands[1], Base64Util.encodeString("user@example.com"))
        @Expect(m.commands[2], Base64Util.encodeString("secret"))
    }

    @TestCase
    func failureThrowsAuthenticationFailedException(): Unit {
        let m = MockSession()
        m.push(334, "dXNlcm5hbWU6")
        m.push(535, "Authentication failed")
        var threw = false
        try { LoginMechanism().execute(m.makeCtx("u@x.com", "bad", None, "")) }
        catch (_: AuthenticationFailedException) { threw = true }
        @Assert(threw)
    }
}

// ─── PLAIN ────────────────────────────────────────────────────────────────────

@Test
public class PlainMechanismTest {

    @TestCase
    func sendsSingleCommandWithNullSeparatedCredentials(): Unit {
        let m = MockSession()
        m.push(235, "Authentication successful")
        let ok = PlainMechanism().execute(m.makeCtx("user@x.com", "pass123", None, ""))
        @Assert(ok)
        @Expect(m.commands.size, 1)
        @Assert(m.commands[0].startsWith("AUTH PLAIN "))
        let decoded = Base64Util.decodeToString(m.commands[0][11..m.commands[0].size])
        @Assert(decoded.contains("user@x.com"))
        @Assert(decoded.contains("pass123"))
    }

    @TestCase
    func failureThrowsException(): Unit {
        let m = MockSession()
        m.push(535, "5.7.8 Username and Password not accepted")
        var threw = false
        try { PlainMechanism().execute(m.makeCtx("u@x.com", "bad", None, "")) }
        catch (_: AuthenticationFailedException) { threw = true }
        @Assert(threw)
    }
}

// ─── XOAUTH2 ─────────────────────────────────────────────────────────────────

@Test
public class XOAuth2MechanismTest {

    @TestCase
    func bearerTokenInBase64Payload(): Unit {
        let m = MockSession()
        m.push(235, "Authentication successful")
        let ok = XOAuth2Mechanism().execute(
            m.makeCtx("user@gmail.com", "", Some("ya29.token"), ""))
        @Assert(ok)
        @Assert(m.commands[0].startsWith("AUTH XOAUTH2 "))
        let decoded = Base64Util.decodeToString(m.commands[0][13..m.commands[0].size])
        @Assert(decoded.contains("user=user@gmail.com"))
        @Assert(decoded.contains("auth=Bearer ya29.token"))
    }

    @TestCase
    func server334ErrorResponseSendsEmptyReply(): Unit {
        let m = MockSession()
        m.push(334, "eyJzdGF0dXMiOiI0MDEifQ==")
        m.push(535, "5.7.1 Bad credentials")
        var threw = false
        try { XOAuth2Mechanism().execute(m.makeCtx("u@g.com", "", Some("bad"), "")) }
        catch (_: AuthenticationFailedException) { threw = true }
        @Assert(threw)
        @Assert(m.commands.size >= 2)
        @Expect(m.commands[1], "")
    }
}

// ─── NTLM ─────────────────────────────────────────────────────────────────────

@Test
public class NtlmMechanismTest {

    @TestCase
    func type1MessageStartsWithNtlmsspSignature(): Unit {
        let type2 = Array<Byte>(56, repeat: 0u8)
        let sig = [0x4Eu8,0x54u8,0x4Cu8,0x4Du8,0x53u8,0x53u8,0x50u8,0x00u8]
        for (i in 0..8) { type2[i] = sig[i] }
        type2[8] = 2u8
        for (i in 0..8) { type2[24 + i] = UInt8(i + 1) }

        let m = MockSession()
        m.push(334, "")
        m.push(334, Base64Util.encode(type2))
        m.push(235, "Authentication successful")

        let ok = NtlmMechanism().execute(m.makeCtx("user@corp.com", "Password123", None, "CORP"))
        @Assert(ok)
        @Expect(m.commands[0], "AUTH NTLM")
        let type1Bytes = Base64Util.decode(m.commands[1])
        @Assert(type1Bytes.size >= 8)
        for (i in 0..8) { @Expect(type1Bytes[i], sig[i]) }
    }
}

// ─── DIGEST-MD5 ───────────────────────────────────────────────────────────────

@Test
public class DigestMd5MechanismTest {

    @TestCase
    func responseContainsRequiredFields(): Unit {
        let challenge = "realm=\"example.com\",nonce=\"nonce123\",qop=\"auth\",algorithm=md5-sess"
        let m = MockSession()
        m.push(334, Base64Util.encodeString(challenge))
        m.push(235, "Authentication successful")
        let ok = DigestMd5Mechanism().execute(m.makeCtx("user@example.com", "password", None, ""))
        @Assert(ok)
        @Expect(m.commands[0], "AUTH DIGEST-MD5")
        let respDecoded = Base64Util.decodeToString(m.commands[1])
        @Assert(respDecoded.contains("response="))
        @Assert(respDecoded.contains("username="))
        @Assert(respDecoded.contains("nonce="))
    }

    @TestCase
    func responseValueIs32HexChars(): Unit {
        let challenge = "realm=\"test.com\",nonce=\"abc\",qop=\"auth\",algorithm=md5-sess"
        let m = MockSession()
        m.push(334, Base64Util.encodeString(challenge))
        m.push(235, "OK")
        DigestMd5Mechanism().execute(m.makeCtx("u@test.com", "pass", None, ""))
        let decoded = Base64Util.decodeToString(m.commands[1])
        match (decoded.indexOf("response=")) {
            case Some(idx) =>
                let after = decoded[(idx + 9)..decoded.size]
                let hexVal = match (after.indexOf(",")) {
                    case Some(end) => after[0..end]
                    case None      => after
                }
                @Expect(hexVal.size, 32)
            case None => @Assert(false)
        }
    }

    @TestCase
    func rspauth334IsAcknowledgedWithEmptyResponse(): Unit {
        let challenge = "realm=\"r\",nonce=\"n\",qop=\"auth\",algorithm=md5-sess"
        let m = MockSession()
        m.push(334, Base64Util.encodeString(challenge))
        m.push(334, Base64Util.encodeString("rspauth=abc123"))
        m.push(235, "OK")
        let ok = DigestMd5Mechanism().execute(m.makeCtx("u@r.com", "p", None, ""))
        @Assert(ok)
        @Assert(m.commands.size >= 3)
        @Expect(m.commands[2], "")
    }
}

// ─── AuthMechanismSelector ────────────────────────────────────────────────────

@Test
public class AuthMechanismSelectorTest {

    @TestCase
    func xoauth2ChosenWhenTokenAvailableAndServerSupports(): Unit {
        let serverMechs = ArrayList<String>()
        serverMechs.add("LOGIN"); serverMechs.add("PLAIN")
        serverMechs.add("XOAUTH2"); serverMechs.add("NTLM")
        let m = MockSession()
        m.push(235, "OK")
        AuthMechanismSelector.authenticate(serverMechs, None, m.makeCtx("u@g.com", "", Some("token"), ""))
        @Assert(m.commands[0].startsWith("AUTH XOAUTH2"))
    }

    @TestCase
    func customPriorityOverridesDefault(): Unit {
        let serverMechs = ArrayList<String>()
        serverMechs.add("LOGIN"); serverMechs.add("PLAIN"); serverMechs.add("NTLM")
        let m = MockSession()
        m.push(235, "OK")
        AuthMechanismSelector.authenticate(serverMechs, Some("PLAIN LOGIN"), m.makeCtx("u@x.com", "pass", None, ""))
        @Assert(m.commands[0].startsWith("AUTH PLAIN"))
    }

    @TestCase
    func noMatchingMechanismThrowsException(): Unit {
        let serverMechs = ArrayList<String>()
        serverMechs.add("LOGIN")
        let m = MockSession()
        var threw = false
        try {
            AuthMechanismSelector.authenticate(serverMechs, Some("PLAIN"), m.makeCtx("u@x.com", "pass", None, ""))
        } catch (_: AuthenticationFailedException) { threw = true }
        @Assert(threw)
    }

    @TestCase
    func emptyServerMechsTriesAllCandidates(): Unit {
        let serverMechs = ArrayList<String>()
        let m = MockSession()
        m.push(334, "dXNlcm5hbWU6")
        m.push(334, "UGFzc3dvcmQ6")
        m.push(235, "OK")
        let ok = try {
            AuthMechanismSelector.authenticate(serverMechs, Some("LOGIN"), m.makeCtx("u@x.com", "pass", None, ""))
            true
        } catch (_: Exception) { false }
        @Assert(ok)
    }
}
