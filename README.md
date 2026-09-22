# StagePoint

고정 iPhone 카메라에서 무대 바닥의 기준점을 지정하고 목표 위치의 매핑 정확도를 검증하는 Swift 앱입니다.

프로젝트: `2026-C6-A13-StagePoint`

## 개발 환경

- Swift / SwiftUI, iOS 18 이상, iPhone 가로 화면
- Xcode 16 이상 (실제 검증 버전은 아래 검증 기록에 명시)
- 외부 서버·유료 SDK 없이 기기 내에서 처리
- `StagePoint.xcodeproj`를 열고 `StagePoint` 스킴을 실행합니다.
- 실제 iPhone 실행 시 Signing & Capabilities에서 본인의 Development Team을 선택합니다.

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

## 로컬 검증

```sh
swift test --package-path Packages/StagePointCore
xcodebuild -project StagePoint.xcodeproj -scheme StagePoint \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

시스템 개발 경로가 Command Line Tools이면 명령 앞에 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 지정합니다. 전역 설정을 바꿀 필요는 없습니다.
