import SwiftUI
import NotchitCore

struct Placeholder: View {
    let symbol: String
    let text: String
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
            Text(text).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center)
        }
        .foregroundStyle(settings.colors.secondary.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CardTitle: View {
    let text: String
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(settings.colors.secondary.color)
    }
}

struct PillButton: View {
    let title: String
    var prominent = false
    let action: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @State private var hover = false

    var body: some View {
        let c = settings.colors
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(Capsule().fill(prominent ? c.accent.color.opacity(hover ? 1 : 0.85) : c.foreground.color.opacity(hover ? 0.16 : 0.09)))
                .foregroundStyle(prominent ? (c.accent.luminance > 0.5 ? Color.black : Color.white) : c.foreground.color)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct CalendarCard: View {
    var maxItems = 3
    @EnvironmentObject var calendar: CalendarModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        let c = settings.colors
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                CardTitle(text: Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                CardTitle(text: Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
            }
            switch calendar.access {
            case .unknown:
                Text("Notchit a besoin d'accéder au calendrier pour afficher vos prochains événements.")
                    .font(.system(size: 11)).foregroundStyle(c.secondary.color)
                    .fixedSize(horizontal: false, vertical: true)
                PillButton(title: "Autoriser", prominent: true) { calendar.requestAccess() }
            case .denied:
                Text("Accès au calendrier refusé.")
                    .font(.system(size: 11)).foregroundStyle(c.secondary.color)
                PillButton(title: "Ouvrir les réglages") { calendar.openPrivacySettings() }
            case .granted:
                if calendar.items.isEmpty {
                    Text("Rien de prévu d'ici demain soir")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(c.secondary.color)
                } else {
                    ForEach(calendar.items.prefix(maxItems)) { EventRow(item: $0) }
                    if calendar.items.count > maxItems {
                        Text(calendar.items.count - maxItems == 1 ? "+ 1 autre" : "+ \(calendar.items.count - maxItems) autres")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(c.secondary.color)
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    let item: CalendarItem
    @EnvironmentObject var settings: SettingsStore

    private var when: String {
        let cal = Calendar.current
        let now = Date()
        let prefix = cal.isDateInTomorrow(item.start) ? "Demain " : ""
        if item.allDay { return prefix.isEmpty ? "Toute la journée" : "Demain, toute la journée" }
        if item.start <= now { return "En cours, jusqu'à " + item.end.formatted(date: .omitted, time: .shortened) }
        let minutes = Int(item.start.timeIntervalSince(now) / 60)
        if minutes < 60 && prefix.isEmpty { return "Dans \(max(1, minutes)) min" }
        return prefix + item.start.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        let c = settings.colors
        HStack(alignment: .top, spacing: 7) {
            Capsule().fill(Color(nsColor: item.color)).frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(when).font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(c.secondary.color).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum TimerStyle {
    static let orange = Color(red: 1, green: 0.624, blue: 0.039)
}

struct RoundButton: View {
    let symbol: String
    let tint: Color
    let fill: Color
    let label: String
    var size: CGFloat = 40
    let action: () -> Void
    @State private var hover = false
    @State private var down = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(fill.opacity(hover ? 1 : 0.85)))
                .scaleEffect(down ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in withAnimation(.easeOut(duration: 0.08)) { down = true } }
            .onEnded { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { down = false } })
        .accessibilityLabel(label)
    }
}

struct TimerCard: View {
    @EnvironmentObject var timer: TimerModel
    @EnvironmentObject var settings: SettingsStore

    private let orange = TimerStyle.orange

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            Group {
                if !timer.isActive {
                    idle(w: w, h: h)
                } else if w >= 190 && h >= 84 {
                    wide(w: w, h: h)
                } else {
                    compact(w: w, h: h)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: timer.isActive)
        .animation(.easeOut(duration: 0.2), value: timer.mode)
    }

    private var title: some View {
        HStack(spacing: 5) {
            Image(systemName: timer.mode.symbol)
            Text(timer.title).lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(orange)
    }

    private var digits: String { timer.label }

    private func ring(_ d: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle().stroke(orange.opacity(0.22), lineWidth: line)
            Circle().trim(from: 0, to: max(0.001, timer.mode == .stopwatch ? timer.progress : 1 - timer.progress))
                .stroke(orange, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: timer.progress)
        }
        .frame(width: d, height: d)
    }

    private func pauseButton(_ size: CGFloat) -> some View {
        RoundButton(symbol: timer.isRunning ? "pause.fill" : "play.fill", tint: orange, fill: orange.opacity(0.24),
                    label: timer.isRunning ? "Mettre en pause" : "Reprendre", size: size) { timer.toggle() }
    }

    private func stopButton(_ size: CGFloat) -> some View {
        RoundButton(symbol: "xmark", tint: settings.colors.foreground.color, fill: settings.colors.foreground.color.opacity(0.16),
                    label: timer.mode == .stopwatch ? "Remettre à zéro" : "Arrêter", size: size) { timer.cancel() }
    }

    @ViewBuilder private var extra: some View {
        switch timer.mode {
        case .timer: pill("+1 min", label: "Ajouter une minute") { timer.addMinute() }
        case .pomodoro: pill("Passer", label: "Passer à l'étape suivante") { timer.skipPhase() }
        case .stopwatch: EmptyView()
        }
    }

    private func pill(_ text: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(orange)
                .padding(.horizontal, 8).frame(height: 20)
                .background(Capsule().fill(orange.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func wide(w: CGFloat, h: CGFloat) -> some View {
        let b = min(42, max(30, h * 0.36))
        let f = min(40, max(24, h * 0.34))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 4)
                extra
            }
            Spacer(minLength: 6)
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    ring(b + 9, line: 3)
                    pauseButton(b)
                }
                stopButton(b)
                Spacer(minLength: 8)
                Text(digits)
                    .font(.system(size: timer.remaining >= 3600 ? f * 0.75 : f, weight: .regular).monospacedDigit())
                    .foregroundStyle(orange.opacity(timer.isRunning ? 1 : 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Spacer(minLength: 0)
        }
    }

    private func compact(w: CGFloat, h: CGFloat) -> some View {
        let d = max(56, min(w, h) - 4)
        return ZStack {
            ring(d, line: max(3, d * 0.04))
            VStack(spacing: d * 0.04) {
                if timer.mode == .pomodoro {
                    Text(timer.title)
                        .font(.system(size: max(8, d * 0.08), weight: .semibold))
                        .foregroundStyle(orange.opacity(0.8))
                        .lineLimit(1)
                }
                Text(digits)
                    .font(.system(size: d * (timer.remaining >= 3600 ? 0.17 : 0.22), weight: .medium).monospacedDigit())
                    .foregroundStyle(orange.opacity(timer.isRunning ? 1 : 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(spacing: d * 0.06) {
                    pauseButton(max(20, d * 0.24))
                    stopButton(max(20, d * 0.24))
                }
            }
            .padding(d * 0.14)
        }
        .frame(width: w, height: h)
    }

    private func idle(w: CGFloat, h: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ModePicker()
            Group {
                switch timer.mode {
                case .timer:
                    TimerWheels(width: w, height: h - 30) { timer.start(seconds: $0) }
                case .pomodoro:
                    idleLaunch(w: w, h: h - 30,
                               big: "\(timer.pomodoroMinutes) min",
                               small: "puis \(settings.value.pomodoro.shortBreak) min de pause") { timer.startPomodoro() }
                case .stopwatch:
                    idleLaunch(w: w, h: h - 30, big: "0:00", small: "Chronomètre") { timer.startStopwatch() }
                }
            }
            .transition(.opacity)
        }
    }

    private func idleLaunch(w: CGFloat, h: CGFloat, big: String, small: String, action: @escaping () -> Void) -> some View {
        let button = min(40, max(28, h * 0.4))
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(big)
                    .font(.system(size: min(30, max(18, h * 0.32)), weight: .regular).monospacedDigit())
                    .foregroundStyle(settings.colors.foreground.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(small)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(settings.colors.secondary.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            RoundButton(symbol: "play.fill", tint: orange, fill: orange.opacity(0.24), label: "Lancer", size: button, action: action)
        }
        .frame(width: w, height: min(h, 90), alignment: .top)
    }
}

struct ModePicker: View {
    @EnvironmentObject var timer: TimerModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TimerMode.allCases) { m in
                Button { timer.select(m) } label: {
                    Image(systemName: m.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 26, height: 18)
                        .foregroundStyle(m == timer.mode ? TimerStyle.orange : settings.colors.secondary.color)
                        .background(Capsule().fill(m == timer.mode ? TimerStyle.orange.opacity(0.2) : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(m.name)
                .accessibilityLabel(m.name)
                .accessibilityAddTraits(m == timer.mode ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(settings.colors.foreground.color.opacity(0.06)))
    }
}

struct TimerWheels: View {
    let width: CGFloat
    let height: CGFloat
    let start: (Int) -> Void
    @EnvironmentObject var settings: SettingsStore
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0
    @State private var loaded = false

    private var total: Int { hours * 3600 + minutes * 60 + seconds }

    var body: some View {
        let c = settings.colors
        let showHours = width >= 190
        let button = min(40, max(28, height * 0.34))
        let columns: CGFloat = showHours ? 3 : 2
        let unitSize = max(9, min(26, height / 3) * 0.42)
        let labels = unitSize * (showHours ? 3.6 : 2.8) + (showHours ? 12 : 8)
        let room = width - button - 10 - labels
        let column = max(24, min(40, room / columns))
        let row = max(16, min(26, height / 3))
        let visible = max(3, min(5, Int(height / row) | 1))
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: row * 0.4, style: .continuous)
                    .fill(c.foreground.color.opacity(0.1))
                    .frame(height: row)
                HStack(spacing: 0) {
                    if showHours {
                        WheelColumn(range: 0...23, value: $hours, row: row, visible: visible, width: column)
                        unit("h", size: unitSize)
                    }
                    WheelColumn(range: showHours ? 0...59 : 0...99, value: $minutes, row: row, visible: visible, width: column)
                    unit("min", size: unitSize)
                    WheelColumn(range: 0...59, value: $seconds, row: row, visible: visible, width: column)
                    unit("s", size: unitSize)
                }
            }
            .frame(height: row * CGFloat(visible))
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3),
                                         .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            RoundButton(symbol: "play.fill", tint: total > 0 ? TimerStyle.orange : c.secondary.color,
                        fill: total > 0 ? TimerStyle.orange.opacity(0.24) : c.foreground.color.opacity(0.08),
                        label: "Lancer le minuteur", size: button) {
                guard total > 0 else { return }
                settings.value.timerLast = total
                start(total)
            }
            .disabled(total == 0)
        }
        .frame(width: width, height: height, alignment: .top)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let t = settings.value.timerLast
            hours = showHours ? t / 3600 : 0
            minutes = showHours ? t / 60 % 60 : min(99, t / 60)
            seconds = t % 60
        }
    }

    private func unit(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(TimerStyle.orange)
            .fixedSize()
            .padding(.trailing, 4)
    }
}

struct WheelColumn: View {
    let range: ClosedRange<Int>
    @Binding var value: Int
    let row: CGFloat
    let visible: Int
    let width: CGFloat
    @EnvironmentObject var settings: SettingsStore
    @State private var position: Int?

    var body: some View {
        let c = settings.colors
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(range), id: \.self) { v in
                    Text(String(format: "%02d", v))
                        .font(.system(size: row * 0.68, weight: v == value ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(v == value ? c.foreground.color : c.secondary.color.opacity(0.7))
                        .frame(width: width, height: row)
                    .id(v)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.vertical, row * CGFloat(visible - 1) / 2, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .frame(width: width, height: row * CGFloat(visible))
        .contentShape(Rectangle())
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .local).onEnded { t in
            let offset = Int(((t.location.y - row * CGFloat(visible) / 2) / row).rounded())
            let target = min(range.upperBound, max(range.lowerBound, value + offset))
            withAnimation(.snappy) { position = target }
        })
        .onAppear { position = value }
        .onChange(of: value) { _, v in if position != v { position = v } }
        .onChange(of: position) { _, p in
            if let p, p != value {
                value = p
                if settings.value.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Valeur \(value)")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: if value < range.upperBound { value += 1 }
            case .decrement: if value > range.lowerBound { value -= 1 }
            @unknown default: break
            }
        }
    }
}

struct MirrorCard: View {
    @EnvironmentObject var mirror: MirrorModel
    @EnvironmentObject var settings: SettingsStore
    @State private var hover = false

    var body: some View {
        let c = settings.colors
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        ZStack {
            shape.fill(c.foreground.color.opacity(hover ? 0.12 : 0.07))
            if mirror.running, let session = mirror.session {
                MirrorPreview(session: session)
                    .scaleEffect(x: -1, y: 1)
                    .clipShape(shape)
            } else if mirror.starting {
                ProgressView().controlSize(.small)
            } else if mirror.denied {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash").font(.system(size: 16))
                    Text("Caméra refusée").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(c.secondary.color)
            } else if mirror.unavailable {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash").font(.system(size: 16))
                    Text("Pas de caméra").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(c.secondary.color)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "camera").font(.system(size: 18, weight: .medium))
                    Text("Miroir").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(c.secondary.color)
            }
        }
        .contentShape(shape)
        .onHover { hover = $0 }
        .onTapGesture {
            if mirror.denied { mirror.openPrivacySettings(); return }
            withAnimation(settings.animation) { mirror.toggle() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mirror.running ? "Miroir actif, cliquer pour couper la caméra" : "Miroir, cliquer pour allumer la caméra")
        .accessibilityAddTraits(.isButton)
    }
}
