import Foundation

struct Track: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let durationMilliseconds: Int
    let artworkURL: URL?
    let permalinkURL: String
    let playable: Bool

    var durationText: String { TrackFormatting.duration(durationMilliseconds) }
}

enum TrackFormatting {
    static func duration(_ milliseconds: Int) -> String {
        let total = max(0, milliseconds) / 1000
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

enum ServiceError: LocalizedError {
    case notConfigured, offline, unauthorized, rateLimited, restricted, invalidResponse, server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Сервис пока не настроен. Добавьте URL одобренного SoundCloud backend в схему Xcode."
        case .offline: return "Нет подключения к сети. Проверьте соединение и повторите попытку."
        case .unauthorized: return "Авторизация истекла. Подключите аккаунт SoundCloud заново."
        case .rateLimited: return "Слишком много запросов. Подождите немного и повторите."
        case .restricted: return "SoundCloud не разрешает воспроизведение этого трека."
        case .invalidResponse: return "Сервис вернул неожиданный ответ."
        case .server(let message): return message
        }
    }
}

struct SearchResponse: Decodable { let tracks: [Track] }
struct PlaybackResponse: Decodable { let streamURL: URL }

struct SoundCloudService {
    private var baseURL: URL? {
        guard let value = ProcessInfo.processInfo.environment["SOUNDCLOUD_BACKEND_URL"],
              let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }

    func search(query: String) async throws -> [Track] {
        guard let baseURL else { throw ServiceError.notConfigured }
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/search/tracks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "30")]
        guard let url = components.url else { throw ServiceError.invalidResponse }
        let (data, response) = try await request(url)
        try validate(response, data: data)
        do { return try JSONDecoder().decode(SearchResponse.self, from: data).tracks }
        catch { throw ServiceError.invalidResponse }
    }

    func playbackURL(track: Track) async throws -> URL {
        guard track.playable else { throw ServiceError.restricted }
        guard let baseURL else { throw ServiceError.notConfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/playback/\(track.id)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        guard let url = try? JSONDecoder().decode(PlaybackResponse.self, from: data).streamURL,
              url.scheme == "https" else { throw ServiceError.invalidResponse }
        return url
    }

    private func request(_ url: URL) async throws -> (Data, URLResponse) {
        do { return try await URLSession.shared.data(from: url) }
        catch { throw ServiceError.offline }
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw ServiceError.unauthorized
        case 403, 404, 422: throw ServiceError.restricted
        case 429: throw ServiceError.rateLimited
        default:
            let message = (try? JSONDecoder().decode(ServerError.self, from: data).message)
            throw ServiceError.server(message ?? "Ошибка сервиса (\(http.statusCode)).")
        }
    }
}

private struct ServerError: Decodable { let message: String }

final class MetadataStore {
    private let defaults = UserDefaults.standard
    func load(key: String) -> [Track] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Track].self, from: data)) ?? []
    }
    func save(_ tracks: [Track], key: String) {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        defaults.set(data, forKey: key)
    }
}
