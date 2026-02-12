/**
 * 数据处理器实现
 */
package mail.activation

import std.io.*

/**
 * 数据处理器
 * 对应：jakarta.activation.DataHandler
 */
public class DataHandler {
    private var _dataSource: ?DataSource = None
    private var _object: ?Object = None
    private var _objectMimeType: ?String = None

    /**
     * 从数据源构造
     */
    public init(dataSource: DataSource) {
        _dataSource = Some(dataSource)
    }

    /**
     * 从对象和 MIME 类型构造
     */
    public init(object: Object, mimeType: String) {
        _object = Some(object)
        _objectMimeType = Some(mimeType)
    }

    /**
     * 获取内容类型
     */
    public func getContentType(): String {
        match (_dataSource) {
            case Some(ds) => ds.getContentType()
            case None =>
                match (_objectMimeType) {
                    case Some(mt) => mt
                    case None => "application/octet-stream"
                }
        }
    }

    /**
     * 获取输入流
     */
    public func getInputStream(): InputStream {
        match (_dataSource) {
            case Some(ds) => ds.getInputStream()
            case None =>
                match (_object) {
                    case Some(obj) =>
                        match (obj) {
                            case s: String => ByteArrayInputStream(s.toArray())
                            case _ => throw Exception("无法为对象类型获取输入流")
                        }
                    case None => throw Exception("没有数据源或对象")
                }
        }
    }

    /**
     * 获取数据源
     */
    public func getDataSource(): DataSource {
        match (_dataSource) {
            case Some(ds) => ds
            case None =>
                // 从对象创建数据源
                match (_object) {
                    case Some(obj) =>
                        let mimeType = match (_objectMimeType) {
                            case Some(mt) => mt
                            case None => "application/octet-stream"
                        }
                        match (obj) {
                            case s: String => ByteArrayDataSource(s, mimeType)
                            case _ => throw Exception("无法为对象类型创建数据源")
                        }
                    case None => throw Exception("没有数据源或对象")
                }
        }
    }

    /**
     * 获取名称
     */
    public func getName(): String {
        match (_dataSource) {
            case Some(ds) => ds.getName()
            case None => ""
        }
    }

    /**
     * 写入输出流
     */
    public func writeTo(output: OutputStream): Unit {
        let input = getInputStream()
        let buffer = Array<Byte>(4096, repeat: 0)

        while (true) {
            let n = input.read(buffer)
            if (n <= 0) {
                break
            }
            // 仅写入已读取的字节
            if (n == buffer.size) {
                output.write(buffer)
            } else {
                var partial = Array<Byte>(n, repeat: 0)
                for (i in 0..n) {
                    partial[i] = buffer[i]
                }
                output.write(partial)
            }
        }

        output.flush()
    }
}
