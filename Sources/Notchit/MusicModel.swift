import AppKit

struct MediaSource: Equatable {
    let bundleID: String
    let name: String
    let icon: NSImage?

    static let browsers: Set<String> = [
        "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "org.mozilla.firefox",
        "com.brave.Browser", "com.microsoft.edgemac", "com.operasoftware.Opera", "app.zen-browser.zen",
        "com.vivaldi.Vivaldi", "com.apple.SafariTechnologyPreview"
    ]

    var isBrowser: Bool { Self.browsers.contains(bundleID) }

    init(bundleID: String, name: String, icon: NSImage?) {
        self.bundleID = bundleID
        self.name = name
        self.icon = icon
    }

    init?(pid: Int32) {
        guard pid > 0, let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        self.init(bundleID: app.bundleIdentifier ?? "", name: app.localizedName ?? "", icon: app.icon)
    }

    init(bundleID: String) {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let name = url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? bundleID
        self.init(bundleID: bundleID, name: name, icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) })
    }

    static func == (a: MediaSource, b: MediaSource) -> Bool { a.bundleID == b.bundleID }
}

final class MusicModel: ObservableObject {
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var position: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var player: MediaSource?

    private var elapsed: Double = 0
    private var stamp = Date()
    private var rate: Double = 0
    private var clock: Timer?
    private var bridge: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var restarts = 0
    private var fallback: AppleScriptMusic?
    private var systemEnabled = true

    init(system: Bool = true) {
        systemEnabled = system
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        if !system || !startBridge() { useFallback() }
    }

    func setSystemMedia(_ enabled: Bool) {
        guard enabled != systemEnabled else { return }
        systemEnabled = enabled
        restarts = 0
        if enabled {
            fallback?.stop()
            fallback = nil
            if !startBridge() { useFallback() }
        } else {
            let b = bridge
            bridge = nil
            input = nil
            b?.terminate()
            useFallback()
        }
    }

    deinit { bridge?.terminate() }

    func playPause() { send("toggle") }
    func next() { send("next") }
    func previous() { send("prev") }

    func seek(to seconds: Double) {
        send("seek \(max(0, min(duration, seconds)))")
        elapsed = seconds
        stamp = Date()
        position = seconds
    }

    private func send(_ command: String) {
        if let fallback { fallback.send(command); return }
        input?.write(Data((command + "\n").utf8))
    }

    private func tick() {
        guard isPlaying, fallback == nil else { return }
        let p = elapsed + Date().timeIntervalSince(stamp) * max(rate, 1)
        position = duration > 0 ? min(duration, p) : p
    }

    @discardableResult
    private func startBridge() -> Bool {
        guard let lib = Bundle.main.url(forResource: "MediaBridge", withExtension: "dylib"),
              FileManager.default.isExecutableFile(atPath: "/usr/bin/perl") else { return false }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = ["-e", "use DynaLoader; my $l = DynaLoader::dl_load_file($ARGV[0]) or exit 4; my $s = DynaLoader::dl_find_symbol($l, 'notchit_media_run') or exit 5; DynaLoader::dl_install_xsub('main::run', $s); run();", lib.path]
        let out = Pipe()
        let inp = Pipe()
        p.standardOutput = out
        p.standardInput = inp
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            DispatchQueue.main.async { self?.consume(data) }
        }
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.bridgeEnded() }
        }
        do { try p.run() } catch { return false }
        bridge = p
        input = inp.fileHandleForWriting
        return true
    }

    private func bridgeEnded() {
        guard systemEnabled, bridge != nil else { return }
        bridge = nil
        input = nil
        restarts += 1
        if restarts > 3 || !startBridge() { useFallback() }
    }

    private func useFallback() {
        guard fallback == nil else { return }
        let f = AppleScriptMusic()
        f.onUpdate = { [weak self] u in self?.apply(u) }
        fallback = f
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let i = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<i]
            buffer.removeSubrange(buffer.startIndex...i)
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            handle(obj)
        }
    }

    private func handle(_ o: [String: Any]) {
        let title = o["title"] as? String ?? ""
        let pid = (o["pid"] as? NSNumber)?.int32Value ?? 0
        guard !title.isEmpty, let source = MediaSource(pid: pid) else {
            apply(Update(source: nil))
            return
        }
        var u = Update(source: source)
        u.title = title
        u.artist = o["artist"] as? String ?? ""
        if u.artist.isEmpty, source.isBrowser { u.artist = source.name }
        u.duration = (o["duration"] as? NSNumber)?.doubleValue ?? 0
        u.elapsed = (o["elapsed"] as? NSNumber)?.doubleValue ?? 0
        u.stamp = Date(timeIntervalSince1970: (o["timestamp"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970)
        u.rate = (o["rate"] as? NSNumber)?.doubleValue ?? 0
        u.playing = (o["playing"] as? NSNumber)?.boolValue ?? false
        if let art = o["artwork"] as? String {
            u.artworkChanged = true
            let image = Data(base64Encoded: art).flatMap(NSImage.init(data:))
            let square = image.map { abs($0.size.width - $0.size.height) < 1 } ?? false
            u.artwork = source.isBrowser && square && u.title.isEmpty == false && (o["album"] as? String ?? "").isEmpty ? nil : image
        }
        apply(u)
    }

    struct Update {
        var source: MediaSource?
        var title = ""
        var artist = ""
        var duration: Double = 0
        var elapsed: Double = 0
        var stamp = Date()
        var rate: Double = 0
        var playing = false
        var artworkChanged = false
        var artwork: NSImage?
    }

    private func apply(_ u: Update) {
        guard let source = u.source else {
            player = nil
            title = ""
            artist = ""
            isPlaying = false
            artwork = nil
            duration = 0
            position = 0
            return
        }
        if player != source || title != u.title { if !u.artworkChanged { artwork = nil } }
        player = source
        title = u.title
        artist = u.artist
        duration = u.duration
        elapsed = u.elapsed
        stamp = u.stamp
        rate = u.rate
        isPlaying = u.playing
        if u.artworkChanged { artwork = u.artwork }
        position = u.playing ? min(u.duration > 0 ? u.duration : .infinity, u.elapsed + Date().timeIntervalSince(u.stamp) * max(u.rate, 1)) : u.elapsed
    }
}

final class AppleScriptMusic {
    var onUpdate: ((MusicModel.Update) -> Void)?
    private var timer: Timer?
    private var lastKey = ""
    private var lastArt: NSImage?
    private var current: String?
    private let queue = DispatchQueue(label: "notchit.music.applescript")
    private static let apps = [("Spotify", "com.spotify.client"), ("Music", "com.apple.Music")]

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func send(_ command: String) {
        guard let app = current else { return }
        let verb = ["toggle": "playpause", "next": "next track", "prev": "previous track"][command]
        let script: String
        if let verb { script = "tell application \"\(app)\" to \(verb)" }
        else if command.hasPrefix("seek "), let v = Double(command.dropFirst(5)) { script = "tell application \"\(app)\" to set player position to \(v)" }
        else { return }
        queue.async { [weak self] in
            var e: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&e)
            self?.refresh()
        }
    }

    private func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            var chosen: (String, String, NSAppleEventDescriptor)?
            for (name, id) in Self.apps where !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty {
                guard let d = self.query(name) else { continue }
                if d.atIndex(1)?.stringValue == "playing" { chosen = (name, id, d); break }
                if chosen == nil, d.atIndex(1)?.stringValue != "stopped" { chosen = (name, id, d) }
            }
            guard let (name, id, d) = chosen else {
                self.current = nil
                DispatchQueue.main.async { self.onUpdate?(MusicModel.Update(source: nil)) }
                return
            }
            self.current = name
            var u = MusicModel.Update(source: MediaSource(bundleID: id))
            u.title = d.atIndex(2)?.stringValue ?? ""
            u.artist = d.atIndex(3)?.stringValue ?? ""
            u.duration = (d.atIndex(4)?.doubleValue ?? 0) / (name == "Spotify" ? 1000 : 1)
            u.elapsed = d.atIndex(5)?.doubleValue ?? 0
            u.playing = d.atIndex(1)?.stringValue == "playing"
            let key = name + u.title + u.artist
            if key != self.lastKey {
                self.lastKey = key
                self.lastArt = self.artwork(name, d)
                u.artworkChanged = true
            }
            u.artwork = self.lastArt
            u.artworkChanged = true
            DispatchQueue.main.async { self.onUpdate?(u) }
        }
    }

    private static func download(_ url: URL, limit: Int) -> Data? {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.httpMethod = "GET"
        let done = DispatchSemaphore(value: 0)
        var result: Data?
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               http.expectedContentLength <= Int64(limit), let data, data.count <= limit {
                result = data
            }
            done.signal()
        }
        task.resume()
        if done.wait(timeout: .now() + 10) == .timedOut { task.cancel() }
        return result
    }

    private func query(_ app: String) -> NSAppleEventDescriptor? {
        let art = app == "Spotify" ? "artwork url of t" : "\"\""
        let source = """
        tell application "\(app)"
            if player state is stopped then return {"stopped", "", "", 0, 0, ""}
            set t to current track
            return {player state as string, name of t, artist of t, duration of t, player position, \(art)}
        end tell
        """
        var e: NSDictionary?
        let r = NSAppleScript(source: source)?.executeAndReturnError(&e)
        return e == nil ? r : nil
    }

    private func artwork(_ app: String, _ d: NSAppleEventDescriptor) -> NSImage? {
        if app == "Spotify" {
            guard let s = d.atIndex(6)?.stringValue, let url = URL(string: s), url.scheme == "https",
                  let host = url.host?.lowercased(), host == "i.scdn.co" || host.hasSuffix(".scdn.co") || host.hasSuffix(".spotifycdn.com"),
                  let data = Self.download(url, limit: 5_000_000) else { return nil }
            return NSImage(data: data)
        }
        var e: NSDictionary?
        guard let r = NSAppleScript(source: "tell application \"Music\"\ntry\nreturn raw data of artwork 1 of current track\nend try\nend tell")?.executeAndReturnError(&e), e == nil else { return nil }
        return NSImage(data: r.data)
    }
}
