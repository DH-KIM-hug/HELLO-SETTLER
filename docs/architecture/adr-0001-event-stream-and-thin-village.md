# ADR-0001: 사건 기록 흐름과 얇은 `Village` 겉면

## Status
Proposed (TD-ADR CONCERNS·엔진 전문가 BLOCKING 2건 반영한 개정판, 2026-11-07)

## Date
2026-11-07

## Last Verified
2026-11-07 (코드 읽기: godot/sim/village.gd 3,745줄, firsts.gd, catch_up.gd, health.gd, 호출처 집계 · 엔진 참고 문서 `docs/engine-reference/godot/` 2026-11-07 작성본으로 확인).

## Decision Makers
사용자(거인 단위 안내·도구 결정, 2026-11-07) · technical-director (TD-SYSTEM-BOUNDARY) · 메인 세션

## Summary
시뮬레이션에서 일어난 일이 연대기·연출·안내 창·알림·시험에 닿는 길이 계통마다 달라(연대기 줄, 발견 기록, `just_*` 표시 변수, static 전역) `village.gd` 한 파일에 계통이 몰리고 병렬 작업이 충돌한다. **날짜가 찍힌 구조화 사건을 한 줄(`EventStream`)에 쌓고 나머지는 구독만 하게** 하며, `Village`는 마을 하나의 상태를 담고 계통을 부르는 얇은 겉면으로 줄이고, static 전역 상태를 없앤다.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile 렌더러) |
| **Domain** | Core (시뮬레이션 구조·스크립팅) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM — 4.4~4.7은 참고 문서로 확인. 이 ADR은 `RefCounted`·`Array`·`Dictionary`·`StringName`만 쓴다 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.3→4.7), `modules/gdscript.md` (static var: 클래스 단위 공유·`@static_unload` 해제 버그 기록), `modules/threading.md` (RefCounted 스레드 안전성은 문서에 없음, 컨테이너 크기 변경은 뮤텍스 필요) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | 사건 줄 쓰기 비용(10초 걸음당), 따라잡기 6일 동안 사건 수·메모리, 헤드리스 시험에서 결정성, 저장 크기 · 따라잡기를 `WorkerThreadPool`로 옮길 경우 사건 줄(배열 크기 변경)은 한 스레드에서만 쓰거나 뮤텍스 (threading.md) · 4.7 패킹 배열 요소 설정이 setter를 부르지 않음 — 사건 줄에서 setter로 dirty를 세우지 않음 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | 사건 연출 / 안내·수첩 / 연대기·편지 / 알림 GDD (모두 이 줄을 구독), 필요와 기분·촌장의 결정 GDD (이 줄에 사건을 냄), `village.gd` 나누기 에픽 |
| **Blocks** | `village.gd` 나누기 에픽 · 알림·세션 끝 훅(#30) · 사건 연출 연결 정리 — 이 ADR이 Accepted가 되기 전에는 시작하지 않음 |
| **Ordering Note** | 나누는 동안 다른 작업이 `village.gd`를 건드리지 않도록 잠금 (PR-SCOPE 지적). 이 ADR이 Accepted된 뒤 한 담당이 짧게 진행 |

## Context

### Problem Statement
오늘 코드에서 "일어난 일"이 밖으로 나가는 길은 다섯 가지다.
1. `log_line(text)` — 연대기 줄 (호출처 약 190곳: village 67, small_crises 33, mold 16, wildlife 13, flora 12, village_era 10, giant_hand 6, sky_drops 6 …). 문자열만 남는다.
2. `note_discovery(id, who)` — 도감.
3. `just_manna`, `just_blueprint`, … — "방금 ~했다" 표시를 시뮬레이션 안에 켜 두고 화면이 읽어서 끄는 변수 (`view/manna_fx.gd`, `view/sky_drop_view.gd`).
4. `Firsts.fire(id)` / `StageDirector.play(id, village)` — 화면 쪽이 어떤 상태를 보고 안내 창·연출을 직접 띄운다.
5. `giant_acted()` — 거인의 행동이 끝났다는 콜백 (저장).
그리고 `Firsts`(seen·tools·queue·plays), `CatchUp`(fast·step_override·rate_override), `Health`(_wmax)는 **static 전역 상태**라 병이 여러 개가 되면 서로 섞인다. 표시 변수와 static은 "보는지 여부가 결과에 영향"을 주는 길도 열어 둔다 (`is_watching`·`pace_walk`·`staged`가 시뮬레이션 안에 있음).

### Constraints
- 헤드리스 시험(결정성, 600여 개)이 계속 통과해야 한다. 보통 이하 속도의 결과는 프레임 예산과 무관해야 한다 (오늘 고침).
- 따라잡기(비운 시간)는 그림·연출을 건너뛰어도 사건은 같아야 한다.
- 옛 저장은 늘 읽힌다 (`book` 형식 보존).
- 폰 성능: 10초 걸음마다 사건 줄 쓰기가 비용이 되면 안 된다 (TD 예산: 시뮬 ≤ 8ms/프레임).
- 4~5개월 일정, 한 담당이 짧게 끝내야 한다 (PR-SCOPE).

### Requirements
- 시뮬레이션은 사건만 내보내고, 연출·안내·연대기·알림·시험은 구독만 한다.
- 거인이 보든 말든 사건은 똑같이 쌓인다 (연출 길이만 다름).
- 한 거인에게 속한 것(처음 겪는 사건 안내 `seen`, 열린 도구)은 병이 아니라 **거인 단위** (사용자 확정).
- 시뮬레이션 상태는 `JarWorld`/`Village` 인스턴스 안에만. static 전역 상태 금지.

## Decision

### 1) 사건 기록 흐름 (`EventStream`)
`sim/event_stream.gd` (`RefCounted`, Node 아님). 병(`JarWorld`)마다 하나, 그 병의 마을들이 같이 씀.
- 사건 = `Dictionary` `{"n": 번호, "t": 병 시각, "village": 마을 id, "kind": StringName, "who": 주민 id 또는 -1, "at": Vector2 또는 null, "v": 값}`. `data`에는 숫자·문자열·StringName·Vector2·id만 — **어떤 Object도(Node·Resident·Village 포함) 넣지 않는다** (RefCounted는 순환 참조를 치우지 못함, 헤드리스·알림에서 같은 사건을 읽기 위함).
- `emit(kind, data := {}) -> int` — 시뮬레이션의 유일한 출구, O(1) 추가, **난수를 쓰지 않는다**. 부른 쪽은 넘긴 `data`를 그 뒤 고치지 않고, 구독자는 받은 사건을 읽기만 한다 (복사 비용 없이 공유).
- **고정 창 둥근 버퍼**: 최근 `CAP`건만 둔다 (CAP은 측정 후 확정, 시작값 4,096). 내부 `_base`(가장 오래 남은 번호)로 위치 = `n - _base`. 넘치면 앞부분을 `slice()`로 한 번에 잘라 냄 (`remove_at(0)` 반복 금지). 자르는 기준은 구독자 등록 없이 창 크기만 — **시뮬레이션은 구독자를 모른다**.
- `since(cursor) -> Array[Dictionary]` 와 `oldest() -> int`: 커서가 `oldest()`보다 오래되면 구독자는 "놓친 사건이 있다"를 안다 (연출은 놓친 것을 건너뛰고, 시험은 창을 키워 돌림). 반환은 형을 정한 지역 변수에 담아 돌려준다 (`slice()` 결과의 형 유지가 문서로 확인되지 않음 — 시험으로 고정).
- **연대기는 늦게 읽는 구독자가 아니다**: 연대기에 남는 kind는 `emit` 안에서 바로 `book`에 문장으로 쓴다 (사건 줄은 저장하지 않으므로 읽기 전에 저장되면 잃는다). `kind → 문장 만드는 함수` 표, 키는 모두 `&"…"`로 통일 (StringName/String 키 동등성은 문서로 확인되지 않음 — 시험으로 고정). `log_line(text)`는 호환 껍데기로 `emit(&"chronicle", {"text": text})`. 옛 `book` 저장 형식 그대로.
- **저장 순번과 사건 번호를 나눈다**: 지금 `event_serial`은 저장 신호다 (`save_manager.gd`가 바뀌면 곧 저장 — 연대기·위기 때만 오름; `notebook.gd`·`awakening.gd`는 사건 없이 올림). 사건 번호 `n`은 새 값으로 두고, `event_serial`은 **저장 순번(dirty)**으로 이름 그대로 남겨 연대기·위기 kind와 지금 올리는 곳에서만 올린다 → 10초마다 저장되는 일 없음.
- 사건 줄은 **저장하지 않는다**. 불러온 뒤 모든 구독자 커서는 줄의 끝(`clear_to_end()`), 따라잡기 뒤에는 **화면 구독자 커서만** 끝으로 (연대기는 이미 `emit`에서 씀).
- **따라잡기 중에도 모든 사건이 쌓인다** (보든 안 보든 같음). 메모리는 고정 창이 지키고, 연출 구독자 쪽이 따라잡기 사건을 걸러 무시한다 (쌓는 쪽에서 거르지 않음).
- 사건 `kind` 목록은 `docs/architecture/event-kinds.md`에 모으고 새 kind는 거기 먼저 적는다.

### 2) 구독자 (모두 읽기만)
| 구독자 | 하는 일 | 어디 |
|---|---|---|
| 연출 | 사건 → 연출 표 (`Stagings`) 로 `StageDirector.play` | view |
| 안내 창 | 사건 → `Firsts` 큐 | view/sim 경계, 거인 단위 |
| 연대기 | 사건 중 연대기용만 문장으로 | sim |
| 알림 (#30) | 비운 사이 일어난 사건 중 알릴 것 | sim → OS |
| 시험 | 사건 줄을 읽어 "이 상황에서 이 사건이 나왔는가" | tests |
- **`just_*` 표시 변수는 없앤다** — 화면은 사건을 읽는다. 마이그레이션 동안은 사건을 내보내며 같은 이름의 변수도 같이 켜 두는 호환 기간을 둔다.

### 3) 거인이 있는지(입력) ↔ 연출(결과에 영향 없음) — 계약을 둘로 나눔
지금 기획은 **거인이 지켜보는지에 따라 결과가 일부 달라진다** — 지켜볼 때 태어난 아기의 첫 믿음(`BELIEF_BABY_WATCHED`/`ALONE`), 안 볼 때 시대 점수 0.3배(`era_watch_k`), 거인이 없으면 새 위기가 조짐에서 기다림(mold·small_crises, SAVE 3·GD 14장), 계시 자동 여부·중얼거림. 이것은 **기획상 입력**이므로 유지한다. 계약:
- **거인이 있음(presence)** = 시간대가 찍힌 **입력**. `Village.set_watching(bool)`으로만 바뀌고, 바뀔 때 `emit(&"watch_changed", {"on": …})`로 기록한다. 같은 씨앗 + 같은 지켜봄 입력 기록이면 결과가 같다.
- **연출** = 카메라, 연출 길이, 연출 중 걸음 속도, 말풍선·마을의 삶 장면 표시 (`stage_on`·`pace_walk`·`staged`, `Social.stage_on`). **결과를 바꾸지 않는다** — 연출이 시간을 늦추고 싶으면 JarClock(화면)이 속도를 낮춘다. 시뮬레이션 안의 연출 의존은 화면 쪽으로 옮긴다.
- 시험 (a)는 "**같은 지켜봄 입력이면 연출을 켜든 끄든 결과(연대기·위치·난수)가 같다**"로 한다.
- 기획서의 "보는 곳만 자세히 계산"은 **계산의 정밀도**(화면 밖 요약 계산·따라잡기 빠른 길)에 관한 원칙이며 이 계약과 충돌하지 않는다 — 정밀도 차이는 통계적으로 같은 결과를 내는 별도 시험(따라잡기 빠른 길 시험)이 지킨다.

### 4) `Village`는 얇은 겉면
`sim/village.gd`는 마을 하나의 **상태를 담고 계통을 부르는** 겉면으로 줄인다.
- 각 계통은 자기 파일에 **상태와 규칙**을 가진다 (systems-index.md 계통 번호와 1:1): 필요와 기분, 촌장의 결정, 일정·일자리, 움직임·길, 건물·짓기, 인구, 깨달음·믿음, 제단·공물, 소원, 손길 …
- 각 계통은 **자기 `to_dict/from_dict`와 판 올림**을 가진다. 저장 계통(`save_manager`·`save_codec`)은 입출력·코덱·판 사이 옮김만.
- 계통 사이 호출은 `Village`를 통하거나 사건으로. 계통이 다른 계통의 상태를 직접 쓰지 않는다 (금지 패턴, 아래).
- 나누기는 **계통마다 차례로 떼어 내며 한 번에 하나**. 떼어 낼 때마다 헤드리스 시험 통과를 유지하고 커밋을 작게 한다.

### 5) static 전역 상태 금지 — 전체 목록과 행선지
| 지금 static | 행선지 |
|---|---|
| `Firsts.seen`·`tools`·`plays` | **`Giant`** (거인 단위, 저장 묶음 `firsts`) — 여러 병의 사건 줄을 읽도록 병마다 커서를 `Giant`가 가짐 |
| `Firsts.queue`·`_dry_since` | `Village` (병·마을 단위) |
| `Market`의 지폐·손에 든 물건·이주민 뽑기 흐름·등불·`first_paid` (`market.gd`) | **`Giant`** (거인의 지갑 — systems-index #22) |
| `Village.on_giant_action`(static Callable)·`default_created`·`start_aware` | 인스턴스: SaveManager가 각 `Village` 인스턴스에 연결 (시험의 static 훅 바꾸기 패턴도 인스턴스 방식으로) |
| `Social.stage_on`·`rate`·`_lines` | `stage_on`·`rate`는 화면(연출) 쪽으로, `_lines`(대사 표)는 읽기 전용 데이터 — const 취급 허용 |
| `CatchUp.fast`·`step_override`·`rate_override` | `CatchUp` 인스턴스 설정 |
| `Health._wmax` | `Village`(또는 Health 인스턴스) 캐시 |
| `JarWater.dew_legacy`, `SaveCodec.errors`, `SimProf.*` | **허용 예외**: 시험 전용 스위치(`dew_legacy`)·진단 수집(`SimProf`)은 금지 검사 예외 목록에 명시. `SaveCodec.errors`는 호출 결과로 돌려주도록 인스턴스화 |
- 순수 `const` 표와 위 허용 예외 외의 `static var`는 금지 — 시험 (d)가 예외 목록을 뺀 grep으로 검사.

### Architecture Diagram
```
  계통들 (sim/*, 각자 상태·규칙·to_dict/from_dict)
     │ emit(kind, data)           ▲ Village 겉면을 통한 호출
     ▼                            │
  EventStream (병마다 1개, 단조 번호, 저장 안 함) ──────────┐
     │ since(cursor)                                        │
     ├──▶ 연출 (StageDirector/Stagings, view)               │
     ├──▶ 안내 창 큐 (Firsts, 거인 단위)                    │ 시험도 읽음
     ├──▶ 연대기 (book 파생, 저장됨, 옛 형식 호환)          │
     └──▶ 알림 (#30)                                        ▼
                                                   tests (결정성·사건 검증)
```

### Key Interfaces
```gdscript
# sim/event_stream.gd
class_name EventStream
extends RefCounted
func emit(kind: StringName, data: Dictionary = {}) -> int   # 번호를 돌려줌
func since(serial: int) -> Array[Dictionary]                # 이 번호보다 큰 사건들
var serial: int                                             # 마지막 사건 번호 (event_serial과 별개 — 그건 저장 순번)
func oldest() -> int                                        # 창에 남은 가장 오래된 번호
func clear_to_end() -> int                                  # 끝 번호 (불러온 뒤·따라잡기 뒤 화면 구독자 커서용)
# 4.7: 덮어쓰는 메서드는 부모 반환형을 물려받고 명시적 return이 필요 (시험용 가짜 객체도)

# Village (겉면)
var events: EventStream
func log_line(text: String) -> void   # 호환 껍데기: events.emit(&"chronicle", {"text": text})
```

### Implementation Guidelines
- 시뮬레이션 코드는 **반드시** 사건을 `events.emit`으로 낸다. **절대** 화면 쪽 상태(`just_*`, 카메라, 연출 중 여부)를 읽거나 쓰지 않는다.
- 사건 `data`에는 **반드시** 숫자·문자열·StringName·Vector2·id만 — **어떤 Object도 금지** (Node·Resident·Village 포함). `EventStream`은 `Village`를 거꾸로 가리키지 않는다.
- `emit`은 **절대** 난수를 쓰지 않고, 구독자는 **절대** 시뮬레이션 상태에 쓰지 않는다 (결정성 시험 (a)·(b)의 전제).
- 따라잡기를 `WorkerThreadPool`로 옮기면, 그 동안 `Village`+`EventStream` 묶음 전체를 작업 스레드 하나만 쓰고 메인은 `wait_for_task_completion` 뒤에만 `since()`를 읽는다 (RefCounted 스레드 안전성은 문서에 없음 — 소유를 넘기는 방식).
- 구독자는 **반드시** 자기 커서를 가진다. 시뮬레이션이 구독자 목록을 알면 안 된다.
- `static var`는 **절대** 새로 만들지 않는다 (const와 시험 도우미 제외).
- 사건 종류를 새로 만들면 **반드시** `docs/architecture/event-kinds.md`에 먼저 적는다.
- 사건 줄은 **저장하지 않는다**. 저장해야 하는 것은 해당 계통이 자기 상태로 저장한다.
- 나누기 중에는 `village.gd`에 새 기능을 얹지 않는다 — 해당 계통 파일에 쓴다.

## Alternatives Considered

### Alternative 1: 지금 방식 유지 (`log_line` + `just_*` + 화면이 상태를 봄)
- **Description**: 새 연출이 필요할 때마다 시뮬레이션에 표시 변수를 더하고 화면이 읽어 끈다.
- **Pros**: 바꿀 것이 없음. 이미 돌아감.
- **Cons**: 계통이 `village.gd`에 몰려 병합 충돌이 반복되고, 보는지 여부가 결과를 바꿀 길이 열려 있으며, 알림(#30)·연출·안내가 같은 상태를 제각기 해석해 어긋난다. static 전역은 여러 병에서 깨진다.
- **Rejection Reason**: 첫 출시에 알림·소원·계시 같은 사건이 늘어날수록 비용이 커지고 충돌이 반복됨.

### Alternative 2: Godot 신호(signal)로 직접 알림
- **Description**: 시뮬레이션 객체가 `signal`을 선언해 화면이 연결한다.
- **Pros**: 엔진 관용구, 가벼움.
- **Cons**: 따라잡기 6일 동안 수많은 신호를 흘려보내거나 걸러야 하고, 사건을 나중에 다시 읽기(알림·시험) 어렵고, 연결 순서에 결과가 묶일 수 있다.
- **Rejection Reason**: (RefCounted도 신호를 가질 수 있다 — `giant_hand.gd`에 이미 있음.) 진짜 이유는 신호가 **미는 방식이라 나중에 다시 읽을 수 없고**(알림·시험·따라잡기 뒤), 구독자 연결 순서에 결과가 묶일 수 있다는 점이다.

### Alternative 3: 한 번에 `village.gd`를 계통별 파일로 크게 나누기 (빅뱅)
- **Description**: 한 작업으로 모든 계통을 새 파일로 옮긴다.
- **Pros**: 구조가 한 번에 정리됨.
- **Cons**: 3,745줄과 호출처 수백 곳이 동시에 바뀌어 병렬 작업·시험·저장 호환과 크게 충돌하고, 일정(4~5개월)에 위험.
- **Rejection Reason**: 계통마다 차례로 떼어 내며 시험을 유지하는 점진 이행이 안전.

## Consequences

### Positive
- 새 연출·안내·알림은 `village.gd`를 고치지 않고 구독자만 더하면 된다 → 병합 충돌이 줄어 병렬 작업이 쉬워진다.
- 보든 안 보든 같은 사건 → 따라잡기·알림·결정성 시험이 같은 근거를 쓴다.
- 병이 여러 개가 되어도 `Firsts`·`CatchUp`·`Health`가 섞이지 않는다.

### Negative
- 이행 동안 `log_line` 호출 약 190곳을 점진적으로 구조화 사건으로 바꿔야 하고, 호환 기간 동안 두 길이 함께 존재한다.
- 사건 `kind` 표를 관리해야 한다.
- 사건 줄이 메모리를 쓴다 (따라잡기 6일 동안 수만 건 가능) — 상한과 비움 규칙 필요.

## Risks
- **사건 줄이 커져 따라잡기 메모리·시간이 늘어남** → 구독자 커서 이전 사건은 주기적으로 잘라 내고, 따라잡기 중에는 연대기용·알림용 kind만 쌓는다 (측정 후 확정).
- **이행 중 `just_*`와 사건이 어긋남** → 호환 기간에는 한 곳(`emit`)에서 두 길을 함께 켠다 + 시험으로 같은지 확인.
- **나누는 동안 다른 작업이 충돌** → 잠금 (이 ADR이 Accepted될 때까지 시작하지 않음, 시작하면 `village.gd` 잠금을 공지).
- **static var 해제 버그** (`@static_unload`를 써도 스크립트가 해제되지 않음 — gdscript.md) → static 전역 금지의 근거가 하나 더.
- **스레드로 옮길 때** RefCounted 스레드 안전성은 문서에 없음 → 따라잡기를 스레드로 옮기면 병 하나는 한 스레드만 만지고, 사건 줄은 그 스레드에서만 씀.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md (기둥 1·2) | 지켜봄은 기획상 입력(아기 믿음·시대 점수·위기 대기), 연출은 결과를 바꾸지 않음, 막힌 곳이 화면에서 보임 | 3절: 지켜봄 = 기록된 입력, 연출 = 결과 무영향 |
| systems-index #7 사건 기록 흐름 | 시뮬레이션은 날짜 찍힌 사건만 내보내고 연출·안내·연대기·알림은 구독 | `EventStream` 정의 |
| systems-index #1 시간·따라잡기 | 따라잡기 중 연출 생략, 결과 같음 | 사건은 같이 쌓고 커서를 끝으로, 연출만 생략 |
| systems-index #26 안내·수첩 | 처음 겪는 사건 안내·열린 도구는 거인 단위 | `Firsts` static 상태를 거인 인스턴스로 |
| systems-index #5 저장 | 각 계통이 자기 직렬화, 옛 저장 항상 읽힘 | 계통별 `to_dict/from_dict`, `book` 형식 보존 |
| systems-index #22 선반·여러 병 | 병마다 상태 분리 | static 전역 금지 |
| systems-index #30 알림 | 비운 사이 알릴 사건 | 알림이 사건 줄을 구독 |

## Performance Implications
- **CPU**: `emit`은 배열 추가 O(1). 10초 걸음당 수십 건 이하로 예상 (따라잡기 6일 ≈ 수만 건, 측정 필요).
- **Memory**: Dictionary 한 건 수백 바이트(추정) — 고정 창 CAP(시작 4,096건)이 상한을 지킴 (≈ 1~2MB, 측정 후 CAP 확정). 그래도 크면 kind를 정수로, 또는 열별 Packed 배열 검토.
- **Load Time**: 사건 줄은 저장하지 않아 불러오기 영향 없음.
- **Network**: 해당 없음.

## Migration Plan
1. `EventStream` 추가, `Village.events` 생성, `log_line`을 호환 껍데기로 (동작 동일). 헤드리스 시험 통과.
2. `just_*` 표시 변수가 있는 곳(`just_manna`·`just_blueprint`)에서 사건도 같이 내고, 화면(`manna_fx`·`sky_drop_view`)을 사건 구독으로 옮긴 뒤 변수 삭제. 옛 저장에 남은 `just_*` 값은 불러올 때 무시한다. 저장 순번(`event_serial`)과 사건 번호를 이 단계에서 나눈다.
3. `Firsts`·`StageDirector.play` 연결을 사건 구독으로: 안내 큐가 사건에서 채워짐. static 상태를 거인 인스턴스로.
4. `Market`(지폐·손에 든 물건 등)을 `Giant`로, `CatchUp`·`Health`·`Village.on_giant_action` 등 static을 인스턴스로 (5절 표). `Social.stage_on`·`pace_walk`·`staged`를 화면 쪽으로.
5. `village.gd`에서 계통을 하나씩 떼어 냄 (우선 순서: 필요와 기분 → 촌장의 결정 → 인구 → 제단·공물 → 손길 …). 떼어 낼 때마다 시험·커밋.
6. 계약 시험 추가: 같은 씨앗 + 같은 지켜봄 입력이면 연출을 켜든 끄든 연대기·위치·난수가 같음.
- 이행 동안 `village.gd` 잠금 공지 (한 담당, 계통 하나당 한 병합).

## Validation Criteria
- 헤드리스 quick 시험이 단계마다 통과 (실패 0).
- 새 시험: (a) 같은 지켜봄 입력이면 연출 켬/끔 결과 동일, (b) 따라잡기 뒤 연대기 줄이 정밀 따라잡기와 동일, (c) 병 둘을 같은 프로세스에서 돌려도 안내·도구·건강 상태가 섞이지 않음, (d) `static var` 금지 검사 (5절 허용 예외 목록을 뺀 grep 시험), (e) 사건 Dictionary 순회 순서·StringName 키 동등성·`since()` 반환 형, (f) 불러온 뒤 커서 = 끝, (g) 10초 걸음 동안 저장 순번이 연대기·위기 없이 오르지 않음.
- `village.gd`가 단계마다 줄어드는 추세 (예: 3,745줄 → 계통 하나 뗄 때마다 감소).
- 사건 줄이 따라잡기 6일 동안 메모리 예산(≤ 2MB 제안) 안.

## Related
- design/gdd/systems-index.md (TD-SYSTEM-BOUNDARY 반영)
- docs/GAME_DESIGN.md 6장, docs/EVENTS_STAGING.md, docs/SAVE.md
- godot/sim/village.gd (`log_line`·`giant_acted`·`event_serial`), godot/sim/firsts.gd, godot/sim/catch_up.gd, godot/sim/health.gd, godot/view/stage_director.gd
- 앞으로: ADR-0002 성능 예산 (실측 뒤), ADR-0003 저장 계약
