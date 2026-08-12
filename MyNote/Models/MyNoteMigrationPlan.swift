import Foundation
import SwiftData

/// SwiftData의 버전별 스키마 정의. 여기 등재된 모델 목록이 곧 "현재
/// 저장 포맷"이다. 앱을 업데이트해도 기기에 이미 저장된 노트북/노트/
/// PDF/필기 데이터가 사라지지 않도록, 모델을 바꿀 때는 아래 두 단계를
/// 반드시 거친다:
///
/// 1. 기존 버전은 그대로 두고 새 버전을 추가한다.
///    (예: `enum MyNoteSchemaV2: VersionedSchema { ... versionIdentifier = Schema.Version(2, 0, 0) }`)
/// 2. `MyNoteMigrationPlan.schemas`에 새 버전을 추가하고, `stages`에
///    마이그레이션 단계를 등록한다.
///    - 속성 추가/삭제처럼 SwiftData가 스스로 처리할 수 있는 단순 변경:
///      `.lightweight(fromVersion: MyNoteSchemaV1.self, toVersion: MyNoteSchemaV2.self)`
///    - 값 변환이나 데이터 이전이 필요한 복잡한 변경:
///      `.custom(fromVersion:toVersion:willMigrate:didMigrate:)`
///
/// `@Model` 클래스를 직접 고치기만 하고 여기에 새 버전/단계를 등록하지
/// 않으면 SwiftData의 암묵적(라이트웨이트) 마이그레이션에만 의존하게
/// 되는데, 이는 단순한 변경(옵셔널 속성 추가 등)에는 대체로 잘 동작하지만
/// 보장된 방법은 아니다. 새 스키마 버전을 명시적으로 등록해두면 항상
/// 같은 방식으로, 테스트 가능하게 마이그레이션할 수 있다.
///
/// 가장 중요한 규칙: `ModelContainer` 생성이 실패했다고 해서 기존 스토어
/// 파일을 지우고 새로 만드는 "복구"를 절대 하지 않는다 — 그건 사용자의
/// 모든 노트를 지우는 것과 같다. 실패하면 원인을 고쳐야 한다.
enum MyNoteSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Folder.self, Notebook.self, Note.self, PDFPageAnnotation.self,
            ImageAttachment.self, TextBoxAttachment.self, AudioRecording.self,
        ]
    }
}

enum MyNoteMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MyNoteSchemaV1.self]
    }

    /// 지금은 V1이 유일한(첫) 버전이라 마이그레이션 단계가 없다.
    /// V2를 추가하면 여기에 해당 단계를 채워 넣는다.
    static var stages: [MigrationStage] {
        []
    }
}
