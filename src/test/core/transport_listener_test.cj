package mail.test.core

import mail.core.*
import mail.internet.*
import mail.smtp.*
import std.collection.*

// ─── recording listeners ─────────────────────────────────────────────────────

class RecordingTransportListener <: TransportListener {
    public var delivered:  Int64 = 0
    public var failed:     Int64 = 0
    public var partial:    Int64 = 0
    public var lastEvent:  ?TransportEvent = None

    public init() {}

    public func messageDelivered(e: TransportEvent): Unit {
        delivered++; lastEvent = Some(e)
    }
    public func messageNotDelivered(e: TransportEvent): Unit {
        failed++; lastEvent = Some(e)
    }
    public func messagePartiallyDelivered(e: TransportEvent): Unit {
        partial++; lastEvent = Some(e)
    }
}

class RecordingConnectionListener <: ConnectionListener {
    public var openCount:  Int64 = 0
    public var closeCount: Int64 = 0
    public var discCount:  Int64 = 0

    public init() {}

    public func opened(_: ConnectionEvent): Unit       { openCount++ }
    public func closed(_: ConnectionEvent): Unit       { closeCount++ }
    public func disconnected(_: ConnectionEvent): Unit { discCount++ }
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func makeMsg(): MimeMessage {
    let s = Session.getInstance(HashMap<String, String>())
    let m = MimeMessage(s)
    m.setFrom(InternetAddress("a@b.com"))
    m
}

func sent(addrs: Array<String>): Array<Address> {
    let r = ArrayList<Address>()
    for (a in addrs) { r.add(InternetAddress(a)) }
    r.toArray()
}

// ─── TransportEvent ──────────────────────────────────────────────────────────

@Test
public class TransportEventTest {

    @TestCase
    func deliveredEventHasCorrectType(): Unit {
        let e = TransportEvent(TransportEventType.DELIVERED, makeMsg(),
            sent(["ok@x.com"]), Array<Address>(), Array<Address>())
        let ok = match (e.eventType) { case DELIVERED => true; case _ => false }
        @Assert(ok)
        @Expect(e.validSentAddresses.size, 1)
        @Expect(e.invalidAddresses.size, 0)
    }

    @TestCase
    func partiallyDeliveredEventCarriesBothLists(): Unit {
        let e = TransportEvent(TransportEventType.PARTIALLY_DELIVERED, makeMsg(),
            sent(["ok@x.com"]), Array<Address>(), sent(["bad@y.com"]))
        let ok = match (e.eventType) { case PARTIALLY_DELIVERED => true; case _ => false }
        @Assert(ok)
        @Expect(e.validSentAddresses.size, 1)
        @Expect(e.invalidAddresses.size, 1)
    }

    @TestCase
    func notDeliveredEventHasEmptyValidSent(): Unit {
        let e = TransportEvent(TransportEventType.NOT_DELIVERED, makeMsg(),
            Array<Address>(), Array<Address>(), sent(["bad@y.com"]))
        let ok = match (e.eventType) { case NOT_DELIVERED => true; case _ => false }
        @Assert(ok)
        @Assert(e.validSentAddresses.isEmpty())
        @Expect(e.invalidAddresses.size, 1)
    }
}

// ─── ConnectionEvent ─────────────────────────────────────────────────────────

@Test
public class ConnectionEventTest {

    @TestCase
    func openedClosedDisconnectedTypes(): Unit {
        let isOpen = match (ConnectionEvent(ConnectionEventType.OPENED).eventType) {
            case OPENED => true; case _ => false
        }
        let isClosed = match (ConnectionEvent(ConnectionEventType.CLOSED).eventType) {
            case CLOSED => true; case _ => false
        }
        let isDisc = match (ConnectionEvent(ConnectionEventType.DISCONNECTED).eventType) {
            case DISCONNECTED => true; case _ => false
        }
        @Assert(isOpen)
        @Assert(isClosed)
        @Assert(isDisc)
    }
}

// ─── listener callbacks ──────────────────────────────────────────────────────

@Test
public class ListenerCallbackTest {

    @TestCase
    func transportListenerCountsEachEventType(): Unit {
        let l = RecordingTransportListener()
        let msg = makeMsg()
        l.messageDelivered(TransportEvent(
            TransportEventType.DELIVERED, msg, sent(["a@x.com"]), Array<Address>(), Array<Address>()))
        l.messageNotDelivered(TransportEvent(
            TransportEventType.NOT_DELIVERED, msg, Array<Address>(), Array<Address>(), sent(["b@x.com"])))
        l.messagePartiallyDelivered(TransportEvent(
            TransportEventType.PARTIALLY_DELIVERED, msg, sent(["a@x.com"]), Array<Address>(), sent(["b@x.com"])))
        @Expect(l.delivered, 1)
        @Expect(l.failed,    1)
        @Expect(l.partial,   1)
    }

    @TestCase
    func connectionListenerCountsEachEventType(): Unit {
        let l = RecordingConnectionListener()
        l.opened(ConnectionEvent(ConnectionEventType.OPENED))
        l.closed(ConnectionEvent(ConnectionEventType.CLOSED))
        l.disconnected(ConnectionEvent(ConnectionEventType.DISCONNECTED))
        @Expect(l.openCount,  1)
        @Expect(l.closeCount, 1)
        @Expect(l.discCount,  1)
    }

    @TestCase
    func lastEventIsStoredByTransportListener(): Unit {
        let l = RecordingTransportListener()
        let msg = makeMsg()
        @Assert(l.lastEvent.isNone())
        l.messageDelivered(TransportEvent(
            TransportEventType.DELIVERED, msg, sent(["a@x.com"]), Array<Address>(), Array<Address>()))
        @Assert(l.lastEvent.isSome())
    }
}

// ─── registration ────────────────────────────────────────────────────────────

@Test
public class ListenerRegistrationTest {

    @TestCase
    func smtpTransportAcceptsBothListeners(): Unit {
        initSMTPModule()
        let s = Session.getInstance(HashMap<String, String>())
        let t = SMTPTransport(s, false)
        t.addTransportListener(RecordingTransportListener())
        t.addConnectionListener(RecordingConnectionListener())
        @Assert(!t.isConnected())
    }

    @TestCase
    func multipleListenersCanBeRegistered(): Unit {
        initSMTPModule()
        let s = Session.getInstance(HashMap<String, String>())
        let t = SMTPTransport(s, false)
        t.addTransportListener(RecordingTransportListener())
        t.addTransportListener(RecordingTransportListener())
        t.addConnectionListener(RecordingConnectionListener())
        @Assert(true)
    }
}

// ─── offline state ───────────────────────────────────────────────────────────

@Test
public class TransportOfflineTest {

    @TestCase
    func isConnectedFalseWhenNew(): Unit {
        initSMTPModule()
        let s = Session.getInstance(HashMap<String, String>())
        @Assert(!SMTPTransport(s, false).isConnected())
    }

    @TestCase
    func noopReturnsFalseWhenNotConnected(): Unit {
        initSMTPModule()
        let s = Session.getInstance(HashMap<String, String>())
        @Assert(!SMTPTransport(s, false).noop())
    }

    @TestCase
    func resetReturnsFalseWhenNotConnected(): Unit {
        initSMTPModule()
        let s = Session.getInstance(HashMap<String, String>())
        @Assert(!SMTPTransport(s, false).reset())
    }
}
