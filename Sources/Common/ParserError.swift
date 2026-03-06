import Foundation

public enum ParserError: LocalizedError {
    case invalidURL
    case badImagePage
    case badImagePages(url: URL)
    case badMatchingData
    case docNotLocation
    case notAuthData
    case invalidEndOption
    case internalError
    case notSupported
}

extension ParserError {

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Неудалось провалидировать URL."
        case .badImagePage:
            "Изображение не обнаружено."
        case .badImagePages(let url):
            "Изображений не обнаружено. Статья: \(url.absoluteString)"
        case .badMatchingData:
            "Неудалось получить ссылки на изображения."
        case .notAuthData:
            "Данные для аутентификации просрочены."
        case .invalidEndOption:
            "Некорректный номер последней ссылки."
        case .internalError:
            "Внутрненяя ошибка"
        case .docNotLocation:
            "Отсутсвует инофрмация об изображении"
        case .notSupported:
            "Не поддерживается."
        }
    }

}
