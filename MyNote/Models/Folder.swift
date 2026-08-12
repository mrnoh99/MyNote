import Foundation
import SwiftData

/// 노트북(그리고 하위 폴더)을 담는 정리용 폴더. 자기 자신을 참조하는
/// 트리 구조라 폴더 안에 폴더를 무제한으로 중첩할 수 있다.
@Model
final class Folder {
    var id: UUID = UUID()
    var title: String = "새 폴더"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var parentFolder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder)
    var subfolders: [Folder] = []

    @Relationship(deleteRule: .cascade, inverse: \Notebook.folder)
    var notebooks: [Notebook] = []

    init(title: String, parentFolder: Folder? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.parentFolder = parentFolder
    }
}
