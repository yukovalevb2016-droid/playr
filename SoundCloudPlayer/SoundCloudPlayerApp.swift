import SwiftUI
import AVFoundation

@Observable
final class AppIntentRouter {
    static let shared = AppIntentRouter()
    var openSearchRequest = UUID()
    var playFavoriteRequest: String?

    private init() {}
}

@main
struct SoundCloudPlayerApp: App {
    @State private var model = PlayerModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(AppIntentRouter.shared)
                .preferredColorScheme(.dark)
        }
    }
}

@Observable
final class PlayerModel {
    var query = ""
    var tracks: [Track] = []
    var queue: [Track] = []
    var favorites: [Track] = []
    var currentTrack: Track?
    var isPlaying = false
    var isSearching = false
    var errorMessage: String?
    var hasSearched = false
    private var player: AVPlayer?
    private let service = SoundCloudService()
    let store = MetadataStore()
    static let shared = PlayerModel()

    init() {
        favorites = store.load(key: "favorites")
        queue = store.load(key: "queue")
    }

    func favoriteTrack(id: String) -> Track? {
        favorites.first { $0.id == id }
    }

    @MainActor
    func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        errorMessage = nil
        hasSearched = true
        defer { isSearching = false }
        do { tracks = try await service.search(query: query) }
        catch { errorMessage = error.localizedDescription }
    }

    func toggleFavorite(_ track: Track) {
        if favorites.contains(where: { $0.id == track.id }) {
            favorites.removeAll { $0.id == track.id }
        } else {
            favorites.insert(track, at: 0)
        }
        store.save(favorites, key: "favorites")
    }

    func enqueue(_ track: Track) {
        if !queue.contains(where: { $0.id == track.id }) { queue.append(track) }
        store.save(queue, key: "queue")
    }

    @MainActor
    func play(_ track: Track) async {
        guard track.playable else {
            errorMessage = "Этот трек недоступен для воспроизведения в приложении."
            return
        }
        do {
            let url = try await service.playbackURL(track: track)
            currentTrack = track
            player = AVPlayer(url: url)
            player?.play()
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func open(_ track: Track) {
        guard let url = URL(string: track.permalinkURL) else { return }
        UIApplication.shared.open(url)
    }
}
