import SwiftUI

public struct ChaptersListView: View {
    @Environment(\.appContentFontSize) private var contentFontSize

    @State private var selectedChapter: Chapter?
    @State private var selectedLanguage: ContentLanguage = .english
    @State private var isShowingSearch = false

    public init() {}

    public var body: some View {
        List(ChaptersResource.chapters) { chapter in
            Button {
                selectedChapter = chapter
            } label: {
                ChapterRowView(
                    chapter: chapter,
                    language: selectedLanguage,
                    fontSize: contentFontSize.wrappedValue
                )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(item: $selectedChapter) { chapter in
            SlokasView(
                chapterIndex: chapter.id,
                chapterTitle: selectedLanguage.chapterTitle(for: chapter),
                language: selectedLanguage
            )
        }
        .navigationTitle("Chapters")
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
    NavigationStack {
        ChaptersListView()
    }
}
