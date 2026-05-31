import SwiftUI
import AVFoundation
import Combine

public enum ContentLanguage: String, CaseIterable, Identifiable, Hashable {
    case english
    case sanskrit

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .sanskrit:
            return "Sanskrit"
        }
    }

    var apiContentValue: String {
        rawValue
    }

    func chapterTitle(for chapter: Chapter) -> String {
        switch self {
        case .english:
            return chapter.english
        case .sanskrit:
            return chapter.sanskrit
        }
    }
}

private struct SlokaResponse: Decodable {
    let text: String
    let meaning: String
}

private struct ChapterResourceResponse: Decodable {
    let url: URL
}

struct Sloka: Identifiable, Hashable {
    var id: Int { number }

    let number: Int
    let text: String
    let meaning: String
    let audioURL: URL?
    let isLoading: Bool

    static func placeholder(number: Int) -> Sloka {
        Sloka(number: number, text: "", meaning: "", audioURL: nil, isLoading: true)
    }
}

final class AudioPlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?

    func play(url: URL) {
        print("Attempting sloka audio playback: \(url.absoluteString)")

        if player == nil || (player?.currentItem?.asset as? AVURLAsset)?.url != url {
            let item = AVPlayerItem(url: url)
            statusObservation = item.observe(\.status, options: [.initial, .new]) { item, _ in
                switch item.status {
                case .unknown:
                    print("Sloka audio player item status: unknown")
                case .readyToPlay:
                    print("Sloka audio player item status: readyToPlay")
                case .failed:
                    print("Sloka audio player item failed: \(item.error?.localizedDescription ?? "Unknown error")")
                    if let errorLog = item.errorLog() {
                        for event in errorLog.events {
                            print("Sloka audio error log: status=\(event.errorStatusCode) domain=\(event.errorDomain) comment=\(event.errorComment ?? "") uri=\(event.uri ?? "")")
                        }
                    }
                @unknown default:
                    print("Sloka audio player item status: unhandled")
                }
            }
            player = AVPlayer(playerItem: item)
        }

        player?.play()
        isPlaying = true
        print("Sloka audio player rate after play: \(player?.rate ?? 0)")
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }
}

public struct SlokasView: View {
    public let chapterIndex: Int
    public let chapterTitle: String
    private let language: ContentLanguage

    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.appContentFontSize) private var contentFontSize

    @State private var expandedSlokaID: Sloka.ID?
    @State private var slokas: [Sloka] = []
    @State private var chapterPDFURL: URL?
    @State private var tamilChapterPDFURL: URL?
    @State private var chapterAudioURL: URL?
    @State private var isLoadingChapterPDF = false
    @State private var resourceErrorMessage: String?
    @StateObject private var audioPlayer = AudioPlayer()

    public init(chapterIndex: Int, chapterTitle: String, language: ContentLanguage = .english) {
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.language = language
    }

    public var body: some View {
        List {
            ForEach(slokas) { sloka in
                Section(header: slokaHeader(number: sloka.number)) {
                    VStack(alignment: .leading, spacing: 8) {
                        if sloka.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading sloka")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        } else {
                            Text(sloka.text)
                                .font(.system(size: contentFontSize.wrappedValue))
                                .lineSpacing(5)
                                .textSelection(.enabled)

                            if expandedSlokaID == sloka.id {
                                Divider()
                                    .padding(.vertical, 4)

                                Label("Meaning", systemImage: "quote.opening")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                Text(sloka.meaning)
                                    .font(.system(size: contentFontSize.wrappedValue))
                                    .lineSpacing(5)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                if let url = sloka.audioURL {
                                    Button {
                                        if audioPlayer.isPlaying {
                                            audioPlayer.pause()
                                        } else {
                                            audioPlayer.play(url: url)
                                        }
                                    } label: {
                                        Label(audioPlayer.isPlaying ? "Pause" : "Play", systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    }
                                    .buttonStyle(SlokaAudioButtonStyle())
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            expandedSlokaID = expandedSlokaID == sloka.id ? nil : sloka.id
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(chapterTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FontSizeMenu()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let chapterPDFURL {
                        Link(destination: chapterPDFURL) {
                            Label("PDF", systemImage: "doc.richtext")
                        }
                    } else {
                        Label(isLoadingChapterPDF ? "Loading PDF" : "PDF Unavailable", systemImage: "doc.richtext")
                    }

                    if let tamilChapterPDFURL {
                        Link(destination: tamilChapterPDFURL) {
                            Label("Tamil PDF", systemImage: "doc.richtext")
                        }
                    } else {
                        Label(isLoadingChapterPDF ? "Loading Tamil PDF" : "Tamil PDF Unavailable", systemImage: "doc.richtext")
                    }

                    if let chapterAudioURL {
                        Link(destination: chapterAudioURL) {
                            Label("Audio", systemImage: "speaker.wave.2")
                        }
                    } else {
                        Label("Audio Unavailable", systemImage: "speaker.slash")
                    }
                } label: {
                    Label("Chapter Resources", systemImage: "ellipsis.circle")
                }
            }
        }
        .task(id: "\(chapterIndex)-\(language.rawValue)") {
            await loadChapterResources()
            await loadSlokas()
        }
        .alert("Resource Unavailable", isPresented: resourceErrorBinding) {
            Button("OK", role: .cancel) {
                resourceErrorMessage = nil
            }
        } message: {
            Text(resourceErrorMessage ?? "Please try again.")
        }
    }

    private func slokaHeader(number: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.caption.weight(.semibold))
            Text("Sloka \(number)")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .textCase(nil)
    }

    @MainActor
    private func loadChapterResources() async {
        chapterPDFURL = nil
        tamilChapterPDFURL = nil
        chapterAudioURL = nil
        isLoadingChapterPDF = true
        defer { isLoadingChapterPDF = false }

        async let selectedLanguagePDF = Self.fetchChapterPDFURL(
            chapterIndex: chapterIndex,
            content: language.apiContentValue,
            configuration: appConfiguration
        )
        async let tamilPDF = Self.fetchChapterPDFURL(
            chapterIndex: chapterIndex,
            content: "tamil",
            configuration: appConfiguration
        )
        async let chapterAudio = Self.fetchChapterAudioURL(
            chapterIndex: chapterIndex,
            configuration: appConfiguration
        )

        do {
            chapterPDFURL = try await selectedLanguagePDF
        } catch {
            resourceErrorMessage = "Unable to load the PDF resource."
        }

        do {
            tamilChapterPDFURL = try await tamilPDF
        } catch {
            resourceErrorMessage = "Unable to load the Tamil PDF resource."
        }

        do {
            chapterAudioURL = try await chapterAudio
        } catch {
            resourceErrorMessage = "Unable to load the audio resource."
        }
    }

    @MainActor
    private func loadSlokas() async {
        let count = ChaptersResource.slokaCount(for: chapterIndex) ?? 0
        guard count > 0 else {
            slokas = []
            return
        }

        let configuration = appConfiguration
        let selectedLanguage = language
        slokas = (1...count).map { Sloka.placeholder(number: $0) }

        await withTaskGroup(of: Sloka.self) { group in
            for slokaNumber in 1...count {
                group.addTask {
                    await Self.fetchSloka(
                        chapterIndex: chapterIndex,
                        slokaNumber: slokaNumber,
                        language: selectedLanguage,
                        configuration: configuration
                    )
                }
            }

            for await sloka in group {
                guard let index = slokas.firstIndex(where: { $0.number == sloka.number }) else { continue }
                slokas[index] = sloka
            }
        }
    }

    private var resourceErrorBinding: Binding<Bool> {
        Binding(
            get: { resourceErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    resourceErrorMessage = nil
                }
            }
        )
    }

    private static func fetchChapterAudioURL(chapterIndex: Int, configuration: AppConfiguration) async throws -> URL {
        guard var components = URLComponents(url: configuration.slokaAPIBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = pathByAppending("/api/chapterAudio/\(chapterIndex)", to: components.path)

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ChapterResourceResponse.self, from: data).url
    }

    private static func fetchChapterPDFURL(chapterIndex: Int, content: String, configuration: AppConfiguration) async throws -> URL {
        guard var components = URLComponents(url: configuration.slokaAPIBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = pathByAppending("/api/chapterResource/\(chapterIndex)", to: components.path)
        components.queryItems = [URLQueryItem(name: "content", value: content)]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ChapterResourceResponse.self, from: data).url
    }

    private static func fetchSloka(chapterIndex: Int, slokaNumber: Int, language: ContentLanguage, configuration: AppConfiguration) async -> Sloka {
        do {
            guard let url = slokaURL(chapterIndex: chapterIndex, slokaNumber: slokaNumber, language: language, configuration: configuration) else {
                throw URLError(.badURL)
            }

            print("Sloka content API URL [chapter \(chapterIndex), sloka \(slokaNumber)]: \(url.absoluteString)")

            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
                throw URLError(.badServerResponse)
            }

            let slokaResp = try JSONDecoder().decode(SlokaResponse.self, from: data)
            let audio: URL?
            do {
                audio = try await fetchSlokaAudioURL(chapterIndex: chapterIndex, slokaNumber: slokaNumber, configuration: configuration)
                if let audio {
                    print("Sloka audio resource URL [chapter \(chapterIndex), sloka \(slokaNumber)]: \(audio.absoluteString)")
                }
            } catch {
                audio = nil
                print("Failed to fetch sloka audio resource [chapter \(chapterIndex), sloka \(slokaNumber)]: \(error.localizedDescription)")
            }
            return Sloka(number: slokaNumber, text: slokaResp.text, meaning: slokaResp.meaning, audioURL: audio, isLoading: false)
        } catch {
            return Sloka(number: slokaNumber, text: "", meaning: "", audioURL: nil, isLoading: false)
        }
    }

    private static func slokaURL(chapterIndex: Int, slokaNumber: Int, language: ContentLanguage, configuration: AppConfiguration) -> URL? {
        guard var components = URLComponents(url: configuration.slokaAPIBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = pathByAppending("/api/sloka/\(chapterIndex)/\(slokaNumber)", to: components.path)
        components.queryItems = [URLQueryItem(name: "content", value: language.apiContentValue)]
        return components.url
    }

    private static func fetchSlokaAudioURL(chapterIndex: Int, slokaNumber: Int, configuration: AppConfiguration) async throws -> URL {
        guard var components = URLComponents(url: configuration.slokaAPIBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = pathByAppending("/api/slokaAudio/\(chapterIndex)/\(slokaNumber)", to: components.path)

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("Sloka audio API URL [chapter \(chapterIndex), sloka \(slokaNumber)]: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
            let body = String(data: data, encoding: .utf8) ?? "<non-text response>"
            print("Sloka audio API failed [chapter \(chapterIndex), sloka \(slokaNumber)] status=\(http.statusCode) body=\(body)")
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ChapterResourceResponse.self, from: data)
        print("Sloka audio API decoded URL [chapter \(chapterIndex), sloka \(slokaNumber)]: \(decoded.url.absoluteString)")
        return decoded.url
    }

    private static func pathByAppending(_ path: String, to basePath: String) -> String {
        let trimmedBase = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard trimmedBase.isEmpty == false else {
            return "/\(trimmedPath)"
        }

        return "/\(trimmedBase)/\(trimmedPath)"
    }
}

private struct SlokaAudioButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(.label))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(red: 0.933, green: 0.965, blue: 0.945))
            )
            .overlay(
                Capsule()
                    .stroke(Color.blue.opacity(0.55), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    NavigationStack {
        SlokasView(chapterIndex: 0, chapterTitle: "Dhyanam")
    }
}
