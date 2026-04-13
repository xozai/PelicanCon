import XCTest
@testable import PelicanCon

final class BadgeTypeTests: XCTestCase {

    // MARK: - Raw values

    func testRawValues() {
        XCTAssertEqual(BadgeType.earlyBird.rawValue,       "early_bird")
        XCTAssertEqual(BadgeType.socialButterfly.rawValue, "social_butterfly")
        XCTAssertEqual(BadgeType.shutterbug.rawValue,      "shutterbug")
        XCTAssertEqual(BadgeType.checkedIn.rawValue,       "checked_in")
    }

    func testIdEqualsRawValue() {
        for badge in BadgeType.allCases {
            XCTAssertEqual(badge.id, badge.rawValue)
        }
    }

    // MARK: - allCases

    func testAllCasesCount() {
        XCTAssertEqual(BadgeType.allCases.count, 4)
    }

    func testAllCasesContainsEveryType() {
        let cases = Set(BadgeType.allCases.map(\.rawValue))
        XCTAssertTrue(cases.contains("early_bird"))
        XCTAssertTrue(cases.contains("social_butterfly"))
        XCTAssertTrue(cases.contains("shutterbug"))
        XCTAssertTrue(cases.contains("checked_in"))
    }

    // MARK: - displayName

    func testDisplayNames() {
        XCTAssertEqual(BadgeType.earlyBird.displayName,       "Early Bird")
        XCTAssertEqual(BadgeType.socialButterfly.displayName, "Social Butterfly")
        XCTAssertEqual(BadgeType.shutterbug.displayName,      "Shutterbug")
        XCTAssertEqual(BadgeType.checkedIn.displayName,       "Checked In")
    }

    func testDisplayNamesAreNonEmpty() {
        for badge in BadgeType.allCases {
            XCTAssertFalse(badge.displayName.isEmpty)
        }
    }

    // MARK: - description

    func testDescriptions() {
        XCTAssertEqual(BadgeType.earlyBird.description,       "Among the first to join")
        XCTAssertEqual(BadgeType.socialButterfly.description, "Sent 10+ messages")
        XCTAssertEqual(BadgeType.shutterbug.description,      "Shared 5+ photos")
        XCTAssertEqual(BadgeType.checkedIn.description,       "Checked in at the reunion")
    }

    func testDescriptionsAreNonEmpty() {
        for badge in BadgeType.allCases {
            XCTAssertFalse(badge.description.isEmpty)
        }
    }

    // MARK: - icon (SF Symbol names)

    func testIcons() {
        XCTAssertEqual(BadgeType.earlyBird.icon,       "bird.fill")
        XCTAssertEqual(BadgeType.socialButterfly.icon, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(BadgeType.shutterbug.icon,      "camera.fill")
        XCTAssertEqual(BadgeType.checkedIn.icon,       "checkmark.seal.fill")
    }

    func testIconsAreNonEmpty() {
        for badge in BadgeType.allCases {
            XCTAssertFalse(badge.icon.isEmpty)
        }
    }

    // MARK: - Codable

    func testCodableRoundtrip() throws {
        for badge in BadgeType.allCases {
            let data    = try JSONEncoder().encode(badge)
            let decoded = try JSONDecoder().decode(BadgeType.self, from: data)
            XCTAssertEqual(decoded, badge)
        }
    }

    func testDecodingFromRawValue() throws {
        let json = Data("\"early_bird\"".utf8)
        let badge = try JSONDecoder().decode(BadgeType.self, from: json)
        XCTAssertEqual(badge, .earlyBird)
    }

    func testDecodingInvalidRawValueThrows() {
        let json = Data("\"unknown_badge\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(BadgeType.self, from: json))
    }
}
