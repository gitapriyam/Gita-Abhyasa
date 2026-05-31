import SwiftUI

struct ChapterRowView: View {
    let chapter: Chapter
    let language: ContentLanguage
    let fontSize: CGFloat

    private var primaryTitle: String {
        language.chapterTitle(for: chapter)
    }

    private var secondaryTitle: String? {
        switch language {
        case .english:
            return chapter.sanskrit
        case .sanskrit:
            return chapter.english
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(primaryTitle)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let secondaryTitle, secondaryTitle != primaryTitle {
                    Text(secondaryTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Label("\(chapter.slokaCount) slokas", systemImage: "text.book.closed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

}
