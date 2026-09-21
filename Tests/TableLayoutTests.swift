import XCTest
@testable import iPinball

/// The layout is pure data, so the table can be proven sane without ever
/// rendering it: nothing off the playfield, nothing stacked on top of
/// anything else, and the flippers where a pinball player expects them.
final class TableLayoutTests: XCTestCase {

    func testEveryElementSitsOnTheTable() {
        for element in TableLayout.allElementCentres {
            XCTAssertTrue(TableLayout.contains(element.point),
                          "\(element.name) is off the playfield at \(element.point)")
            XCTAssertGreaterThan(element.point.y, 0.05,
                                 "\(element.name) is inside the drain")
            XCTAssertLessThan(element.point.y, TableLayout.height,
                              "\(element.name) is above the top arc")
        }
    }

    func testNoTwoElementsOverlap() {
        let elements = TableLayout.allElementCentres
        for (index, a) in elements.enumerated() {
            for b in elements[(index + 1)...] {
                let distance = a.point.distance(to: b.point)
                XCTAssertGreaterThan(distance, a.radius + b.radius,
                                     "\(a.name) overlaps \(b.name)")
            }
        }
    }

    func testTheBallFitsThroughEveryGapItHasToPass() {
        let diameter = TableLayout.ballRadius * 2

        let laneGap = TableLayout.rollovers[1].center.x - TableLayout.rollovers[0].center.x
        XCTAssertGreaterThan(laneGap, diameter, "the P-I-N-B lanes are too narrow")

        let shooterWidth = TableLayout.width - 0.01 - TableLayout.playfieldRightEdge
        XCTAssertGreaterThan(shooterWidth, diameter, "the shooter lane is too narrow")
    }

    func testTheFlippersAreMirroredAndLeaveADrainGap() {
        let lower = TableLayout.flippers.filter { !$0.isUpper }
        XCTAssertEqual(lower.count, 2)

        guard let left = lower.first(where: { $0.side == .left }),
              let right = lower.first(where: { $0.side == .right }) else {
            return XCTFail("expected one lower flipper per side")
        }

        XCTAssertEqual(left.pivot.x, 1 - right.pivot.x, accuracy: 0.0001)
        XCTAssertEqual(left.pivot.y, right.pivot.y, accuracy: 0.0001)

        // The real gap is measured at the rest angle, in TableClearanceTests;
        // this only checks the pivots are far enough apart to leave one at all.
        XCTAssertGreaterThan((right.pivot.x - left.pivot.x) - 2 * left.length,
                             TableLayout.ballRadius,
                             "the flippers meet, so nothing can ever drain")
    }

    func testTheSlingshotsAreMirrored() {
        guard let left = TableLayout.slingshots.first(where: { $0.side == .left }),
              let right = TableLayout.slingshots.first(where: { $0.side == .right }) else {
            return XCTFail("expected one slingshot per side")
        }
        for (l, r) in zip(left.vertices, right.vertices) {
            XCTAssertEqual(l.x, 1 - r.x, accuracy: 0.0001)
            XCTAssertEqual(l.y, r.y, accuracy: 0.0001)
        }
    }

    func testTheRampsAreMirroredAndRunUphill() {
        guard let left = TableLayout.ramps.first(where: { $0.side == .left }),
              let right = TableLayout.ramps.first(where: { $0.side == .right }) else {
            return XCTFail("expected one ramp per side")
        }
        XCTAssertEqual(left.path.count, right.path.count)
        for (l, r) in zip(left.path, right.path) {
            XCTAssertEqual(l.x, 1 - r.x, accuracy: 0.0001)
            XCTAssertEqual(l.y, r.y, accuracy: 0.0001)
        }

        for ramp in TableLayout.ramps {
            guard let entrance = ramp.path.first, let peak = ramp.path.max(by: { $0.y < $1.y })
            else { return XCTFail("a ramp needs a path") }
            XCTAssertGreaterThan(peak.y, entrance.y, "the ramp does not climb")
        }
    }

    func testTheBallStartsInTheShooterLane() {
        let start = TableLayout.ballStart
        XCTAssertGreaterThan(start.x, TableLayout.playfieldRightEdge,
                             "the ball would start on the playfield")
        XCTAssertLessThan(start.x, TableLayout.width)
        XCTAssertGreaterThan(start.y, TableLayout.shooterLaneBottomY)
    }

    func testTheDrainSpansTheBottomOfTheTable() {
        XCTAssertEqual(TableLayout.drainRect.minX, 0, accuracy: 0.0001)
        XCTAssertEqual(TableLayout.drainRect.maxX, TableLayout.width, accuracy: 0.0001)
        XCTAssertLessThan(TableLayout.drainRect.minY, 0, "the drain must sit below the table")
    }

    func testTheTableIsTallerThanItIsWide() {
        XCTAssertGreaterThan(TableLayout.aspectRatio, 1.5)
    }

    func testThereIsOneRolloverPerLetter() {
        XCTAssertEqual(TableLayout.rollovers.count, LaneLetter.allCases.count)
        XCTAssertEqual(Set(TableLayout.rollovers.map(\.index)).count,
                       TableLayout.rollovers.count)
    }
}

final class TableGeometryTests: XCTestCase {

    func testTheTableIsCentredAndUniformlyScaled() {
        let geometry = TableGeometry(sceneSize: CGSize(width: 400, height: 900))

        // One scale for both axes, or circles would render as ellipses.
        let expected = 400 / TableLayout.width
        XCTAssertEqual(geometry.length(1), expected, accuracy: 0.001)

        let bottomLeft = geometry.point(CGPoint(x: 0, y: 0))
        let topRight = geometry.point(CGPoint(x: TableLayout.width, y: TableLayout.height))
        XCTAssertEqual(bottomLeft.x, 0, accuracy: 0.001)
        XCTAssertEqual(topRight.x, 400, accuracy: 0.001)
        XCTAssertEqual((900 - (topRight.y - bottomLeft.y)) / 2, bottomLeft.y, accuracy: 0.001)
    }

    func testAWideSceneFitsToHeightInstead() {
        let geometry = TableGeometry(sceneSize: CGSize(width: 2_000, height: 900))
        XCTAssertEqual(geometry.length(TableLayout.height), 900, accuracy: 0.001)
        XCTAssertGreaterThan(geometry.origin.x, 0, "the table is centred horizontally")
    }
}

final class PersistenceTests: XCTestCase {

    func testHighScoresStaySortedAndCapped() {
        var data = SavedData()
        for score in stride(from: 1_000, through: 30_000, by: 1_000) {
            data.insert(HighScore(initials: "DAM", score: score, missionsCompleted: 0))
        }
        XCTAssertEqual(data.highScores.count, SavedData.highScoreCount)
        XCTAssertEqual(data.highScores.map(\.score), data.highScores.map(\.score).sorted(by: >))
        XCTAssertEqual(data.highScores.first?.score, 30_000)
    }

    func testRankIsNilForAScoreThatDoesNotMakeTheTable() {
        var data = SavedData()
        for score in stride(from: 100_000, through: 1_000_000, by: 100_000) {
            data.insert(HighScore(initials: "DAM", score: score, missionsCompleted: 0))
        }
        XCTAssertNil(data.rank(for: 1))
        XCTAssertEqual(data.rank(for: 2_000_000), 0)
        XCTAssertNil(data.rank(for: 0), "a scoreless game never makes the table")
    }

    func testInitialsAreTrimmedAndUppercased() {
        let entry = HighScore(initials: "david", score: 10, missionsCompleted: 0)
        XCTAssertEqual(entry.initials, "DAV")
    }

    func testSavedDataSurvivesARoundTrip() throws {
        var original = SavedData()
        original.settings.language = .pt
        original.settings.theme = .dark
        original.insert(HighScore(initials: "DAM", score: 1_234, missionsCompleted: 2))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedData.self, from: encoded)

        XCTAssertEqual(decoded.settings, original.settings)
        XCTAssertEqual(decoded.highScores.first?.score, 1_234)
    }

    func testAnEmptyStoreReturnsDefaults() {
        let defaults = UserDefaults(suiteName: "iPinballTests.\(UUID().uuidString)")!
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.load(), SavedData())
    }

    func testStoredDataComesBackOut() {
        let defaults = UserDefaults(suiteName: "iPinballTests.\(UUID().uuidString)")!
        let store = GameStore(defaults: defaults)

        var data = SavedData()
        data.settings.language = .en
        data.lifetime.gamesPlayed = 7
        store.save(data)

        XCTAssertEqual(store.load().lifetime.gamesPlayed, 7)
        store.clear()
        XCTAssertEqual(store.load().lifetime.gamesPlayed, 0)
    }
}

final class LocalizationTests: XCTestCase {

    func testEveryStringExistsInBothLanguages() {
        for (key, pair) in Strings.all {
            XCTAssertFalse(pair.pt.isEmpty, "\(key) has no Portuguese text")
            XCTAssertFalse(pair.en.isEmpty, "\(key) has no English text")
        }
    }

    func testEveryMissionHasANameAndAGoalInBothLanguages() {
        for mission in MissionEngine.catalog {
            XCTAssertNotNil(Strings.all["mission.\(mission.id).name"],
                            "\(mission.id) has no name")
            XCTAssertNotNil(Strings.all["mission.\(mission.id).goal"],
                            "\(mission.id) has no goal")
        }
    }

    func testTheCreditIsTheSameInBothLanguages() {
        let credit = Strings.all["about.developedBy"]
        XCTAssertEqual(credit?.pt, "Developed by David Arsénio Martins")
        XCTAssertEqual(credit?.en, "Developed by David Arsénio Martins")
    }

    func testPortugueseDoesNotUseBrazilianForms() {
        // A house rule: PT-PT throughout, never PT-BR.
        let banned = [" pra ", "você", " tela ", " time "]
        for (key, pair) in Strings.all {
            let text = " \(pair.pt.lowercased()) "
            for term in banned {
                XCTAssertFalse(text.contains(term), "\(key) uses \"\(term.trimmingCharacters(in: .whitespaces))\"")
            }
        }
    }
}
