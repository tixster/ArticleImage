import Foundation
#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif
@preconcurrency import Zip
@_exported import Logging
@_exported import Common
@_exported import Semaphore

open class Parser: IParser, @unchecked Sendable {

    public static func build() -> (any IParser & Sendable) {
        Self()
    }

    open var name: String { "" }

    nonisolated public static var logger: Logger { .init(label: String(describing: Self.self)) }

    private static let userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"
    public let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": Parser.userAgent,
            "Content-Type": "application/json"
        ]
        config.timeoutIntervalForRequest = 300
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        let session: URLSession = URLSession(configuration: config)
        return session
    }()
    public let fileManager: FileManager = .default
    public let downloadDir: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    open var parseDir: URL { downloadDir.appending(path: "articles").appending(path: name) }
    public let decoder: JSONDecoder = .init()

    required public init() {}

    open func parseAndFetch(
        info: ArticleInfo
    ) async throws -> (fileName: String, images: [URL]) {
        fatalError("parseAndFetch not implemented")
    }

    /// Парсинг группы статей с одинаковой тематиков
    /// - Parameters:
    ///   - info: Информация о типе статьи
    ///   - start: Начальный номер статьи
    ///   - end: Последний номер статьи
    ///   - withZip: Архивация файла
    /// - Returns: Ссылка на папку со статьями
    @discardableResult
    open func parse(
        info: ArticleInfo,
        start: Int,
        end: Int,
        withZip: Bool = false
    ) async throws -> URL {
        throw ParserError.notSupported
    }

    @discardableResult
    open func parse(
        info: ArticleInfo,
        withZip: Bool
    ) async throws -> URL {

        let (fileName, imageURLs) = try await parseAndFetch(info: info)

        if withZip {
            let files = try await downloadPagesAndArchive(urls: imageURLs)
            let zipPath = downloadDir.appending(path: fileName).appendingPathExtension("zip")

            try Zip.zipData(
                archiveFiles: files,
                zipFilePath: zipPath,
                password: nil,
                compression: .BestCompression
            ) { progress in

            }

            return zipPath
        } else {
            let folderURL = try await downloadPages(urls: imageURLs, fileName: fileName)
            return folderURL
        }

    }

}

extension Parser {

    // Парсинг со сохранением в папку
    /// - Parameters:
    ///   - info: Информация о статье
    ///   - folderName: Название папки
    ///   - rootPath: Папка, в которой должна находится папка с картинками.
    /// - Returns: Путь до папки.
    @discardableResult
    public func parse(
        info: ArticleInfo,
        folderName: String? = nil,
        rootPath: String? = nil
    ) async throws -> URL {

        let (fileName, imageURLs) = try await parseAndFetch(info: info)

        Self.logger.info("Начинаем парсинг \(fileName)")
        defer {
            Self.logger.info("Парсинг \(fileName) завершён.")
        }

        let downloadImagesURL = try await downloadPages(
            urls: imageURLs,
            fileName: folderName != nil ? folderName! : fileName.replacingOccurrences(of: "/", with: "-"),
            rootPath: rootPath
        )

        return downloadImagesURL

    }

    @discardableResult
    public func parse(
        urls: [URL?],
        info: ArticleInfo,
        withZip: Bool = false
    ) async throws -> URL {

        let semaphore = AsyncSemaphore(value: 1)
        let folders: [URL] = try await withThrowingTaskGroup(of: URL.self) { group in

            var files: [URL] = []

            for case let url? in urls {
                await semaphore.wait()
                group.addTask {
                    defer { semaphore.signal() }
                    let newInfo: ArticleInfo = info.update(url: url)
                    return try await self.parse(info: newInfo)
                }

            }

            for try await file in group {
                files.append(file)
            }

            return files

        }

        if withZip {
            let zipPath = parseDir
                .appending(path: Date.now.timeIntervalSince1970.description)
                .appendingPathExtension("zip")
            try Zip.zipFiles(
                paths: folders,
                zipFilePath: zipPath,
                password: nil,
                compression: .BestCompression
            ) { _ in }
            folders.forEach({ try? fileManager.removeItem(at: $0) })
            return zipPath
        } else {
            return parseDir
        }

    }


}

// MARK: - Download and Save
public extension Parser {

    @discardableResult
    func downloadPages(
        urls: [URL],
        fileName: String,
        rootPath: String? = nil
    ) async throws -> URL {

        let dirURL: URL = if let rootPath {
            try getFolderDirectiory(fileName: rootPath + fileName)
        } else {
            try getFolderDirectiory(fileName: fileName)
        }

        try await withThrowingTaskGroup(of: (url: URL, name: String).self) { group in

            for (index, url) in urls.enumerated() {
                group.addTask {
                    Self.logger.info("Скачиваю изображение \(index + 1)/\(urls.count):\n\(url)")
                    let (urlFilePath, resp) = try await self.session.download(from: url)
                    let name: String = "\(index).\(url.imageExt)"
                    if let resp = resp as? HTTPURLResponse {
                        if resp.statusCode != 200 {
                            throw NSError(domain: "statusCode != 200", code: resp.statusCode, userInfo: nil)
                        }
                    }
                    return (urlFilePath, name)
                }
            }

            for try await file in group {
                Self.logger.info("Загружено изображение: \(file.name)")
                let pathURL = dirURL.appending(path: file.name)
                if fileManager.fileExists(atPath: pathURL.path(percentEncoded: false)) {
                    try fileManager.removeItem(at: pathURL)
                }
                try fileManager.moveItem(at: file.url, to: pathURL)
            }

        }

        return dirURL

    }

    func getFolderDirectiory(fileName: String) throws -> URL {
        let fileURL = parseDir.appending(path: fileName)
        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            try fileManager.createDirectory(at: fileURL, withIntermediateDirectories: true)
            return fileURL
        }
        try fileManager.removeItem(at: fileURL)
        try fileManager.createDirectory(at: fileURL, withIntermediateDirectories: true)
        return fileURL
    }

}

// MARK: - Download and Archive
extension Parser {

    func downloadPagesAndArchive(urls: [URL]) async throws -> [ArchiveFile] {
        try await withThrowingTaskGroup(of: ArchiveFile.self) { group in
            var files: [ArchiveFile] = []

            for (index, url) in urls.enumerated() {
                group.addTask {
                    let urlFilePath = try await self.session.download(from: url).0
                    let file: ArchiveFile = .init(
                        filename: "\(index).\(url.imageExt)",
                        data: try Data(contentsOf: urlFilePath),
                        modifiedTime: .now
                    )
                    return file
                }
            }

            for try await file in group {
                files.append(file)
            }

            return files
        }

    }

}
