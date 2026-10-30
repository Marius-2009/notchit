import AppKit
import NotchitCore

final class TimerModel: ObservableObject {
    @Published private(set) var state: TimerSnapshot
    @Published private(set) var now = Date()
    var onFinish: ((String) -> Void)?
    var plan: () -> PomodoroPlan = { PomodoroPlan() }
    var autoNext: () -> Bool = { true }
    private var tick: Timer?
    private static let key = "timer.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(TimerSnapshot.self, from: data) {
            state = saved.restored(at: Date())
        } else {
            state = TimerSnapshot()
        }
        if state.isRunning { run() }
    }

    var mode: TimerMode { state.mode }
    var countdown: Countdown { state.countdown }
    var isActive: Bool { state.isActive }
    var isRunning: Bool { state.isRunning }

    var remaining: TimeInterval {
        mode == .stopwatch ? state.stopwatch.elapsed(at: now) : state.countdown.remaining(at: now)
    }

    var progress: Double {
        mode == .stopwatch ? (remaining.truncatingRemainder(dividingBy: 60)) / 60 : state.countdown.progress(at: now)
    }

    var label: String {
        mode == .stopwatch ? Countdown.format(remaining, roundUp: false) : Countdown.format(remaining)
    }

    var title: String {
        switch mode {
        case .timer: return "Minuteur"
        case .pomodoro: return state.pomodoro.title(plan())
        case .stopwatch: return "Chrono"
        }
    }

    var pomodoroMinutes: Int { state.pomodoro.minutes(plan()) }

    func select(_ mode: TimerMode) {
        guard !isActive, state.mode != mode else { return }
        state.mode = mode
        save()
    }

    func start(seconds: Int) {
        state.mode = .timer
        state.countdown.start(TimeInterval(seconds), now: Date())
        run()
    }

    func startPomodoro() {
        state.mode = .pomodoro
        state.countdown.start(TimeInterval(state.pomodoro.minutes(plan()) * 60), now: Date())
        run()
    }

    func startStopwatch() {
        state.mode = .stopwatch
        state.stopwatch.start(now: Date())
        run()
    }

    func toggle() {
        let t = Date()
        if mode == .stopwatch {
            if state.stopwatch.isRunning { state.stopwatch.pause(now: t); stopTicking() } else { state.stopwatch.start(now: t); run() }
        } else if state.countdown.isRunning {
            state.countdown.pause(now: t)
            stopTicking()
        } else {
            state.countdown.resume(now: t)
            run()
        }
        save()
    }

    func addMinute() {
        guard mode != .stopwatch else { return }
        state.countdown.add(60, now: Date())
        now = Date()
        save()
    }

    func skipPhase() {
        guard mode == .pomodoro else { return }
        state.pomodoro.advance(plan())
        startPomodoro()
    }

    func cancel() {
        state.countdown.cancel()
        state.stopwatch.reset()
        state.pomodoro.reset()
        stopTicking()
        save()
    }

    private func run() {
        now = Date()
        tick?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(t, forMode: .common)
        tick = t
        save()
    }

    private func step() {
        now = Date()
        guard mode != .stopwatch, state.countdown.isFinished(at: now) else { return }
        if mode == .pomodoro {
            let ended = state.pomodoro.onBreak ? "Pause terminée" : "Session de travail terminée"
            state.pomodoro.advance(plan())
            if autoNext() {
                startPomodoro()
            } else {
                state.countdown.cancel()
                stopTicking()
                save()
            }
            onFinish?(ended)
        } else {
            state.countdown.cancel()
            stopTicking()
            save()
            onFinish?("Minuteur terminé")
        }
    }

    private func stopTicking() {
        tick?.invalidate()
        tick = nil
        now = Date()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
