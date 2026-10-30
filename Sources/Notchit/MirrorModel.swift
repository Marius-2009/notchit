import AVFoundation
import AppKit
import SwiftUI

final class MirrorModel: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var starting = false
    @Published private(set) var denied = false
    @Published private(set) var unavailable = false
    @Published private(set) var session: AVCaptureSession?
    private let queue = DispatchQueue(label: "fr.livio-studio.notchit.mirror")
    private var generation = 0
    private var errorObserver: NSObjectProtocol?

    func toggle() { running || starting ? stop() : start() }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            launch()
        case .notDetermined:
            NSApp.activate(ignoringOtherApps: true)
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    if ok { self.launch() } else { self.denied = true }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        guard running || starting else { return }
        generation += 1
        running = false
        starting = false
        let old = session
        session = nil
        if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
        errorObserver = nil
        queue.async { old?.stopRunning() }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func camera() -> AVCaptureDevice? {
        let found = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
                                                     mediaType: .video, position: .unspecified).devices
        let real = found.filter { !$0.localizedName.localizedCaseInsensitiveContains("virtual") }
        return real.first { $0.deviceType == .builtInWideAngleCamera } ?? real.first ?? found.first
    }

    private func launch() {
        guard !running, !starting else { return }
        denied = false
        unavailable = false
        starting = true
        generation += 1
        let gen = generation
        queue.async {
            let s = AVCaptureSession()
            guard let device = Self.camera(),
                  let input = try? AVCaptureDeviceInput(device: device),
                  s.canAddInput(input) else {
                DispatchQueue.main.async {
                    guard gen == self.generation else { return }
                    self.unavailable = true
                    self.starting = false
                }
                return
            }
            s.beginConfiguration()
            if s.canSetSessionPreset(.high) { s.sessionPreset = .high }
            s.addInput(input)
            s.commitConfiguration()
            s.startRunning()
            DispatchQueue.main.async {
                guard gen == self.generation else { self.queue.async { s.stopRunning() }; return }
                self.session = s
                self.starting = false
                self.running = s.isRunning
                self.errorObserver = NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError, object: s, queue: .main) { [weak self] _ in
                    self?.stop()
                }
            }
        }
    }
}

final class PreviewView: NSView {
    private let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { (layer as? AVCaptureVideoPreviewLayer)?.session = nil }
    }
}

struct MirrorPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView { PreviewView(session: session) }

    func updateNSView(_ view: PreviewView, context: Context) {}

    static func dismantleNSView(_ view: PreviewView, coordinator: ()) {
        (view.layer as? AVCaptureVideoPreviewLayer)?.session = nil
    }
}
