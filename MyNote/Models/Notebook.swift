import Foundation
import SwiftData

@Model
final class Notebook {
    var id: UUID = UUID()
    var title: String = "새 노트북"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var colorHex: String = "#4A90D9"

    /// nil이면 최상위(루트)에 있는 노트북.
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Note.notebook)
    var notes: [Note] = []

    init(title: String, colorHex: String = "#4A90D9", folder: Folder? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.colorHex = colorHex
        self.folder = folder
    }
}
