import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SlokaSearchResult: Identifiable, Hashable, Decodable {
    let chapter: Int
    let slokaNumber: Int
    let sloka: String
    let meaning: String?

    var id: String {
        "\(chapter)-\(slokaNumber)-\(sloka.hashValue)"
    }

    var headerTitle: String {
        String(format: "Chapter-%02d, Sloka %d", chapter, slokaNumber)
    }

    private enum CodingKeys: String, CodingKey {
        case chapter
        case chapterId
        case chapterIndex
        case chapterNumber
        case sloka
        case slokaId
        case slokaNumber
        case verseNumber
        case text
        case content
        case slokaText
        case meaning
        case translation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chapter = try container.decodeFirstInt(forKeys: [.chapter, .chapterId, .chapterIndex, .chapterNumber])
        slokaNumber = try container.decodeFirstInt(forKeys: [.slokaNumber, .slokaId, .verseNumber])
        sloka = try container.decodeFirstString(forKeys: [.sloka, .text, .content, .slokaText])
        meaning = try container.decodeFirstOptionalString(forKeys: [.meaning, .translation])
    }
}

struct SlokaSearchResponse: Decodable {
    let results: [SlokaSearchResult]

    private enum CodingKeys: String, CodingKey {
        case results
        case items
        case slokas
    }

    init(from decoder: Decoder) throws {
        if let results = try? [SlokaSearchResult](from: decoder) {
            self.results = results
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let results = try? container.decode([SlokaSearchResult].self, forKey: .results) {
            self.results = results
        } else if let items = try? container.decode([SlokaSearchResult].self, forKey: .items) {
            self.results = items
        } else {
            self.results = try container.decode([SlokaSearchResult].self, forKey: .slokas)
        }
    }
}

struct SlokaSearchRequest {
    let searchText: String
    let language: ContentLanguage
    let limit: Int
    let configuration: AppConfiguration

    func url() throws -> URL {
        guard var components = URLComponents(url: configuration.slokaAPIBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = Self.pathByAppending("/api/slokaSearch", to: components.path)
        components.queryItems = [
            URLQueryItem(name: "searchText", value: searchText),
            URLQueryItem(name: "top", value: String(limit)),
            URLQueryItem(name: "lang", value: language.apiContentValue)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
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

public struct SlokaSearchView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.appContentFontSize) private var contentFontSize
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedLanguage: ContentLanguage
    @State private var resultLimit = 10
    @State private var results: [SlokaSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var submittedSearchText: String?
    @State private var isSearchFieldFocused = false

    private let resultLimits = [10, 20]

    public init(language: ContentLanguage = .english) {
        _selectedLanguage = State(initialValue: language)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            PlatformSearchTextField(
                placeholder: "Search slokas",
                text: $searchText,
                isFocused: $isSearchFieldFocused
            ) {
                Task { await search() }
            }

            if searchText.isEmpty == false {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = true
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                List {
                    Section {
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(ContentLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Results", selection: $resultLimit) {
                            ForEach(resultLimits, id: \.self) { limit in
                                Text("Top \(limit)").tag(limit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if isSearching {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    } else if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        }
                    } else if results.isEmpty, let submittedSearchText {
                        Section {
                            Text("No results for \"\(submittedSearchText)\"")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(results) { result in
                            Section(header: Text(result.headerTitle).textCase(nil)) {
                                Text(result.sloka)
                                    .font(.system(size: contentFontSize.wrappedValue))
                                    .lineSpacing(5)
                                    .textSelection(.enabled)

                                if let meaning = result.meaning, meaning.isEmpty == false {
                                    Text(meaning)
                                        .font(.system(size: contentFontSize.wrappedValue))
                                        .lineSpacing(5)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search Slokas")
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                isSearchFieldFocused = true
            }
            .onChange(of: selectedLanguage) { _, _ in
                Task { await searchIfNeeded() }
            }
            .onChange(of: resultLimit) { _, _ in
                Task { await searchIfNeeded() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        Task { await search() }
                    }
                    .disabled(trimmedSearchText.isEmpty || isSearching)
                }
            }
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearSearch() {
        searchText = ""
        results = []
        errorMessage = nil
        submittedSearchText = nil
        isSearchFieldFocused = true
    }

    @MainActor
    private func searchIfNeeded() async {
        guard submittedSearchText != nil else { return }
        await search()
    }

    @MainActor
    private func search() async {
        let query = trimmedSearchText
        guard query.isEmpty == false else {
            results = []
            errorMessage = nil
            submittedSearchText = nil
            return
        }

        isSearching = true
        errorMessage = nil
        submittedSearchText = query

        do {
            results = try await Self.fetchResults(
                searchText: query,
                language: selectedLanguage,
                limit: resultLimit,
                configuration: appConfiguration
            )
        } catch {
            results = []
            errorMessage = "Search failed. Please try again."
        }

        isSearching = false
    }

    private static func fetchResults(searchText: String, language: ContentLanguage, limit: Int, configuration: AppConfiguration) async throws -> [SlokaSearchResult] {
        let url = try SlokaSearchRequest(
            searchText: searchText,
            language: language,
            limit: limit,
            configuration: configuration
        ).url()

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(SlokaSearchResponse.self, from: data).results
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

private struct PlatformSearchTextField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        #if canImport(UIKit)
        UIKitSearchTextField(
            placeholder: placeholder,
            text: $text,
            isFocused: $isFocused,
            onSubmit: onSubmit
        )
        .frame(height: 24)
        #else
        TextField(placeholder, text: $text)
            .onSubmit(perform: onSubmit)
        #endif
    }
}

#if canImport(UIKit)
private struct UIKitSearchTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.returnKeyType = .search
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .never
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused, uiView.isFirstResponder == false {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if isFocused == false, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool
        private let onSubmit: () -> Void

        init(text: Binding<String>, isFocused: Binding<Bool>, onSubmit: @escaping () -> Void) {
            _text = text
            _isFocused = isFocused
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return true
        }
    }
}
#endif

private extension KeyedDecodingContainer {
    func decodeFirstInt(forKeys keys: [Key]) throws -> Int {
        for key in keys {
            if let value = try? decode(Int.self, forKey: key) {
                return value
            }
            if let string = try? decode(String.self, forKey: key), let value = Int(string) {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing expected integer value")
        )
    }

    func decodeFirstString(forKeys keys: [Key]) throws -> String {
        for key in keys {
            if let value = try? decode(String.self, forKey: key) {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing expected string value")
        )
    }

    func decodeFirstOptionalString(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }

        return nil
    }
}

#Preview {
    SlokaSearchView()
}
