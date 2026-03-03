import Foundation

// MARK: - FrameStore — Persistence

class FrameStore {
    private let fileURL: URL

    private(set) var frames: [FrameGroup] = []

    var onChange: (() -> Void)?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("FrameIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("frames.json")
        load()
    }

    // MARK: CRUD

    func add(_ frame: FrameGroup) {
        frames.append(frame)
        save()
    }

    func update(_ frame: FrameGroup) {
        guard let idx = frames.firstIndex(where: { $0.id == frame.id }) else { return }
        frames[idx] = frame
        save()
    }

    func remove(id: UUID) {
        frames.removeAll { $0.id == id }
        save()
    }

    // MARK: Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(frames)
            try data.write(to: fileURL, options: .atomic)
            onChange?()
        } catch {
            print("[FrameStore] Save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            frames = try JSONDecoder().decode([FrameGroup].self, from: data)
        } catch {
            print("[FrameStore] Load failed: \(error)")
        }
    }
}
