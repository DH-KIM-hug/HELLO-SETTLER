# Systems Index: 나의 작은 지구 (My Little Earth)

> **Status**: Approved (사용자 2026-11-07, /map-systems)
> **Created**: 2026-11-07
> **Last Updated**: 2026-11-07
> **Source Concept**: design/gdd/game-concept.md
> **Gates**: TD-SYSTEM-BOUNDARY = CONCERNS (반영: 새 계통 3개·쪼개기 4개·순환 계약) · PR-SCOPE = OPTIMISTIC (반영) · CD-SYSTEMS = CONCERNS (반영: 안개·마을의 삶 나눔, 담당 지정 — 46개)

---

## Overview

유리병 속 5cm 소인의 마을을 거인이 돕는 관찰형 시뮬레이션이라, 시스템은 크게 **닫힌 병의 자연**(시간·물·빛·꽃숲), **스스로 사는 사람들**(유전·건강·필요·일정·움직임·인구·마을의 삶), **보이는 생산**(건물·생산 사슬·경제·촌장의 결정), **거인과의 관계**(손길·깨달음·제단·지갑·소원), **위기와 탐험**(곰팡이·물방울·개미·애벌레·안개·분가), 그리고 **보여 주는 층**(카메라·연출·안내·연대기·모델·HUD·소리·렌더링)으로 나뉜다. 기둥 1(스스로 살고 나를 알아보는 사람들)은 필요와 기분·일정·인구·깨달음이 받치고, 기둥 2(보는 것이 곧 재미)는 움직임·나르기·생산 사슬·사건 연출이, 기둥 3(작은 세상의 실감)은 물·빛·꽃숲·소인 생물이, 기둥 4(의미 있는 손길)는 손길·소원이, 기둥 5(안개 너머의 설렘)는 안개·분가·큰 나무가 받친다.

**이미 코드가 있는 게임**이라 Status 칸은 설계 문서 상태이고, 코드 상태는 이름 옆에 적는다 (✅ 있음 · 🔄 일부 · ⬜ 없음). 세부 규칙의 기준 문서는 지금 `docs/`(GAME_DESIGN·OPENING·EVENTS_STAGING·WORLD_EVENTS·BALANCE 등)이고, `/design-system`이 시스템마다 정식 GDD로 옮긴다.

**TD-SYSTEM-BOUNDARY 반영 (2026-11-07)**: 실제 코드에서는 `godot/sim/village.gd`(3,745줄) 한 파일이 인구·일자리·짓기·공물·손길·믿음·소원·분가를 함께 가진다. 그래서 (1) 계통 셋을 새로 세우고 — **사건 기록 흐름**(시뮬은 날짜 찍힌 사건만 내보내고 연출·안내·연대기·알림은 구독), **필요와 기분**(배고픔·행복·두려움), **촌장의 결정**(무엇을 지을지·살 수 있는지·소원 쓰기) — (2) 넷을 쪼갰다 — 주민(유전·겉모습 / 건강·나이·죽음), 주민 AI(일정·일자리 / 움직임·길·나르기, 길·도로는 움직임 소유), 건물(건물·짓기 / 시대), 깨달음·제단(믿음 / 제단·공물, **지폐는 거인의 지갑 소유**). (3) 각 GDD에 "이 계통의 상태와 규칙을 가진 파일"을 적고, `Village`는 마을 하나의 상태를 담고 계통을 부르는 얇은 겉면으로 줄인다 (ADR 예정, 한 담당이 짧게, 그동안 다른 작업은 village.gd를 건드리지 않음).

**계약 (모든 GDD가 지킴)**: 물은 보존 (위기는 빌려 옴) · 거인이 보고 있느냐는 연출 길이만 바꾸고 결과(호감·혼인·다툼)는 바꾸지 않음 — 보지 않을 때는 같은 결과를 요약 규칙으로 (같은 씨앗 결정성 시험) · 보통 이하 속도의 결과는 프레임 예산과 무관 · 저장은 각 계통이 자기 `to_dict/from_dict`·판 올림을 갖고 저장 계통은 입출력·코덱·판 옮김만 · 옛 저장은 늘 읽힘 · 처음 겪는 사건 안내와 열린 손 도구는 **거인 단위** (병 단위 아님, 사용자 확정) — 시뮬 상태는 `JarWorld` 인스턴스 안에만, static 전역 상태 금지.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 병 시간·속도·비운 시간 따라잡기 + 중요한 일이 생기면 저절로 느려지고 까닭을 말함 ✅ | Core | MVP | Designed | design/gdd/jar-time.md | — |
| 2 | 세상 생성·창조 오프닝 ✅ | Core | MVP | Not Started | — (docs/OPENING.md) | — |
| 3 | 닫힌 병의 물·소금·이슬 ✅ | Core | MVP | Not Started | — | 1, 2, 4 |
| 4 | 빛·등불·계절·날씨 ✅ | Core | MVP | Not Started | — | 1 |
| 5 | 저장·불러오기 (입출력·코덱·판 옮김) ✅ | Persistence | MVP | Not Started | — (docs/SAVE.md) | 1 (모든 계통의 끝단) |
| 6 | 소인의 꽃숲·큰 나무 다섯·땅 덮개 ✅ | Core | MVP | Not Started | — | 2, 4 |
| 7 | 사건 기록 흐름 (inferred) ⬜ | Core | MVP | Not Started | — | 1 |
| 8 | 유전·겉모습 ✅ | Gameplay | MVP | Not Started | — | 1 |
| 9 | 건강·나이·죽음 ✅ | Gameplay | MVP | Not Started | — (docs/HEALTH.md) | 1, 8, 10 |
| 10 | 필요와 기분 (배고픔·행복·두려움) (inferred) 🔄 | Gameplay | MVP | Designed | design/gdd/needs-and-mood.md | 1, 8, 15 |
| 11 | 하루 일정·일자리 배정 ✅ | Gameplay | MVP | Not Started | — | 8, 10, 13, 15 |
| 12 | 움직임·길 찾기·나르기·길과 도로 + **손에 든 물건·더미·멈춤 표시** (막힌 곳이 화면에 보임 — 기둥 2, 그림은 28) ✅ | Gameplay | MVP | Not Started | — | 2, 11 |
| 13 | 건물·짓기 ✅ | Economy | MVP | Not Started | — | 2, 8, 18 |
| 14 | 시대 ✅ | Progression | MVP | Not Started | — | 13, 17, 20 |
| 15 | 생산 사슬 (밀·빵·송사리·거대 과일, 애벌레 = 31) ✅ | Economy | MVP | Designed | design/gdd/production-chain.md | 13, 6, 3 |
| 16 | 마을 경제 (창고·가격·장터) ✅ | Economy | MVP | Not Started | — (docs/BALANCE.md) | 15 |
| 17 | 인구 (출산·혼인·가족·세대) ✅ | Gameplay | MVP | Designed | design/gdd/population.md | 8, 9, 10, 16 |
| 18 | 촌장의 결정 (inferred) 🔄 — VS는 지금 최소판, 막힌 곳을 보고 고르는 판단은 MVP 밖 | Gameplay | MVP | Designed | design/gdd/mayor-decisions.md | 13, 16, 10 |
| 19 | 거인의 손길 — **MVP에 열림: 내려 주기·유리 톡·물 뿌리기** / VS(위기와 함께) 열림: 유리 닦기·핀셋·떠돌이 물방울 톡·등불 옮기기 ✅ | Gameplay | MVP | Designed | design/gdd/giant-touch.md | 3, 4, 7 |
| 20 | 깨달음·믿음 ✅ | Narrative | MVP | Not Started | — | 7, 8, 17 |
| 21 | 제단·공물 ✅ | Economy | MVP | Not Started | — | 20, 16 |
| 22 | 거인의 지갑·상점·설계도·이주민 ✅ | Economy | MVP | Not Started | — (docs/SHOP.md) | 21, 16 |
| 23 | 소원 들어주기·계시 🔄 | Gameplay | MVP | Not Started | — (EVENTS_STAGING 6d·3b) | 20, 19, 22, 18 |
| 24 | 카메라·확대·병 안 ↔ 방 ✅ | UI | MVP | Not Started | — (docs/GIANT_ROOM.md) | 2 |
| 25 | 사건 연출 ✅ | Narrative | MVP | Not Started | — (EVENTS_STAGING) | 7, 24 |
| 26 | 처음 겪는 사건 안내·거인의 수첩·튜토리얼 ✅ | Meta | MVP | Not Started | — (OPENING 3.1b) | 7, 19 |
| 27 | 연대기·돌아온 편지 ✅ (도감은 VS — #44) | Narrative | MVP | Not Started | — | 7, 1 |
| 28 | 주민 모델·초상화·옷 🔄 (4등신 다시) | UI | MVP | Not Started | — (art-bible 5장) | 8, 12 |
| 29 | HUD·시트·설정·접근성 🔄 | UI | MVP | Not Started | — (art-bible 7장, docs/UI.md) | 전 계통 |
| 30 | 알림·세션 끝 훅 🔄 | Meta | MVP | Not Started | — | 7, 1 |
| 31 | 애벌레 사냥 — 애벌레·고치·나비 순환·꿀까지 MVP로 (사용자 2026-11-08) | Gameplay | MVP | Designed | design/gdd/production-chain.md R7 | 15, 33 |
| 32 | 위기 — 곰팡이·떠돌이 물방울 ✅ | Gameplay | Vertical Slice | Not Started | — (docs/WORLD_EVENTS.md) | 3, 8, 19, 7 |
| 33 | 소인 크기 생물 (사슴·토끼 대신) ⬜ | Gameplay | Vertical Slice | Not Started | — (GD 3.0) | 6, 12 |
| 34 | 개미 군단 ⬜ | Gameplay | Vertical Slice | Not Started | — (WORLD_EVENTS 2.1b) | 15, 16, 32, 19 |
| 35 | 마을의 삶 — VS 부분: 연애~혼례·다툼·아이 놀이·추수 축제 (뺄 수 있음: 추수 축제·삼각관계) ✅ | Narrative | Vertical Slice | Not Started | — | 8, 11, 12, 7 |
| 36 | 안개 걷기·탐험 (망루·나들이, **분가 없이도 큰 나무에 닿는 길을 처음부터**) 🔄 | Progression | Vertical Slice | Not Started | — | 2, 12, 17 |
| 37 | 분가 마을 (화면 밖 요약 계산 포함) 🔄 — 폰 성능 통과 전에는 시작하지 않음 | Progression | Vertical Slice | Not Started | — | 36, 17, 13, 1 |
| 38 | 소리·음악·목소리 ✅ | Audio | Vertical Slice | Not Started | — (docs/AUDIO.md) | 7 |
| 39 | 렌더링·품질 단계·외곽선·꽃 그늘 🔄 | Core | Vertical Slice | Not Started | — (art-bible 8장, docs/RENDERING.md) | 24, 6 |
| 40 | 성능·계측 🔄 | Meta | Vertical Slice | Not Started | — | 1, 39 |
| 41 | 출시 트랙 (스토어·개인정보·등급·AAB·Play 비공개 테스트) ⬜ | Meta | Vertical Slice | Not Started | — | 40 |
| 45 | 안개 보이기 (덮인 상태·칠하지 않은 스케치·경계의 윤곽과 소리) — CD-SYSTEMS로 36에서 나눔 🔄 | Core | MVP | Not Started | — (art-bible 6.6) | 2, 39 |
| 46 | 마을의 삶 MVP 최소판 (대화·생각 말풍선·하루의 흐름·저녁 모닥불) — CD-SYSTEMS로 35에서 나눔 ✅ | Narrative | MVP | Not Started | — | 8, 10, 11, 12, 7 |
| 44 | 도감 (발견 기록) ✅ | Narrative | Vertical Slice | Not Started | — (docs/DISCOVERIES.md) | 7 |
| 42 | 선반·여러 병 ✅ | Progression | Alpha | Not Started | — | 5, 2, 1 |
| 43 | 친구의 선반 (온라인 이웃) ⬜ | Meta | Full Vision | Not Started | — | 42, 5 |

---

## Categories

| Category | Description | Typical Systems |
|----------|-------------|-----------------|
| **Core** | Foundation systems everything depends on | 시간, 세상 생성, 물, 빛, 꽃숲, 사건 흐름, 렌더링 |
| **Gameplay** | The systems that make the game fun | 주민·필요·일정·움직임·인구·촌장, 손길, 소원, 위기·생물·사냥 |
| **Progression** | How the player grows over time | 시대, 안개·탐험, 분가, 선반 |
| **Economy** | Resource creation and consumption | 건물, 생산 사슬, 마을 경제, 제단·공물, 거인의 지갑 |
| **Persistence** | Save state and continuity | 저장 |
| **UI** | Player-facing information displays | 카메라, 주민 모델·초상, HUD·설정 |
| **Audio** | Sound and music systems | 소리·음악·목소리 |
| **Narrative** | Story and dialogue delivery | 깨달음, 사건 연출, 연대기, 마을의 삶 |
| **Meta** | Systems outside the core game loop | 안내·수첩, 알림, 성능, 출시 트랙, 친구의 선반 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | 핵심 루프가 처음부터 끝까지 도는 판 — 창조 → 첫날 → 깨달음 → 제단 → **첫 빵(튜토리얼 끝)**까지의 첫 30분. 이것 없이는 "재밌나?"를 시험할 수 없다 | 첫 30분 플레이어블 (여정 1~3단계, 12월 중순 폰 통과 목표) | Design FIRST |
| **Vertical Slice** | **첫 출시 범위**의 나머지 — 첫 주를 붙잡는 위기·생물·사냥·마을의 삶·안개·분가 + 소리·렌더링·성능·출시 트랙 | 첫 출시 (4~5개월, Play 비공개 테스트 늦어도 2027-02 초 시작) | Design SECOND |
| **Alpha** | 두 번째 병·읍내 이후 시대 | 출시 뒤 첫 갱신 | Design THIRD |
| **Full Vision** | 친구의 선반(온라인), 여러 기후 | 장기 | Design as needed |

> **Creative Director Note** (CD-SYSTEMS CONCERNS, 2026-11-07 — 사용자: 목록 고치기로 반영): (MVP) 기둥 5가 첫 30분에 보이도록 안개를 '보이기(45, MVP)'와 '걷기·탐험(36, VS)'으로 나눔 · 기둥 2의 핵심 신호(손에 든 물건·더미·멈춤 표시)는 12가 맡음 · 마을의 삶 중 대화·생각 말풍선·하루 흐름·저녁 모닥불은 MVP 최소판(46) · 손길(19)은 MVP 손짓과 위기 때 열리는 손짓을 나눠 적음 · 저절로 느려짐은 1이 맡음 · 도감은 VS(44). (VS) 36은 분가 없이도 큰 나무에 닿는 길을 처음부터 설계 (분가를 빼도 기둥 5 유지). **확인 기준**: 첫 30분에 다섯 기둥이 모두 한 번 이상 화면에 보임 (특히 안개 경계, 쌓인 밀가루를 보고 알아채기), MVP 계통만으로 OPENING 3.1 대본이 끝까지 돎.

> **Producer Note** (PR-SCOPE OPTIMISTIC, 2026-11-07): 코드 속도는 충분(3일 커밋 392), 위험은 폰 성능(미측정)·✅ 뒤에 숨은 다시 할 일(아트 바이블 A23~A27, 사건 흐름 재연결, village.gd 나누기)·서두를 수 없는 달력(사용자 검수, 비공개 테스트 12명 × 14일). 조정 반영: village.gd 나누기는 ADR 먼저 + 한 담당 + 그동안 잠금 · 마을의 삶 반드시/뺄 수 있음 · 촌장 판단은 MVP 최소판 · 필요와 기분 담당 지정 · 출시 날짜 역산(개인정보·등급·스토어 자료 지금 병행, 테스터 12명 미리) · A23~A27을 로드맵에 크기와 함께. **검증 기준**: 11/21까지 중저가 폰 주민 30명 30fps + 6일 따라잡기 10초 안 · 12월 중순 여정 3단계 폰 통과 · 2월 초 비공개 테스트 시작 — 하나라도 2주 넘게 밀리면 분가를 빼는 중간 단계로 (사용자 결정). **사용자 선택: 폰 실측과 그림 다시 만들기 병행** (예산 초과 시 다시 만들 위험을 받아들임).

---

## Dependency Map

### Foundation Layer (no dependencies)
1. 병 시간·따라잡기 (1) — 모든 계통의 시계, 결정성의 근원
2. 세상 생성·창조 (2) — 땅·물길·큰 나무 자리를 정함
3. 빛·계절 (4) — 1에만 기댐, 물·꽃·생산의 박자
4. 사건 기록 흐름 (7) — 시뮬과 보여 주는 층의 경계 (신설)
5. 저장 (5) — 입출력 껍데기 (각 계통이 자기 직렬화)

### Core Layer (depends on foundation)
1. 물·소금·이슬 (3) — 1, 2, 4
2. 꽃숲·큰 나무 (6) — 2, 4
3. 유전·겉모습 (8) — 1 (능력 값을 읽지 않음)
4. 필요와 기분 (10) — 1, 8, 15
5. 건강·나이·죽음 (9) — 1, 8, 10
6. 건물·짓기 (13) — 2, 8, 18
7. 생산 사슬 (15) — 13, 6, 3 (생산은 "일감"을 내놓고 11이 가져감)
8. 마을 경제 (16) — 15
9. 촌장의 결정 (18) — 13, 16, 10 (9 ↔ 11 순환을 풂)
10. 하루 일정·일자리 (11) — 8, 10, 13, 15
11. 움직임·길·나르기 (12) — 2, 11
12. 인구 (17) — 8, 9, 10, 16
13. 시대 (14) — 13, 17, 20

### Feature Layer (depends on core)
1. 거인의 손길 (19) — 3, 4, 7 ("giant_acted" 사건만 내보냄)
2. 깨달음·믿음 (20) — 7, 8, 17 (손길 사건을 구독)
3. 제단·공물 (21) — 20, 16
4. 거인의 지갑·상점 (22) — 21, 16
5. 소원·계시 (23) — 20, 19, 22, 18
6. 위기 곰팡이·물방울 (32) — 3, 8, 19, 7
7. 소인 생물 (33) — 6, 12
8. 애벌레 사냥 (31) — 15, 33
9. 개미 군단 (34) — 15, 16, 32, 19
10. 마을의 삶 (35) — 8, 11, 12, 7
11. 안개·탐험 (36) — 2, 12, 17
12. 분가 마을 (37) — 36, 17, 13, 1
13. 선반·여러 병 (42) — 5, 2, 1

### Presentation Layer (depends on features)
1. 카메라 (24) — 2
2. 사건 연출 (25) — 7, 24
3. 안내·수첩 (26) — 7, 19
4. 연대기·편지 (27) — 7, 1
5. 주민 모델·초상 (28) — 8, 12
6. HUD·설정 (29) — 전 계통
7. 소리 (38) — 7
8. 렌더링·품질 (39) — 24, 6

### Polish Layer (depends on everything)
1. 알림·세션 끝 훅 (30) — 7, 1
2. 성능·계측 (40) — 1, 39
3. 출시 트랙 (41) — 40
4. 친구의 선반 (43) — 42, 5

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 사건 기록 흐름 (7) | MVP | Foundation | technical-director, game-designer | S |
| 2 | 필요와 기분 (10) | MVP | Core | systems-designer | M |
| 3 | 촌장의 결정 (18, 최소판) | MVP | Core | systems-designer, economy-designer | M |
| 4 | 병 시간·따라잡기 (1) | MVP | Foundation | technical-director | S (있는 것 정리) |
| 5 | 생산 사슬 (15) | MVP | Core | economy-designer | M |
| 6 | 마을 경제 (16) | MVP | Core | economy-designer | M |
| 7 | 하루 일정·일자리 (11) | MVP | Core | ai-programmer, game-designer | M |
| 8 | 움직임·나르기 (12) | MVP | Core | ai-programmer | S |
| 9 | 인구 (17) | MVP | Core | systems-designer | M |
| 10 | 거인의 손길 (19) | MVP | Feature | game-designer, ux-designer | M |
| 11 | 깨달음·믿음 (20) · 제단·공물 (21) | MVP | Feature | game-designer, narrative-director | M |
| 12 | 거인의 지갑·상점 (22) | MVP | Feature | economy-designer | S |
| 13 | 소원·계시 (23) | MVP | Feature | game-designer | M |
| 14 | 사건 연출 (25) · 안내·수첩 (26) · 연대기·편지 (27) | MVP | Presentation | narrative-director, ux-designer | M |
| 15 | 나머지 MVP (2·3·4·5·6·8·9·13·14·24·28·29·30) | MVP | 각 층 | 담당별 | S~M (대부분 있는 것 정리) |
| 16 | 개미 군단 (34) | Vertical Slice | Feature | game-designer, systems-designer | M |
| 17 | 소인 생물 (33) · 애벌레 사냥 (31) | Vertical Slice | Feature | game-designer, world-builder | M |
| 18 | 안개·탐험 (36) · 분가 (37) | Vertical Slice | Feature | game-designer, technical-director | L |
| 19 | 마을의 삶 (35) · 위기 (32) | Vertical Slice | Feature | narrative-director, systems-designer | S (있는 것 정리) |
| 20 | 렌더링 (39) · 성능 (40) · 소리 (38) · 출시 트랙 (41) | Vertical Slice | Presentation/Polish | technical-artist, performance-analyst, audio-director, release-manager | M |
| 21 | 선반 (42) | Alpha | Feature | game-designer | S |
| 22 | 친구의 선반 (43) | Full Vision | Polish | network-programmer | L |

---

## Circular Dependencies

- **건물(13) ↔ 경제(16)** (`_affordable`이 경제를 읽음) → **촌장의 결정(18)**을 위로 올려 13 ← 18 → 16으로 풂.
- **일정·일자리(11) ↔ 생산(15)** → 생산이 "일감"을 내놓고 11이 가져가는 계약.
- **손길(19) ↔ 믿음(20)** → 19는 `giant_acted` 사건만 사건 흐름(7)에 내보내고 20이 구독.
- **물(3) ↔ 위기(32)** → 떠돌이 물방울은 병의 물에서 빌려 옴 (총량 보존 계약).
- **일정(11) ↔ 마을의 삶(35)** → 삶은 AI의 쉬는 시간에만 끼어들고, 결과는 보는지 여부와 무관.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| `village.gd` (계통 다수) | Technical / Scope | 3,745줄에 계통이 몰려 병렬 작업마다 병합 충돌 | ADR 먼저 → 한 담당이 짧게 나눔 → 그동안 잠금 |
| 렌더링·성능 (39·40) | Technical | 폰 성능 미측정, 큰 나무·건물 예산 초과 | 11/21까지 실측 (병행 진행, 초과 시 다시 만듦) |
| 분가 마을 (37) | Technical / Scope | 화면 밖 요약 계산·성능 의존, 반쯤 만든 채 멈출 위험 | 성능 통과 전에는 시작하지 않음, 밀리면 중간 단계 |
| 따라잡기 (1) | Technical | 폰에서 15~22초 + 열 스로틀링 추정 | 실측, 보던 병만 정밀, WorkerThreadPool 검토 |
| 사건 기록 흐름 (7) | Technical | 이미 ✅인 연출·연대기·편지를 다시 연결 | 맨 먼저 설계, 계약 시험 |
| 주민 모델 (28) | Scope | 4등신 다시 만들기 + 단위 통일 + 짐 소품 | 뼈대·클립 28 유지, 원경 모델 먼저 예산 확인 |
| 출시 트랙 (41) | Scope (달력) | 비공개 테스트 12명 × 14일·심사는 서두를 수 없음 | 날짜 역산, 지금부터 병행 준비 |
| 필요와 기분 (10) | Design | 담당 없는 로직, 빠듯함 곡선과 직결 | 담당 지정, BALANCE v5-0 측정 도구로 확인 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 46 |
| Design docs started | 0 (콘셉트·아트 바이블 완료) |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 0/32 |
| Vertical Slice systems designed | 0/12 |

---

## Next Steps

- [x] Review and approve this systems enumeration (사용자 2026-11-07)
- [ ] ADR: 사건 기록 흐름 + `Village`는 얇은 겉면 (`/architecture-decision`)
- [ ] Design MVP-tier systems first (`/design-system 사건 기록 흐름` → 필요와 기분 → 촌장의 결정 …)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check systems-design` (Concept → Systems Design)
- [ ] Run `/gate-check technical-setup` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
