package mail.test.internet

import mail.internet.*
import std.collection.*

// ─── get/set/add/remove ──────────────────────────────────────────────────────

@Test
public class InternetHeadersBasicTest {

    @TestCase
    func setHeaderReplacesExistingValue(): Unit {
        let h = InternetHeaders()
        h.setHeader("Subject", "first")
        h.setHeader("Subject", "second")
        @Expect(h.getFirstHeader("Subject"), Some("second"))
    }

    @TestCase
    func addHeaderAccumulatesMultipleValues(): Unit {
        let h = InternetHeaders()
        h.addHeader("X-Track", "id-001")
        h.addHeader("X-Track", "id-002")
        let vals = h.getHeader("X-Track")
        @Expect(vals.size, 2)
        @Expect(vals[0], "id-001")
        @Expect(vals[1], "id-002")
    }

    @TestCase
    func getFirstHeaderReturnsFirstAdded(): Unit {
        let h = InternetHeaders()
        h.addHeader("X-H", "v1")
        h.addHeader("X-H", "v2")
        @Expect(h.getFirstHeader("X-H"), Some("v1"))
    }

    @TestCase
    func getMissingHeaderReturnsNone(): Unit {
        @Expect(InternetHeaders().getFirstHeader("X-Missing"), None)
    }

    @TestCase
    func removeHeaderDeletesAllValues(): Unit {
        let h = InternetHeaders()
        h.addHeader("X-H", "v1")
        h.addHeader("X-H", "v2")
        h.removeHeader("X-H")
        @Expect(h.getFirstHeader("X-H"), None)
        @Expect(h.getHeader("X-H").size, 0)
    }

    @TestCase
    func getHeaderWithDelimiterJoinsValues(): Unit {
        let h = InternetHeaders()
        h.addHeader("Accept", "text/plain")
        h.addHeader("Accept", "text/html")
        let joined = h.getHeader("Accept", ",")
        @Assert(joined.isSome())
        @Assert(joined.getOrThrow().contains("text/plain"))
        @Assert(joined.getOrThrow().contains("text/html"))
    }
}

// ─── case-insensitive lookup ─────────────────────────────────────────────────

@Test
public class InternetHeadersCaseTest {

    @TestCase
    func lookupIsCaseInsensitive(): Unit {
        let h = InternetHeaders()
        h.setHeader("Content-Type", "text/plain")
        @Assert(h.getFirstHeader("content-type").isSome())
        @Assert(h.getFirstHeader("CONTENT-TYPE").isSome())
        @Assert(h.getFirstHeader("Content-Type").isSome())
    }

    @TestCase
    func removeIsCaseInsensitive(): Unit {
        let h = InternetHeaders()
        h.setHeader("X-Custom", "value")
        h.removeHeader("x-custom")
        @Expect(h.getFirstHeader("X-Custom"), None)
    }
}

// ─── matching / non-matching ─────────────────────────────────────────────────

@Test
public class InternetHeadersFilterTest {

    @TestCase
    func getMatchingHeadersFindsSubset(): Unit {
        let h = InternetHeaders()
        h.setHeader("Subject", "Test")
        h.setHeader("From", "a@b.com")
        h.setHeader("To", "c@d.com")
        let matched = h.getMatchingHeaders(["subject", "from"])
        @Expect(matched.size, 2)
        var names = ArrayList<String>()
        for (hdr in matched) { names.add(hdr.getName().toAsciiLower()) }
        @Assert(names.contains("subject"))
        @Assert(names.contains("from"))
        @Assert(!names.contains("to"))
    }

    @TestCase
    func getNonMatchingHeadersExcludesNames(): Unit {
        let h = InternetHeaders()
        h.setHeader("Subject", "Test")
        h.setHeader("From", "a@b.com")
        let nonMatched = h.getNonMatchingHeaders(["Subject"])
        for (hdr in nonMatched) {
            @Assert(hdr.getName().toAsciiLower() != "subject")
        }
    }

    @TestCase
    func getMatchingHeadersEmptyFilterReturnsNothing(): Unit {
        let h = InternetHeaders()
        h.setHeader("Subject", "Test")
        @Expect(h.getMatchingHeaders([]).size, 0)
    }
}

// ─── getAllHeaders / toString ─────────────────────────────────────────────────

@Test
public class InternetHeadersSerializeTest {

    @TestCase
    func getAllHeadersReturnsAll(): Unit {
        let h = InternetHeaders()
        h.setHeader("A", "1")
        h.setHeader("B", "2")
        @Expect(h.getAllHeaders().size, 2)
    }

    @TestCase
    func toStringContainsHeaderLines(): Unit {
        let h = InternetHeaders()
        h.setHeader("Subject", "Hello")
        h.setHeader("From", "a@b.com")
        let s = h.toString()
        @Assert(s.contains("Subject: Hello"))
        @Assert(s.contains("From: a@b.com"))
        @Assert(s.contains("\r\n"))
    }

    @TestCase
    func sizeCountsHeaders(): Unit {
        let h = InternetHeaders()
        @Expect(h.size(), 0)
        h.addHeader("X", "1")
        h.addHeader("X", "2")
        @Expect(h.size(), 2)
    }
}
