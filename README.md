# MyNote

OneNote와 비슷한 방식으로 쓰는 iOS 노트 앱입니다. SwiftUI + SwiftData(+ CloudKit)로 작성된 네이티브 iOS 앱이며, Xcode 프로젝트(`MyNote.xcodeproj`)가 저장소에 포함되어 있어 바로 열어서 빌드할 수 있습니다.

## 주요 기능

1. **자체 노트 작성** — 노트북 안에 새 "필기 노트"를 만들고 PencilKit 캔버스에 손가락/애플펜슬로 자유롭게 필기합니다. (`NoteEditorView`, `CanvasRepresentable`)
2. **PDF 불러오기 + 애플펜슬 메모** — `fileImporter`로 PDF를 불러오면 페이지 단위로 넘겨보면서 애플펜슬로 필기를 겹쳐 쓸 수 있습니다. 필기는 페이지별로 원본 PDF와 분리되어 저장되므로 원본이 손상되지 않습니다. "내보내기" 버튼으로 필기가 합쳐진 PDF를 공유 시트로 내보낼 수 있습니다. (`PDFAnnotationView`, `PDFCanvasOverlay`, `PDFPageRepresentable`, `PDFAnnotationFlattener`)
3. **OneNote 내보내기 파일 가져오기 → iCloud 저장/동기화** — OneNote에서 "PDF로 내보내기"한 파일을 같은 파일 가져오기 기능으로 MyNote에 새 노트로 추가합니다. 노트 데이터(SwiftData 모델)는 `ModelConfiguration(cloudKitDatabase: .automatic)`로 구성되어 있어 별도 서버 코드 없이 iCloud(CloudKit 프라이빗 데이터베이스)에 저장되고, 같은 iCloud 계정의 다른 기기와 자동으로 동기화됩니다. (`FileImportService`)

## 프로젝트 구조

```
MyNote.xcodeproj/          Xcode 프로젝트 파일
MyNote/
  MyNoteApp.swift          앱 진입점, SwiftData ModelContainer(+CloudKit) 구성
  Info.plist
  MyNote.entitlements      iCloud / CloudKit 권한
  Models/
    Notebook.swift         노트북(폴더) 모델
    Note.swift              노트 모델(필기 노트 / PDF 노트 공용)
    PDFPageAnnotation.swift PDF 페이지별 필기 데이터
  Views/
    RootView.swift          NavigationSplitView 루트
    NotebookListView.swift  노트북 목록(사이드바)
    NotebookDetailView.swift 노트북 안의 노트 목록 + 새 노트/가져오기
    NoteEditorView.swift    필기 노트 편집 화면
    PDFAnnotationView.swift PDF 뷰어 + 애플펜슬 필기 화면
    Components/
      CanvasRepresentable.swift   PencilKit 캔버스(UIViewRepresentable)
      PDFPageRepresentable.swift  단일 페이지 PDF 뷰
      PDFCanvasOverlay.swift      PDF 위 애플펜슬 전용 필기 레이어
      ActivityView.swift          공유 시트 래퍼
  Services/
    FileImportService.swift        PDF 가져오기 → Note 생성
    PDFAnnotationFlattener.swift   필기를 합친 PDF 내보내기용 렌더러
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

- OneNote(.one) 파일 자체를 직접 파싱하지는 않습니다. OneNote 앱의 "PDF로 내보내기" 기능으로 만든 PDF를 가져오는 방식입니다.
- 앱 아이콘 이미지(PNG)는 포함되어 있지 않습니다(`Assets.xcassets/AppIcon.appiconset`에 슬롯만 정의됨). Xcode에서 아이콘 이미지를 채워 넣어야 합니다.
- 이 프로젝트 파일은 macOS/Xcode가 없는 환경에서 작성되었으므로, 실제 Xcode에서 연 뒤 빌드 로그를 한 번 확인해 주세요.
