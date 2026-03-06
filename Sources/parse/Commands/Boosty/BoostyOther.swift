import ArgumentParser
import Foundation
import BoostyParser

extension VKParserApp.Boosty {

    struct Other: AsyncParsableCommand {

        static let parser: (IParser & Sendable) = BoostyParser.build()

        @Option(name: [.short])
        var cookie: String?

        @Argument(help: "Ссылки на статьи", transform: { URL(string: $0) })
        var urls: [URL?] //= [URL(string: "https://boosty.to/nochnoy/posts/3c3b43a8-41d9-453f-91bd-18e4a0358b96?share=post_link")!]

        func run() async throws {
            try await Self.parser.parse(
                urls: urls,
                info: .init(url: nil, cookie: cookie),
                withZip: false
            )
        }


    }

}
