import Foundation

public struct TokenInfo: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Int
    public let isEmptyUser: String?
    public let redirectAppId: String?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.expiresAt = if let date = try? container.decodeIfPresent(Int.self, forKey: .expiresAt) {
            date
        } else if let dateStr = try? container.decodeIfPresent(String.self, forKey: .expiresAt) {
            Int(dateStr) ?? -1
        } else {
            -1
        }
        self.isEmptyUser = try container.decodeIfPresent(String.self, forKey: .isEmptyUser)
        self.redirectAppId = try container.decodeIfPresent(String.self, forKey: .redirectAppId)
    }
}
