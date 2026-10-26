import XCTest
import SleeperKit
import SleeperKitMocks

final class ScoreDisplayTests: XCTestCase {
    private func snapshot(
        me: Double, opponent: Double?, isStale: Bool = false
    ) -> MatchupSnapshot {
        func team(_ id: Int, _ points: Double) -> TeamScore {
            TeamScore(rosterId: id, teamName: "Equipo \(id)", avatarURL: nil, points: points, starters: [])
        }
        return MatchupSnapshot(
            week: 7,
            me: team(1, me),
            opponent: opponent.map { team(2, $0) },
            fetchedAt: Date(timeIntervalSince1970: 0),
            isStale: isStale
        )
    }

    // MARK: Formato

    func testPointsUseOneDecimalWithDotRegardlessOfLocale() {
        XCTAssertEqual(ScoreDisplay.points(112.4), "112.4")
        XCTAssertEqual(ScoreDisplay.points(98.66), "98.7")
        XCTAssertEqual(ScoreDisplay.points(5), "5.0")
    }

    func testZeroShowsAsZeroPointZero() {
        XCTAssertEqual(ScoreDisplay.points(0), "0.0")
    }

    func testTinyNegativeNeverShowsMinusZero() {
        XCTAssertEqual(ScoreDisplay.points(-0.04), "0.0")
        XCTAssertEqual(ScoreDisplay.points(-1.26), "-1.3")
    }

    func testCompactTextUsesEnDashWithSpaces() {
        let text = ScoreDisplay.compactText(for: snapshot(me: 112.4, opponent: 98.7))
        XCTAssertEqual(text, "112.4 \u{2013} 98.7")
    }

    func testCompactTextWithoutOpponentIsSinMatchup() {
        XCTAssertEqual(ScoreDisplay.compactText(for: snapshot(me: 10, opponent: nil)), "Sin matchup")
    }

    func testAccessibilityLabel() {
        XCTAssertEqual(
            ScoreDisplay.accessibilityLabel(for: snapshot(me: 112.4, opponent: 98.7)),
            "Tú 112.4, rival 98.7"
        )
        XCTAssertEqual(
            ScoreDisplay.accessibilityLabel(for: snapshot(me: 10, opponent: nil)),
            "Sin matchup"
        )
    }

    func testAccessibilityLabelMentionsStaleDataNotOnlyColor() {
        XCTAssertEqual(
            ScoreDisplay.accessibilityLabel(for: snapshot(me: 112.4, opponent: 98.7, isStale: true)),
            "Tú 112.4, rival 98.7, desactualizado"
        )
        XCTAssertEqual(
            ScoreDisplay.accessibilityLabel(for: snapshot(me: 10, opponent: nil, isStale: true)),
            "Sin matchup, desactualizado"
        )
    }

    // MARK: Pie de la vista expandida

    func testFooterShowsSecondsSinceFetch() {
        let s = snapshot(me: 1, opponent: 2)
        let now = s.fetchedAt.addingTimeInterval(42.9)
        XCTAssertEqual(ScoreDisplay.footerText(for: s, now: now), "Actualizado hace 42 s")
    }

    func testFooterAdvancesWithTheClock() {
        let s = snapshot(me: 1, opponent: 2)
        XCTAssertEqual(ScoreDisplay.footerText(for: s, now: s.fetchedAt.addingTimeInterval(5)), "Actualizado hace 5 s")
        XCTAssertEqual(ScoreDisplay.footerText(for: s, now: s.fetchedAt.addingTimeInterval(6)), "Actualizado hace 6 s")
    }

    func testFooterNeverShowsNegativeSeconds() {
        let s = snapshot(me: 1, opponent: 2)
        XCTAssertEqual(ScoreDisplay.footerText(for: s, now: s.fetchedAt.addingTimeInterval(-3)), "Actualizado hace 0 s")
    }

    func testStaleFooterShowsMinutesWithAtLeastOne() {
        let s = snapshot(me: 1, opponent: 2, isStale: true)
        XCTAssertEqual(
            ScoreDisplay.footerText(for: s, now: s.fetchedAt.addingTimeInterval(20)),
            "Sin conexión · datos de hace 1 min")
        XCTAssertEqual(
            ScoreDisplay.footerText(for: s, now: s.fetchedAt.addingTimeInterval(190)),
            "Sin conexión · datos de hace 3 min")
    }

    // MARK: Color por estado

    func testWinningLosingTied() {
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 112.4, opponent: 98.7)), .winning)
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 98.7, opponent: 112.4)), .losing)
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 100, opponent: 100)), .tied)
    }

    func testToneComparesRoundedValuesShownOnScreen() {
        // 112.44 y 112.36 se ven como "112.4 – 112.4": no pueden salir en verde.
        let s = snapshot(me: 112.44, opponent: 112.36)
        XCTAssertEqual(ScoreDisplay.compactText(for: s), "112.4 \u{2013} 112.4")
        XCTAssertEqual(ScoreDisplay.tone(for: s), .tied)
    }

    func testNoOpponentIsNoMatchupTone() {
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 10, opponent: nil)), .noMatchup)
    }

    func testStaleOverridesWinningAndLosing() {
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 112.4, opponent: 98.7, isStale: true)), .stale)
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 98.7, opponent: 112.4, isStale: true)), .stale)
        XCTAssertEqual(ScoreDisplay.tone(for: snapshot(me: 10, opponent: nil, isStale: true)), .stale)
    }

    func testIsLeadingUsesDisplayedValue() {
        XCTAssertTrue(ScoreDisplay.isLeading(112.4, over: 98.7))
        XCTAssertFalse(ScoreDisplay.isLeading(112.44, over: 112.36))
        XCTAssertFalse(ScoreDisplay.isLeading(3, over: 3))
    }

    func testPreviewSnapshots() {
        XCTAssertEqual(ScoreDisplay.tone(for: .previewLive), .winning)
        XCTAssertEqual(ScoreDisplay.tone(for: .previewFinal), .winning)
        XCTAssertEqual(ScoreDisplay.tone(for: .previewBye), .noMatchup)
        XCTAssertEqual(ScoreDisplay.tone(for: .previewStale), .stale)
    }
}
