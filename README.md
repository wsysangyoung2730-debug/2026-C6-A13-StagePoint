# StagePoint

iPhone으로 무대를 스캔·촬영하고 iPad에서 영상과 목표 위치를 함께 확인하는 Swift 연구용 앱입니다. 기존 단일 기기 매핑 도구도 유지합니다.

프로젝트: `2026-C6-A13-StagePoint`

## 개발 환경

- Swift / SwiftUI, iOS / iPadOS 18 이상, iPhone·iPad 가로 화면
- Xcode 16 이상 (실제 검증 버전은 아래 검증 기록에 명시)
- 기존 단일 기기 도구는 기기 내부에서 처리합니다. 새 두 기기 모드는 WebRTC 패키지와 로컬 연결 서버가 필요합니다.
- `StagePoint.xcodeproj`를 열고 `StagePoint` 스킴을 실행합니다.
- 실제 iPhone 실행 시 Signing & Capabilities에서 본인의 Development Team을 선택합니다.

## 1차 두 기기 프로토타입 — 2026-09-29

StagePoint의 최신 원격 `develop`에서 출발해 StageVision의 RoomPlan 스캔 방식을 통합하고, Figma 와이어프레임을 네이티브 SwiftUI 화면으로 구현했습니다.

- iPhone: RoomPlan 스캔 → 공연 구역 수동 수정·확정 → 고정 카메라의 네 기준점 보정 → 독립 검증점 3곳 기록 → 큰 가로 촬영 화면.
- iPad: 실시간 WebRTC 영상, 큰 무대 평면도, 목표 A 변경 및 촬영 기기의 반영 응답.
- 통신: 같은 Wi-Fi에서 촬영 1대 + 운영 1대. 스캔 중에는 영상 대신 진행 상태를 공유합니다.
- 별도 진입점에서 기존 사각형 자동 제안·표준 무대 보관함·오차 측정 도구를 사용할 수 있습니다. 기존 보관함을 새 실시간 모드에 가져오는 기능은 다음 단계입니다.
- 이어폰·Watch·비콘·무용수/장애물 추적·공연 큐·안전 구역 편집은 이번 범위에 포함하지 않습니다.

실행 순서, 로컬 서버 설정, 검증 결과와 한계는 [1차 구현 기록](docs/phase1.md)을 확인하세요. 아래 기존 기능 설명은 **기존 단일 기기 매핑 도구** 기준입니다.

## iPad 확장

원격 `develop`의 `dae8e4a`에서 만든 `feat/#5-iPadSupport` 브랜치에서 작업했습니다. `#5`는 기존 1~4번 작업을 잇는 로컬 작업 번호이며, 실제 GitHub 작업 이슈는 [#10](https://github.com/wsysangyoung2730-debug/2026-C6-A13-StagePoint/issues/10)입니다. 로컬 구현·검증 후 원격에 푸시하고 `develop` 대상 PR로 통합합니다.

- Xcode 실행 대상에서 연결한 iPad 또는 iPad 시뮬레이터를 선택합니다. 실제 기기는 Development Team 서명이 필요합니다.
- 아이폰 호환 화면을 확대하는 방식이 아니라 iPad를 지원 기기로 포함한 공용 앱입니다.
- 사용 가능한 화면 너비가 1,000pt 이상이면 300~360pt 설정 패널, 큰 평면도와 기준점 손잡이를 사용합니다. 더 좁은 화면에서는 기존의 간결한 배치를 사용합니다.
- 영상의 종횡비와 영상 바깥 여백을 유지합니다. 터치·기준점·목표 표시는 같은 영상 좌표를 사용하며 무대 크기의 정규화 계산은 바뀌지 않습니다.
- 이번 범위는 **고정 카메라용 가로 화면(Landscape Right)**입니다. 반대 가로 방향·세로 촬영·완전한 다중 창 지원은 포함하지 않습니다. 촬영 방향을 늘리려면 카메라 프레임 회전과 매핑 무효화도 함께 검증해야 합니다.
- 기존 `UIRequiresFullScreen` 설정을 유지합니다. 최신 iPadOS의 창 관리 동작에 대해서는 [Apple의 전체 화면 설정 이행 안내](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)를 참고하세요. 모든 창 크기에서의 사용을 보장하는 버전은 아닙니다.

실제 iPad 카메라의 영상 방향·인식률·물리적 위치 오차는 별도 현장 검증이 필요합니다.

## Git 전략

### 태그 컨벤션

| 태그 | 용도 |
| --- | --- |
| `init` | 최초 Initial Commit. 실제 Git 태그 `init`도 붙입니다. |
| `feat` | 새로운 기능 구현 |
| `fix` | 버그·오류 해결 |
| `docs` | README·템플릿 등 문서 수정 |
| `setting` | 프로젝트 설정 변경 |
| `add` | 사진·에셋·라이브러리 추가 |
| `refactor` | 기존 코드 리팩토링 |
| `chore` | 기타 작은 수정 |

`feat`, `fix` 등은 커밋·브랜치의 분류 접두어이며 같은 이름의 Git 태그를 매번 만들지 않습니다.

### 커밋 컨벤션

- 태그는 소문자, 내용은 한글로 작성합니다.
- 제목은 50자 이내의 간단한 명령조로 작성합니다.
- 형식: `[태그] 작업 내용` (예: `[feat] 무대 기준점 드래그 구현`)
- 부가 설명은 커밋 본문에 작성합니다.
- 기능·문서·버그 수정은 의미 있는 단위로 나눠 커밋합니다.

### 브랜치 컨벤션

형식: `태그/#이슈번호-작업하는파일`

예: `feat/#2-StageMapping`. 쉘에서는 `#`가 포함된 브랜치 이름을 따옴표로 감쌉니다.

### 브랜치 전략

- `main`: 출시 브랜치. 검증된 `develop`을 PR로 머지합니다.
- `develop`: 기본 브랜치. 개발한 기능을 최종 통합·검증합니다.
- 작업 브랜치: 모든 기능·버그 수정·문서 작업은 이슈별 브랜치에서 수행합니다.
- 작업이 끝나면 작업 브랜치에 최신 `develop`을 먼저 머지하고, `develop` 대상 PR을 만듭니다.
- 세부 커밋을 보존하기 위해 merge commit 방식으로 통합합니다.
- 빈 저장소의 첫 초기화 커밋만 `main`에서 만들고 `init` 태그와 `develop`을 생성합니다.

```sh
git switch develop
git pull --ff-only origin develop
git switch -c 'feat/#2-StageMapping'
# 구현 및 세부 커밋
git fetch origin
git merge origin/develop
git push -u origin 'feat/#2-StageMapping'
# develop 대상 PR → 검증 → merge commit
```

## 작업 순서

1. #1 프로젝트 구조·Git 전략: `setting/#1-StagePointApp`
2. #2 카메라·사각형 제안·수동 매핑: `feat/#2-StageMapping`
3. #3 표준 무대·정규화 목표 배치: `feat/#3-StageTemplate`
4. #4 오차 측정·통합 검증: `feat/#4-AccuracyValidation`

## 코드 구조

- `StagePoint/`: SwiftUI 앱, 카메라 입력, 파일 저장
- `Packages/StagePointCore/`: 좌표 변환·정규화·검증 계산과 단위 테스트
- `StagePointUITests/`: 시뮬레이터에서 카메라 없이 실행하는 UI 테스트
- `Config/`: 앱 권한과 화면 방향 설정

## 구현 기능

### 1. 사각형 자동 제안과 손 보정

앱을 열면 카메라의 첫 프레임에서 Vision으로 사각형 후보를 찾습니다. 후보는 무대의 의미를 이해한 결과가 아니므로 사람이 무대 바닥인지 확인해야 합니다. 후보를 선택하고 A·B·C·D를 드래그한 뒤 실제 가로·세로(m)를 입력해 **매핑 적용**을 누릅니다. 후보가 없으면 **수동**으로 네 점을 배치합니다.

- 카메라 영상과 Vision 모두 같은 가로 프레임을 사용합니다. 이미지 맞춤 표시의 여백을 좌표 계산에서 제외합니다.
- A=관객 기준 앞쪽 왼쪽, B=앞쪽 오른쪽, C=뒤쪽 오른쪽, D=뒤쪽 왼쪽입니다.
- 카메라를 무대 뒤쪽에 두었다면 **앞쪽 A·B 전환**으로 좌표 기준을 확인합니다.
- 네 점의 교차·퇴화·화면 밖 좌표를 검사합니다. 입력 치수는 0 초과~100m입니다.
- 인식 중 손 보정을 막고, 늦게 도착한 과거 인식 결과는 폐기합니다.
- 카메라 없는 시뮬레이터에서는 합성 데모 무대로 같은 Vision 요청을 실행합니다.

### 2. 표준 무대 작성 → 저장 → 실제 무대에 배치

상단 **표준 무대**에서 가로·세로를 입력하고 평면도를 눌러 목표 A를 지정합니다. 숫자 좌표 입력과 여러 목표도 지원합니다. **저장 후 무대에 배치**하면 기기 보관함에 저장되고 실제 카메라 화면에 목표가 투영됩니다. 저장한 무대는 보관함에서 다시 선택하거나 JSON으로 내보내 다른 기기에 가져올 수 있습니다.

```text
표준 무대: 6 × 4m, 목표 A: (2, 3)m
저장 비율: u = 2/6, v = 3/4
실제 무대: 9 × 8m
실제 목표: (u×9, v×8) = (3, 6)m
화면 표시: Homography(u, v)
```

가로·세로 비율을 각각 적용합니다. 절대 이동 거리나 안무의 종횡비를 보존하는 기능은 아닙니다. 같은 관객 기준 원점을 사용해야 합니다. 표준 목표를 가져온 뒤 현장에서 터치로 바꿔도 보관함 원본은 바뀌지 않습니다.

`Examples/standard-stage.json`을 파일 앱을 통해 가져와 바로 시험할 수 있습니다. JSON은 버전, 이름, 기준 크기, 정규화 목표 좌표를 포함하며 버전·좌표 범위·목표 ID·파일 크기를 검증합니다.

### 3. 독립 검증점의 오차 기록

**정확도 검증**에서 기준점 등록에 쓰지 않은 바닥 표식을 선택하고, 줄자로 잰 실제 X/Y를 입력합니다. 계산한 위치와 실제 위치의 유클리드 거리를 cm로 표시하고 저장합니다. 평균·최대 오차는 같은 매핑 ID의 기록만 모아 계산합니다. 전체 기록과 JSON 내보내기를 지원합니다.

측정 기록에는 실제·계산 좌표, 무대 치수, 네 기준점, 매핑 ID, 기기 설명, 날짜, 데모 여부가 들어갑니다. 매핑은 재실행 시 자동 복원하지 않으며 다시 확인해야 합니다. 표준 무대와 측정 기록만 기기에 저장합니다. 영상은 저장하거나 전송하지 않습니다.

## 첫 실행 순서

1. 실기기에 설치하고 카메라를 허용합니다. 가로 화면에서 iPhone을 고정합니다.
2. **자동 제안** → 후보 선택 → 네 모서리 보정 → 실제 치수 입력 → **매핑 적용**.
3. **표준 무대** → 표준 크기와 목표점 작성 → **저장 후 무대에 배치**.
4. 카메라와 평면도에서 같은 목표 비율·실제 좌표를 확인합니다.
5. **정확도 검증**에서 별도의 바닥 표식과 실측 좌표를 비교합니다.

카메라를 움직였거나 앱·촬영이 중단되면 다시 매핑합니다. 평평한 바닥을 전제로 하며 렌즈 왜곡·가림·설치 거리 등 실물 오차는 별도 측정해야 합니다. 이 버전은 위치 매핑 연구용이며 사람 추적·햅틱·공연 큐·충돌 방지는 구현 범위에 포함하지 않습니다.

## 로컬 검증

```sh
swift test --package-path Packages/StagePointCore
xcodebuild -project StagePoint.xcodeproj -scheme StagePoint \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

시스템 개발 경로가 Command Line Tools이면 명령 앞에 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 지정합니다. 전역 설정을 바꿀 필요는 없습니다.

UI 테스트는 설치된 시뮬레이터 이름 또는 ID를 지정합니다.

```sh
xcodebuild -project StagePoint.xcodeproj -scheme StagePoint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

`--demo` 실행 인수는 카메라 대신 합성 무대를 사용합니다. `--uitesting`은 사용자 파일과 분리된 테스트 저장 파일을 사용합니다.

## 검증 기록

### iPad 확장 — 2026-09-28

- Xcode 26.5: 좌표 계산 단위 테스트 12개, 공용 시뮬레이터 빌드와 실제 기기용 Release 빌드(서명 제외) 통과.
- iPad Pro 11-inch (M5), iPadOS 26.5: UI 테스트 4개 통과.
- iPad mini (A17 Pro), iPadOS 26.5: UI 테스트 4개 항목 통과. 첫 실행의 측정 테스트는 시뮬레이터 background assertion 시간 초과로 중단되어, 같은 코드로 해당 항목을 재실행해 통과했습니다.
- iPhone 17 Pro, iOS 26.5: 기존 기능 및 화면 배치 UI 테스트 4개 통과.
- 추가한 화면 검증은 가로 전체 화면, 무대 영역 크기, 패널 겹침, 손잡이 잘림, 주요 버튼 접근, 표준 무대 편집 영역을 확인합니다. 데모 화면 캡처를 시각적으로도 확인했습니다.
- 위 결과는 로컬 검증 기록입니다. 이후 원격 CI 및 통합 결과는 [이슈 #10](https://github.com/wsysangyoung2730-debug/2026-C6-A13-StagePoint/issues/10)에서 확인합니다. 실제 iPad 카메라 검증은 수행하지 않았습니다.

### 최초 버전

2026-09-23 기준:

- Xcode 26.5: 좌표·원근 변환·표준 파일·오차 계산 단위 테스트 12개 통과.
- iPhone 17 Pro / iOS 26.5 시뮬레이터: UI 테스트 3개 통과. 실제 Vision 사각형 제안, 모서리 조정, 목표 비율 배치·재실행 복원, 측정 저장·기록 목록과 재매핑 시 무효화를 확인했습니다.
- iPhone 대상 Release 빌드 성공 (`CODE_SIGNING_ALLOWED=NO`). 기기 설치·배포에는 별도 개발자 서명이 필요합니다.
- 자동 빌드는 `develop`·`main` 대상 PR 및 push에서 단위 테스트와 시뮬레이터 빌드를 실행합니다. 실행별 결과는 GitHub Actions에서 확인합니다.
- GitHub Actions의 Xcode 16.4: 단위 테스트와 iOS 시뮬레이터 빌드 통과.

위 테스트는 수학적 변환과 앱 흐름의 검증입니다. 실제 무대에서의 카메라 인식률·cm 단위 물리 오차·공연 안전성을 입증하지 않습니다.

## 실기기에서 확인할 항목

- 무대 전체가 보이는 설치 위치에서 사각형 후보가 실제 바닥을 가리키는지
- A/B가 관객 기준 앞쪽이고 카메라 영상이 올바른 방향인지
- 근거리·원거리·가장자리의 별도 검증점 오차
- 인식 실패 시 수동 보정 및 카메라 위치 변경 후 재매핑
- 다른 기기에서 JSON을 가져와 같은 비율로 배치되는지

## 공식 기술 자료

- [Vision 사각형 검출](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest)
- [AVFoundation 영상 회전](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)
- [OpenCV Homography 설명](https://docs.opencv.org/4.x/d9/dab/tutorial_homography.html) — 수학 원리 참고. OpenCV 라이브러리 의존성은 없습니다.
