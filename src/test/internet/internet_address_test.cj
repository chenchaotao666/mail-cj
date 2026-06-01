package mail.test.internet

import mail.internet.*
import mail.core.*
import std.collection.*

// ─── helpers ─────────────────────────────────────────────────────────────────

func firstAddr(list: Array<Address>): InternetAddress {
    match (list[0]) {
        case ia: InternetAddress => ia
        case _ => throw Exception("Expected InternetAddress")
    }
}

// ─── construction ────────────────────────────────────────────────────────────

@Test
public class InternetAddressConstructionTest {

    @TestCase
    func addressOnlyConstructor(): Unit {
        let a = InternetAddress("user@example.com")
        @Expect(a.getAddress(), "user@example.com")
        @Expect(a.getPersonal(), None)
    }

    @TestCase
    func addressWithAsciiPersonal(): Unit {
        let a = InternetAddress("user@example.com", "John Smith")
        @Expect(a.getAddress(), "user@example.com")
        @Expect(a.getPersonal(), Some("John Smith"))
    }

    @TestCase
    func addressWithChinesePersonal(): Unit {
        let a = InternetAddress("user@example.com", "张三")
        @Expect(a.getAddress(), "user@example.com")
        @Expect(a.getPersonal(), Some("张三"))
    }

    @TestCase
    func addressWithCharsetConstructor(): Unit {
        let a = InternetAddress("user@example.com", "Alice", "UTF-8")
        @Expect(a.getAddress(), "user@example.com")
        @Expect(a.getPersonal(), Some("Alice"))
    }

    @TestCase
    func defaultConstructorIsEmpty(): Unit {
        let a = InternetAddress()
        @Expect(a.getAddress(), "")
        @Expect(a.getPersonal(), None)
    }
}

// ─── toString ────────────────────────────────────────────────────────────────

@Test
public class InternetAddressToStringTest {

    @TestCase
    func asciiPersonalProducesNameAndAngle(): Unit {
        let s = InternetAddress("user@example.com", "John Smith").toString()
        @Assert(s.contains("John Smith"))
        @Assert(s.contains("user@example.com"))
    }

    @TestCase
    func noPersonalProducesAddressOnly(): Unit {
        let s = InternetAddress("user@example.com").toString()
        @Expect(s, "user@example.com")
    }

    @TestCase
    func personalWithCommaIsQuoted(): Unit {
        let s = InternetAddress("user@example.com", "Smith, John").toString()
        @Assert(s.contains("\""))
        @Assert(s.contains("Smith, John"))
    }

    @TestCase
    func nonAsciiPersonalIsRfc2047Encoded(): Unit {
        let s = InternetAddress("user@example.com", "张三").toString()
        @Assert(s.startsWith("=?UTF-8?B?") || s.startsWith("=?utf-8?b?"))
        @Assert(s.contains("user@example.com"))
    }

    @TestCase
    func rfc2047EncodedPersonalCanBeDecoded(): Unit {
        let encoded = InternetAddress("u@x.com", "日本語").toString()
        let decoded = MimeUtility.decodeText(
            encoded[0..match (encoded.indexOf("<")) {
                case Some(i) => if (i > 0) { i - 1 } else { 0 }
                case None    => encoded.size
            }].trimAscii()
        )
        @Assert(decoded.contains("日本語"))
    }
}

// ─── parsing ─────────────────────────────────────────────────────────────────

@Test
public class InternetAddressParseTest {

    @TestCase
    func parseSingleAddress(): Unit {
        let list = InternetAddress.parse("user@example.com")
        @Expect(list.size, 1)
        @Expect(firstAddr(list).getAddress(), "user@example.com")
    }

    @TestCase
    func parseMultipleCommaDelimited(): Unit {
        let list = InternetAddress.parse("a@x.com, b@y.com, c@z.com")
        @Expect(list.size, 3)
    }

    @TestCase
    func parseQuotedNameAngleBracket(): Unit {
        let list = InternetAddress.parse("\"Alice\" <alice@example.com>")
        @Expect(list.size, 1)
        @Expect(firstAddr(list).getAddress(), "alice@example.com")
    }

    @TestCase
    func parseUnquotedNameAngleBracket(): Unit {
        let list = InternetAddress.parse("Bob <bob@example.com>")
        @Expect(list.size, 1)
        @Expect(firstAddr(list).getAddress(), "bob@example.com")
    }

    @TestCase
    func parseEmptyStringReturnsEmpty(): Unit {
        @Expect(InternetAddress.parse("").size, 0)
    }

    @TestCase
    func parseTrimsLeadingTrailingWhitespace(): Unit {
        let list = InternetAddress.parse("  user@example.com  ")
        @Expect(list.size, 1)
        @Expect(firstAddr(list).getAddress(), "user@example.com")
    }

    @TestCase
    func parseAddressWithDisplayName(): Unit {
        let list = InternetAddress.parse("user@example.com (John Doe)")
        @Expect(list.size, 1)
        @Assert(firstAddr(list).getAddress().contains("user@example.com"))
    }
}

// ─── validation ──────────────────────────────────────────────────────────────

@Test
public class InternetAddressValidateTest {

    @TestCase
    func validAddressDoesNotThrow(): Unit {
        InternetAddress("user@example.com").validate()
        @Assert(true)
    }

    @TestCase
    func missingAtSignThrowsAddressException(): Unit {
        var threw = false
        try {
            InternetAddress("invalid-email").validate()
        } catch (_: AddressException) {
            threw = true
        }
        @Assert(threw)
    }

    @TestCase
    func missingDomainThrowsAddressException(): Unit {
        var threw = false
        try {
            InternetAddress("user@").validate()
        } catch (_: AddressException) {
            threw = true
        }
        @Assert(threw)
    }

    @TestCase
    func emptyStringThrowsAddressException(): Unit {
        var threw = false
        try {
            InternetAddress("").validate()
        } catch (_: AddressException) {
            threw = true
        }
        @Assert(threw)
    }
}

// ─── equality ────────────────────────────────────────────────────────────────

@Test
public class InternetAddressEqualityTest {

    @TestCase
    func sameAddressAndPersonalAreEqual(): Unit {
        let a1 = InternetAddress("user@example.com", "John")
        let a2 = InternetAddress("user@example.com", "John")
        @Assert(a1 == a2)
    }

    @TestCase
    func differentAddressIsNotEqual(): Unit {
        let a1 = InternetAddress("a@x.com")
        let a2 = InternetAddress("b@x.com")
        @Assert(a1 != a2)
    }
}

// ─── getLocalAddress ─────────────────────────────────────────────────────────

@Test
public class InternetAddressLocalTest {

    @TestCase
    func getLocalAddressUsesSessionProps(): Unit {
        let m = HashMap<String, String>()
        m["mail.smtp.localhost"] = "myhost.example.com"
        m["mail.smtp.user"]      = "myuser"
        let s = Session.getInstance(m)
        let a = InternetAddress.getLocalAddress(s)
        @Assert(a.getAddress().contains("myuser"))
    }
}
