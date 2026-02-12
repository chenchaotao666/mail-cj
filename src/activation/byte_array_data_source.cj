/**
 * 字节数组数据源实现
 */
package mail.activation

import std.io.*
import std.collection.*
import mail.core.*

/**
 * 内存字节数组输入流
 */
public class ByteArrayInputStream <: InputStream {
    private let _data: Array<Byte>
    private var _position: Int64 = 0

    public init(data: Array<Byte>) {
        _data = data
    }

    public func read(buffer: Array<Byte>): Int64 {
        if (_position >= _data.size) {
            return 0
        }

        let remaining = _data.size - _position
        let toRead = if (buffer.size < remaining) { buffer.size } else { remaining }

        for (i in 0..toRead) {
            buffer[i] = _data[_position + i]
        }
        _position += toRead

        toRead
    }
}

/**
 * 内存字节数组输出流
 */
public class ByteArrayOutputStream <: OutputStream {
    private var _data: ArrayList<Byte> = ArrayList<Byte>()

    public init() {}

    public init(initialCapacity: Int64) {
        _data = ArrayList<Byte>(initialCapacity)
    }

    public func write(buffer: Array<Byte>): Unit {
        for (b in buffer) {
            _data.add(b)
        }
    }

    /**
     * 获取所有已写入的数据
     */
    public func toArray(): Array<Byte> {
        _data.toArray()
    }

    /**
     * 获取当前大小
     */
    public func size(): Int64 {
        _data.size
    }

    /**
     * 重置输出流
     */
    public func reset(): Unit {
        _data.clear()
    }

    /**
     * 转换为字符串（UTF-8）
     */
    public func toString(): String {
        String.fromUtf8(_data.toArray())
    }
}

/**
 * 字节数组数据源
 * 对应：jakarta.mail.util.ByteArrayDataSource
 */
public class ByteArrayDataSource <: DataSource {
    private let _data: Array<Byte>
    private let _contentType: String
    private var _name: String = ""

    /**
     * 从字节数组构造
     */
    public init(data: Array<Byte>, contentType: String) {
        _data = data
        _contentType = contentType
    }

    /**
     * 从字符串构造
     */
    public init(data: String, contentType: String) {
        _data = data.toArray()
        _contentType = contentType
    }

    public func getInputStream(): InputStream {
        ByteArrayInputStream(_data)
    }

    public func getOutputStream(): OutputStream {
        throw MessagingException("ByteArrayDataSource does not support output")
    }

    public func getContentType(): String {
        _contentType
    }

    public func getName(): String {
        _name
    }

    public func setName(name: String): Unit {
        _name = name
    }

    /**
     * 获取数据大小
     */
    public func getSize(): Int64 {
        _data.size
    }

    /**
     * 获取数据副本
     */
    public func getData(): Array<Byte> {
        _data
    }
}

/**
 * 创建文本数据源
 */
public func createTextDataSource(text: String, name!: String = "text.txt"): ByteArrayDataSource {
    let ds = ByteArrayDataSource(text, "text/plain; charset=UTF-8")
    ds.setName(name)
    ds
}

/**
 * 创建 HTML 数据源
 */
public func createHtmlDataSource(html: String, name!: String = "content.html"): ByteArrayDataSource {
    let ds = ByteArrayDataSource(html, "text/html; charset=UTF-8")
    ds.setName(name)
    ds
}

/**
 * 创建 JSON 数据源
 */
public func createJsonDataSource(json: String, name!: String = "data.json"): ByteArrayDataSource {
    let ds = ByteArrayDataSource(json, "application/json; charset=UTF-8")
    ds.setName(name)
    ds
}

/**
 * 创建二进制数据源
 */
public func createBinaryDataSource(data: Array<Byte>, contentType: String, name: String): ByteArrayDataSource {
    let ds = ByteArrayDataSource(data, contentType)
    ds.setName(name)
    ds
}

/**
 * 创建图片数据源
 */
public func createImageDataSource(data: Array<Byte>, imageType: String, name: String): ByteArrayDataSource {
    let contentType = match (imageType.toAsciiLower()) {
        case "png" => "image/png"
        case "jpg" | "jpeg" => "image/jpeg"
        case "gif" => "image/gif"
        case "bmp" => "image/bmp"
        case "webp" => "image/webp"
        case "svg" => "image/svg+xml"
        case _ => "application/octet-stream"
    }
    let ds = ByteArrayDataSource(data, contentType)
    ds.setName(name)
    ds
}
