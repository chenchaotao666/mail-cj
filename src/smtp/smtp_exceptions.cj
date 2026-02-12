/**
 * SMTP 特定异常
 */
package mail.smtp

import mail.core.*
import mail.internet.*

/**
 * SMTP 发送失败异常
 * 对应：org.eclipse.angus.mail.smtp.SMTPSendFailedException
 */
public class SMTPSendFailedException <: SendFailedException {
    private let _command: String
    private let _returnCode: Int64

    public init(
        command: String,
        returnCode: Int64,
        message: String,
        validSent: Array<Address>,
        validUnsent: Array<Address>,
        invalid: Array<Address>
    ) {
        super(message, validSent, validUnsent, invalid)
        _command = command
        _returnCode = returnCode
    }

    public func getCommand(): String {
        _command
    }

    public func getReturnCode(): Int64 {
        _returnCode
    }
}

/**
 * SMTP 地址失败异常
 * 对应：org.eclipse.angus.mail.smtp.SMTPAddressFailedException
 */
public class SMTPAddressFailedException <: SendFailedException {
    private let _address: InternetAddress
    private let _command: String
    private let _returnCode: Int64

    public init(
        address: InternetAddress,
        command: String,
        returnCode: Int64,
        message: String
    ) {
        super(message)
        _address = address
        _command = command
        _returnCode = returnCode
    }

    public func getAddress(): InternetAddress {
        _address
    }

    public func getCommand(): String {
        _command
    }

    public func getReturnCode(): Int64 {
        _returnCode
    }
}

/**
 * SMTP 发件人失败异常
 * 对应：org.eclipse.angus.mail.smtp.SMTPSenderFailedException
 */
public class SMTPSenderFailedException <: SendFailedException {
    private let _address: InternetAddress
    private let _command: String
    private let _returnCode: Int64

    public init(
        address: InternetAddress,
        command: String,
        returnCode: Int64,
        message: String
    ) {
        super(message)
        _address = address
        _command = command
        _returnCode = returnCode
    }

    public func getAddress(): InternetAddress {
        _address
    }

    public func getCommand(): String {
        _command
    }

    public func getReturnCode(): Int64 {
        _returnCode
    }
}
