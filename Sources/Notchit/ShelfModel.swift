import AppKit
import QuickLookThumbnailing

final class ShelfModel: ObservableObject {
    @Published private(set) var items: [URL] = []
    @Published private(set) var thumbnails: [URL: NSImage] = [:]
    @Published var previewing: URL?
    private let key = "shelf.paths"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        items = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        items.forEach(thumbnail)
    }

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(url) {
            items.append(url)
            thumbnail(url)
        }
        save()
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
        thumbnails[url] = nil
        if previewing == url { previewing = nil }
        save()
    }

    func clear() {
        items.removeAll()
        thumbnails.removeAll()
        previewing = nil
        save()
    }

    func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    func isImage(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .image)) ?? false
    }

    func fullImage(_ url: URL) -> NSImage? {
        isImage(url) ? NSImage(contentsOf: url) : nil
    }

    private func thumbnail(_ url: URL) {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 320, height: 320),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let image = rep?.nsImage else { return }
            DispatchQueue.main.async { self?.thumbnails[url] = image }
        }
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.path), forKey: key)
    }
}
