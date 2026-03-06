import Foundation
import Common
import Parser
import Zip
@_exported import Common

extension ParserParametersKey {
    static let tags: Self = .init("Boosty_Tags")
}

public final class BoostyParser: Parser, @unchecked Sendable {

    private let api: URL = .init(string: "https://api.boosty.to/v1/blog")!

    public override var name: String { "boosty" }

    public override func parseAndFetch(
        info: ArticleInfo
    ) async throws -> (fileName: String, images: [URL]
    ) {
        guard let url = info.url else {
            throw ParserError.invalidURL
        }

        let postId = url.lastPathComponent
        let userUrl = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        let postURL = api
            .appending(path: userUrl)
            .appending(path: "post")
            .appending(path: postId)

        var request = URLRequest(url: postURL)
        if let tokenInfo = info.tokenInfo {
            request.addValue("Bearer \(tokenInfo.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let post = try decoder.decode(BoostyPost.self, from: data)
        
        guard post.hasAccess else {
            throw ParserError.notAuthData
        }

        let images = post.data
            .filter({ $0.type == .image })
            .compactMap({
                if let urlStr = $0.url {
                    return URL(string: urlStr)
                }
                return nil
            })

        guard !images.isEmpty else { throw ParserError.badImagePages(url: url) }

        return (post.title.replacingOccurrences(of: " ", with: "_"), images)
    }

    public override func parse(
        info: ArticleInfo,
        withZip: Bool
    ) async throws -> URL {
        guard let url = info.url else {
            throw ParserError.invalidURL
        }

        if let tags = getPostsTagsIds(from: url) {
            return try await fetchAllPosts(by: tags, userURL: url.lastPathComponent, info: info, withZip: withZip)
        }

        throw ParserError.invalidURL

    }

}

private extension BoostyParser {

    func fetchAllPosts(
        by tags: [String],
        userURL: String,
        info: ArticleInfo,
        withZip: Bool
    ) async throws -> URL {
        let url = api
            .appending(path: userURL)
            .appending(path: "post/")
            .appending(queryItems: [.init(name: "tags_ids", value: tags.joined(separator: ","))])

        var request = URLRequest(url: url)
        if let tokenInfo = info.tokenInfo {
            request.addValue("Bearer \(tokenInfo.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let posts = try decoder.decode(BoostyPostFeed.self, from: data).data.filter({ $0.hasAccess })

        Self.logger.info("=====Начинаем парсинг статей по тегам=====")
        defer {
            Self.logger.info("=====Парсинг статей по тегам завершён.=====")
        }

        guard !posts.isEmpty else { throw ParserError.badImagePages(url: url) }
        let nameFolder: String

        let postFirst = posts[0]
        if !postFirst.tags.isEmpty {
            nameFolder = postFirst.tags.map({ $0.title }).joined(separator: ",")
        } else {
            nameFolder = tags.joined(separator: ",")
        }
        
        let titleFolderURL: URL = try getFolderDirectiory(fileName: nameFolder)

        let semaphore = AsyncSemaphore(value: 1)

        try await withThrowingTaskGroup(of: Void.self) { group in

            for post in posts {

                let images = post.data
                    .filter({ $0.type == .image })
                    .compactMap({
                        if let urlStr = $0.url {
                            return URL(string: urlStr)
                        }
                        return nil
                    })

                guard !images.isEmpty else { continue }
                await semaphore.wait()
                group.addTask { [weak self] in
                    defer { semaphore.signal() }
                    try await self?.downloadPages(
                        urls: images,
                        fileName: post.title.replacingOccurrences(of: " ", with: "_"),
                        rootPath: titleFolderURL.lastPathComponent + "/"
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

    func getPostsTagsIds(from url: URL) -> [String]? {
        guard let urlComponents = URLComponents(string: url.absoluteString) else {
            Self.logger.info("Invalid URL")
            return nil
        }

        guard let queryItems = urlComponents.queryItems else {
            Self.logger.info("No query items found")
            return nil
        }

        for queryItem in queryItems {
            if queryItem.name == "postsTagsIds" {
                return queryItem.value?.components(separatedBy: ",")
            }
        }

        return nil
    }


}
