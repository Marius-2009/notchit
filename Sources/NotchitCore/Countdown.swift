import Foundation

public struct Countdown: Codable, Equatable, Sendable {
    public private(set) var duration: TimeInterval = 0
    public private(set) var end: Date?
    public private(set) var pausedRemaining: TimeInterval?

    public init() {}

    public var isActive: Bool { end != nil || pausedRemaining != nil }
    public var isRunning: Bool { end != nil }

    public func remaining(at now: Date) -> TimeInterval {
        if let end { return max(0, end.timeIntervalSince(now)) }
        return pausedRemaining ?? 0
    }

    public func progress(at now: Date) -> Double {
        duration > 0 ? 1 - remaining(at: now) / duration : 0
    }

    public func isFinished(at now: Date) -> Bool {
        guard let end else { return false }
        return now >= end
    }

    public mutating func start(_ seconds: TimeInterval, now: Date) {
        duration = max(1, seconds)
        end = now.addingTimeInterval(duration)
        pausedRemaining = nil
    }

    public mutating func pause(now: Date) {
        guard let end else { return }
        pausedRemaining = max(0, end.timeIntervalSince(now))
        self.end = nil
    }

    public mutating func resume(now: Date) {
        guard let r = pausedRemaining else { return }
        end = now.addingTimeInterval(r)
        pausedRemaining = nil
    }

    public mutating func add(_ seconds: TimeInterval, now: Date) {
        duration += seconds
        if let end { self.end = end.addingTimeInterval(seconds) }
        else if let r = pausedRemaining { pausedRemaining = r + seconds }
    }

    public mutating func cancel() {
        self = Countdown()
    }

    public static func format(_ t: TimeInterval, roundUp: Bool = true) -> String {
        let s = Int(roundUp ? t.rounded(.up) : t.rounded(.down))
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

public struct Stopwatch: Codable, Equatable, Sendable {
    public private(set) var started: Date?
    public private(set) var accumulated: TimeInterval = 0

    public init() {}

    public var isRunning: Bool { started != nil }
    public var isActive: Bool { isRunning || accumulated > 0 }

    public func elapsed(at now: Date) -> TimeInterval {
        accumulated + (started.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    public mutating func start(now: Date) {
        if started == nil { started = now }
    }

    public mutating func pause(now: Date) {
        guard let s = started else { return }
        accumulated += max(0, now.timeIntervalSince(s))
        started = nil
    }

    public mutating func reset() { self = Stopwatch() }
}

public enum TimerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case timer, pomodoro, stopwatch

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .timer: return "Minuteur"
        case .pomodoro: return "Pomodoro"
        case .stopwatch: return "Chrono"
        }
    }

    public var symbol: String {
        switch self {
        case .timer: return "timer"
        case .pomodoro: return "target"
        case .stopwatch: return "stopwatch"
        }
    }
}

public struct PomodoroPlan: Codable, Equatable, Sendable {
    public var work: Int
    public var shortBreak: Int
    public var longBreak: Int
    public var rounds: Int

    public init(work: Int = 25, shortBreak: Int = 5, longBreak: Int = 15, rounds: Int = 4) {
        self.work = work
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.rounds = rounds
    }

    public func clamped() -> PomodoroPlan {
        PomodoroPlan(work: min(120, max(1, work)), shortBreak: min(60, max(1, shortBreak)),
                     longBreak: min(90, max(1, longBreak)), rounds: min(12, max(1, rounds)))
    }
}

public struct Pomodoro: Codable, Equatable, Sendable {
    public private(set) var round = 1
    public private(set) var onBreak = false

    public init() {}

    public func isLongBreak(_ plan: PomodoroPlan) -> Bool { onBreak && round >= plan.rounds }

    public func minutes(_ plan: PomodoroPlan) -> Int {
        if !onBreak { return plan.work }
        return isLongBreak(plan) ? plan.longBreak : plan.shortBreak
    }

    public func title(_ plan: PomodoroPlan) -> String {
        if !onBreak { return "Travail \(round)/\(plan.rounds)" }
        return isLongBreak(plan) ? "Grande pause" : "Pause"
    }

    public mutating func advance(_ plan: PomodoroPlan) {
        if onBreak {
            onBreak = false
            round = round >= plan.rounds ? 1 : round + 1
        } else {
            onBreak = true
        }
    }

    public mutating func reset() { self = Pomodoro() }
}

public struct TimerSnapshot: Codable, Equatable, Sendable {
    public var mode: TimerMode = .timer
    public var countdown = Countdown()
    public var stopwatch = Stopwatch()
    public var pomodoro = Pomodoro()

    public init() {}

    public var isActive: Bool {
        mode == .stopwatch ? stopwatch.isActive : countdown.isActive
    }

    public var isRunning: Bool {
        mode == .stopwatch ? stopwatch.isRunning : countdown.isRunning
    }

    public func restored(at now: Date) -> TimerSnapshot {
        var s = self
        if s.countdown.isFinished(at: now) {
            s.countdown.cancel()
            s.pomodoro.reset()
        }
        return s
    }
}
