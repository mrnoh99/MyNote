import SwiftUI
import SwiftData

@main
struct MyNoteApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema(versionedSchema: MyNoteSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: MyNoteMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            // 여기서 실패했다고 기존 스토어 파일을 지우고 새로 만드는 식으로
            // "복구"하지 않는다 — 그건 사용자의 모든 노트를 지우는 것과
            // 같다. 마이그레이션 실패는 MyNoteMigrationPlan에 필요한 단계를
            // 추가해서 고쳐야 할 문제다.
            fatalError("ModelContainer 생성에 실패했습니다: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
