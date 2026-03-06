import Regex
import Foundation
import Zip
import Parser
@_exported import Common

public final class VKParser: Parser, @unchecked Sendable {

    internal required init() { super.init() }

    public override var name: String { "vk" }

    public static let parseSymbol: String = "keyChapterNumberArgument"
    private let host: String = "https://vk.com"

    /// Парсинг группы статей с одинаковой тематиков
    /// - Parameters:
    ///   - info: Информация о типе статьи
    ///   - start: Начальный номер статьи
    ///   - end: Последний номер статьи
    ///   - withZip: Архивация файла
    /// - Returns: Ссылка на папку со статьями
    @discardableResult
    public override func parse(info: ArticleInfo, start: Int, end: Int, withZip: Bool = false) async throws -> URL {
        guard end >= start else { throw ParserError.invalidEndOption }
        guard let url = info.url else { throw ParserError.invalidURL }

        let articleTitle: String = url
            .path(percentEncoded: false)
            .replacingOccurrences(of: "/@", with: "")
            .replacingOccurrences(of: Self.parseSymbol, with: "")

        Self.logger.info("=====Начинаем парсинг статей \(articleTitle)=====")
        defer {
            Self.logger.info("=====Парсинг статей \(articleTitle) завершён.=====")
        }

        let chapterRange: Range = .init(start...end)

        let titleFolderURL: URL = try getFolderDirectiory(fileName: articleTitle)

        try await withThrowingTaskGroup(of: Void.self) { group in

            for chapterNumber in chapterRange {

                let urlStr = url
                    .absoluteString
                    .replacingOccurrences(of: Self.parseSymbol, with: "\(chapterNumber)")

                let chapterNumberUrl = URL(string: urlStr)

                let newInfo = info.update(url: chapterNumberUrl)

                group.addTask { [weak self] in
                    try await self?.parse(
                        info: newInfo,
                        folderName: "\(chapterNumber)",
                        rootPath: articleTitle + "/"
                    )
                }

            }

            try await group.waitForAll()

        }

        if withZip {
            defer { try? fileManager.removeItem(at: titleFolderURL) }
            let zipPath = parseDir
                .appending(path: titleFolderURL.lastPathComponent)
                .appendingPathExtension("zip")
            try Zip.zipFiles(
                paths: [titleFolderURL],
                zipFilePath: zipPath,
                password: nil,
                compression: .BestCompression
            ) { _ in }
            return zipPath
        } else {
            return titleFolderURL
        }

    }

    public override func parseAndFetch(
        info: ArticleInfo
    ) async throws -> (fileName: String, images: [URL]) {
        let (html, url) = try await fetchHTML(info: info)

        let imageURLs: [URL] = try await fetchImages(html: html, url: url)

        let fileName = url.lastPathComponent.replacingOccurrences(of: "@", with: "")

        return (fileName, imageURLs)
    }

}

// MARK: - Base

private extension VKParser {

    func fetchHTML(info: ArticleInfo) async throws -> (html: String, url: URL) {
        guard let url = info.url else { throw ParserError.invalidURL }

        var request: URLRequest = .init(url: URL(string: "https://vk.com/al_articles.php?act=view")!)
        request.httpMethod = "POST"
        if let cookie = info.cookie {
            request.addValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyParameters = "url=\(url.lastPathComponent)".data(using: .utf8, allowLossyConversion: true)
        request.httpBody = bodyParameters
        do {
            let (data, _) = try await session.data(for: request)
            let html: String = String(decoding: data, as: UTF8.self)
            return (html, url)
        } catch URLError.httpTooManyRedirects {
            throw ParserError.notAuthData
        } catch {
             throw error
        }
    }

    func fetchImages(html: String, url: URL) async throws -> [URL] {
        var pagesURL: [URL] = []
        pagesURL.append(contentsOf: try await parseAsDoc(html: html))
        pagesURL.append(contentsOf: try parseAsImg(html: html))
        guard !pagesURL.isEmpty else { throw ParserError.badImagePages(url: url) }
        return pagesURL
    }

    func parseAsImg(html: String) throws -> [URL] {

        var pageURLs: [URL] = []

        let pagesRegex: Regex = try Regex(pattern: #"class="article_object_sizer_wrap" data-sizes="(?<dataSizes>[^"]+)"#)
        let pages = pagesRegex.findAll(in: html)

        for page in pages {
            guard let firstMatch = page.subgroups.first, let firstMatch else { continue }
            let new = firstMatch
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: #"\"#, with: "")
            guard let data = new.data(using: .utf8) else { throw ParserError.badMatchingData }
            let models = try decoder.decode(Pages.self, from: data)
            guard let imageURL = models.first?.largeURL else { throw ParserError.badImagePage }
            pageURLs.append(imageURL)
        }

        return pageURLs

    }

    func parseAsDoc(html: String) async throws -> [URL] {

        var docURLs: [URL] = []

        let pagesRegex: Regex = try Regex(pattern: #"img src="(?<url>/doc\d+_\d+[^"]+)"#)
        let pages: MatchSequence = pagesRegex.findAll(in: html)

        for page in pages {
            guard let firstMatch = page.subgroups.first, let firstMatch else { continue }
            let new = firstMatch
                .replacingOccurrences(of: "&amp;", with: "&")
            guard let imageURL = URL(string: host + new) else {
                Self.logger.critical("Host: \(host)\nPath: \(new)")
                throw ParserError.badImagePage
            }
            docURLs.append(imageURL)
        }

        guard !docURLs.isEmpty else { return [] }

        var pageUrls: [URL] = []

        for docURL in docURLs {
            let response = try await session.data(from: docURL).1
            guard let imageURL = response.url else { throw ParserError.docNotLocation }
            pageUrls.append(imageURL)
        }

        return pageUrls

    }

}
