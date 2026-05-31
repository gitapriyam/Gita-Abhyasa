import Foundation
import Testing
@testable import Gita_Abhyasa

@MainActor
struct Gita_AbhyasaTests {
    @Test func searchResultDecodesSupportedKeyVariants() throws {
        let json = Data(#"""
        {
            "chapterId": "2",
            "verseNumber": "47",
            "text": "कर्मण्येवाधिकारस्ते",
            "translation": "You have a right to action alone."
        }
        """#.utf8)

        let result = try JSONDecoder().decode(SlokaSearchResult.self, from: json)

        #expect(result.chapter == 2)
        #expect(result.slokaNumber == 47)
        #expect(result.sloka == "कर्मण्येवाधिकारस्ते")
        #expect(result.meaning == "You have a right to action alone.")
        #expect(result.headerTitle == "Chapter-02, Sloka 47")
    }

    @Test func searchResponseDecodesWrappedResults() throws {
        let json = Data(#"""
        {
            "results": [
                {
                    "chapter": 1,
                    "slokaNumber": 1,
                    "sloka": "धृतराष्ट्र उवाच",
                    "meaning": "Dhritarashtra said"
                }
            ]
        }
        """#.utf8)

        let response = try JSONDecoder().decode(SlokaSearchResponse.self, from: json)

        #expect(response.results.count == 1)
        #expect(response.results.first?.chapter == 1)
        #expect(response.results.first?.slokaNumber == 1)
        #expect(response.results.first?.sloka == "धृतराष्ट्र उवाच")
    }

    @Test func searchResponseDecodesTopLevelArray() throws {
        let json = Data(#"""
        [
            {
                "chapterNumber": 18,
                "slokaId": 66,
                "content": "सर्वधर्मान्परित्यज्य",
                "meaning": "Abandon all duties"
            }
        ]
        """#.utf8)

        let response = try JSONDecoder().decode(SlokaSearchResponse.self, from: json)

        #expect(response.results.count == 1)
        #expect(response.results[0].chapter == 18)
        #expect(response.results[0].slokaNumber == 66)
        #expect(response.results[0].sloka == "सर्वधर्मान्परित्यज्य")
    }

    @Test func searchRequestBuildsURLWithQueryItems() throws {
        let configuration = AppConfiguration(
            slokaAPIBaseURL: try #require(URL(string: "https://example.com"))
        )
        let url = try SlokaSearchRequest(
            searchText: "karma yoga",
            language: .english,
            limit: 20,
            configuration: configuration
        ).url()
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.scheme == "https")
        #expect(components.host == "example.com")
        #expect(components.path == "/api/slokaSearch")
        #expect(queryItems["searchText"] == "karma yoga")
        #expect(queryItems["top"] == "20")
        #expect(queryItems["lang"] == "english")
    }

    @Test func searchRequestPreservesBasePath() throws {
        let configuration = AppConfiguration(
            slokaAPIBaseURL: try #require(URL(string: "https://example.com/dev"))
        )
        let url = try SlokaSearchRequest(
            searchText: "कृष्ण",
            language: .sanskrit,
            limit: 10,
            configuration: configuration
        ).url()
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.path == "/dev/api/slokaSearch")
        #expect(queryItems["searchText"] == "कृष्ण")
        #expect(queryItems["lang"] == "sanskrit")
    }

    @Test func appConfigurationUsesProductionForInvalidEnvironmentURL() {
        let configuration = AppConfiguration.current(
            environment: ["GITA_SLOKA_API_BASE_URL": "not a url"]
        )

        #expect(configuration.slokaAPIBaseURL == AppConfiguration.production.slokaAPIBaseURL)
    }

    @Test func appConfigurationUsesValidEnvironmentURL() throws {
        let url = try #require(URL(string: "https://local.example.com"))
        let configuration = AppConfiguration.current(
            environment: ["GITA_SLOKA_API_BASE_URL": url.absoluteString]
        )

        #expect(configuration.slokaAPIBaseURL == url)
    }
}
