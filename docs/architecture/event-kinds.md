# 사건 kind 목록 (ADR-0001)

시뮬레이션이 `EventStream.emit(kind, data)` (마을에서는 `Village.emit`)으로 내는 사건 종류. **새 kind는 여기 먼저 적는다.**

사건 모양: `{"n": 번호, "t": 병 시각, "village": 마을 sid, "kind": StringName, "who": 주민 id 또는 -1, "at": Vector2 또는 null, "v": 값}`
— `Village.emit`이 `t`·`village`를 채운다. `data`에 Object(Node·Resident·Village 등) 금지. kind는 늘 `&"…"`로 쓴다.

| kind | 내는 곳 | v | at / who | 저장 순번(`event_serial`) +1 | 연대기(`book`) | 읽는 곳 |
|---|---|---|---|---|---|---|
| `&"chronicle"` | `Village.log_line(text)` (호환 껍데기, 약 190곳) | 연대기 글 (String) | — | 예 | 예 — `emit` 안에서 바로 (옛 형식 `{t, text}`) | (앞으로 알림·시험) |
| `&"crisis"` | `Village.crisis(kind, text)` — 굶주림·쓰러짐 등 위기 시작 | 위기 kind (String) | — | 예 | 아니오 (`crises`에 따로) | JarClock은 아직 `crises`를 읽음 |
| `&"manna_fall"` | `Village.manna_fall(reason)` (도착·새벽 하늘 낟알) · `SkyDrops._grain` (수첩 '하늘 낟알 한 줌') | 까닭: `"arrival"`·`"dawn"`… / `"grain"` | `at` = 떨어뜨린 자리 (한 줌만) | 아니오 | 아니오 | `view/manna_fx.gd` (커서, 최근 120병초 안 것만, 여러 번이어도 연출 한 번) |
| `&"blueprint_dropped"` | `SkyDrops.place_building` (거인이 설계도를 내림) | 건물 종류 (String) | — | 아니오 | 아니오 (연대기는 `Production.give_blueprint`의 log_line) | `view/sky_drop_view.gd` (커서, 마지막 것, 최근 병 1시간 안) · `Firsts.check` (안내 창 '설계도' — 구독, notebook N1) |
| `&"talk_started"` | `Social._stage` · `Social.wedding_gathering` (만남 → 멈춰 서서 이야기 — 늘, 지켜봄과 무관, village-life-min R2) | `{"with": 상대 id, "kind": 장면 종류, "secs": 멈춤 병 초, "id": 장면 번호}` | `who` = 먼저 말한 사람 · `at` = 장면 자리 | 아니오 | 아니오 | `tests/social_tests.gd` (화면은 아직 `Social.take_events`) |
| `&"dog_born"` | `Dogs.litter` (새벽 — 다 자란 암수 강아지, 1~3마리, E3-13b) | 새 강아지 id (int) | `who` = 막내 이름을 지은 아이 (없으면 -1) · `at` = 엄마 자리 | 아니오 | 아니오 (연대기는 `log_line`) | `tests/fauna_tests.gd` (화면 연출은 나중) |
| `&"dog_adopted"` | `Dogs._grow_up` (새끼가 다 자람 — 강아지 없는 집이 데려감, 없으면 마을 강아지) | 강아지 id (int) | `who` = 데려간 집 주인 (마을 강아지면 -1) · `at` | 아니오 | 아니오 | (화면 연출은 나중) |
| `&"dog_died"` | `Dogs.die` (늙어서 — 가족·아이들이 가볍게 슬퍼함) | 강아지 id (int) | `who` = 주인 (마을 강아지면 -1) · `at` | 아니오 | 아니오 | (화면 연출은 나중) |
| `&"dog_bark"` | `Dogs._bark` (애벌레가 곁에 — 개미 정찰은 E3-10이 오면) | 강아지 id (int) | `who` = 주인 (-1 = 마을 강아지) · `at` = 짖는 상대 자리 | 아니오 | 아니오 | `view/fauna_view.gd` (커서 — 짖는 동작은 강아지 state로도) |
| `&"giant_acted"` | 손짓이 받아들여짐 (design/gdd/giant-touch.md 사건) — `Village.touch_event`: 유리 톡(`tap_glass`, 세게 친 톡 빼고) · 등불(`_after_lamp`, 무리마다) · 물 뿌리기·유리 닦기·핀셋(`GiantHand`) | `{"kind": StringName (&"tap"·&"lamp"·&"spray"·&"wipe"·&"tweeze"), "n_today": int (그날 이 무리의 몇 번째), "free": bool (두려움 없는 횟수 안 — 톡 3번·등불 1번)}` | — | 아니오 | 아니오 | (앞으로 깨달음·소리·시험 — 지금은 시험만) |
| `&"giant_refused"` | 손짓이 거절됨 — `Village.touch_refused` (물 뿌리기·유리 닦기·핀셋) | `{"kind": StringName, "why": StringName (&"lid"·&"cooldown"·&"edge"·&"no_target"·&"no_spot")}` | — | 아니오 | 아니오 | (앞으로 화면 한 줄 말) |
| `&"spray_flooded"` | 물 뿌리기 넘침 (`GiantHand.spray`, giant-touch F4) | `{"x", "y": float, "houses": int}` | `at` = 뿌린 자리 | 아니오 | 아니오 (연대기는 log_line) | (앞으로 연출) |
| `&"tweeze_done"` | 핀셋으로 집음/옮김 (`GiantHand.tweeze`) | `{"what": StringName (&"gnat"·&"dust"·&"drop"·&"rock"), "moved": bool, "crushed": int (0·1)}` | `at` = 누른 자리 | 아니오 | 아니오 | (앞으로 연출) |

## 메모
- 저장 순번은 위 표의 "예"인 kind와, 사건 없이 올리는 곳(`notebook.gd`·`awakening.gd`)에서만 오른다 — 10초 걸음마다 저장되지 않게.
- 2026-11-07: 사건 줄은 넓은 세상이면 `JarWorld.events` 하나를 무리들이 함께 쓰고(`village` = sid), 작은 병(`Village.new_prototype`)은 마을마다 하나. 저장하지 않으며 불러오면 새 줄(번호 0부터).
- `watch_changed`(ADR 3절)는 아직 없음 — 이행 4단계에서 `set_watching`과 함께.
- 2026-11-08 (giant-touch): `giant_acted`·`giant_refused`·`spray_flooded`·`tweeze_done`을 냄. GDD의 `tool_unlocked`·`sky_drop_landed`·`lamp_moved`·`drop_knocked`와 내려 주기의 `giant_acted{kind: &"drop"}`는 아직 내지 않음 (이름만 예약 — 내기 시작할 때 이 표에 적는다). 손길 사건은 `emit` 앞뒤로 난수를 쓰지 않는다.
