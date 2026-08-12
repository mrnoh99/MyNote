# MyNote

OneNote와 비슷한 방식으로 쓰는 iOS 노트 앱입니다. SwiftUI + SwiftData(+ CloudKit)로 작성된 네이티브 iOS 앱이며, Xcode 프로젝트(`MyNote.xcodeproj`)가 저장소에 포함되어 있어 바로 열어서 빌드할 수 있습니다.

## 주요 기능

1. **자체 노트 작성** — 노트북 안에 새 "필기 노트"를 만들고 PencilKit 캔버스에 손가락/애플펜슬로 자유롭게 필기합니다. 필기 노트도 PDF 노트처럼 여러 페이지를 가질 수 있어서 페이지 이동 바의 "페이지 추가" 버튼으로 새 빈 페이지를 계속 늘려나갈 수 있고, 손가락 핀치로 각 페이지를 확대/축소·이동할 수 있으며(애플펜슬은 필기 전용) 툴바의 "화면에 맞추기" 버튼으로 언제든 페이지 전체가 보이는 배율로 되돌아옵니다. 캔버스 배경은 OneNote 스타일의 백지 / 줄친 종이 / 점선지 / 모눈종이, 그리고 손글씨 악보용 오선지 중에서 고를 수 있고 노트별로 저장됩니다. (`NoteEditorView`, `ZoomableNotePageView`, `NotePage`)
2. **PDF 불러오기 + 애플펜슬 메모** — `fileImporter`로 PDF를 불러오면 페이지 단위로 넘겨보면서 애플펜슬로 필기를 겹쳐 쓸 수 있습니다. 필기는 페이지별로 원본 PDF와 분리되어 저장되므로 원본이 손상되지 않습니다. 손가락으로 핀치하여 확대/축소·이동할 수 있고(애플펜슬은 필기 전용), 툴바의 "화면에 맞추기" 버튼으로 언제든 페이지 전체가 보이는 배율로 즉시 되돌아옵니다 — 페이지 이미지와 필기 레이어가 같은 컨테이너에서 함께 확대되므로 확대해도 어긋나지 않습니다. "내보내기" 버튼으로 필기가 합쳐진 PDF를 공유 시트로 내보낼 수 있습니다. (`PDFAnnotationView`, `ZoomablePDFPageView`, `PDFAnnotationFlattener`)
3. **커스텀 필기 도구 모음** — iOS 기본 플로팅 도구 모음 대신, 캔버스 위에 고정된 자체 툴바로 올가미/펜/형광펜/지우개, 굵기(얇음/중간/굵음), 색상(프리셋 + 커스텀 색상 선택기), 실행 취소/다시 실행을 직접 제어합니다. 필기 노트와 PDF 필기 화면 모두 같은 툴바를 씁니다. (`PencilToolbarView`, `PencilToolState`)
4. **OneNote 내보내기 파일 가져오기 → iCloud 저장/동기화** — OneNote에서 "PDF로 내보내기"한 파일을 같은 파일 가져오기 기능으로 MyNote에 새 노트로 추가합니다. 노트 데이터(SwiftData 모델)는 `ModelConfiguration(cloudKitDatabase: .automatic)`로 구성되어 있어 별도 서버 코드 없이 iCloud(CloudKit 프라이빗 데이터베이스)에 저장되고, 같은 iCloud 계정의 다른 기기와 자동으로 동기화됩니다. PDF가 아닌 Word/PPT/한글/Keynote/Pages 파일은 각 앱에서 PDF로 내보낸 뒤 가져오도록 안내합니다. (`FileImportService`)
5. **백업 / 복원** — 사이드바 오른쪽 위 `+` 메뉴에서 "백업 내보내기"를 누르면 폴더 구조를 포함한 라이브러리 전체(폴더·노트북·노트·필기·PDF·페이지별 주석)를 하나의 JSON 파일(`MyNote-Backup-*.json`)로 만들어 공유 시트로 내보냅니다(파일 앱, iCloud Drive, AirDrop 등에 저장 가능). "백업에서 복원"으로 그 파일을 다시 선택하면 새 폴더/노트북들로 추가 복원됩니다 — 기존 데이터는 지우지 않는 안전한(추가형) 복원입니다. CloudKit 자동 동기화와는 별개로, 기기 이전이나 수동 스냅샷 용도로 씁니다. (`BackupService`)
6. **폴더 정리 / 이동 / 복제** — 노트북을 폴더로 묶어 정리할 수 있고(폴더 안에 폴더도 중첩 가능), 폴더·노트북·노트를 다른 폴더/노트북으로 옮기거나 복제할 수 있습니다. 사이드바에서 폴더를 길게 눌러(컨텍스트 메뉴) 이름 변경/이동/삭제, 노트북은 이름 변경/이동/복제/삭제를 할 수 있고, 노트북 안에서는 노트별로 다른 노트북으로 이동·복제할 수 있습니다. (`Models/Folder.swift`, `FolderBrowserView`, `FolderPickerView`, `NotebookPickerView`, `OrganizationService`)
7. **앱 업데이트 시 데이터 보존** — SwiftData 스토어는 앱을 삭제하지 않는 한 기기에 남아있고(iOS가 업데이트 때 자동으로 보존), 스키마가 바뀌어도 손실 없이 마이그레이션되도록 `VersionedSchema` + `SchemaMigrationPlan`을 명시적으로 구성해뒀습니다. `ModelContainer` 생성이 실패해도 절대 기존 스토어 파일을 지우고 새로 만드는 "복구"를 하지 않습니다. 자세한 내용과 앞으로 모델을 바꿀 때 지켜야 할 절차는 `Models/MyNoteMigrationPlan.swift`의 주석을 참고하세요.
8. **이미지 삽입 / 텍스트 상자** (필기 노트 + PDF 노트 모두, 페이지별로 저장) — 캔버스 위에 사진 라이브러리에서 고른 이미지나 키보드로 입력하는 텍스트 상자를 자유롭게 올려놓을 수 있습니다. 필기 노트와 PDF 노트 모두 같은 순수 UIKit 뷰(`PageAttachmentUIViews`)로 구현했습니다 — 페이지를 확대/축소하는 컨테이너 안에 직접 얹혀 있어서 확대해도 첨부물이 페이지와 함께 움직이고, 여러 페이지 중 지금 보고 있는 페이지에 속한 첨부물만 나타납니다. "첨부물 편집" 버튼으로 편집 모드를 켜야 드래그·리사이즈·삭제가 되고, 편집 모드가 아닐 때는 손가락이 다시 페이지 확대/축소·이동(또는 필기 노트의 애플펜슬 필기)에 쓰입니다(두 종류의 손가락 제스처가 서로 다투지 않도록 모드를 분리). (`PageAttachmentUIViews`, `ImageAttachment`, `TextBoxAttachment`)
9. **음성 메모** — 필기 노트와 PDF 노트 모두에서 툴바의 마이크 버튼으로 녹음 시트를 열어 음성 메모를 녹음·재생·삭제할 수 있습니다. (`AudioRecordingsSheet`, `AudioRecorderController`/`AudioPlaybackController`, `AudioRecording`)
10. **여러 노트를 앱 전체에서 탭으로 열기** — 노트를 탭하면 브라우저 탭처럼 상단에 열린 노트 목록이 생기고, 탭을 눌러 전환하거나 ×로 닫을 수 있습니다. 탭 바의 + 버튼은 열려 있는 탭은 그대로 두고 노트 목록으로 돌아가 다른 노트북의 노트를 추가로 열 수 있게 해줍니다. 탭 상태(`NoteWorkspace`)는 사이드바보다 위, `RootView` 수준에서 관리되어 다른 노트북으로 이동해도 유지됩니다. 노트북/폴더를 삭제하면 그 안에 있던 노트가 열려 있는 탭도 함께 정리됩니다(삭제된 데이터를 탭이 계속 들고 있지 않도록). (`NoteWorkspace`, `NoteTabBarView`, `RootView`)

## 프로젝트 구조

```
MyNote.xcodeproj/          Xcode 프로젝트 파일
MyNote/
  MyNoteApp.swift          앱 진입점, SwiftData ModelContainer(+CloudKit) 구성
  Info.plist
  MyNote.entitlements      iCloud / CloudKit 권한
  Models/
    Folder.swift            정리용 폴더(자기 참조 트리, 노트북을 담음)
    Notebook.swift           노트북 모델(폴더에 소속되거나 최상위에 위치)
    Note.swift               노트 모델(필기 노트 / PDF 노트 공용)
    PDFPageAnnotation.swift  PDF 페이지별 필기 데이터
    NotePage.swift           필기 노트 페이지별 필기 데이터(여러 페이지 지원)
    MyNoteMigrationPlan.swift  VersionedSchema + SchemaMigrationPlan (데이터 손실 없는 업그레이드)
    ImageAttachment.swift    캔버스 위 이미지 첨부(위치/크기 포함)
    TextBoxAttachment.swift  캔버스 위 텍스트 상자 첨부(위치/크기 포함)
    AudioRecording.swift     노트에 딸린 음성 메모
  Views/
    RootView.swift           NavigationSplitView 루트
    FolderBrowserView.swift  폴더/노트북 탐색(사이드바), 새 폴더/노트북, 백업/복원
    FolderPickerView.swift   폴더 "이동" 대상 선택 모달
    NotebookPickerView.swift 노트 "이동/복제" 대상 노트북 선택 모달
    NotebookDetailView.swift 노트북 안의 노트 목록 + 탭으로 열린 노트 전환/닫기 + 새 노트/가져오기/이동/복제
    NoteEditorView.swift     필기 노트 편집 화면
    PDFAnnotationView.swift  PDF 뷰어 + 애플펜슬 필기 화면
    AudioRecordingsSheet.swift  음성 메모 녹음/재생/삭제 시트
    Components/
      ZoomablePDFPageView.swift   확대/축소·이동 가능한 PDF 페이지 + 애플펜슬 필기 레이어
      ZoomableNotePageView.swift  확대/축소·이동 가능한 필기 노트 페이지 + 종이 배경(UIKit) + 애플펜슬 필기 레이어
      ActivityView.swift          공유 시트 래퍼
      PencilToolbarView.swift     커스텀 필기 도구 모음(펜/형광펜/지우개/올가미/굵기/색상/실행취소)
      PageAttachmentUIViews.swift 필기 노트 + PDF 노트 공용 이미지/텍스트 상자(순수 UIKit, 확대 컨테이너에 얹힘)
      NoteWorkspace.swift         앱 전체 탭 상태(NoteWorkspace) + 탭 바(NoteTabBarView)
  Services/
    FileImportService.swift        PDF 가져오기 → Note 생성, 형식 안내
    PDFAnnotationFlattener.swift   필기를 합친 PDF 내보내기용 렌더러
    BackupService.swift            폴더 구조 포함 전체 JSON 백업 생성 / 복원
    OrganizationService.swift      노트북/노트 복제(딥카피) 헬퍼
    AudioRecordingController.swift AVFoundation 녹음/재생 컨트롤러
```

## 빌드 전 준비 (Xcode에서)

1. Xcode 15 이상, iOS 17 이상 시뮬레이터/기기가 필요합니다. (SwiftData + CloudKit, PencilKit, PDFKit 사용)
2. `MyNote.xcodeproj`를 엽니다.
3. **Signing & Capabilities** 탭에서:
   - 본인의 Apple Developer 팀을 `Team`에 선택합니다.
   - `PRODUCT_BUNDLE_IDENTIFIER`(기본값 `com.mrnoh99.MyNote`)를 본인 소유의 고유 Bundle ID로 바꿉니다.
   - iCloud capability가 켜져 있는지 확인하고, CloudKit 컨테이너를 본인 Bundle ID에 맞는 `iCloud.<bundle-id>`로 다시 생성/선택합니다. (`MyNote.entitlements`의 컨테이너 식별자도 함께 맞춰주세요.)
4. 애플펜슬 필기 테스트는 iPad 실기기(또는 Apple Pencil을 지원하는 시뮬레이터 입력)에서 확인하는 것을 권장합니다.

## 알려진 제한 사항 / 다음 단계

- OneNote(.one) 파일 자체를 직접 파싱하지는 않습니다. OneNote 앱의 "PDF로 내보내기" 기능으로 만든 PDF를 가져오는 방식입니다. Word/PPT/한글/Keynote/Pages도 마찬가지로 해당 앱에서 PDF로 내보내야 합니다.
- 앱 아이콘은 `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`(1024×1024, 알파 채널 없음)로 포함되어 있습니다. 마음에 들지 않으면 같은 경로의 PNG만 교체하면 됩니다.
- 백업 파일 포맷은 버전 5(`formatVersion = 5`, 폴더 구조 + 노트 배경 스타일 + 필기 노트 페이지(`NotePage`) + 이미지/텍스트 상자/음성 메모 포함)이며, 이전 버전의 백업 파일은 호환되지 않습니다.
- 여러 페이지 도입 이전에 만든 필기 노트는 `Note.drawingData`(레거시 단일 페이지 필드)에 내용이 남아있는데, 노트를 처음 열 때 자동으로 0번 페이지(`NotePage`)로 옮겨지므로 기존에 그려둔 내용은 그대로 보존됩니다.
- 필기 노트/PDF 노트의 이미지/텍스트 상자는 "첨부물 편집" 버튼을 눌러 편집 모드로 들어가야 옮기거나 크기를 바꿀 수 있습니다. 편집 모드 중에는 페이지 확대/축소·이동과 애플펜슬 필기가 잠시 꺼집니다(손가락 제스처가 페이지 조작과 첨부물 조작으로 겹치지 않도록).
- 음성 메모는 마이크 권한이 필요합니다(`NSMicrophoneUsageDescription`을 Info.plist에 포함했습니다). 시뮬레이터에서는 마이크 입력이 제한적일 수 있어 실기기 테스트를 권장합니다.
- 이 프로젝트 파일은 macOS/Xcode가 없는 환경에서 작성되었으므로, 실제 Xcode에서 연 뒤 빌드 로그를 한 번 확인해 주세요.
