# 사건 kind 목록 (ADR-0001)

시뮬레이션이 `EventStream.emit(kind, data)` (마을에서는 `Village.emit`)으로 내는 사건 종류. **새 kind는 여기 먼저 적는다.**

사건 모양: `{"n": 번호, "t": 병 시각, "village": 마을 sid, "kind": StringName, "who": 주민 id 또는 -1, "at": Vector2 또는 null, "v": 값}`
— `Village.emit`이 `t`·`village`를 채운다. `data`에 Object(Node·Resident·Village 등) 금지. kind는 늘 `&"…"`로 쓴다.

| kind | 내는 곳 | v | at / who | 저장 순번(`event_serial`) +1 | 연대기(`book`) | 읽는 곳 |
|---|---|---|---|---|---|---|
| `&"chronicle"` | `Village.log_line(text)` (호환 껍데기, 약 190곳) | 연대기 글 (String) | — | 예 | 예 — `emit` 안에서 바로 (옛 형식 `{t, text}`) | (앞으로 알림·시험) |
| `&"crisis"` | `Village.crisis(kind, text)` — 굶주림·쓰러짐 등 위기 시작 | 위기 kind (String) | — | 예 | 아니오 (`crises`에 따로) | JarClock은 아직 `crises`를 읽음 |
| `&"manna_fall"` | `Village.manna_fall(reason)` (도착·새벽 하늘 낟알) · `SkyDrops._grain` (수첩 '하늘 낟알 한 줌') | 까닭: `"arrival"`·`"dawn"`… / `"grain"` | `at` = 떨어뜨린 자리 (한 줌만) | 아니오 | 아니오 | `view/manna_fx.gd` (커서, 최근 120병초 안 것만, 여러 번이어도 연출 한 번) |
| `&"blueprint_dropped"` | `SkyDrops.place_building` (거인이 설계도를 내림) | 건물 종류 (String) | — | 아니오 | 아니오 (연대기는 `Production.give_blueprint`의 log_line) | `view/sky_drop_view.gd` (커서, 마지막 것, 최근 병 1시간 안) |
| `&"dog_born"` | `Dogs.litter` (새벽 — 다 자란 암수 강아지, 1~3마리, E3-13b) | 새 강아지 id (int) | `who` = 막내 이름을 지은 아이 (없으면 -1) · `at` = 엄마 자리 | 아니오 | 아니오 (연대기는 `log_line`) | `tests/fauna_tests.gd` (화면 연출은 나중) |
| `&"dog_adopted"` | `Dogs._grow_up` (새끼가 다 자람 — 강아지 없는 집이 데려감, 없으면 마을 강아지) | 강아지 id (int) | `who` = 데려간 집 주인 (마을 강아지면 -1) · `at` | 아니오 | 아니오 | (화면 연출은 나중) |
| `&"dog_died"` | `Dogs.die` (늙어서 — 가족·아이들이 가볍게 슬퍼함) | 강아지 id (int) | `who` = 주인 (마을 강아지면 -1) · `at` | 아니오 | 아니오 | (화면 연출은 나중) |
| `&"dog_bark"` | `Dogs._bark` (애벌레가 곁에 — 개미 정찰은 E3-10이 오면) | 강아지 id (int) | `who` = 주인 (-1 = 마을 강아지) · `at` = 짖는 상대 자리 | 아니오 | 아니오 | `view/fauna_view.gd` (커서 — 짖는 동작은 강아지 state로도) |

## 메모
- 저장 순번은 위 표의 "예"인 kind와, 사건 없이 올리는 곳(`notebook.gd`·`awakening.gd`)에서만 오른다 — 10초 걸음마다 저장되지 않게.
- 2026-11-07: 사건 줄은 넓은 세상이면 `JarWorld.events` 하나를 무리들이 함께 쓰고(`village` = sid), 작은 병(`Village.new_prototype`)은 마을마다 하나. 저장하지 않으며 불러오면 새 줄(번호 0부터).
- `watch_changed`(ADR 3절)는 아직 없음 — 이행 4단계에서 `set_watching`과 함께.
