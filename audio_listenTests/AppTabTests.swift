import Testing
@testable import audio_listen

struct AppTabTests {
    @Test func firstReleaseShipsOnlyTheOriginalFourScreens() {
        #expect(ReleaseScope.shippingTabs == [.drill, .progress, .tuner, .settings])
    }

    @Test func chordScreensAreBuiltButNotShipped() {
        #expect(!ReleaseScope.shippingTabs.contains(.chords))
        #expect(!ReleaseScope.shippingTabs.contains(.suggest))
    }

    @Test func shippingTabsAreOrderedAsTheyAppearInTheCatalog() {
        let catalogOrder = AppTab.allCases.filter(ReleaseScope.shippingTabs.contains)
        #expect(ReleaseScope.shippingTabs == catalogOrder)
    }

    @Test func everyTabHasATitleAndASymbol() {
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.systemImage.isEmpty)
        }
    }

    @Test func titlesAreDistinct() {
        let titles = Set(AppTab.allCases.map(\.title))
        #expect(titles.count == AppTab.allCases.count)
    }
}
