/**
 * 互联网邮件头管理
 */
package mail.internet

import std.collection.*

/**
 * 头名称-值对
 */
public class Header {
    private let _name: String
    private let _value: String

    public init(name: String, value: String) {
        _name = name
        _value = value
    }

    public func getName(): String {
        _name
    }

    public func getValue(): String {
        _value
    }
}

/**
 * 互联网邮件头
 * 对应：jakarta.mail.internet.InternetHeaders
 */
public class InternetHeaders {
    private var _headers: ArrayList<Header> = ArrayList<Header>()

    public init() {}

    /**
     * 获取指定头的所有值
     */
    public func getHeader(name: String): Array<String> {
        let result = ArrayList<String>()
        let lowerName = name.toAsciiLower()
        for (h in _headers) {
            if (h.getName().toAsciiLower() == lowerName) {
                result.add(h.getValue())
            }
        }
        result.toArray()
    }

    /**
     * 获取指定头的第一个值
     */
    public func getFirstHeader(name: String): ?String {
        let lowerName = name.toAsciiLower()
        for (h in _headers) {
            if (h.getName().toAsciiLower() == lowerName) {
                return Some(h.getValue())
            }
        }
        None
    }

    /**
     * 获取头值（多个值使用分隔符连接）
     */
    public func getHeader(name: String, delimiter: String): ?String {
        let values = getHeader(name)
        if (values.isEmpty()) {
            return None
        }

        var result = ""
        for (i in 0..values.size) {
            if (i > 0) {
                result += delimiter
            }
            result += values[i]
        }
        Some(result)
    }

    /**
     * 设置头值（替换所有现有值）
     */
    public func setHeader(name: String, value: String): Unit {
        removeHeader(name)
        addHeader(name, value)
    }

    /**
     * 添加头值
     */
    public func addHeader(name: String, value: String): Unit {
        _headers.add(Header(name, value))
    }

    /**
     * 删除指定头的所有值
     */
    public func removeHeader(name: String): Unit {
        let lowerName = name.toAsciiLower()
        let newHeaders = ArrayList<Header>()
        for (h in _headers) {
            if (h.getName().toAsciiLower() != lowerName) {
                newHeaders.add(h)
            }
        }
        _headers = newHeaders
    }

    /**
     * 获取所有头
     */
    public func getAllHeaders(): ArrayList<Header> {
        _headers
    }

    /**
     * 获取头数量
     */
    public func size(): Int64 {
        _headers.size
    }

    /**
     * 将头写入字符串
     */
    public func toString(): String {
        var result = ""
        for (h in _headers) {
            result += "${h.getName()}: ${h.getValue()}\r\n"
        }
        result
    }
}
