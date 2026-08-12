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

    // CloudKit 동기화는 to-many 관계도 반드시 옵셔널 타입이어야 한다
    // (그냥 기본값이 []인 것만으로는 부족하다). 실제 값은 항상 빈
    // 배열로 초기화되므로 사용할 때는 `folder.subfolders ?? []`처럼
    // 읽으면 된다.
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder)
    var subfolders: [Folder]? = []

    @Relationship(deleteRule: .cascade, inverse: \Notebook.folder)
    var notebooks: [Notebook]? = []

    init(title: String, parentFolder: Folder? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.parentFolder = parentFolder
    }
}
