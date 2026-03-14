import Foundation

// MARK: - FrameStore

class FrameStore {
    private let fileURL: URL

    private(set) var frames: [FrameGroup] = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("FrameIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("frames.json")
        load()
    }

    func add(_ frame: FrameGroup) {
        frames.append(frame)
        save()
    }

    func update(_ frame: FrameGroup) {
        guard let index = frames.firstIndex(where: { $0.id == frame.id }) else { return }
        frames[index] = frame
        save()
    }

    func remove(id: UUID) {
        frames.removeAll { $0.id == id }
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(frames)
            try data.write(to: fileURL, options: .atomic)
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
