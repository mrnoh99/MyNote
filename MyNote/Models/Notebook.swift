import Foundation
import SwiftData

@Model
final class Notebook {
    var id: UUID = UUID()
    var title: String = "새 노트북"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var colorHex: String = "#4A90D9"

    @Relationship(deleteRule: .cascade, inverse: \Note.notebook)
    var notes: [Note] = []

    init(title: String, colorHex: String = "#4A90D9") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.colorHex = colorHex
    }
}
