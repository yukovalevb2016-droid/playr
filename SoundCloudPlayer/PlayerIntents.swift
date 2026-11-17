import AppIntents
import Foundation

struct FavoriteTrackEntity: AppEntity, Identifiable {
    let id: String
    let title: String
    let artist: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Избранный трек")
    static let defaultQuery = FavoriteTrackQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(artist)")
    }
}

struct FavoriteTrackQuery: EntityQuery {
    func entities(for identifiers: [FavoriteTrackEntity.ID]) async throws -> [FavoriteTrackEntity] {
        PlayerModel.shared.favorites
            .filter { identifiers.contains($0.id) }
            .map { FavoriteTrackEntity(id: $0.id, title: $0.title, artist: $0.artist) }
    }

    func suggestedEntities() async throws -> [FavoriteTrackEntity] {
        PlayerModel.shared.favorites.prefix(10)
            .map { FavoriteTrackEntity(id: $0.id, title: $0.title, artist: $0.artist) }
    }
}

struct PlayFavoriteTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Воспроизвести избранный трек"
    static let description = IntentDescription("Запускает выбранный трек из локального избранного.")
    static let openAppWhenRun = false

    @Parameter(title: "Трек")
    var track: FavoriteTrackEntity

    init() {}

    init(track: FavoriteTrackEntity) {
        self.track = track
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let savedTrack = PlayerModel.shared.favoriteTrack(id: track.id) else {
            return .result(dialog: "Этот трек больше не находится в избранном.")
        }
        await MainActor.run {
            AppIntentRouter.shared.playFavoriteRequest = savedTrack.id
        }
        return .result(dialog: "Открываю приложение и запускаю \(savedTrack.title).")
    }
}

struct OpenSoundCloudSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Открыть поиск музыки"
    static let description = IntentDescription("Открывает поиск треков в приложении.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.openSearchRequest = UUID()
        }
        return .result()
    }
}

struct SoundCloudPlayerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSoundCloudSearchIntent(),
            phrases: [
                "Открой поиск музыки в \(.applicationName)",
                "Найди музыку в \(.applicationName)"
            ],
            shortTitle: "Поиск музыки",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: PlayFavoriteTrackIntent(),
            phrases: [
                "Воспроизведи избранный трек в \(.applicationName)",
                "Включи любимую музыку в \(.applicationName)"
            ],
            shortTitle: "Избранный трек",
            systemImageName: "heart.fill"
        )
    }
}
