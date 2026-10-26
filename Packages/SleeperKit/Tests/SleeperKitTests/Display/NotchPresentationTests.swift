import XCTest
import SleeperKit

final class NotchPresentationTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    func testStartsHiddenAndShowGoesToCompactOnce() {
        var machine = NotchPresentationMachine()
        XCTAssertEqual(machine.presentation, .hidden)
        XCTAssertEqual(machine.show(), .compact)
        XCTAssertEqual(machine.presentation, .compact)
        XCTAssertNil(machine.show(), "un segundo snapshot solo actualiza valores")
    }

    func testExpandOnlyFromCompact() {
        var machine = NotchPresentationMachine()
        XCTAssertNil(machine.expand(viaHover: false, now: t0), "hidden no expande")
        _ = machine.show()
        XCTAssertEqual(machine.expand(viaHover: false, now: t0), .expanded)
        XCTAssertNil(machine.expand(viaHover: false, now: t0), "ya expandida")
    }

    func testCollapseOnlyFromExpanded() {
        var machine = NotchPresentationMachine()
        XCTAssertNil(machine.collapse(now: t0))
        _ = machine.show()
        XCTAssertNil(machine.collapse(now: t0), "compacta no colapsa")
        _ = machine.expand(viaHover: false, now: t0)
        XCTAssertEqual(machine.collapse(now: t0), .compact)
    }

    func testHoverExpandIsIgnoredRightAfterCollapseButClickIsNot() {
        var machine = NotchPresentationMachine()
        _ = machine.show()
        _ = machine.expand(viaHover: true, now: t0)
        _ = machine.collapse(now: t0)
        let soon = t0.addingTimeInterval(NotchPresentationMachine.hoverCooldown - 0.1)
        XCTAssertNil(machine.expand(viaHover: true, now: soon), "las zonas reaparecen bajo el puntero")
        XCTAssertEqual(machine.expand(viaHover: false, now: soon), .expanded, "el clic siempre expande")
    }

    func testHoverExpandWorksAfterCooldown() {
        var machine = NotchPresentationMachine()
        _ = machine.show()
        _ = machine.expand(viaHover: true, now: t0)
        _ = machine.collapse(now: t0)
        let later = t0.addingTimeInterval(NotchPresentationMachine.hoverCooldown + 0.1)
        XCTAssertEqual(machine.expand(viaHover: true, now: later), .expanded)
    }

    func testCloseFromAnyVisibleStateGoesHidden() {
        var machine = NotchPresentationMachine()
        XCTAssertNil(machine.close())
        _ = machine.show()
        XCTAssertEqual(machine.close(), .hidden)
        _ = machine.show()
        _ = machine.expand(viaHover: false, now: t0)
        XCTAssertEqual(machine.close(), .hidden)
        XCTAssertEqual(machine.show(), .compact, "se puede volver a mostrar")
    }

    func testPointerLeavingSchedulesCollapseOnlyWhenExpanded() {
        var machine = NotchPresentationMachine()
        XCTAssertFalse(machine.shouldCollapseOnHoverChange(inside: false))
        _ = machine.show()
        XCTAssertFalse(machine.shouldCollapseOnHoverChange(inside: false))
        _ = machine.expand(viaHover: false, now: t0)
        XCTAssertFalse(machine.shouldCollapseOnHoverChange(inside: true))
        XCTAssertTrue(machine.shouldCollapseOnHoverChange(inside: false))
    }
}
