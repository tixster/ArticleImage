import ArgumentParser
import Foundation
import VKParser

extension VKParserApp.VK {

    struct Other: AsyncParsableCommand {

        static let parser: (IParser & Sendable) = VKParser.build()

        @Option(name: [.customLong("nsid")])
        var remixnsid: String?
        @Option(name: [.customLong("sid")])
        var remixsid: String?
        @Option(name: [.customLong("dmgr")])
        var remixdmgr: String?

        @Argument(help: "Ссылки на статьи", transform: { URL(string: $0) })
        var urls: [URL?]

        func run() async throws {
            try await Self.parser.parse(
                urls: urls,
                info: .init(
                    url: nil,
                    remixnsid: remixnsid,
                    remixsid: remixsid,
                    remixdmgr: remixdmgr
                ),
                withZip: false
            )
        }


    }

}
