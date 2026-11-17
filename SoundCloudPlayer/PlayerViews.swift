import SwiftUI

private enum LibraryTab: String, CaseIterable {
    case home = "Главная", search = "Поиск", favorites = "Избранное"
    var icon: String {
        switch self { case .home: "house.fill"; case .search: "magnifyingglass"; case .favorites: "heart.fill" }
    }
}

struct RootView: View {
    @Environment(PlayerModel.self) private var model
    @Environment(AppIntentRouter.self) private var intentRouter
    @State private var selection: LibraryTab = .home
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.17, green: 0.08, blue: 0.10), .black, Color(red: 0.08, green: 0.13, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SOUNDCLOUD").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.orange)
                        Text(selection.rawValue).font(.largeTitle.bold())
                    }
                    Spacer()
                    Image(systemName: "waveform").font(.title2).foregroundStyle(.orange)
                }.padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 18)
                Group {
                    switch selection {
                    case .home: RecommendationsView()
                    case .search: SearchView()
                    case .favorites: TrackListView(tracks: model.favorites, empty: "Избранное пока пусто")
                    }
                }
                Spacer(minLength: 0)
                if let track = model.currentTrack {
                    MiniPlayer(track: track) { showPlayer = true }
                        .padding(.horizontal, 14).padding(.bottom, 8)
                }
                HStack(spacing: 0) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Button { selection = tab } label: {
                            VStack(spacing: 5) {
                                Image(systemName: tab.icon).font(.system(size: 18, weight: .semibold))
                                Text(tab.rawValue).font(.caption2.weight(.medium))
                            }.foregroundStyle(selection == tab ? .orange : .secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }.accessibilityLabel(tab.rawValue)
                    }
                }.padding(.horizontal, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 14).padding(.bottom, 6)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPlayer) { NowPlayingView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .onChange(of: intentRouter.openSearchRequest) {
            selection = .search
        }
        .onChange(of: intentRouter.playFavoriteRequest) {
            guard let id = intentRouter.playFavoriteRequest,
                  let track = model.favoriteTrack(id: id) else { return }
            Task { await model.play(track) }
            intentRouter.playFavoriteRequest = nil
        }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Понятно", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

private struct SearchView: View {
    @Environment(PlayerModel.self) private var model
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Треки, исполнители", text: Bindable(model).query)
                    .submitLabel(.search).onSubmit { Task { await model.search() } }
                    .accessibilityLabel("Поиск треков и исполнителей")
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .accessibilityLabel("Очистить поиск")
                }
                Button { Task { await model.search() } } label: {
                    Image(systemName: "arrow.right").font(.headline).foregroundStyle(.black)
                        .frame(width: 36, height: 36).background(.orange, in: Circle())
                }.accessibilityLabel("Искать")
            }
            .padding(.leading, 16).padding(.trailing, 7).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.1)))
            if model.isSearching {
                ProgressView("Ищем в SoundCloud…").tint(.orange).frame(maxHeight: .infinity)
            } else if model.tracks.isEmpty {
                ContentUnavailableView(model.hasSearched ? "Ничего не найдено" : "Найдите следующий трек",
                    systemImage: model.hasSearched ? "waveform.slash" : "music.note.list",
                    description: Text(model.hasSearched ? "Попробуйте другой запрос." : "Результаты появятся после настройки официального API-сервиса."))
                    .frame(maxHeight: .infinity)
            } else {
                TrackListView(tracks: model.tracks, empty: "")
            }
        }.padding(.horizontal, 18)
    }
}

private struct RecommendationsView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Подборка для вас")
                            .font(.title2.bold())
                        Text("Откройте нов��е треки на SoundCloud")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "waveform.path")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }

                HStack(spacing: 12) {
                    Button {
                        model.query = "trending"
                        Task { await model.search() }
                    } label: {
                        Label("Популярное", systemImage: "chart.line.uptrend.xyaxis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                        model.query = "new music"
                        Task { await model.search() }
                    } label: {
                        Label("Новое", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if model.tracks.isEmpty {
                    ContentUnavailableView(
                        "Рекомендации появятся здесь",
                        systemImage: "music.note",
                        description: Text("Подключите одобренный SoundCloud API-сервис, чтобы загружать реальные треки.")
                    )
                    .frame(minHeight: 260)
                } else {
                    Text("Рекомендуемое").font(.headline)
                    TrackListView(tracks: model.tracks, empty: "")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct TrackListView: View {
    @Environment(PlayerModel.self) private var model
    let tracks: [Track]
    let empty: String
    var body: some View {
        if tracks.isEmpty {
            ContentUnavailableView(empty, systemImage: "music.note")
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(tracks) { track in
                        HStack(spacing: 12) {
                            ArtworkView(url: track.artworkURL, size: 54)
                            Button { Task { await model.play(track) } } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                                    Text("\(track.artist)  ·  \(track.durationText)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Button { model.enqueue(track) } label: { Image(systemName: "text.badge.plus").frame(width: 34, height: 40) }
                                .accessibilityLabel("Добавить в очередь")
                            Button { model.toggleFavorite(track) } label: {
                                Image(systemName: model.favorites.contains(where: { $0.id == track.id }) ? "heart.fill" : "heart")
                                    .foregroundStyle(.orange).frame(width: 34, height: 40)
                            }.accessibilityLabel("Добавить или убрать из избранного")
                        }.padding(.vertical, 8)
                    }
                }.padding(.bottom, 8)
            }.scrollIndicators(.hidden)
        }
    }
}

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat
    var body: some View {
        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08))
                .overlay(Image(systemName: "waveform").foregroundStyle(.orange))
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Обложка трека")
    }
}

private struct MiniPlayer: View {
    @Environment(PlayerModel.self) private var model
    let track: Track
    let open: () -> Void
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 11) {
                Button(action: open) {
                    HStack(spacing: 10) {
                        ArtworkView(url: track.artworkURL, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.caption.weight(.semibold)).lineLimit(1)
                            Text(track.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).frame(width: 44, height: 44)
                }
                .accessibilityLabel(model.isPlaying ? "Пауза" : "Воспроизвести")
            }
            ProgressView(value: 0)
                .tint(.orange)
                .accessibilityLabel("Позиция воспроизведения")
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.12)))
    }
}

struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.secondary.opacity(0.5)).frame(width: 36, height: 5).padding(.top, 10)
            if let track = model.currentTrack {
                ArtworkView(url: track.artworkURL, size: 190)
                VStack(spacing: 5) {
                    Text(track.title).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(track.artist).foregroundStyle(.secondary)
                }
                HStack {
                    Image(systemName: "waveform").foregroundStyle(.orange)
                    Text("SoundCloud").font(.caption.weight(.medium))
                    Spacer()
                    Button { model.open(track) } label: { Label("Открыть трек", systemImage: "arrow.up.right") }.font(.caption)
                }
                HStack(spacing: 36) {
                    Button {
                        guard let track = model.queue.first else { return }
                        Task { await model.play(track) }
                    } label: { Image(systemName: "backward.end.fill") }
                        .accessibilityLabel("Предыдущий трек")
                    Button { model.togglePlayback() } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 30))
                            .frame(width: 68, height: 68).background(.orange, in: Circle()).foregroundStyle(.black)
                    }.accessibilityLabel(model.isPlaying ? "Пауза" : "Воспроизвести")
                    Button {
                        guard let track = model.queue.first else { return }
                        model.queue.removeFirst()
                        Task { await model.play(track) }
                    } label: { Image(systemName: "forward.end.fill") }
                        .accessibilityLabel("Следующий трек")
                }.font(.title2).padding(.top, 4)
            } else {
                ContentUnavailableView("Нет активного трека", systemImage: "waveform")
            }
            Spacer(minLength: 8)
        }.padding(.horizontal, 26).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(colors: [Color(red: 0.22, green: 0.11, blue: 0.12), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}
