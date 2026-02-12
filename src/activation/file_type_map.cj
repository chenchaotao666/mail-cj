/**
 * 文件类型映射
 * 根据文件扩展名获取 MIME 类型
 */
package mail.activation

import std.collection.*

/**
 * 文件类型映射
 * 对应：jakarta.activation.FileTypeMap
 */
public class FileTypeMap {
    private static let _defaultMap: FileTypeMap = FileTypeMap()
    private let _mimeTypes: HashMap<String, String> = HashMap<String, String>()

    /**
     * 私有构造函数
     */
    private init() {
        registerDefaults()
    }

    /**
     * 注册默认 MIME 类型映射
     */
    private func registerDefaults(): Unit {
        // ========== 文本文档 ==========
        _mimeTypes["txt"] = "text/plain"
        _mimeTypes["text"] = "text/plain"
        _mimeTypes["log"] = "text/plain"
        _mimeTypes["md"] = "text/markdown"
        _mimeTypes["markdown"] = "text/markdown"
        _mimeTypes["csv"] = "text/csv"
        _mimeTypes["tsv"] = "text/tab-separated-values"

        // ========== Web 相关 ==========
        _mimeTypes["html"] = "text/html"
        _mimeTypes["htm"] = "text/html"
        _mimeTypes["xhtml"] = "application/xhtml+xml"
        _mimeTypes["css"] = "text/css"
        _mimeTypes["js"] = "application/javascript"
        _mimeTypes["mjs"] = "application/javascript"
        _mimeTypes["json"] = "application/json"
        _mimeTypes["xml"] = "application/xml"
        _mimeTypes["xsl"] = "application/xml"
        _mimeTypes["xslt"] = "application/xslt+xml"
        _mimeTypes["rss"] = "application/rss+xml"
        _mimeTypes["atom"] = "application/atom+xml"
        _mimeTypes["wasm"] = "application/wasm"

        // ========== 办公文档 ==========
        // PDF
        _mimeTypes["pdf"] = "application/pdf"

        // Microsoft Office (旧格式)
        _mimeTypes["doc"] = "application/msword"
        _mimeTypes["dot"] = "application/msword"
        _mimeTypes["xls"] = "application/vnd.ms-excel"
        _mimeTypes["xlt"] = "application/vnd.ms-excel"
        _mimeTypes["ppt"] = "application/vnd.ms-powerpoint"
        _mimeTypes["pot"] = "application/vnd.ms-powerpoint"
        _mimeTypes["pps"] = "application/vnd.ms-powerpoint"

        // Microsoft Office (新格式 OOXML)
        _mimeTypes["docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        _mimeTypes["dotx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
        _mimeTypes["xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        _mimeTypes["xltx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
        _mimeTypes["pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        _mimeTypes["potx"] = "application/vnd.openxmlformats-officedocument.presentationml.template"
        _mimeTypes["ppsx"] = "application/vnd.openxmlformats-officedocument.presentationml.slideshow"

        // OpenDocument
        _mimeTypes["odt"] = "application/vnd.oasis.opendocument.text"
        _mimeTypes["ods"] = "application/vnd.oasis.opendocument.spreadsheet"
        _mimeTypes["odp"] = "application/vnd.oasis.opendocument.presentation"
        _mimeTypes["odg"] = "application/vnd.oasis.opendocument.graphics"

        // WPS Office
        _mimeTypes["wps"] = "application/vnd.ms-works"
        _mimeTypes["et"] = "application/vnd.ms-excel"
        _mimeTypes["dps"] = "application/vnd.ms-powerpoint"

        // ========== 图片 ==========
        _mimeTypes["jpg"] = "image/jpeg"
        _mimeTypes["jpeg"] = "image/jpeg"
        _mimeTypes["jpe"] = "image/jpeg"
        _mimeTypes["png"] = "image/png"
        _mimeTypes["gif"] = "image/gif"
        _mimeTypes["bmp"] = "image/bmp"
        _mimeTypes["webp"] = "image/webp"
        _mimeTypes["svg"] = "image/svg+xml"
        _mimeTypes["svgz"] = "image/svg+xml"
        _mimeTypes["ico"] = "image/x-icon"
        _mimeTypes["tif"] = "image/tiff"
        _mimeTypes["tiff"] = "image/tiff"
        _mimeTypes["psd"] = "image/vnd.adobe.photoshop"
        _mimeTypes["ai"] = "application/postscript"
        _mimeTypes["eps"] = "application/postscript"
        _mimeTypes["raw"] = "image/raw"
        _mimeTypes["heic"] = "image/heic"
        _mimeTypes["heif"] = "image/heif"
        _mimeTypes["avif"] = "image/avif"

        // ========== 音频 ==========
        _mimeTypes["mp3"] = "audio/mpeg"
        _mimeTypes["wav"] = "audio/wav"
        _mimeTypes["wave"] = "audio/wav"
        _mimeTypes["ogg"] = "audio/ogg"
        _mimeTypes["oga"] = "audio/ogg"
        _mimeTypes["flac"] = "audio/flac"
        _mimeTypes["aac"] = "audio/aac"
        _mimeTypes["m4a"] = "audio/mp4"
        _mimeTypes["wma"] = "audio/x-ms-wma"
        _mimeTypes["mid"] = "audio/midi"
        _mimeTypes["midi"] = "audio/midi"
        _mimeTypes["opus"] = "audio/opus"

        // ========== 视频 ==========
        _mimeTypes["mp4"] = "video/mp4"
        _mimeTypes["m4v"] = "video/mp4"
        _mimeTypes["avi"] = "video/x-msvideo"
        _mimeTypes["mov"] = "video/quicktime"
        _mimeTypes["qt"] = "video/quicktime"
        _mimeTypes["wmv"] = "video/x-ms-wmv"
        _mimeTypes["flv"] = "video/x-flv"
        _mimeTypes["mkv"] = "video/x-matroska"
        _mimeTypes["webm"] = "video/webm"
        _mimeTypes["ogv"] = "video/ogg"
        _mimeTypes["3gp"] = "video/3gpp"
        _mimeTypes["3g2"] = "video/3gpp2"
        _mimeTypes["ts"] = "video/mp2t"
        _mimeTypes["m3u8"] = "application/vnd.apple.mpegurl"
        _mimeTypes["mpg"] = "video/mpeg"
        _mimeTypes["mpeg"] = "video/mpeg"

        // ========== 压缩包 ==========
        _mimeTypes["zip"] = "application/zip"
        _mimeTypes["rar"] = "application/vnd.rar"
        _mimeTypes["7z"] = "application/x-7z-compressed"
        _mimeTypes["tar"] = "application/x-tar"
        _mimeTypes["gz"] = "application/gzip"
        _mimeTypes["gzip"] = "application/gzip"
        _mimeTypes["bz2"] = "application/x-bzip2"
        _mimeTypes["xz"] = "application/x-xz"
        _mimeTypes["lz"] = "application/x-lzip"
        _mimeTypes["lzma"] = "application/x-lzma"
        _mimeTypes["tgz"] = "application/gzip"
        _mimeTypes["tbz2"] = "application/x-bzip2"

        // ========== 可执行文件和安装包 ==========
        _mimeTypes["exe"] = "application/x-msdownload"
        _mimeTypes["msi"] = "application/x-msdownload"
        _mimeTypes["dmg"] = "application/x-apple-diskimage"
        _mimeTypes["pkg"] = "application/x-newton-compatible-pkg"
        _mimeTypes["deb"] = "application/vnd.debian.binary-package"
        _mimeTypes["rpm"] = "application/x-rpm"
        _mimeTypes["apk"] = "application/vnd.android.package-archive"
        _mimeTypes["ipa"] = "application/x-itunes-ipa"
        _mimeTypes["jar"] = "application/java-archive"
        _mimeTypes["war"] = "application/java-archive"
        _mimeTypes["ear"] = "application/java-archive"

        // ========== 编程/开发相关 ==========
        _mimeTypes["java"] = "text/x-java-source"
        _mimeTypes["class"] = "application/java-vm"
        _mimeTypes["py"] = "text/x-python"
        _mimeTypes["pyc"] = "application/x-python-code"
        _mimeTypes["rb"] = "text/x-ruby"
        _mimeTypes["php"] = "application/x-httpd-php"
        _mimeTypes["c"] = "text/x-c"
        _mimeTypes["cpp"] = "text/x-c++src"
        _mimeTypes["cxx"] = "text/x-c++src"
        _mimeTypes["cc"] = "text/x-c++src"
        _mimeTypes["h"] = "text/x-c"
        _mimeTypes["hpp"] = "text/x-c++hdr"
        _mimeTypes["hxx"] = "text/x-c++hdr"
        _mimeTypes["cs"] = "text/x-csharp"
        _mimeTypes["go"] = "text/x-go"
        _mimeTypes["rs"] = "text/x-rust"
        _mimeTypes["swift"] = "text/x-swift"
        _mimeTypes["kt"] = "text/x-kotlin"
        _mimeTypes["scala"] = "text/x-scala"
        _mimeTypes["ts"] = "application/typescript"
        _mimeTypes["tsx"] = "application/typescript"
        _mimeTypes["jsx"] = "text/jsx"
        _mimeTypes["vue"] = "text/x-vue"
        _mimeTypes["sh"] = "application/x-sh"
        _mimeTypes["bash"] = "application/x-sh"
        _mimeTypes["zsh"] = "application/x-sh"
        _mimeTypes["bat"] = "application/x-msdos-program"
        _mimeTypes["cmd"] = "application/x-msdos-program"
        _mimeTypes["ps1"] = "application/x-powershell"
        _mimeTypes["sql"] = "application/sql"
        _mimeTypes["yaml"] = "application/x-yaml"
        _mimeTypes["yml"] = "application/x-yaml"
        _mimeTypes["toml"] = "application/toml"
        _mimeTypes["ini"] = "text/plain"
        _mimeTypes["cfg"] = "text/plain"
        _mimeTypes["conf"] = "text/plain"

        // 仓颉语言
        _mimeTypes["cj"] = "text/x-cangjie"

        // ========== 字体 ==========
        _mimeTypes["ttf"] = "font/ttf"
        _mimeTypes["otf"] = "font/otf"
        _mimeTypes["woff"] = "font/woff"
        _mimeTypes["woff2"] = "font/woff2"
        _mimeTypes["eot"] = "application/vnd.ms-fontobject"

        // ========== 电子书 ==========
        _mimeTypes["epub"] = "application/epub+zip"
        _mimeTypes["mobi"] = "application/x-mobipocket-ebook"
        _mimeTypes["azw"] = "application/vnd.amazon.ebook"
        _mimeTypes["azw3"] = "application/vnd.amazon.ebook"

        // ========== 其他 ==========
        _mimeTypes["rtf"] = "application/rtf"
        _mimeTypes["ics"] = "text/calendar"
        _mimeTypes["vcf"] = "text/vcard"
        _mimeTypes["eml"] = "message/rfc822"
        _mimeTypes["mhtml"] = "message/rfc822"
        _mimeTypes["swf"] = "application/x-shockwave-flash"
        _mimeTypes["torrent"] = "application/x-bittorrent"
    }

    /**
     * 获取默认文件类型映射
     */
    public static func getDefaultFileTypeMap(): FileTypeMap {
        _defaultMap
    }

    /**
     * 根据文件名获取 MIME 类型
     *
     * @param filename 文件名（可以是完整路径或仅文件名）
     * @return MIME 类型字符串
     */
    public func getContentType(filename: String): String {
        let ext = getExtension(filename).toAsciiLower()
        match (_mimeTypes.get(ext)) {
            case Some(mimeType) => mimeType
            case None => "application/octet-stream"
        }
    }

    /**
     * 获取文件扩展名
     */
    private func getExtension(filename: String): String {
        // 先获取文件名（去掉路径）
        var name = filename
        match (filename.lastIndexOf("/")) {
            case Some(idx) => name = filename[(idx + 1)..filename.size]
            case None => ()
        }
        match (name.lastIndexOf("\\")) {
            case Some(idx) => name = name[(idx + 1)..name.size]
            case None => ()
        }

        // 获取扩展名
        match (name.lastIndexOf(".")) {
            case Some(idx) where idx < name.size - 1 =>
                name[(idx + 1)..name.size]
            case _ => ""
        }
    }

    /**
     * 添加自定义 MIME 类型映射
     *
     * @param extension 文件扩展名（不含点号）
     * @param mimeType MIME 类型
     */
    public func addMimeType(extension: String, mimeType: String): Unit {
        _mimeTypes[extension.toAsciiLower()] = mimeType
    }

    /**
     * 批量添加 MIME 类型映射
     *
     * @param mappings 扩展名到 MIME 类型的映射
     */
    public func addMimeTypes(mappings: HashMap<String, String>): Unit {
        for ((ext, mime) in mappings) {
            _mimeTypes[ext.toAsciiLower()] = mime
        }
    }

    /**
     * 检查是否支持该扩展名
     *
     * @param extension 文件扩展名
     * @return 是否有对应的 MIME 类型
     */
    public func hasContentType(extension: String): Bool {
        _mimeTypes.contains(extension.toAsciiLower())
    }

    /**
     * 根据 MIME 类型获取可能的扩展名
     *
     * @param mimeType MIME 类型
     * @return 对应的扩展名，如果没有则返回 None
     */
    public func getExtensionForMimeType(mimeType: String): ?String {
        let lowerMime = mimeType.toAsciiLower()
        for ((ext, mime) in _mimeTypes) {
            if (mime.toAsciiLower() == lowerMime) {
                return Some(ext)
            }
        }
        None
    }

    /**
     * 判断是否是文本类型
     */
    public func isTextType(filename: String): Bool {
        let contentType = getContentType(filename)
        contentType.startsWith("text/") ||
        contentType == "application/json" ||
        contentType == "application/xml" ||
        contentType == "application/javascript"
    }

    /**
     * 判断是否是图片类型
     */
    public func isImageType(filename: String): Bool {
        getContentType(filename).startsWith("image/")
    }

    /**
     * 判断是否是音频类型
     */
    public func isAudioType(filename: String): Bool {
        getContentType(filename).startsWith("audio/")
    }

    /**
     * 判断是否是视频类型
     */
    public func isVideoType(filename: String): Bool {
        getContentType(filename).startsWith("video/")
    }
}
