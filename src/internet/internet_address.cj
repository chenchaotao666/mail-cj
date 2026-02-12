/**
 * RFC 822 互联网邮件地址实现
 */
package mail.internet

import mail.core.*
import std.collection.*

/**
 * RFC 822 地址实现
 * 对应：jakarta.mail.internet.InternetAddress
 */
public class InternetAddress <: Address {
    private var _address: String = ""       // 邮件地址（user@domain）
    private var _personal: ?String = None   // 个人名称
    private var _charset: String = "UTF-8"  // 字符编码

    /**
     * 默认构造函数
     */
    public init() {}

    /**
     * 使用邮件地址构造
     */
    public init(address: String) {
        _address = address
    }

    /**
     * 使用邮件地址和个人名称构造
     */
    public init(address: String, personal: String) {
        _address = address
        _personal = if (personal.isEmpty()) { None } else { Some(personal) }
    }

    /**
     * 使用邮件地址、个人名称和字符集构造
     */
    public init(address: String, personal: String, charset: String) {
        _address = address
        _personal = if (personal.isEmpty()) { None } else { Some(personal) }
        _charset = charset
    }

    /**
     * 解析逗号分隔的地址列表
     */
    public static func parse(addressList: String, strict!: Bool = true): Array<Address> {
        let result = ArrayList<Address>()

        if (addressList.isEmpty()) {
            return result.toArray()
        }

        // 简单解析：按逗号分隔并处理每个地址
        var current = ""
        var inQuotes = false
        var inAngleBracket = false

        for (ch in addressList.toRuneArray()) {
            match (ch) {
                case r'"' =>
                    inQuotes = !inQuotes
                    current += ch.toString()
                case r'<' =>
                    inAngleBracket = true
                    current += ch.toString()
                case r'>' =>
                    inAngleBracket = false
                    current += ch.toString()
                case r',' where !inQuotes && !inAngleBracket =>
                    let trimmed = current.trimAscii()
                    if (!trimmed.isEmpty()) {
                        result.add(parseAddress(trimmed, strict))
                    }
                    current = ""
                case _ =>
                    current += ch.toString()
            }
        }

        // 处理最后一个地址
        let trimmed = current.trimAscii()
        if (!trimmed.isEmpty()) {
            result.add(parseAddress(trimmed, strict))
        }

        result.toArray()
    }

    /**
     * 解析单个地址
     */
    private static func parseAddress(addr: String, strict: Bool): InternetAddress {
        let address = addr.trimAscii()

        // 检查格式："Personal Name" <email@domain>
        match (address.indexOf("<")) {
            case Some(angleBracketStart) =>
                match (address.indexOf(">")) {
                    case Some(angleBracketEnd) where angleBracketEnd > angleBracketStart =>
                        let email = address[(angleBracketStart + 1)..angleBracketEnd].trimAscii()
                        var personal = address[0..angleBracketStart].trimAscii()

                        // 移除个人名称两侧的引号
                        if (personal.size >= 2 && personal.startsWith("\"") && personal.endsWith("\"")) {
                            personal = personal[1..(personal.size - 1)]
                        }

                        if (personal.isEmpty()) {
                            return InternetAddress(email)
                        } else {
                            return InternetAddress(email, personal)
                        }
                    case _ => ()
                }
            case None => ()
        }

        // 简单邮件地址
        InternetAddress(address)
    }

    /**
     * 获取邮件地址
     */
    public func getAddress(): String {
        _address
    }

    /**
     * 设置邮件地址
     */
    public func setAddress(address: String): Unit {
        _address = address
    }

    /**
     * 获取个人名称
     */
    public func getPersonal(): ?String {
        _personal
    }

    /**
     * 设置个人名称
     */
    public func setPersonal(name: String): Unit {
        _personal = if (name.isEmpty()) { None } else { Some(name) }
    }

    /**
     * 设置个人名称（指定字符集）
     */
    public func setPersonal(name: String, charset: String): Unit {
        _personal = if (name.isEmpty()) { None } else { Some(name) }
        _charset = charset
    }

    /**
     * 验证地址格式
     * 如果无效则抛出 AddressException
     */
    public func validate(): Unit {
        if (_address.isEmpty()) {
            throw AddressException("空地址", _address)
        }

        let atIndex = match (_address.indexOf("@")) {
            case Some(idx) => idx
            case None => throw AddressException("地址中缺少 '@'", _address)
        }

        if (atIndex == 0) {
            throw AddressException("'@' 之前缺少本地部分", _address, 0)
        }

        if (atIndex == _address.size - 1) {
            throw AddressException("'@' 之后缺少域名", _address, atIndex)
        }

        // 检查无效字符
        let domain = _address[(atIndex + 1).._address.size]

        match (domain.indexOf(".")) {
            case None => throw AddressException("域名必须包含至少一个 '.'", _address, atIndex + 1)
            case _ => ()
        }
    }

    /**
     * 获取地址类型
     */
    public override func getType(): String {
        "rfc822"
    }

    /**
     * 获取 RFC 822 格式字符串
     * 格式："Personal Name" <user@domain>
     */
    public override func toString(): String {
        match (_personal) {
            case Some(name) =>
                // 检查名称是否需要引用
                var needsQuoting = false
                for (ch in name.toRuneArray()) {
                    if (ch == r'"' || ch == r',' || ch == r'<' || ch == r'>' || ch == r'@') {
                        needsQuoting = true
                        break
                    }
                }

                if (needsQuoting) {
                    // 转义名称中的引号
                    var escaped = ""
                    for (ch in name.toRuneArray()) {
                        if (ch == r'"') {
                            escaped += "\\\""
                        } else {
                            escaped += ch.toString()
                        }
                    }
                    "\"${escaped}\" <${_address}>"
                } else {
                    "${name} <${_address}>"
                }
            case None =>
                _address
        }
    }

    /**
     * 获取 Unicode 字符串（不编码）
     */
    public func toUnicodeString(): String {
        toString()
    }
}
