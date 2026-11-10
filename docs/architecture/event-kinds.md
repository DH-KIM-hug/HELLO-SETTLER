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
| `&"immigrant_hint"` | `Immigrants.give_hints` (어른 이주민이 조각 하나를 지니고 옴 — design/gdd/population.md R6-6, 굴림은 `Village.pop_rng`) | `{"hint": String (&"word"·"song"·"moon"·"coin" — `Balance.IMMIGRANT_HINTS` id)}` | `who` = 그 이주민 | 아니오 | 아니오 (연대기는 log_line) | `tests/population_tests.gd` (거인 UI는 `Resident.hint`를 읽음) |
| `&"first_harvest"` | `Production.first_made` (그 병의 첫 밀 — `Village._update_building`, design/gdd/production-chain.md) | `{"b": 건물 id}` | `who` = 일꾼 id | 아니오 | 아니오 (연대기는 `harvest_check`의 log_line) | `tests/production_tests.gd` |
| `&"first_flour"` | `Production.first_made` (첫 가루 — 맷돌간·방앗간) | `{"b": 건물 id}` | `who` = 일꾼 id | 아니오 | 아니오 | (앞으로 연출) |
| `&"first_bread"` | `Production.first_made` (첫 빵 — 화덕·빵집, `stats.first_bread`와 같은 걸음) | `{"b": 건물 id}` | `who` = 일꾼 id | 아니오 | 아니오 (연대기는 log_line) | (앞으로 #26 안내 · 연출) |
| `&"chain_stalled"` | `Production.stall_tick` (재료 기다림·일꾼 없음이 `STALL_AFTER` 1시간 이어짐 — 넉넉해서 쉼은 아님, 불러온 첫 걸음엔 없음) | `{"b": 건물 id, "type": StringName, "why": &"no_input"·&"no_worker"}` | — | 아니오 | 아니오 | `tests/production_tests.gd` (앞으로 #12 멈춤 표시) |
| `&"chain_resumed"` | `Production.stall_tick` (다시 돌아감이 `STALL_CLEAR` 30분 이어짐) | `{"b": 건물 id, "secs": float (막혔던 병 초)}` | — | 아니오 | 아니오 | `tests/production_tests.gd` |
| `&"spoiled"` | `Production.spoil` (새벽 — 물건마다 그날 상한 합) | `{"k": StringName, "amt": float}` | — | 아니오 | 아니오 | `tests/production_tests.gd` |
| `&"honey_found"` | `Caterpillars._honey` (여름 반나절마다 성한 꽃 무리 곁 어른 — 마을 `rng`, id 순) | `{}` (null) | `who` = 주운 사람 · `at` = 그 자리 | 아니오 | 아니오 | (앞으로 #38 맑은 한 음) |
| `&"caterpillar_caught"` | `Caterpillars.catch_now` (조에서 처음 끝낸 사람이 잡음) | `{"crew": int}` | `who` = 조장 id · `at` = 애벌레 자리 | 아니오 | 아니오 | `tests/production_tests.gd` |
| `&"cocoon_taken"` | `Caterpillars.take_cocoon` (산 고치 따기·빈 고치 줍기 → 비단 실) | `{"live": bool}` | `who` = 딴 사람 · `at` | 아니오 | 아니오 | `tests/production_tests.gd` |
| `&"found_object"` | `FoundObjects.discover` (매시간 `FoundObjects.hourly` — 묻힌 물건 곁에서 일하던·돌아다니던 사람, id 순, 난수 없음 · E3-16 / GD 3.0) | `{"kind": StringName (&"button"·&"marble"·&"cap"·&"sugar"·&"match"), "id": int}` | `who` = 찾은 사람 · `at` = 묻혀 있던 자리 | 아니오 | 아니오 (연대기는 `log_line` — 찾음·쓰임 한 줄씩) | `tests/found_tests.gd` (화면은 `FoundObjects.shown`을 직접 읽음) |
| `&"butterfly_out"` | `Caterpillars._tick` (고치 → 나비 + 빈 고치) | `{"patch": int (꽃 무리 id)}` | `at` = 고치 자리 | 아니오 | 아니오 | `tests/production_tests.gd` (앞으로 #33 작은 장면) |
| `&"awakened"` | `Awakening.awaken` (깨달음 — 한 번, 부르는 말을 정한 바로 뒤, awakening-altar R2) | `{"name_idx": int (Balance.WATCHER_NAMES 번호, 없으면 -1)}` | — | 아니오 (연대기 두 줄이 이미 올림) | 아니오 (연대기는 log_line 두 줄) | `view/stage_director.gd` (커서 — 보고 있는 무리면 깨달음 연출 EVENTS_STAGING 1, 2026-11-09) |

## 메모
- 저장 순번은 위 표의 "예"인 kind와, 사건 없이 올리는 곳(`notebook.gd`·`awakening.gd`)에서만 오른다 — 10초 걸음마다 저장되지 않게.
- 2026-11-07: 사건 줄은 넓은 세상이면 `JarWorld.events` 하나를 무리들이 함께 쓰고(`village` = sid), 작은 병(`Village.new_prototype`)은 마을마다 하나. 저장하지 않으며 불러오면 새 줄(번호 0부터).
- `watch_changed`(ADR 3절)는 아직 없음 — 이행 4단계에서 `set_watching`과 함께.
- 2026-11-08 (giant-touch): `giant_acted`·`giant_refused`·`spray_flooded`·`tweeze_done`을 냄. GDD의 `tool_unlocked`·`sky_drop_landed`·`lamp_moved`·`drop_knocked`와 내려 주기의 `giant_acted{kind: &"drop"}`는 아직 내지 않음 (이름만 예약 — 내기 시작할 때 이 표에 적는다). 손길 사건은 `emit` 앞뒤로 난수를 쓰지 않는다.
- 2026-11-08 (production-chain): 사슬 사건 10개 (`first_harvest`~`butterfly_out`)를 냄. 바로 보냄·넉넉해서 쉼은 사건을 내지 않는다. 막힘 판정 상태(`Village._stall`)는 저장하지 않는다. 사슬 사건은 `emit` 앞뒤로 난수를 쓰지 않는다 (꿀방울 굴림은 사건과 무관하게 먼저 함).
- 2026-11-08 (F-2 거대 식물 — design/gdd/flower-forest.md, `sim/giant_plants.gd`): 아래 kind를 냄. 모두 저장 순번 아니오 · 연대기는 `log_line` (씨앗비·목화 첫 줄만). 병 하나의 것은 물을 흘리는 첫 무리(`owns_water`)가 낸다.

| kind | 내는 곳 | v | at / who | 읽는 곳 |
|---|---|---|---|---|
| `&"sunflower_turned"` | `GiantPlants.step` — 등불을 옮긴 뒤 꽃판이 SF_TURN(병 2시간)에 걸쳐 다 돎 | `{"id": int}` | `at` = 줄기 · who −1 | `tests/plants_tests.gd` |
| `&"sunflower_bloomed"` / `&"sunflower_drooped"` | `GiantPlants.hourly` — 철이 바뀜 (6월 핌 / 9월 숙임) | `{"id": int}` | `at` = 줄기 · who −1 | (앞으로 연출) |
| `&"seed_shadow"` | `GiantPlants.step` — 씨앗비 씨앗이 떨어지기 SEED_WARN(병 20분) 전, 땅 위 그림자가 커지기 시작 | `{"id": int}` | `at` = 떨어질 자리 | (화면은 `SunflowerView`가 `sf_seeds`를 직접 읽음) |
| `&"seed_landed"` | `GiantPlants._land` — 씨앗이 땅에 박힘 (먼지, 곁에 선 사람 작은 확률로 다침) | `{"id": int, "hurt": int}` | `at` = 자리 | `tests/plants_tests.gd` |
| `&"seed_stored"` | `GiantPlants.run_op("gplant_seed_put")` — 어른이 굴려 와 창고에 `해바라기씨` | `{"amt": float}` | `who` = 굴린 사람 · `at` | `tests/plants_tests.gd` |
| `&"cotton_burst"` | `GiantPlants._cotton_season` — 그 해 처음 목화 다래가 터짐 (9~11월) | `{"n": int}` | — | `tests/plants_tests.gd` |
- 2026-11-08 (B-1 빠듯한 철 — docs/BALANCE.md B-1, `sim/lean_seasons.gd`): 아래 kind를 냄. 저장 순번 아니오 · 연대기는 `log_line` (시작·끝 한 줄씩). 날·해는 마을 씨앗 해시로 정하고 `emit` 앞뒤로 난수를 쓰지 않는다.

| kind | 내는 곳 | v | at / who | 읽는 곳 |
|---|---|---|---|---|
| `&"lean_season"` | `LeanSeasons.hourly` — 빠듯한 철이 오고 감 (그 해 한 번씩, 알린 해는 `Village.stats`) | `{"kind": &"green_wheat"·&"caterpillar_year", "on": bool}` | — | `tests/lean_tests.gd` (앞으로 #26 안내 · 연출) |
- 2026-11-08 (A28b 핵 크기 = 병의 따뜻함 — docs/BALANCE.md A28b, `sim/core_warmth.gd`): 아래 kind를 냄. 저장 순번 아니오 · 연대기는 `log_line`. 흔들림 날·시각·항아리·온천은 마을 씨앗 해시로 정하고 `emit` 앞뒤로 난수를 쓰지 않는다 (온천을 알아낼 사람만 `Discovery.finder`의 `disc_rng` — 뜨거운 별에서만). 보통 별(핵 1)은 어느 것도 내지 않는다.

| kind | 내는 곳 | v | at / who | 읽는 곳 |
|---|---|---|---|---|
| `&"ground_tremor"` | `CoreWarmth.tremor` — 뜨거운 별의 작은 땅 흔들림 (병 하루 `CORE_TREMOR_DAY`, 첫 빵 뒤). 죽음·다침 없음 | `{"n": int (몇 번째), "pot": String (깨진 항아리의 먹을 것, 없으면 ""), "lost": float}` | `at` = 마을 가운데 | `tests/warmth_tests.gd` (앞으로 화면의 먼지·흔들림 연출) |
| `&"jar_trait_noticed"` | `CoreWarmth.note` — 병의 성질이 처음 눈에 띔 (별지기의 수첩 한 줄, `Village.jar_notes`에 저장 — 같은 병의 무리끼리 한 번) | `{"id": String (`CoreWarmth.NOTES` 열쇠), "text": String, "core": int}` | — | `tests/warmth_tests.gd` (앞으로 #26 수첩 '안내' 쪽) |
- 2026-11-08 (E3-14 우유·계란 없는 부엌 — docs/FOOD.md 5, `sim/kitchen.gd`): 아래 kind를 냄. 모두 저장 순번 아니오 · 연대기는 `log_line` (목장이 섬·첫 단물·목장이 빔·잔치·껍데기·첫 방아·재료마다 첫 좋은 빵). 날마다의 굴림(진딧물 찾기·무당벌레)은 마을 씨앗·날의 해시로 정하고 `emit` 앞뒤로 난수를 쓰지 않는다. 지켜보는지 읽지 않는다.

| kind | 내는 곳 | v | at / who | 읽는 곳 |
|---|---|---|---|---|
| `&"aphids_found"` | `Kitchen.start_ranch` — 여름 꽃 무리 곁 어른이 장미 줄기에서 찾음 (`_try_find`, 10시) · 별지기가 '진딧물 한 무리'를 내려 줌 (`SkyDrops.drop` kind `aphids`) | `{"src": &"rose"·&"sky", "n": int (목장의 진딧물)}` | `who` = 찾은 사람 (내려 준 것은 −1) · `at` = 목장 | `tests/kitchen_tests.gd` (앞으로 목장 울타리·진딧물 모델) |
| `&"honeydew_collected"` | `Kitchen.tend` (`kit_tend` — 아침 목장지기가 톡톡, 하루 한 번, 철만) | `{"amt": float (단물), "n": int (늘어난 뒤 진딧물)}` | `who` = 목장지기 · `at` = 목장 | `tests/kitchen_tests.gd` |
| `&"ladybug_raid"` | `Kitchen._ladybug` (철이면 하루 한 번 해시 `LADYBUG_P`) | `{"lost": int, "n": int (남은 진딧물 — 0이면 목장이 빔)}` | `at` = 목장 | `tests/kitchen_tests.gd` |
| `&"quail_egg_landed"` | `Kitchen.land` (`SkyDrops.drop` kind `egg` — 메추리알, 병마다 `EGG_COOLDOWN` 3일에 하나) | `{"id": int}` | `at` = 떨어진 자리 | `tests/kitchen_tests.gd` (앞으로 큰 알 모델·굴리기 연출) |
| `&"egg_feast"` | `Kitchen.crack` (`kit_egg_crack` — 굴려 와 창고 곁에서 깸, 아무도 못 굴리면 `EGG_WAIT` 뒤 그 자리에서) | `{"food": float (알 = 식량 3일치, 전부 거인 몫), "shell": &"basin"·&"boat"}` | `who` = 깬 사람 (−1 = 그 자리) · `at` = 깬 자리 = 껍데기 자리 | `tests/kitchen_tests.gd` (화면은 `Kitchen.shells` — `props/pf_eggshell`) |
| `&"seed_pressed"` | `Kitchen._press` (하루 한 번 `PRESS_HOUR`, 맷돌간·방앗간 일꾼이 해바라기씨를 빻음) | `{"seeds": float, "milk": float, "oil": float, "binder": float}` | `who` = 일꾼 · `at` = 맷돌간 | `tests/kitchen_tests.gd` |
| `&"fine_bread"` | `Kitchen.on_bake` (화덕·빵집 한 판 — 재료마다 처음 한 번만: 단물 빵·우유 빵·기름 빵) | `{"k": &"단물"·&"씨앗 우유"·&"씨앗 기름"}` | `who` = 빵 굽는 사람 · `at` = 화덕 | `tests/kitchen_tests.gd` |
- 2026-11-10 (Q2-b 귀여움 묶음 ② 아이·아기 — docs/ROADMAP.md Q2-b · E2-2 · E2-3, `sim/child_play.gd`): 아래 kind를 냄. 모두 저장 순번 아니오 · 연대기는 첫걸음마만 `log_line` 한 줄. 굴림(놀이를 열지·무슨 놀이·술래·돌탑이 무너질 높이)은 마을 씨앗·놀이 번호의 해시로 정하고 마을 난수 흐름을 쓰지 않는다 — `emit` 앞뒤로 난수 없음. 지켜보는지 읽지 않는다. 행복·경제 값은 바꾸지 않는다 (놀이는 아이의 `play` 행동 그대로 — 놀 자리와 하는 일 이름만, 들여다보기는 쉬는 사람의 짧은 멈춤).

| kind | 내는 곳 | v | at / who | 읽는 곳 |
|---|---|---|---|---|
| `&"kid_play_started"` | `ChildPlay.try_play` — 아이가 놀이를 엶 (술래잡기·나비 쫓기·돌탑) · `_tick_tag` — 혼자 남아 돌탑으로 바꿈 | `{"game": int, "kind": String ("tag"·"bfly"·"stack")}` | `who` = 연 아이 · `at` = 놀이 가운데 | `view/kids_view.gd` (말풍선) · `tests/kids_tests.gd` |
| `&"kid_tagged"` | `ChildPlay._tick_tag` — 술래가 한 아이를 잡음 (잡힌 아이가 다음 술래) | `{"by": int (잡은 술래), "game": int, "n": int (그 놀이의 몇 번째)}` | `who` = 잡힌 아이 · `at` = 잡힌 자리 | `view/kids_view.gd` ("잡았다!"·폴짝) · `tests/kids_tests.gd` |
| `&"kid_stack_fell"` | `ChildPlay._tick_stack` — 돌탑이 흔들리다 무너짐 (다시 쌓음) | `{"game": int, "h": int (무너질 때 돌 수), "n": int}` | `who` = 다음 차례 아이 (−1 없음) · `at` = 돌탑 | `view/kids_view.gd` (구르는 돌·"와르르") · `tests/kids_tests.gd` |
| `&"baby_peeked"` | `ChildPlay._peek` — 문 옆 요람의 젖먹이를 지나가던 쉬는 이웃이 잠깐 들여다봄 | `{"baby": int, "secs": float}` | `who` = 들여다보는 이웃 · `at` = 요람 | `view/kids_view.gd` (하트 그림 말풍선·아기 꼼지락) · `tests/kids_tests.gd` |
| `&"first_steps"` | `ChildPlay._first_steps` — 아기가 걸음마 나이(보이는 나이 1살)를 넘긴 첫 낮 (아기마다 한 번, `Village.kids["walked"]`) | `{"with": int (곁의 보는 사람, −1 없음)}` | `who` = 아기 · `at` = 집 문 앞 | `view/kids_view.gd` (말풍선) · `tests/kids_tests.gd` |
