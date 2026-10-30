import XCTest
@testable import NotchitCore

final class SettingsTests: XCTestCase {
    func testDefaultsAreAlreadyClamped() {
        XCTAssertEqual(NotchSettings().clamped(), NotchSettings())
    }

    func testClampingKeepsValuesInRange() {
        var s = NotchSettings()
        s.openWidth = 5000
        s.openHeight = -3
        s.openDelay = .nan
        s.springDamping = 9
        let c = s.clamped()
        XCTAssertEqual(c.openWidth, NotchSettings.widthRange.upperBound)
        XCTAssertEqual(c.openHeight, NotchSettings.heightRange.lowerBound)
        XCTAssertEqual(c.openDelay, NotchSettings.openDelayRange.lowerBound)
        XCTAssertEqual(c.springDamping, NotchSettings.dampingRange.upperBound)
    }

    func testRoundTrip() throws {
        var s = NotchSettings()
        s.theme = .minuit
        s.openWidth = 640
        s.modules = [.init(.shelf), .init(.music, false), .init(.clock), .init(.battery)]
        s.shortcut = Shortcut(key: "K", command: true, option: false, control: true)
        let back = try NotchSettings.decode(s.encoded())
        XCTAssertEqual(back, s.clamped())
        XCTAssertEqual(Array(back.modules.prefix(4)), s.modules)
    }

    func testPartialImportKeepsDefaults() throws {
        let json = #"{"openWidth": 700, "theme": "sable"}"#.data(using: .utf8)!
        let s = try NotchSettings.decode(json)
        XCTAssertEqual(s.openWidth, 700)
        XCTAssertEqual(s.theme, .sable)
        XCTAssertEqual(s.openHeight, NotchSettings().openHeight)
        XCTAssertEqual(s.modules, NotchSettings().modules)
    }

    func testInvalidImportThrows() {
        XCTAssertThrowsError(try NotchSettings.decode(Data("[1,2]".utf8)))
        XCTAssertThrowsError(try NotchSettings.decode(Data(#"{"theme": "inconnu"}"#.utf8)))
    }

    func testModulesAreDedupedAndCompleted() {
        var s = NotchSettings()
        s.modules = [.init(.music), .init(.music, false)]
        let c = s.clamped()
        XCTAssertEqual(c.modules.count, ModuleKind.allCases.count)
        XCTAssertEqual(c.modules.first, ModuleEntry(.music, true))
        XCTAssertFalse(c.isEnabled(.shelf))
    }

    func testOrderedEnabledFollowsOrder() {
        var s = NotchSettings()
        s.modules = [.init(.shelf), .init(.battery, false), .init(.music), .init(.clock)]
        XCTAssertEqual(s.orderedEnabled, [.shelf, .music, .clock])
    }
}

final class ShortcutTests: XCTestCase {
    func testDisplayAndKeyCode() {
        let s = Shortcut(key: "n", command: true, option: true)
        XCTAssertEqual(s.display, "⌥⌘N")
        XCTAssertEqual(s.keyCode, 45)
        XCTAssertTrue(s.isValid)
    }

    func testEveryOfferedKeyHasACode() {
        for k in Shortcut.keys { XCTAssertNotNil(Shortcut(key: k).keyCode, k) }
    }

    func testShortcutWithoutModifierIsInvalid() {
        var s = NotchSettings()
        s.shortcut = Shortcut(key: "A", command: false, option: false, control: false, shift: true)
        XCTAssertFalse(s.shortcut.isValid)
        XCTAssertEqual(s.clamped().shortcut, Shortcut(key: "N"))
    }
}

final class ThemeTests: XCTestCase {
    func testPresetsAreReadable() {
        for t in ThemeID.allCases where t != .perso && t != .verre {
            let c = t.colors(custom: NotchSettings().custom)
            XCTAssertGreaterThanOrEqual(c.foreground.contrast(with: c.background), 7, t.name)
            XCTAssertGreaterThanOrEqual(c.secondary.contrast(with: c.background), 4.5, t.name)
        }
    }

    func testHexRoundTrip() {
        XCTAssertEqual(RGBA(hex: "#FF8000")?.hex, "#FF8000")
        XCTAssertNil(RGBA(hex: "zzz"))
        XCTAssertEqual(RGBA(hex: "00000080")?.a ?? 0, 128.0 / 255, accuracy: 0.001)
    }
}

final class GeometryTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let notch = CGSize(width: 185, height: 32)

    func testClosedHotRectIsCenteredUnderTopEdge() {
        let r = NotchGeometry.hotRect(screen: screen, notch: notch, expanded: false, activity: false, settings: NotchSettings())
        XCTAssertEqual(r.midX, screen.midX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.001)
        XCTAssertGreaterThan(r.width, notch.width)
    }

    func testActivityWidensClosedNotch() {
        let a = NotchGeometry.hotRect(screen: screen, notch: notch, expanded: false, activity: false, settings: NotchSettings())
        let b = NotchGeometry.hotRect(screen: screen, notch: notch, expanded: false, activity: true, settings: NotchSettings())
        XCTAssertEqual(b.width - a.width, 104, accuracy: 0.001)
    }

    func testOpenHotRectFollowsSettings() {
        var s = NotchSettings()
        s.openWidth = 700
        s.openHeight = 300
        let r = NotchGeometry.hotRect(screen: screen, notch: notch, expanded: true, activity: false, settings: s)
        XCTAssertEqual(r.width, 724, accuracy: 0.001)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.001)
    }

    func testPanelHoldsLargestNotch() {
        XCTAssertGreaterThanOrEqual(NotchGeometry.panelSize.width, NotchSettings.widthRange.upperBound + 60)
        XCTAssertGreaterThanOrEqual(NotchGeometry.panelSize.height, NotchSettings.heightRange.upperBound + 60)
    }

    func testCountdownRunsPausesAndResumes() {
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        var c = Countdown()
        XCTAssertFalse(c.isActive)
        c.start(300, now: t0)
        XCTAssertEqual(c.remaining(at: t0.addingTimeInterval(60)), 240)
        c.pause(now: t0.addingTimeInterval(100))
        XCTAssertFalse(c.isRunning)
        XCTAssertEqual(c.remaining(at: t0.addingTimeInterval(1000)), 200)
        c.resume(now: t0.addingTimeInterval(1000))
        XCTAssertEqual(c.remaining(at: t0.addingTimeInterval(1050)), 150)
        c.add(60, now: t0.addingTimeInterval(1050))
        XCTAssertEqual(c.remaining(at: t0.addingTimeInterval(1050)), 210)
        XCTAssertTrue(c.isFinished(at: t0.addingTimeInterval(1260)))
        c.cancel()
        XCTAssertFalse(c.isActive)
    }

    func testCountdownFormat() {
        XCTAssertEqual(Countdown.format(65), "1:05")
        XCTAssertEqual(Countdown.format(0.2), "0:01")
        XCTAssertEqual(Countdown.format(3725), "1:02:05")
    }

    func testTimerLastClamped() {
        var s = NotchSettings()
        s.timerLast = 0
        XCTAssertEqual(s.clamped().timerLast, 1)
        s.timerLast = 200_000
        XCTAssertEqual(s.clamped().timerLast, 86_399)
    }

    func testPagesFollowEnabledModules() {
        var s = NotchSettings()
        XCTAssertEqual(s.pages, [.media, .agenda, .files])
        XCTAssertEqual(s.modules(on: .agenda), [.calendar, .timer])
        XCTAssertEqual(s.modules(on: .files), [.mirror, .shelf])
        s.modules = s.modules.map { ModuleEntry($0.kind, $0.kind == .music || $0.kind == .battery) }
        XCTAssertEqual(s.pages, [.media])
        s.modules = s.modules.map { ModuleEntry($0.kind, $0.kind == .battery) }
        XCTAssertEqual(s.pages, [])
    }

    func testStopwatchAccumulates() {
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        var w = Stopwatch()
        w.start(now: t0)
        w.pause(now: t0.addingTimeInterval(10))
        XCTAssertEqual(w.elapsed(at: t0.addingTimeInterval(100)), 10)
        w.start(now: t0.addingTimeInterval(100))
        XCTAssertEqual(w.elapsed(at: t0.addingTimeInterval(105)), 15)
        w.reset()
        XCTAssertFalse(w.isActive)
    }

    func testPomodoroCycle() {
        let plan = PomodoroPlan(work: 25, shortBreak: 5, longBreak: 15, rounds: 2)
        var p = Pomodoro()
        XCTAssertEqual(p.minutes(plan), 25)
        XCTAssertEqual(p.title(plan), "Travail 1/2")
        p.advance(plan)
        XCTAssertEqual(p.minutes(plan), 5)
        p.advance(plan)
        XCTAssertEqual(p.title(plan), "Travail 2/2")
        p.advance(plan)
        XCTAssertEqual(p.minutes(plan), 15)
        XCTAssertEqual(p.title(plan), "Grande pause")
        p.advance(plan)
        XCTAssertEqual(p.title(plan), "Travail 1/2")
    }

    func testSnapshotRoundTripAndExpiry() throws {
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        var s = TimerSnapshot()
        s.countdown.start(60, now: t0)
        let back = try JSONDecoder().decode(TimerSnapshot.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
        XCTAssertTrue(back.restored(at: t0.addingTimeInterval(30)).isActive)
        XCTAssertFalse(back.restored(at: t0.addingTimeInterval(90)).isActive)
    }

    func testPomodoroPlanClamped() {
        var s = NotchSettings()
        s.pomodoro = PomodoroPlan(work: 0, shortBreak: 500, longBreak: 0, rounds: 99)
        XCTAssertEqual(s.clamped().pomodoro, PomodoroPlan(work: 1, shortBreak: 60, longBreak: 1, rounds: 12))
    }
}
