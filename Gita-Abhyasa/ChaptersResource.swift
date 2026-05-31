import Foundation

public struct Chapter: Identifiable, Hashable, Codable {
    public let id: Int
    public let english: String
    public let sanskrit: String
    public let slokaCount: Int
}

private struct ChaptersFile: Decodable {
    let chapters: [Chapter]
}

public enum ChaptersResource {
    private static var cachedChapters: [Chapter]? = nil

    public static var chapters: [Chapter] {
        if let cached = cachedChapters { return cached }
        guard let url = Bundle.main.url(forResource: "chapters", withExtension: "json") else {
            cachedChapters = []
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ChaptersFile.self, from: data)
            cachedChapters = decoded.chapters
            return decoded.chapters
        } catch {
            cachedChapters = []
            return []
        }
    }

    public static func slokaCount(for chapterId: Int) -> Int? {
        chapters.first(where: { $0.id == chapterId })?.slokaCount
    }
}
