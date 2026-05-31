import SwiftUI

public struct HomeView: View {
    @Environment(\.appContentFontSize) private var contentFontSize

    @State private var selectedLanguage: ContentLanguage = .english
    @State private var isShowingSearch = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List(ChaptersResource.chapters) { chapter in
                let title = selectedLanguage.chapterTitle(for: chapter)

                NavigationLink {
                    SlokasView(chapterIndex: chapter.id, chapterTitle: title, language: selectedLanguage)
                } label: {
                    ChapterRowView(
                        chapter: chapter,
                        language: selectedLanguage,
                        fontSize: contentFontSize.wrappedValue
                    )
                    .accessibilityLabel(Text("\(title), \(chapter.slokaCount) slokas"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bhagavad Gita")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSearch = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    FontSizeMenu()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ThemeMenu()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    languageMenu
                }
            }
            .sheet(isPresented: $isShowingSearch) {
                SlokaSearchView(language: selectedLanguage)
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(ContentLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                } label: {
                    if selectedLanguage == language {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            Label(selectedLanguage.displayName, systemImage: "globe")
        }
    }
}

#Preview {
    HomeView()
}
