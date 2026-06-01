/**
 * Transport 和 Connection 事件监听器
 * 对应：jakarta.mail.event.*
 */
package mail.core


// ─────────────────────────────────────────────────────────────────────────────
// Transport 事件
// ─────────────────────────────────────────────────────────────────────────────

public enum TransportEventType {
    | DELIVERED
    | NOT_DELIVERED
    | PARTIALLY_DELIVERED
}

public class TransportEvent {
    public let eventType: TransportEventType
    public let message: Message
    public let validSentAddresses: Array<Address>
    public let validUnsentAddresses: Array<Address>
    public let invalidAddresses: Array<Address>

    public init(
        eventType: TransportEventType,
        message: Message,
        validSent: Array<Address>,
        validUnsent: Array<Address>,
        invalid: Array<Address>
    ) {
        this.eventType           = eventType
        this.message             = message
        this.validSentAddresses   = validSent
        this.validUnsentAddresses = validUnsent
        this.invalidAddresses    = invalid
    }
}

public interface TransportListener {
    func messageDelivered(e: TransportEvent): Unit
    func messageNotDelivered(e: TransportEvent): Unit
    func messagePartiallyDelivered(e: TransportEvent): Unit
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection 事件
// ─────────────────────────────────────────────────────────────────────────────

public enum ConnectionEventType {
    | OPENED
    | CLOSED
    | DISCONNECTED
}

public class ConnectionEvent {
    public let eventType: ConnectionEventType

    public init(eventType: ConnectionEventType) {
        this.eventType = eventType
    }
}

public interface ConnectionListener {
    func opened(e: ConnectionEvent): Unit
    func closed(e: ConnectionEvent): Unit
    func disconnected(e: ConnectionEvent): Unit
}
