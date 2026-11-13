## 부락 시뮬레이션 — 주민·건물·물자·믿음·시대·자율 건설 (RESIDENT_AI.md, 기획서 7·8장, 밸런스 v2).
## 화면과 분리된 순수 로직 (Node 없음). 물·소금·습기는 sim/jar_water.gd(JarWater)를 같이 돌린다.
## 수치는 data/balance.gd. 난수는 시드 하나(RandomNumberGenerator) → 같은 시드면 같은 결과.
## 좌표는 JarWater와 같다 (x 동서, y 남북 / Godot 3D에서는 x, z).
## 원본: prototype/app.html (step·lifeEvents·autoBuild·assignHomes…), 고친 규칙은 RESIDENT_AI.md 9장 · BALANCE.md 0장.
class_name Village
extends RefCounted

const DAY := Balance.DAY
const HOUR := Balance.HOUR
const R := JarWater.R
const PATH_N := 128
const ALTAR_OFFSET := Vector2(-2.4, -1.8)   # (정함) 제단 = 모닥불 곁 — 처음 값. 실제 자리는 pick_altar_pos (건물을 피해 모닥불에서 3칸)
const ALTAR_CLEAR := 2.1                     # 제단 둘레 비움 (돌 단 반지름 1.55 + 여유 — 건물·나무·민들레가 겹치지 않게)

var rng := RandomNumberGenerator.new()
var gene_rng := RandomNumberGenerator.new()   # 7단계: 겉모습 유전자·혈통 유전 전용 (시뮬레이션 난수 순서를 바꾸지 않게)
var health_rng := RandomNumberGenerator.new() # 건강·기후·두려움 전용 (HEALTH.md 7 — 유전·기존 흐름을 흔들지 않게)
# 병 날짜 (HEALTH.md 1.1): 세상을 만든 현실 날짜. 테스트는 Village.default_created로 고정 (비면 기기 날짜)
static var default_created: Dictionary = {}
# 저장 (docs/SAVE.md 2 — 완전 자동): 거인이 무언가 하면 이 함수가 곧바로 불린다 (SaveManager가 거인 묶음 + 이 병을 쓴다)
static var on_giant_action := Callable()
# 깨달음 (A4b — sim/awakening.gd): 시험 고정용. true면 예전처럼 처음부터 거인을 알고 제단이 있다 (기존 시험 묶음이 tests/run.gd에서 켬)
static var start_aware := false
var event_serial := 0                 # 저장 순번(dirty): 큰 일(연대기 한 줄·위기 시작)마다 +1 — SaveManager가 보고 이 병을 곧 저장한다. 사건 번호(events.serial)와 별개 (ADR-0001)
var events := EventStream.new()       # 사건 기록 흐름 (ADR-0001 — sim/event_stream.gd). 넓은 세상은 JarWorld가 무리들에 하나를 나눠 줌. 저장 안 함
var _giant_depth := 0
var created_date: Dictionary = {"year": 2026, "month": 4, "day": 15}
var climate_override := ""            # 비면 물(병)의 기후대
var cold_season := false              # 앞으로 반나절 안에 추위가 온다 (땔감 운반·나무꾼 넉넉함 — 정시마다)
var _sg_day := -1                     # Health.season_grow 캐시 (병 하루마다)
var _sg := 1.0
var sick_share := 0.0                 # 앓는 사람 비율
var warnings: Array = []              # 말풍선·편지로 띄울 위기 예고 {t, kind, text} (화면이 가져감)
var outbreaks: Dictionary = {}        # 병 → 지금 유행 {c 전염 배율, l 치사율, s 독함 0~1, name, t, n, won} (HEALTH.md 2.5 — sim/health.gd)
var _health_acc := 0.0
var _health_hour := 0
var _sick_warn_day := -1
var _taps := [-1, 0]                  # [날, 그날 톡 횟수]
var _rots := [-1, 0]                  # [날, 그날 돌리기 횟수]
var _singers: Array = []              # 노래꾼 혈통 주민 (life_events마다 다시)
var _festival_mult := 1.0             # 마을에 노래꾼이 있으면 축제 효과 ×1.2
var water: JarWater                   # 소형 병(JarWater) 또는 넓은 세상(WorldWater — JarWater를 잇는다)
# 6단계 — 넓은 세상: 마을은 세상 좌표의 한 자리(center)에 있다. 소형 병은 (0, 0)
var center := Vector2.ZERO            # 마을 중심 (창고 자리)
var sid := 0                          # 무리 번호 (키트마다 하나 — 안개·만남)
var layout_seed := -1                 # 마을 길 모양 씨앗 (VillagePlan — 큰길 수·휨·광장 크기). 새 무리를 만들 때 세상 씨앗 + 무리 번호로 한 번 (2026-11-09 1.2).
                                      #   -1 = 옛 저장·작은 시험 병: 옛 4갈래 모양 그대로 (이미 선 집이 길 위에 놓이지 않게)
var settlement_name := ""
var owns_water := true                # 이 마을이 물을 흘린다 (한 세상에 하나 — 나머지 무리는 others로 함께 걷는다)
var others: Array = []                # 같은 세상의 다른 무리 (Village) — 이 마을의 걸음에 맞춰 함께 걷는다
var explore_on := false               # [탐험] — 넓은 세상에서만 (소형 병 결과를 바꾸지 않게)
var path_r := R                       # 오솔길 격자가 덮는 반지름 (center 기준)
var path_n := PATH_N
var view_r := R                       # 화면이 소품을 까는 반지름 (center 기준)
var met: Dictionary = {}              # 만난 무리 sid → t
var _walker: Resident = null          # 지금 걷는 주민 (안개 걷기·발견 기록용)
var t := 0.0
var start_clock := Balance.START_CLOCK
var step_dt := Balance.STEP

# 거인
var watching := true                  # 거인이 지켜보는가 (앱 켜짐). watch_hours가 있으면 그 시각만
var watch_hours: Array = []           # 예: [20, 21] — sim_life.py처럼 하루 2시간만 지켜봄
var chief_off := false                # 테스트 전용 — 촌장이 짓지 않게 (게임에는 끄는 버튼이 없다: 마을은 늘 주민이 짓는다, 기획서 6.7)
var auto_reveal := false             # 시대 점수가 차면 지켜보는 때에 계시 (테스트용: 거인이 바로 승인한다고 가정)

var era := 0
var era_pts := 0.0
var era_watch_day := -1               # 시대 점수 '지켜봄' 몫을 센 달력 날 (era_watch_k)
var era_watch_secs := 0.0             # 그날 지켜봄 100%로 센 병 초 (Balance.ERA_WATCH_HOURS까지)
# A4b 깨달음 (기획서 6.5 · 11.1 — sim/awakening.gd). 기본값 true = 옛 저장(제단이 있던 병)은 그대로 안다. 새 병은 Awakening.start가 끈다
var aware := true                     # 주민이 하늘 너머의 거인을 안다 (깨달음 뒤)
var watcher := ""                     # N2 (STORY 4): 이 마을이 지켜보는 이를 부르는 말 (깨달을 때 정함 — sim/watcher_name.gd). 비면 아직 없음
var altar_built := true               # 제단이 있다 — 그 전엔 기도·제물·소원 편지가 없다
var wonder := 0.0                     # 경이 (목격이 쌓임 — Awakening.WONDER_NEED에서 깨달음)
var awaken_at := -1.0                 # 경이가 찼다 → 이 시각에 깨달음 사건
var awakened_t := -1.0
var guide: Dictionary = {}            # 첫 병의 안내 자막 (OPENING 3.1 v3 — view/ui/guide_caption.gd): {on, tap}. 비면 안내 없음
var _wonder_taps := [-1, 0]           # [날, 그날 경이가 된 톡 수] (거듭될수록 줄어듦)
var notebook: Dictionary = {}         # [거인의 수첩] 첫 병의 쪽지 (OPENING 3.1b — sim/notebook.gd). 비면 수첩 없음
var site_logs: Dictionary = {}        # [거인의 수첩] 짓는 터 id(글자) → 하늘에서 내려와 터로 나른 통나무 (짓는 속도↑ — SkyDrops.site_boost)
# A5 계시 (기획서 8.3 · 6.1 · 14): 시대 점수가 다 차면 주민이 알아채고 거인의 [계시]를 기다린다. 거인만 내린다 (비운 동안은 기다림)
var revelation: Dictionary = {}       # 계시를 기다림 {t, from: 주민 id, name, text} — 비면 기다리는 계시 없음
var _rev_say_t := 0.0                 # 기다리는 동안 노인이 하늘을 보며 한마디 하는 다음 시각
# A10 연대기 (UI 07 · PROGRESSION 4)
var myth: Array = []                  # 창세 신화 줄 (OPENING 9 — 창조가 채울 자리. 비면 연대기의 첫 기록)
var departed: Array = []              # 분가로 떠난 사람 {id, name, sex, age, t, to: 무리 이름, to_sid}
var discoveries: Dictionary = {}      # 발견 id → {t, who: 주민 id, name} (sim/codex.gd — 발견 도감)
var disc: Dictionary = {}             # 발견 조건의 상태 {trees0, bake_t, sun_t, sun_elders} (sim/discovery.gd — 옛 저장은 빈 값)
var disc_rng := RandomNumberGenerator.new()   # 발견할 사람 고르기 전용 (다른 흐름의 난수 순서를 바꾸지 않게)
var faith := 50.0
var fear := 0.0
var stock: Dictionary = {}
var manna: Array = []                 # 들판의 낟알 {x, y, amt, born, res}
var manna_batches: Array = []         # 창고에 주워 온 낟알 {amt, born}
var manna_falls := 0
var first_harvest_t := -1.0
var manna_ended := false
var festival_t := -1.0e9
var _last_dawn := -1
var _arrival_manna := false
var auto_manna := Balance.AUTO_MANNA  # v5: 하늘 낟알이 저절로 내리나 (새 병은 아니다 — 거인이 손으로)
var _hunger_hint_t := -1.0e9
var staged_until := -1.0              # v5: 연출 장면(깨달음 → 제단 짓기 → 첫 기도)이 끝나는 병 시각 — 그동안은 예전 걸음 (장면이 느린 병 시계로 돈다)
var trees: Array = []                 # {x, y, s: "tree"/"stump"/"sapling", g, res}
var rocks: Array = []                 # {x, y, amt, res, ore?} — ore 없음 = 돌. 광맥 돌의 바위는 ore = 돌·소금·철광석·석탄 (SkyDrops.rock_minable)
var buildings: Array[Building] = []
var people: Array[Resident] = []      # 살아 있는 주민
var dead: Array[Resident] = []
var fire := Vector2(2.2, 1.6)
var next_id := 1
var book: Array = []                  # 연대기 {t, text}
var paths := PackedFloat32Array()     # 오솔길 128×128
var deficit := 0.0
var last_short_t := -1.0e9            # 마지막으로 식량이 모자랐던 때
var salt_known := false
var crises: Array = []                # 위기가 시작됨 {t, kind, text} — JarClock이 가져가 ×1로 되돌리고 알림 (기획서 6.6)
var stats := {"born": 0, "died": 0, "built": 0, "starved": 0, "marriages": 0, "moves": 0, "upgrades": 0}
var found: Array[Dictionary] = []     # 떨어진 물건 (작은 시험 병만 — 넓은 세상은 WorldWater.found, sim/found_objects.gd · E3-16)
var birth_log: Array = []             # 테스트용: 출생 때 집 정원 {t, home, occ_before, cap}
var birth_floor_t := -1.0             # 어린것이 드물어 (먹을 것 문이 닫힌 채) 한 집이 아기를 맞은 마지막 때 (병 초 · -1 = 아직 없음) — 병 하루에 하나까지 (Balance.BIRTH_LITTLE_REST_DAYS). 저장됨
var wild_food := 0.0                  # 마을 둘레의 들·숲 가에 지금 나 있는 먹을 것 (식량 단위 · 맨손 채집 — Balance.FORAGE_*). 저장됨
var forage_note_t := -1.0e9           # 연대기에 '바구니를 들고 나갔다'를 마지막으로 적은 때 (병 초). 저장됨
var _fg_t := -1.0                     # (저장 안 함) forage_open()을 마지막으로 센 걸음
var _fg_ok := false
var violations: Array = []            # 테스트용: 규칙 위반 기록
var basins_said: Array = []
var _starve_day := -1
var _timers := {"life": 0.0, "jobs": 0.0, "chief": 0.0, "lake": 0.0, "decay": 0.0, "speak": 0.0, "econ": 0.0}
# v4.0 — 제단·제물·소원·분가 (기획서 6.7 · 11.1 · 3.1). 계산은 아래 '제단' 절
var econ_rng := RandomNumberGenerator.new()   # 소원 편지·제물 전용 (다른 흐름의 난수 순서를 바꾸지 않게)
# [마을의 삶] 사람 사이 — 이야기·다툼·사랑·혼례 모임 (ROADMAP E2 — sim/social.gd, 난수도 따로)
var social := {}                      # {"p": 짝마다 관계 값, "wed": 혼례 모임 약속, "story": 사랑 이야기 …} (저장됨)
var social_rng := RandomNumberGenerator.new()
var kids := {}                        # [아이·아기] 벌어진 놀이·요람 들여다보기·첫걸음마 (sim/child_play.gd — 저장됨)
var milestones: Dictionary = {}      # [자람의 보상] 넘은 고비·기다리는 잔치 (sim/milestones.gd — 저장됨, 병의 첫 정착지 것)
# [인구] 이주민의 조각 (design/gdd/population.md R6-6 · STORY 1) — 따로 흐름 (혼인·출산 흐름 rng를 흔들지 않게)
var pop_rng := RandomNumberGenerator.new()
var hint_bag: Array = []              # 아직 나오지 않은 조각 id (네 가지가 다 나오면 다시 섞어 채움 — 저장됨, 옛 저장은 빈 채로)
var social_events: Array = []         # 화면이 가져가는 장면 (저장 안 함 — view/social_stage.gd)
var social_serial := 0
var _social_t := 0.0
# [곰팡이·뚜껑] 병의 공기(김·연기·탁한 공기·뚜껑)와 곰팡이 무리 — WORLD_EVENTS 2.1 · 3 (sim/jar_air.gd · sim/mold.gd, 난수도 각자)
var air: JarAir
var mold: Mold
var hand: GiantHand                   # [거인의 손] 물 뿌리기·감싸기·커튼·유리 닦기·핀셋 (ROADMAP B6 — sim/giant_hand.gd, 난수 없음)
var smalls: SmallCrises                # [작은 위기] 날벌레·떠돌이 물방울·먼지 뭉치 (WORLD_EVENTS 2.2 — sim/small_crises.gd, 난수도 따로)
var flora: Flora                      # [하늘의 것] 큰 버섯·큰 민들레 (WORLD_EVENTS 2.6 · 2.7 — sim/flora.gd)
var dogs: Dogs                        # [강아지] 집 강아지·마을 강아지·꿀떡이 — 무리마다 (GD 3.0 · E3-13 — sim/dogs.gd, 난수도 따로)
var warmth: CoreWarmth                # [핵] 병의 따뜻함 캐시 (이끼 덮임·밭 이슬 배율 — sim/core_warmth.gd · 저장 안 함)
var jar_notes: Array = []             # [핵] 별지기의 수첩 한 줄 — 처음 눈에 띈 병의 성질 {t, id, text} (A28b · OPENING v4.0-6, 저장됨)
var lean: LeanSeasons                 # 빠듯한 철 캐시 (푸른 밀 고개·애벌레 많은 해 — docs/BALANCE.md B-1, sim/lean_seasons.gd · 저장 안 함)
var kitchen: Kitchen                  # 우유·계란 없는 부엌 — 진딧물 목장·하늘의 큰 알·씨앗 방앗간 (E3-14 — sim/kitchen.gd)
var caterpillars: Caterpillars        # 애벌레 → 고치 → 나비 · 애벌레 잡이 · 꿀방울 — 무리마다 (production-chain R7 — sim/caterpillars.gd)
var direct_route := Balance.DIRECT_ROUTE   # 바로 보냄 (production-chain R3) — 시험이 끌 수 있게 (저장 안 함)
var _stall: Dictionary = {}           # 건물 id → 막힘 판정 (Production.stall_tick — 저장 안 함, 불러온 첫 걸음엔 사건 없음)
var wild: Wildlife                    # [들짐승] 물고기·애벌레 자리 (E3-12 — 큰 짐승 없음) 병 하나에 하나 — 첫 무리가 돌리고 다른 무리는 같은 것을 함께 쓴다 (WILDLIFE — sim/wildlife.gd)
var altar_pos := Vector2.ZERO         # 첫 모닥불 곁 작은 돌 제단
var altar: Array = []                 # 제단의 제물 {item, amt, t, by: PackedInt32Array, away?: 거인이 비운 동안(등불 시간) 바친 것}
var tick_mult := 1.0                  # 따라잡기 빠른 길 (CatchUp.fast): 건강·공기·버섯·혼인출산 계산 간격 배율 (저장하지 않음 — 거인이 보면 1)
var altar_hold := false               # 따라잡기 중 (SAVE.md 3.1): 비운 동안 바친 제물은 이틀이 지나도 창고로 돌아가지 않는다
var favourites: Dictionary = {}       # 거인님이 받으신 물건 → 받은 개수 합 ('거인님은 빵을 좋아하신다')
var letters: Array = []               # 주민의 편지 {id, kind: "wish"/"split", t, from, name, type, text, state: "open"/"granted"/"done"}
var wishes: Array = []                # 들어준 소원 중 아직 터를 잡지 않은 건물 종류
var _offer_day := -1
var _next_wish_t := Balance.WISH_FIRST
var _full_since := -1.0               # 영역이 90% 넘게 찬 때부터
var _letter_id := 0
# (Q25 2026-11-12) 연장이 모자람 — sim/tool_short.gd (신호 · 촌장의 '연장이 모자라요' 편지 · 상점의 연장 꾸러미). 옛 저장은 기본값 = 꺼짐
var tools_short_t := -1.0             # 모자람 신호가 켜진 병 시각 (-1 = 꺼짐)
var tools_short_h := 0                # 한 시간마다 본 조건: 이어서 모자란 시간 (+) · 이어서 풀린 시간 (−)
var tools_short_first := -1.0         # 처음 켜진 병 시각 (상점의 연장 꾸러미가 열림)
var tools_wish_t := -1.0              # 마지막 '연장이 모자라요' 편지를 쓴 병 시각
var tools_signal_off := false         # 시험 전용 (저장 안 함) — 신호를 끈 같은 마을과 경제가 같은지 견줄 때
# (Q30 2026-11-14) 돌이 모자람 — sim/stone_short.gd (신호 · 촌장의 '돌이 모자라요' 편지 · 자갈 한 알 / 회색 돌멩이). 옛 저장은 기본값 = 꺼짐
var stone_short_t := -1.0             # 돌 모자람 신호가 켜진 병 시각 (-1 = 꺼짐)
var stone_short_h := 0                # 이어서 모자란 시간 (+) · 이어서 풀린 시간 (−)
var stone_short_first := -1.0         # 처음 켜진 병 시각
var stone_wish_t := -1.0              # 마지막 '돌이 모자라요' 편지를 쓴 병 시각
var stone_wish_id := -1               # 그 편지의 id (닫히는 것을 지켜봄 — 닫히면 -1)
var stone_wish_miss := 0              # 이어서 들어주지 않고 닫힌 돌 편지 수 (다음 편지까지 4 → 8 → 16일, 돌로 들어주면 0)
var stone_wish_closed_t := -1.0       # 들어주지 않은 돌 편지가 닫힌 병 시각
var stone_signal_off := false         # 시험 전용 (저장 안 함)
var _people_by_id: Dictionary = {}
var _bld_by_id: Dictionary = {}
var _fp_val := 0.0                    # (저장 안 함) 이 걸음 처음에 센 _food_people() — enough("밀")이 같은 걸음 안에서 다시 쓴다
var _fp_n := -1
var _fp_t := -1.0
var _pnz := PackedInt32Array()        # (저장 안 함) 밟힌 적 있는 오솔길 칸 — _path_rebuild_nz
var _pnz_in := PackedByteArray()
var _pnz_ok := false
var _tr_fix := -1.0                   # (저장 안 함) find_spot 동안 고정한 영역 반지름 (<0 = 늘 새로 셈)
var _site_cache := {}                 # (저장 안 함) 자리 고르기 자원 지도 (sim/siting.gd — 한 시간마다 한 번 다시)
var _homes_sig := PackedInt64Array()  # (저장 안 함) 집 배정이 아무것도 바꾸지 않았던 상태 — 같으면 다시 볼 것이 없다 (assign_homes)
var _homes_types := PackedStringArray()
var _opening_chief := 0               # 첫 한 시간에 촌장이 터를 잡은 횟수 (OPENING_CHIEF_AT)
var _spread_left := Balance.HOUR      # 숲이 저절로 퍼지는지 다음에 굴리기까지
# 거인의 상점·하늘에서 내려온 것 (SHOP.md · WORLD_EVENTS 1.1 · 4.1 · 4.4 — sim/shop.gd · sim/sky_drops.gd)
var drops: Array = []                 # 바깥 크기의 물건 {id, item, x, y, res, total, left, size, res_n(깎는 사람), t, dur(효과만 — 사그라드는 시간)}
var towers: Array = []                # 영양제 앰플 탑 {id, x, y, t}
var veins: Array = []                 # 박힌 광맥 돌 {item, ore, x, y, amt, t} (SHOP 2.4 — 바위는 rocks에 ore를 달고)
var algae: Array = []                 # 녹조 {x, y, t, until}
var care: Dictionary = {}             # 돌봄 효과가 끝나는 병 시각 {pill, bandage}
var shop_open: Dictionary = {}        # 상점 탭 → 열린 병 시각 (Shop.update_unlocks)
var shop_seen: Array = []             # 거인이 들여다본 탭 (상점 버튼 옆 반짝임)
var shop_bought: Dictionary = {}      # 이 병에 사 준 건물 수 (또 사면 ×1.5)
# BALANCE v5 (sim/production.gd · sim/altar.gd)
var blueprints: Dictionary = {}       # 거인이 내려 준 설계도 — 건물 종류 → 받은 병 시각 (그 병 주민이 그 건물을 지을 줄 앎)
var era_t := 0.0                      # 지금 시대가 열린 병 시각 (계시) — 새로 배워야 하는 건물은 이로부터 MUST_LEARN_SELF_DAYS 뒤 스스로 깨침
var self_learned: Dictionary = {}     # 주민이 스스로 깨친 새로 배워야 하는 건물 → 병 시각 (연대기 한 줄을 한 번만)
var gift: Dictionary = {}             # 창고의 물건 중 거인이 준 몫 (하늘에서 내려온 것 — 제물로 되돌아가지 않는다. 가공하면 가공품으로 옮겨 감)
var altar_level := 0                  # 제단 단계 0~3 (Balance.ALTAR_NAMES — 돌무더기 · 판석 · 꽃 · 작은 사당)
var altar_rebuild_until := -1.0       # 넓힌 제단을 주민이 다시 짓는 중 (이때까지)
var ate_bread_t := -1.0e9             # 마지막으로 빵을 먹은 때 (행복)
var ate_porridge_t := -1.0e9          # 마지막으로 밀을 죽으로 끓여 먹은 때
var ate_honey_t := -1.0e9             # 마지막으로 꿀을 먹은 때 (행복 + HONEY_HAPPY)
var _offer_key := -1                  # 마지막 기도 제물 (달력 날 × 2 + 아침 0 · 저녁 1)
var _drop_id := 0
var migrants: Dictionary = {}         # 마지막 이주민 맞이 {t, until, mood, kind, ids} (sim/immigrants.gd — 행복 잠깐 ±)
var _sky_acc := 0.0
# 마을 시대 건물 (A6 — sim/village_era.gd) · 등불 옮기기 (A11 — sim/lamp.gd)
var graves: Array = []                # 무덤 {id, name, x, y, t, yard(묘지 안), yard_id}
var wade_secs := 0.0                  # 물을 걸어 건넌 시간 (사람×초, 반감기 하루) — 촌장의 나루터 조건
var wedding_t := -1.0e9               # 교회 혼례 잔치 (반나절)
var bell_t := -1.0e9                  # 교회 종이 울린 때 (화면이 소리 — 저녁 기도·혼례)
var market_day := -1                  # 광장 장날 (병 달력 n일차)
var lamp_hinted := false              # 등불을 처음 옮기려 할 때 노인의 귀띔을 들었다 (GD 4.6)
var lamp_moved_t := -1.0e9            # 마지막으로 등불을 옮긴 때
var lamp_last: Dictionary = {}        # 마지막으로 옮길 때의 미리보기 요약 {from, to, up, down} (지도 반짝임·시험)


# ───────────────────────── 처음 세계 ─────────────────────────
static func new_prototype(seed_v: int = 20261105) -> Village:
	var v := Village.new()
	v._init_prototype(seed_v)
	return v


func _init_prototype(seed_v: int) -> void:
	auto_manna = true                     # v5: 작은 시험 병(개발 장면·시험)은 예전처럼 하늘 낟알이 저절로 — 새 넓은 세상은 거인이 손으로
	rng.seed = seed_v
	gene_rng.seed = seed_v * 7919 + 101
	econ_rng.seed = seed_v * 6151 + 29
	_init_health(seed_v)
	altar_pos = fire + ALTAR_OFFSET
	water = JarWater.new_prototype_world()
	water.start_clock = start_clock
	water.t = 0.0
	stock = Balance.START_STOCK.duplicate()
	paths.resize(PATH_N * PATH_N)
	paths.fill(0.0)
	_pnz_ok = false
	# 숲 다섯 군데 · 바위 · (호수는 물 시뮬레이션)
	for g: Vector2 in [Vector2(-12, 14), Vector2(-20, 4), Vector2(18, -6), Vector2(22, 12), Vector2(4, 22)]:
		for i in 24:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 6.5
			var x := g.x + cos(a) * d
			var y := g.y + sin(a) * d * 0.9
			if Vector2(x, y).length() < R - 1.5 and water.w[JarWater.cell_idx(x, y)] < 0.005:
				trees.append({"x": x, "y": y, "s": "tree", "g": 0.0, "res": 0})
	for p: Vector2 in [Vector2(-6, -18), Vector2(-3, -20), Vector2(4, 20), Vector2(7, 19), Vector2(-24, -2), Vector2(24, -10)]:
		rocks.append({"x": p.x, "y": p.y, "amt": 20, "res": 0})
	for b: Dictionary in water.basins:
		basins_said.append(0)
	var st := add_building("창고", 0.0, 0.0, true)
	st.is_store = true
	altar_pos = pick_altar_pos()
	FoundObjects.bury_local(self, seed_v)     # 떨어진 물건 (E3-16) — 마을 둘레에 2~3개 (따로 쓰는 난수)
	# 첫 정착민 두 가족 + 노인 + 젊은이
	var ids: Array[Resident] = []
	for f: Array in Balance.FIRST_SETTLERS:
		var r := add_person(f[0], f[1], f[2], f[3], fire.x + (rng.randf() - 0.5) * 3.0, fire.y + (rng.randf() - 0.5) * 3.0, null, null)
		ids.append(r)
	marry(ids[0], ids[1])
	for k in [2, 3]:
		ids[k].parents = PackedInt32Array([ids[0].id, ids[1].id])
	marry(ids[4], ids[5])
	ids[6].parents = PackedInt32Array([ids[4].id, ids[5].id])
	# 아이는 부모를 닮는다
	for k in [2, 3]:
		_inherit_look(ids[k], ids[0], ids[1])
	_inherit_look(ids[6], ids[4], ids[5])
	for r in ids:                     # 첫 정착민은 혈통 없음 (기본 키트 — BLOODLINES 5장)
		set_blood(r, PackedStringArray())
	stats["marriages"] = 0
	# 10명 중 최소 1명은 '재능' 이상 (OPENING 단계 8)
	if people.all(func(p: Resident) -> bool: return p.grade == 0):
		ids[4].grade = 1
	_arrive_fed()
	Awakening.start(self)
	log_line("어느 새벽, 우리 조상 열 명이 꽃숲 가장자리에 처음으로 불을 피웠다.")
	log_line("하늘의 두 점에서 거대한 물방울이 똑, 똑 떨어진다. 그 아래 호수는 마르지 않는다. 강은 그늘진 세상 끝 벽에서 흘러내려 낮은 곳으로 간다. 서쪽의 큰 호수에는 흘러드는 강이 없다.")


func _init_health(seed_v: int) -> void:
	health_rng.seed = seed_v * 104729 + 7
	social_rng.seed = seed_v * 2654435 + 17
	pop_rng.seed = seed_v * 15485863 + 31
	Social.lines()                        # 말 묶음을 미리 읽음 (첫 만남 걸음이 갑자기 느려지지 않게 — 빠른 흐름의 계산 예산)
	disc_rng.seed = seed_v * 7919 + 13
	air = JarAir.new(seed_v)              # [곰팡이·뚜껑]
	mold = Mold.new(seed_v)
	smalls = SmallCrises.new(seed_v)     # [작은 위기]
	hand = GiantHand.new()                # [거인의 손]
	flora = Flora.new(seed_v)             # [하늘의 것]
	caterpillars = Caterpillars.new()     # 애벌레 한살이 (production-chain R7-5)
	kitchen = Kitchen.new()               # 우유·계란 없는 부엌 (E3-14)
	dogs = Dogs.new(seed_v)               # [강아지] 처음 걸음에 마을 강아지 둘 (첫 병이면 꿀떡이도)
	wild = Wildlife.new(seed_v)           # [들짐승] (넓은 세상의 다른 무리는 JarWorld.place_kit이 첫 무리 것으로 바꿈)
	if not default_created.is_empty():
		created_date = {"year": int(default_created["year"]), "month": int(default_created["month"]), "day": int(default_created["day"])}
	else:
		var d := Time.get_date_dict_from_system()
		created_date = {"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"])}
	_health_hour = 0


# ───────────────────────── 첫 한 시간 (OPENING 3.1) ─────────────────────────
## 첫 감사 기도 전의 첫 한 시간 — 어른은 곧바로 일하고, 따로 기도하지 않고, 첫 터는 천천히 지어진다
func in_opening() -> bool:
	return int(stats.get("thanks", 0)) == 0 and t < Balance.OPENING_END and not chief_off     # 촌장이 없으면(시험) 대본도 없다


## v5 걸음 배율 — 보통 1. (A28 2026-11-08) 첫날 걸음 덤(옛 WALK_OPENING)은 없앰: 걸음은 어디서나 화면 0.7칸/초 —
## 수첩의 첫날은 병 시계가 느리게·빠르게 흐르는 만큼만 되돌린다 (Notebook.day_scale의 역수 — 시계 보정뿐, 덤 없음)
func pace_walk() -> float:
	if Notebook.first_day(self):
		return 1.0 / maxf(0.01, Notebook.day_scale(self, Notebook.real(self)))
	return 1.0 / Awakening.stage_scale(self)     # 첫날 밖의 깨달음·제단·첫 기도 장면: JarClock이 늦춘 병 시계만큼만 되돌림 (A28 후속 — 시계 보정, 덤 없음)


## 깨달음 → 제단 → 첫 기도 장면 중 (EVENTS_STAGING 1 · 2 — JarClock이 병 시계를 느리게 돌리는 동안)
func staged() -> bool:
	return (aware and not altar_built and awakened_t >= 0.0) or t < staged_until


## v5 채집·일 동작(짓기 제외) 배율 — 첫 한 시간 대본은 예전 길이, 수첩의 첫날은 느린 병 시계에 맞춰
func pace_act() -> float:
	if in_opening() or staged():
		return Balance.GATHER_K
	if Notebook.first_day(self):
		return Balance.PACE_FIRST_DAY
	return 1.0


## 첫 한 시간에 짓는 터의 빠르기 배율 — 그 터는 OPENING_BUILD_WORK(사람×초)를 일해야 다 지어진다
func opening_build(b: Building) -> float:
	if not in_opening() or b.site_type() == Awakening.ALTAR:
		return 1.0
	return minf(1.0, float(Balance.B[b.site_type()]["time"]) / Balance.OPENING_BUILD_WORK)


## 정착민은 먹고 왔다 — 도착한 끼니(아침 7시)는 건너뛴다
func _arrive_fed() -> void:
	var mk := ResidentAI._meal_key(self, hour_now())
	if mk >= 0:
		for p in people:
			p.meal_done = mk


## 첫 감사 기도 (첫날만 — OPENING 3.1 3:30): 첫 건물이 서면 모두 하던 일을 놓고 제단 곁에 모여 허밍
func thanksgiving(b: Building) -> void:
	stats["thanks"] = 1
	if not altar_built:                   # 아직 제단이 없다 (A4b) — 기도 대신 모닥불 곁에 모여 첫 집을 기뻐함 (짧게)
		log_line("%s%s 다 지어지자 모두 모닥불 곁에 모여 손뼉을 쳤다. %s" % [b.label(), josa(b.label(), "이", "가"),
			"우리 손으로 지은 첫 지붕이었다." if b.is_house() else "우리 손으로 일군 첫 터였다."])
		var cc := chief()
		for p in people:
			if p.is_baby() or p.sleeping or p.sick_left > 0.0:
				continue
			if ResidentAI.hauling_to_site(p):
				continue          # (2026-11-09 1.2) 다음 터(밭)로 판자를 나르던 짐꾼은 내려놓고 온다 — 예약이 풀려 첫날 밭·벌목장이 늦어지지 않게
			ResidentAI.cancel(self, p)
			var q := ResidentAI.near(self, fire.x, fire.y, 1.6 + rng.randf() * 1.0)
			p.doing = "첫 집을 기뻐하는 중"
			p.steps.append(ResidentAI.walk(q.x, q.y))
			p.steps.append(ResidentAI.act(Balance.THANKS_TIME * 0.4, "idle"))
		if cc != null:
			speak(cc, "우리 손으로 지었어!", 8)
		var cheer := ["와아, 지붕이다!", "우리 집이야!"] if b.is_house() else ["와아, 다 됐다!", "우리가 해냈어!"]     # [거인의 수첩 v3.3] 첫 터가 서면 짧은 환호
		var k := 0
		for p in people:
			if k >= cheer.size():
				break
			if p != cc and not p.is_baby() and not p.sleeping and p.sick_left <= 0.0:
				speak(p, cheer[k], 7)
				k += 1
		return
	log_line("%s%s 다 지어지자 모두 모닥불 곁 돌 제단에 모여 {w}께 감사 기도를 드렸다." % [b.label(), josa(b.label(), "이", "가")])
	var c := chief()
	for p in people:
		if p.is_baby() or p.sleeping or p.sick_left > 0.0:
			continue
		ResidentAI.cancel(self, p)
		var a := rng.randf() * TAU
		var q := altar_pos + Vector2(cos(a), sin(a)) * (Awakening.RING_R + rng.randf() * 0.8)     # 제단 둘레 고리
		p.action = "pray"
		p.last_action = "pray"
		p.doing = "감사 기도하는 중"
		p.steps.append(ResidentAI.walk(q.x, q.y))
		p.steps.append(Awakening.face_altar_step(self, q))     # 제단을 바라보며
		p.steps.append(ResidentAI.act(Balance.THANKS_TIME, "pray", ResidentAI.op("pray")))
	if c != null:
		speak(c, Balance.LINE_THANKS, 8)


func add_building(type: String, x: float, y: float, built: bool) -> Building:
	var b := Building.new()
	b.id = next_id
	next_id += 1
	b.type = type
	b.x = x
	b.y = y
	b.built = built
	if built:
		b.prog = float(b.def()["time"])
		b.built_t = t
		if type == "농장":
			b.ready_at = t + Balance.GROW_FIRST
	buildings.append(b)
	_bld_by_id[b.id] = b
	VillageEra.on_site(self, b)          # 나루터: 건너편 물가
	return b


func add_person(name: String, sex: String, age: float, trait_n: String, x: float, y: float, mom: Resident, dad: Resident) -> Resident:
	var r := Resident.new()
	r.id = next_id
	next_id += 1
	r.name = name
	r.sex = sex
	r.age = age
	r.born_t = t - age * DAY
	var tr: Array = Balance.TRAITS[rng.randi() % Balance.TRAITS.size()]
	if trait_n != "":
		for q: Array in Balance.TRAITS:
			if q[0] == trait_n:
				tr = q
	r.trait_name = tr[0]
	r.trait_desc = tr[1]
	r.work_mult = tr[2]
	r.trait_mod = tr[3]
	r.fert = _triangular(Balance.FERT_LO, Balance.FERT_HI, 1.0)
	r.talent = _triangular(Balance.TALENT_LO, Balance.TALENT_HI, 1.0)
	r.grade = _roll_grade()
	r.x = x
	r.y = y
	r.px = x
	r.py = y
	r.belief = Balance.BELIEF_START if age > 0.0 else (Balance.BELIEF_BABY_WATCHED if is_watching() else Balance.BELIEF_BABY_ALONE)
	if not aware:
		r.belief = 0.0                    # 아직 거인을 모른다 (A4b)
	# 겉모습
	r.look_head = rng.randi() % Balance.LOOK_HEADS
	r.look_clothes = 1 if sex == "f" else 0
	if rng.randf() < 0.25:
		r.look_clothes = 1 - r.look_clothes
	r.look_hat = rng.randi() % Balance.LOOK_HATS
	r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
	r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
	r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
	r.genes = Genetics.random_genes(gene_rng)
	if mom != null and dad != null:
		_inherit_look(r, mom, dad)
	# 처음 정착민의 숙련: 성인이 된 뒤 일한 날만큼 (sim_life.py와 같은 가정)
	if age > Balance.AGE_ADULT:
		r.skills["일꾼"] = minf(Balance.SKILL_MAX, Balance.SKILL_RATE * r.talent * (minf(age, Balance.AGE_ELDER) - Balance.AGE_ADULT))
	people.append(r)
	_people_by_id[r.id] = r
	return r


func _inherit_look(r: Resident, a: Resident, b: Resident) -> void:
	r.look_hair = (a if rng.randf() < 0.5 else b).look_hair
	r.look_skin = (a if rng.randf() < 0.5 else b).look_skin
	r.look_head = (a if rng.randf() < 0.5 else b).look_head if rng.randf() < 0.7 else rng.randi() % Balance.LOOK_HEADS
	# 7단계: 겉모습 유전자 + 혈통 (BLOODLINES 7장·1장) — gene_rng만 씀
	r.genes = Genetics.inherit(gene_rng, a.genes, b.genes)
	var pb := a.blood.duplicate()
	for id in b.blood:
		if not id in pb:
			pb.append(id)
	r.parent_blood = pb
	r.parent_blood_sex = {}
	for q: Resident in ([a, b] if b != a else [a]):
		for id in q.blood:
			if not r.parent_blood_sex.has(id):
				r.parent_blood_sex[id] = q.sex
	var grand := a.parent_blood.duplicate()
	grand.append_array(b.parent_blood)
	set_blood(r, Bloodlines.inherit(gene_rng, a.blood, b.blood if b != a else PackedStringArray(), grand))
	# 혈통이 어디서 왔나 (화면용 — 난수를 쓰지 않는다). 부모 둘 다 가졌으면 아이 번호로 번갈아
	r.blood_src = {}
	for id in r.blood:
		var in_a := id in a.blood
		var in_b := b != a and id in b.blood
		if in_a or in_b:
			var who: Resident = a if (in_a and (not in_b or r.id % 2 == 0)) else b
			r.blood_src[id] = "mother" if who.sex == "f" else "father"
		elif a.parent_blood_sex.has(id) or b.parent_blood_sex.has(id):
			var sx: String = a.parent_blood_sex.get(id, b.parent_blood_sex.get(id, "m"))
			r.blood_src[id] = "grandmother" if sx == "f" else "grandfather"
		else:
			r.blood_src[id] = "new"


## 혈통을 정한다 — 효과(fx)와, '다산'·'난산'이면 타고난 출산 배율. src = 모두 같은 출처 ("kit"·"migrant"…, 비면 그대로)
func set_blood(r: Resident, b: PackedStringArray, src := "") -> void:
	r.set_blood(b)
	if src != "":
		r.blood_src = {}
		for id in b:
			r.blood_src[id] = src
	var fr: Variant = r.fx.get("fert")
	if fr is Array:
		r.fert = gene_rng.randf_range(float(fr[0]), float(fr[1]))


func _triangular(lo: float, hi: float, mode: float) -> float:
	var u := rng.randf()
	var c := (mode - lo) / (hi - lo)
	if u < c:
		return lo + sqrt(u * (hi - lo) * (mode - lo))
	return hi - sqrt((1.0 - u) * (hi - lo) * (hi - mode))


func _roll_grade() -> int:
	var u := rng.randf()
	for g in range(Balance.GRADE_P.size() - 1, 0, -1):
		if u < Balance.GRADE_P[g]:
			return g
		u -= Balance.GRADE_P[g]
	return 0


func marry(a: Resident, b: Resident) -> void:
	a.partner = b.id
	b.partner = a.id
	stats["marriages"] += 1


func person(id: int) -> Resident:
	return _people_by_id.get(id, null)


func bld(id: int) -> Building:
	return _bld_by_id.get(id, null)


func store() -> Building:
	for b in buildings:
		if b.is_store and b.built:
			return b
	return buildings[0]


# ───────────────────────── 시간 ─────────────────────────
func clock() -> float:
	return fmod(start_clock + t, DAY)


func hour_now() -> float:
	return clock() / HOUR


func day_no() -> int:
	## N일차 — 도착한 순간부터 24시간마다 (1부터)
	return int(t / DAY) + 1


func is_night() -> bool:
	var h := hour_now()
	return h >= Balance.NIGHT_FROM or h < Balance.NIGHT_TO


func is_work_time() -> bool:
	var h := hour_now()
	return h >= Balance.WORK_FROM and h < Balance.WORK_TO


func is_watching() -> bool:
	if watch_hours.is_empty():
		return watching
	return int(hour_now()) in watch_hours


## 표시용 'N일차 HH:MM' — 달력 날짜 (도착한 날 = 1일차, 자정마다 +1, 프로토타입 fmtTime)
func fmt_time(tt: float) -> String:
	var c := fmod(start_clock + tt, DAY)
	return "%d일차 %02d:%02d" % [cal_day(tt), int(c / HOUR), int(fmod(c, HOUR) / 60.0)]


func cal_day(tt: float) -> int:
	return int((start_clock + tt) / DAY) - int(start_clock / DAY) + 1


## 제단 자리: 모닥불에서 3칸 둘레를 돌며 건물·물에 겹치지 않는 첫 자리 (난수 없이). 못 찾으면 지금 자리
func pick_altar_pos() -> Vector2:
	for rr: float in [3.0, 3.6, 4.4]:
		for i in 16:
			var a := deg_to_rad(-60.0 + i * 22.5)
			var p := fire + Vector2(cos(a), sin(a)) * rr
			if altar_spot_ok(p):
				return p
	return altar_pos


# ───────────────────────── 스타터킷 건물을 거인이 놓기 (OPENING 8 v3.9) ─────────────────────────
## 상자(center) 곁 KIT_PLACE_R 안 · 물·벽·바위·가파른 땅이 아닌 곳 · obstacles([[Vector2, 반지름]] — 이미 놓은 것·상자)와 겹치지 않게.
## {ok, why}. 아직 놓지 않은 키트 건물은 세지 않는다 (장면이 obstacles로 놓은 것만 넘김)
const KIT_PLACE_R := 14.0
const KIT_STEEP := 0.25                  # 건물 바닥 둘레 높낮이가 이 위면 '땅이 너무 기울었어요' (정함 — JarWorld.relief 단위)


func kit_item_ok(p: Vector2, size: float, obstacles: Array) -> Dictionary:
	if p.distance_to(center) > KIT_PLACE_R:
		return {"ok": false, "why": "상자에서 너무 멀어요"}
	if water == null or not water.inside(p.x, p.y, size + 1.2):
		return {"ok": false, "why": "세상 끝 벽에 너무 가까워요"}
	if water_at(p.x, p.y):
		return {"ok": false, "why": "물 위에는 놓을 수 없어요"}
	for a in 8:
		var q := p + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * (size + 0.4)
		if water_at(q.x, q.y):
			return {"ok": false, "why": "물가에 너무 붙었어요"}
	var lo := 1.0e9
	var hi := -1.0e9
	for a in 9:
		var q := p if a == 8 else p + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * size
		var g := water.ground(water.idx(q.x, q.y))
		lo = minf(lo, g)
		hi = maxf(hi, g)
	if hi - lo > KIT_STEEP:
		return {"ok": false, "why": "땅이 너무 기울었어요"}
	for r: Dictionary in rocks:
		if Vector2(r["x"] - p.x, r["y"] - p.y).length() < size + 0.8:
			return {"ok": false, "why": "바위가 있어요"}
	for o: Array in obstacles:
		if (o[0] as Vector2).distance_to(p) < float(o[1]) + size + 0.5:
			return {"ok": false, "why": "다른 것과 겹쳐요"}
	return {"ok": true, "why": ""}


## 키트 건물 하나를 거인이 고른 자리로 (건물 자리 = 시뮬레이션 자리 — 저장에 그대로)
func move_kit_building(b: Building, p: Vector2) -> void:
	b.x = p.x
	b.y = p.y
	_clear_trees(p, b.size())


## 모닥불(광장 한가운데)을 거인이 고른 자리로
func move_fire(p: Vector2) -> void:
	fire = p
	_clear_trees(p, 1.2)


## 다 놓았으면: 제단 자리를 새 배치에 맞게 다시 (모닥불 곁, 건물을 피해)
func finish_kit_layout() -> void:
	altar_pos = fire + ALTAR_OFFSET
	altar_pos = pick_altar_pos()
	_clear_trees(altar_pos, ALTAR_CLEAR)


func altar_spot_ok(p: Vector2) -> bool:
	if water == null or not water.inside(p.x, p.y, ALTAR_CLEAR + 0.5) or water_at(p.x, p.y):
		return false
	for b in buildings:
		if b.site_type() == Awakening.ALTAR:
			continue
		if Vector2(b.x, b.y).distance_to(p) < b.size() + ALTAR_CLEAR - 0.3:
			return false
	return true


# ───────────────────────── 기록 ─────────────────────────
## 발견 도감에 적는다 (sim/codex.gd) — 처음 한 번만: 누가 · 언제
func note_discovery(id: String, who: Resident) -> void:
	if discoveries.has(id):
		return
	discoveries[id] = {"t": t, "who": who.id if who != null else -1, "name": who.name if who != null else ""}


func log_line(text: String) -> void:
	emit(&"chronicle", {"v": WatcherName.fill(self, text)})     # {w} = 마을이 부르는 말 (STORY 4 · N2)


## 사건을 낸다 (ADR-0001 — 시뮬레이션의 출구). t·village는 이 마을 것으로 채움. 연대기·위기 kind는 여기서 바로 book·저장 순번에.
func emit(kind: StringName, data: Dictionary = {}) -> int:
	data["t"] = t
	data["village"] = sid
	if kind == &"chronicle":
		book.append({"t": t, "text": data["v"]})   # 사건 줄은 저장하지 않으므로 연대기는 곧바로 (옛 book 형식 그대로)
	if kind == &"chronicle" or kind == &"crisis":
		event_serial += 1
	return events.emit(kind, data)


## 거인의 행동이 끝났다 → 곧바로 저장 (여러 행동을 묶어 부르는 동안은 한 번만 — begin/end_giant)
func giant_acted() -> void:
	if _giant_depth == 0 and on_giant_action.is_valid():
		on_giant_action.call(self)


func begin_giant() -> void:
	_giant_depth += 1


func end_giant() -> void:
	_giant_depth = maxi(0, _giant_depth - 1)
	giant_acted()


## 위기 시작 (굶주림·재해) — 화면 쪽(JarClock)이 빨리 돌리기를 ×1로 되돌리고 알림을 띄운다
func crisis(kind: String, text: String) -> void:
	crises.append({"t": t, "kind": kind, "text": text})
	emit(&"crisis", {"v": kind})


func speak(r: Resident, text: String, dur := 6.0) -> void:
	r.say = WatcherName.fill(self, text)      # {w} = 마을이 부르는 말 (STORY 4 · N2)
	r.say_t = dur


static func josa(w: String, a: String, b: String) -> String:
	if w.is_empty():
		return b
	var c := w.unicode_at(w.length() - 1) - 0xAC00
	return a if (c >= 0 and c < 11172 and c % 28 != 0) else b


# ───────────────────────── 땅·물·기후 (JarWater) ─────────────────────────
func wetness(x: float, y: float) -> float:
	return clampf(0.12 + water.wet_k(water.idx(x, y)) * 0.9 - 0.1 * water.sun_at(x, y), 0.0, 1.0)


func salt_at(x: float, y: float) -> float:
	return water.salt_k(water.idx(x, y))


## 농사 효율 = 따뜻함 × 습기 ÷ (1 + 소금기) — 기획서 4.4, 프로토타입 farmMult
func farm_mult(x: float, y: float) -> float:
	var w := water.warm_at(x, y)
	var m := wetness(x, y)
	return clampf((0.6 + 0.6 * w) * (0.65 + 0.7 * m) / (1.0 + salt_at(x, y) * 300.0), 0.15, 1.5)


func water_at(x: float, y: float) -> bool:
	var k := water.idx(x, y)
	return water.is_lake(k) or water.is_river(k)


## 품을 수 있는 인구 = 영역 넓이 × 0.5 ÷ 1인당 땅 (기획서 3.1 · BALANCE v3-5)
func land_capacity() -> float:
	var r := territory_r()
	return PI * r * r * Balance.LAND_USABLE / Balance.LAND_PER_PERSON[mini(era, 3)]


## 부락 영역 반지름 = 시대별 지름 ÷ 2 (+ 국경 건물). 소형 병은 대지(반지름 R)보다 넓을 수 없다
func territory_r() -> float:
	if _tr_fix >= 0.0:
		return _tr_fix
	var d: float = Balance.TERRITORY_D[mini(era, 3)]
	var extra := 0.0
	for b in buildings:
		if b.built and Balance.BORDER_D.has(b.type):
			extra = maxf(extra, float(Balance.BORDER_D[b.type]))
	var r := (d + extra) * 0.5
	if not (water is WorldWater):
		r = minf(r, R)
	return r


## 영역 안인가 (반지름 size만큼 안쪽) — 다른 무리의 영역과는 겹치지 않는다
func in_territory(x: float, y: float, size := 0.0) -> bool:
	if Vector2(x - center.x, y - center.y).length() + size > territory_r():
		return false
	for o: Village in peers:
		if o != self and Vector2(x - o.center.x, y - o.center.y).length() < o.territory_r() + size:
			return false
	return true


## 영역이 얼마나 찼나 (인구 ÷ 품을 수 있는 인구)
func territory_full() -> float:
	var c := land_capacity()
	return people.size() / c if c > 0.0 else 1.0


# ───────────────────────── 식량 ─────────────────────────
func food_total() -> float:
	return Production.food_total(self)      # v5: 밀은 죽 값 (×0.75)으로 센다 (sim/production.gd)


func food_types() -> int:
	var n := 0
	for k in Balance.FOODS_ALL:
		if float(stock.get(k, 0.0)) >= 1.0:
			n += 1
	if Production.wheat_total(self) >= 1.0:
		n += 1                            # 죽
	if not manna_batches.is_empty() or not manna.is_empty():
		n += 1
	return n


## 식량을 먹는다. 남은 못 먹은 양을 돌려준다. 낟알(상하기 전) → 들판 낟알 → 건량 → 빵 → 밀(죽)
## 식량을 먹는 사람 수 (혈통 '소식' ×0.85 · '대식가' ×1.2 — 혈통이 없으면 인구 그대로)
func _food_people() -> float:
	var n := 0.0
	for p in people:
		n += p.f("food")
	return n


## 먹은 몫 (got) — production-chain R2-3 계약 (sim/production.gd)
func consume(need: float) -> float:
	return Production.consume(self, need)   # v5: 밀은 죽으로 끓여서만


## 옛 계약 (호환): 못 먹은 몫
func consume_unmet(need: float) -> float:
	return Production.consume_unmet(self, need)


## 하늘 낟알 — 도착 직후 1회, 첫 수확 전까지 매일 새벽 하루치 (기획서 8.4)
func manna_fall(reason: String) -> void:
	var amt := people.size() * DAY / Balance.FOOD_IV
	var s := store()
	for i in Balance.MANNA_PILES:
		var a := rng.randf() * TAU
		var d := 5.0 + rng.randf() * 9.0
		var x := s.x + cos(a) * d
		var y := s.y + sin(a) * d
		if water_at(x, y):
			x = s.x + cos(a) * 4.0
			y = s.y + sin(a) * 4.0
		manna.append({"x": x, "y": y, "amt": amt / Balance.MANNA_PILES, "born": t, "res": 0})
	manna_falls += 1
	bless_all(Balance.BELIEF_MANNA)
	var kids := people.filter(func(p: Resident) -> bool: return p.is_child() and not p.is_baby())
	var who: Resident = kids[rng.randi() % kids.size()] if not kids.is_empty() else people[rng.randi() % people.size()]
	emit(&"manna_fall", {"v": reason})    # 화면: 금빛 낟알이 하늘에서 쏟아짐 (view/manna_fx.gd)
	if not aware:                         # 아직 거인을 모른다 — '하늘이 주는 것' (OPENING 3.1 v3)
		speak(who, "하늘에서 뭐가 떨어졌어!", 8)
		for q in people:
			if q.is_adult() and not q.sleeping and q != who:
				speak(q, "하늘이 주는 거란다.", 8)
				break
		Awakening.witness(self, "manna")
		if reason == "arrival":
			log_line("굶주린 조상들 곁에 하늘에서 금빛 낟알이 내렸다. 사람들은 하늘이 주는 것이라 여겼다.")
		else:
			log_line("새벽, 들판에 하늘의 낟알이 금빛으로 깔렸다. 하늘이 또 주었다.")
	elif reason == "arrival":
		speak(who, "엄마, 하늘에서 뭐가 내렸어요!", 8)
		log_line("굶주린 조상들에게 {w:이/가} 하늘에서 낟알을 내렸다.")
	else:
		speak(who, "{w}의 낟알이다!", 6)
		log_line("새벽, 들판에 하늘의 낟알이 하얗게 깔렸다.")


func harvest_check(r: Resident) -> void:
	if first_harvest_t < 0.0:
		first_harvest_t = t
		log_line("%s%s 들에서 첫 곡식을 거두었다." % [r.name, josa(r.name, "이", "가")])
		speak(r, "첫 곡식이다!", 7)


# ───────────────────────── 메인 걸음 ─────────────────────────
## seconds만큼 시간을 흘린다 (step_dt 조각으로)
func advance(seconds: float) -> void:
	var left := seconds
	while left > 1e-6:
		var dt := minf(step_dt, left)
		left -= dt
		step(dt)


func step(dt: float) -> void:
	SimProf.begin()
	for p in people:              # 화면이 걸음 사이를 보간하도록 직전 위치
		p.px = p.x
		p.py = p.y
	t += dt
	SimProf.mark("misc")
	if owns_water:
		water.advance(dt)
	SimProf.mark("water")
	if not _arrival_manna and t >= Balance.MANNA_DELAY:
		_arrival_manna = true
		if auto_manna:
			manna_fall("arrival")
	# 새벽 (6시)
	var dawn_idx := floori((start_clock + t - Balance.DAWN_HOUR * HOUR) / DAY)
	if _last_dawn < 0:
		_last_dawn = floori((start_clock - Balance.DAWN_HOUR * HOUR) / DAY)
	if dawn_idx > _last_dawn:
		_last_dawn = dawn_idx
		_on_dawn()
	# 낟알 상함 (하루)
	if not manna.is_empty():
		for m: Dictionary in manna:
			if t - m["born"] >= Balance.MANNA_SPOIL:
				m["amt"] = 0.0
		manna = manna.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	if not manna_batches.is_empty():
		for m: Dictionary in manna_batches:
			if t - m["born"] >= Balance.MANNA_SPOIL:
				m["amt"] = 0.0
		manna_batches = manna_batches.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	# 식량 소비 (집계 — 1명당 15분에 1개)
	var fp := _food_people() + Dogs.food_people(self)     # [강아지] 사람 몫의 일부 (GD 3.0)
	_fp_val = fp                          # 이 걸음 동안 enough("밀")이 다시 세지 않게 (사람 수가 그대로일 때만)
	_fp_n = people.size()
	_fp_t = t
	var need := fp * dt / Balance.FOOD_IV
	var unmet := consume_unmet(need)
	deficit = unmet / need if need > 0.0 else 0.0
	Production.hunger_hint(self)          # v5: 빵을 굽기 전 배고프면 거인에게 안내
	if deficit > 0.0:
		if t - last_short_t > HOUR:
			crisis("hunger", "창고에 먹을 것이 떨어졌다")
		last_short_t = t
	for p in people:
		if deficit > 0.0:             # v5-0: 모자란 몫만큼 배고파지고 먹은 몫만큼 풀린다 — 반 넘게 모자라야 굶주림이 쌓임 (조금 모자란 날이 온 마을의 죽음이 되지 않게)
			p.hunger = clampf(p.hunger + (deficit - (1.0 - deficit) * Balance.HUNGER_EASE) * dt / Balance.FOOD_IV, 0.0, 4.0)
		else:
			p.hunger = maxf(0.0, p.hunger - dt / Balance.FOOD_IV)
		if p.hunger >= Balance.STARVING_AT:
			p.health -= dt / Balance.STARVE_HEALTH_TIME
			p.harm["굶주림"] = float(p.harm.get("굶주림", 0.0)) + dt / Balance.STARVE_HEALTH_TIME
			if p.is_child() and not p.stunted and p.genes.size() >= Genetics.GENE_BYTES:     # 어릴 때 굶주리면 키 −0.05 (겉모습만)
				p.stunted = true
				p.genes[Genetics.HEIGHT] = maxi(0, p.genes[Genetics.HEIGHT] - roundi(Genetics.STUNT * 255.0))
		elif p.health != 1.0 and Health.can_heal(p):         # 앓는 중·추위·더위 속에서는 저절로 낫지 않는다 (HEALTH.md 1.4 · 2). 다 나았으면 볼 것 없음 (같은 값)
			p.health = minf(1.0, p.health + dt * p.f("heal") / Balance.HEAL_TIME)
		p.age += dt / (DAY * Balance.age_k(p.age))    # 일생 날 하나 = 어린 시절 병 4일 · 어른·노인 병 12일 (2026-11-10 — Balance.AGE_K · AGE_K_ADULT)
		if p.say_t > 0.0:
			p.say_t -= dt
	SimProf.mark("food_people")
	Health.step(self, dt)
	SimProf.mark("health")
	VillageEra.decay(self, dt)        # 걸어 건넌 물 (나루터 조건 — A6)
	SimProf.mark("era_decay")
	air.step(self, dt)                # [곰팡이·뚜껑] 김·연기·공기 + 뚜껑, 곰팡이 무리 (WORLD_EVENTS 2.1 · 3)
	SimProf.mark("air")
	Mold.step(self, dt)
	SimProf.mark("mold")
	SmallCrises.step(self, dt)        # [작은 위기] 날벌레·떠돌이 물방울·먼지 뭉치 (WORLD_EVENTS 2.2)
	SimProf.mark("smallcrises")
	GiantHand.step(self, dt)          # [거인의 손] 쿨타임·감싼 온기·유리의 먼지막·커튼 냉해 (B6)
	SimProf.mark("hand")
	Flora.step(self, dt)              # [하늘의 것] 큰 버섯·큰 민들레·꽃씨 (WORLD_EVENTS 2.6 · 2.7)
	GiantPlants.step(self, dt)        # 해바라기 고개 돌림·씨앗비 (flower-forest R3 — 병 하나에 한 번, sim/giant_plants.gd)
	SimProf.mark("flora")
	Caterpillars.step(self, dt)       # 애벌레 → 고치 → 나비 · 꽃숲 피해 · 꿀방울 (production-chain R7)
	SimProf.mark("caterpillars")
	if owns_water:
		Wildlife.step(self, dt)       # [들짐승] 무리 수·늑대·토끼 밭 피해·상함·늑대 울음 (WILDLIFE 1~4 — 병 하나에 한 번)
	SimProf.mark("wildlife")
	Dogs.step(self, dt)               # [강아지] 따라다님·집 앞 잠·새끼·분양·짖음 (E3-13)
	SimProf.mark("dogs")
	SkyDrops.step(self, dt)           # [상점] 하늘에서 내려온 것·돌봄·앰플 탑·녹조·진열 (SHOP · WORLD_EVENTS 4)
	FoundObjects.step(self, dt)       # [떨어진 물건] 잔치 각설탕이 물 뿌림에 녹음 (E3-16)
	SimProf.mark("skydrops")
	for b in buildings:
		_update_building(b, dt)
	SimProf.mark("buildings")
	for p in people.duplicate():
		_walker = p
		ResidentAI.update(self, p, dt)
	_walker = null
	SimProf.mark("resident_ai")
	Social.step(self, dt)             # [마을의 삶] 쉬는 둘이 만나면 이야기·다툼·사랑 (sim/social.gd)
	ChildPlay.step(self, dt)          # [아이·아기] 술래잡기·나비 쫓기·돌탑, 요람 들여다보기, 첫걸음마 (sim/child_play.gd)
	if owns_water:
		Milestones.step(self, dt)    # [자람의 보상] 고비(첫 빵·식구·첫 겨울)·별명·저녁 잔치 — 병마다 한 번 (sim/milestones.gd)
	_update_trees(dt)
	SimProf.mark("trees")
	# 주기 처리
	for k in _timers:
		_timers[k] += dt
	if _timers["life"] >= Balance.LIFE_EVERY * tick_mult:
		life_events(_timers["life"])
		_timers["life"] = 0.0
		trees = trees.filter(func(tr: Dictionary) -> bool: return water.depth(water.idx(tr["x"], tr["y"])) < 0.03)   # 물에 잠긴 나무는 죽는다
		SimProf.mark("life")
	if _timers["jobs"] >= (Balance.JOBS_EVERY if tick_mult <= 1.0 else Balance.AWAY_JOBS_EVERY):
		SimProf.mark("misc")
		assign_jobs()
		SimProf.mark("jobs")
		assign_homes()
		SimProf.mark("homes")
		_timers["jobs"] = 0.0
	if _opening_chief < Balance.OPENING_CHIEF_AT.size() and t >= float(Balance.OPENING_CHIEF_AT[_opening_chief]):
		_opening_chief += 1
		if in_opening() and not chief_off:     # 첫 한 시간: 촌장이 15분을 기다리지 않고 곧바로 터를 잡는다 (OPENING 3.1 0:30)
			var before := buildings.size()
			chief_build()
			if buildings.size() > before:
				for p in people:              # 쉬던 어른들이 일어나 터로 (짐 나르기·짓기)
					if p.is_adult() and p.action == "idle":
						ResidentAI.cancel(self, p)
				if _opening_chief == 1 and chief() != null:
					speak(chief(), Balance.LINE_FIRST_SITE, 8)
	if _timers["chief"] >= Balance.CHIEF_EVERY:
		if not chief_off:             # 거인이 있든 없든 촌장이 짓는다 (기획서 6.7)
			SimProf.mark("misc")
			chief_build()
			SimProf.mark("chief")
		_timers["chief"] = 0.0
	if _timers["econ"] >= 60.0:       # 제물·소원 편지·분가 (1분마다 확인)
		SimProf.mark("misc")
		_economy_tick()
		SimProf.mark("econ")
		_timers["econ"] = 0.0
	if _timers["lake"] >= Balance.LAKE_EVERY:
		_timers["lake"] = 0.0
		SimProf.mark("misc")
		lake_watch()
		SimProf.mark("lake")
		salt_discovery()
		SimProf.mark("salt")
		Discovery.hourly(self)        # 발견 W2 · F3 · F5 · S3 · P1 (DISCOVERIES — sim/discovery.gd)
		FoundObjects.hourly(self)     # 떨어진 물건: 찾음 · 마을 쪽으로 옮겨 씀 · 각설탕 잔치 (E3-16 — sim/found_objects.gd)
		if owns_water:
			GreatTrees.hourly(self)   # 과일나무의 거대한 열매 (GD 3.0 — 병 하나에 한 번)
		GreatTrees.fetch(self)        # (E3-3) 닿는 곳의 열매를 여럿이 주우러 감
		GiantPlants.hourly(self)      # 해바라기 철·씨앗비 날·목화 (flower-forest R3·R4)
		LeanSeasons.hourly(self)      # 빠듯한 철이 오고 감을 알림 · 애벌레 떼 (BALANCE B-1)
		Kitchen.hourly(self)          # 우유·계란 없는 부엌 — 진딧물 목장·큰 알·씨앗 방앗간 (E3-14 — sim/kitchen.gd)
		CoreWarmth.hourly(self)       # [핵] 병의 따뜻함 — 땅 흔들림 · 처음 보인 차이의 수첩 한 줄 (A28b, 보통 별은 아무것도 안 함)
		ToolShort.hourly(self)        # (Q25) 연장이 모자람 — 신호 사건 · 촌장의 편지 (난수 · 경제 그대로)
		StoneShort.hourly(self)       # (Q30) 돌이 모자람 — 신호 사건 · 촌장의 편지 (연장 편지 다음 · 같은 날엔 하나만)
	SimProf.mark("discovery")
	if _timers["decay"] >= HOUR:      # 오솔길은 다니지 않으면 옅어진다 (1분에 ×0.997)
		var f := pow(0.997, _timers["decay"] / 60.0)
		var pp := paths
		if not _pnz_ok:
			_path_rebuild_nz()
		for i in _pnz:                # 한 번이라도 밟힌 칸만 (나머지는 0 — 같은 결과)
			if pp[i] > 0.0:
				pp[i] *= f
		_timers["decay"] = 0.0
	SimProf.mark("path_decay")
	if _timers["speak"] >= Balance.SPEAK_EVERY:
		idle_chatter()
		_timers["speak"] = 0.0
	SimProf.mark("chatter")
	Awakening.step(self, dt)
	SimProf.mark("awakening")
	_update_era(dt)
	SimProf.mark("era")
	_update_belief(dt)
	SimProf.mark("belief")
	_fp_t = -1.0
	for o: Village in others:        # 같은 세상의 다른 무리 (물은 이 마을이 이미 흘렸다)
		o.step(dt)


## 나무: 묘목은 자라 나무가 되고, 그루터기는 다시 자라지 않고 썩어 사라진다. 숲 곁 빈 땅에는 가끔 묘목이 저절로 돋는다
func _update_trees(dt: float) -> void:
	var rotted := false
	var gdt := dt * GiantHand.grow_mult(self) * CoreWarmth.flower(self)     # [거인의 손] 묘목은 볕을 따라 자람 (커튼·유리 — 그루터기가 썩는 것은 그대로) · [핵] 꽃 자람 (A28b)
	for tr: Dictionary in trees:
		if tr["s"] == "tree":
			continue
		tr["g"] -= gdt if tr["s"] == "sapling" else dt
		if tr["g"] <= 0.0:
			if tr["s"] == "sapling":
				tr["s"] = "tree"
			elif int(tr["res"]) == 0:
				tr["s"] = "gone"
				rotted = true
	if rotted:
		trees = trees.filter(func(tr: Dictionary) -> bool: return tr["s"] != "gone")
	_spread_left -= dt
	if _spread_left <= 0.0:
		_spread_left += HOUR
		_tree_spread()


## 숲이 저절로 퍼진다 (드물게 — 마을 하나에 하루 평균 TREE_SPREAD_PER_DAY, 촉촉한 땅일수록 잘 붙음). 한 시간에 한 번 굴림
func _tree_spread() -> void:
	if trees.is_empty():
		return
	var tr: Dictionary = trees[rng.randi() % trees.size()]
	if tr["s"] != "tree":
		return
	var a := rng.randf() * TAU
	var d := rng.randf_range(Balance.TREE_SPREAD_DIST[0], Balance.TREE_SPREAD_DIST[1])
	var x := float(tr["x"]) + cos(a) * d
	var y := float(tr["y"]) + sin(a) * d
	var p_take := Balance.TREE_SPREAD_PER_DAY / 24.0 * (0.4 + wetness(x, y)) / 0.7 * Discovery.plant_mult(self) * CoreWarmth.flower(self)   # 발견 F3 씨앗을 심다 ×2 · [핵] 꽃 퍼짐 (A28b)
	if rng.randf() >= p_take:
		return
	if not water.inside(x, y, 1.5) or water.depth(water.idx(x, y)) >= 0.005 or water_at(x, y) or is_road(x, y) or path_at(x, y) > 0.0:
		return
	for b in buildings:
		if Vector2(b.x - x, b.y - y).length() < b.size() + 0.8:
			return
	if Vector2(fire.x - x, fire.y - y).length() < 3.0 or Vector2(altar_pos.x - x, altar_pos.y - y).length() < ALTAR_CLEAR:
		return
	for r: Dictionary in rocks:
		if Vector2(r["x"] - x, r["y"] - y).length() < 1.0:
			return
	for q: Dictionary in trees:
		if Vector2(float(q["x"]) - x, float(q["y"]) - y).length() < 1.0:
			return
	if GreatTrees.blocks(water, x, y, 0.0) or GiantPlants.blocks(water, x, y, 0.0):
		return
	trees.append({"x": x, "y": y, "s": "sapling", "g": Balance.SAPLING_GROW, "res": 0})


func _on_dawn() -> void:
	if first_harvest_t < 0.0:
		if auto_manna:
			manna_fall("dawn")
	elif not manna_ended:
		manna_ended = true
		festival_t = t
		if manna_falls > 0:
			log_line("들에서 첫 곡식을 거둔 다음 날, 하늘의 낟알이 그쳤다. 이제 우리는 우리 손으로 먹고산다.")
		else:
			log_line("들에서 첫 곡식을 거두었다. 이제 우리는 우리 손으로 먹고산다.")
		log_line("첫 수확 축제가 열렸다. 모두 모닥불 둘레에서 밤늦게까지 춤을 추었다.")
	# 일한 날 → 숙련 (기획서 11장: 하루 0.6 × 재주, 최대 10)
	for p in people:
		if p.work_secs_today >= Balance.WORKED_DAY_SECS and p.is_adult():
			var key := "일꾼"
			var jb := bld(p.job)
			if jb != null:
				key = jb.type
			p.skills[key] = minf(Balance.SKILL_MAX, float(p.skills.get(key, 0.0)) + Balance.SKILL_RATE * p.talent * p.f("skill_growth") * Discovery.skill_mult(self))     # 발견 P1 글 ×1.2
		p.work_secs_today = 0.0
	VillageEra.dawn(self)                 # 광장 장날 (A6)
	Production.spoil(self)                # v5: 밀은 쥐·눅눅함으로 조금씩 상하고 빵은 오래 간다
	_update_happiness()


func _update_era(dt: float) -> void:
	if era >= Balance.ERA_NEED.size():
		return
	var built_n := 0
	for b in buildings:
		if b.built:
			built_n += 1
	var rate: float = (people.size() * Balance.ERA_POP + built_n * Balance.ERA_BUILDING) * Balance.ERA_MULT[era]
	rate *= era_watch_k(dt)
	era_pts = minf(Balance.ERA_NEED[era], era_pts + rate * dt / HOUR)
	if era_pts < Balance.ERA_NEED[era]:
		return
	if auto_reveal and is_watching():
		reveal()
		return
	if revelation.is_empty():
		_revelation_notice()
	elif is_watching() and t >= _rev_say_t:
		_revelation_murmur()


## 시대 점수의 지켜봄 배율 (BALANCE v2: 지켜봄 1 / 0.3). 100%는 병의 하루에 Balance.ERA_WATCH_HOURS 병 시간까지만 —
## 밸런스 모델(sim_life.py)은 거인이 하루 2시간 지켜본다고 보고 '마을 1.8일'을 냈다. 빨리 돌리며 내내 지켜보면
## (창세의 날 ×12 · 배속) 하루 24시간이 다 100%가 되어 반나절 만에 마을이 됐다 → 지켜봄 몫을 병 시간으로 하루 2시간까지.
## dt만큼을 쓴다 (호출할 때마다 그날 몫이 준다). 반환 = 이 dt의 평균 배율
func era_watch_k(dt: float) -> float:
	if not is_watching():
		return Balance.OFFLINE_ERA
	var day_i := floori((start_clock + t) / DAY)
	if day_i != era_watch_day:
		era_watch_day = day_i
		era_watch_secs = 0.0
	var left := maxf(0.0, Balance.ERA_WATCH_HOURS * HOUR - era_watch_secs)
	if dt <= 0.0:
		return 1.0 if left > 0.0 else Balance.OFFLINE_ERA
	var full := minf(dt, left)
	era_watch_secs += full
	return (full + (dt - full) * Balance.OFFLINE_ERA) / dt


## 시대 점수가 다 찼다 (계시를 기다림)
func era_full() -> bool:
	return era < Balance.ERA_NEED.size() and era_pts >= Balance.ERA_NEED[era]


## 계시를 기다리는가 (제단 시트 맨 위 [계시] · 아래 띠 제단 버튼의 빛)
func revelation_pending() -> bool:
	return not revelation.is_empty() and era_full()


## 이 시대에 새로 열리는 건물 (Balance.B의 era가 e인 것)
## 계시가 시대 e를 열 때 주민이 새로 알게 되는 건물 — 그 시대 기본 + 앞 시대에 새로 배워야 했던 것 (Balance.MUST_LEARN — 다음 계시가 가르침).
## 그 시대의 새로 배워야 하는 건물은 빠진다 (설계도로 먼저 · 다음 계시에)
static func era_unlocks(e: int) -> PackedStringArray:
	var out := PackedStringArray()
	for ty: String in Balance.B:
		var be := int(Balance.B[ty].get("era", 0))
		if ty in Balance.KNOWN_FROM_START:
			continue
		if (be == e and not ty in Balance.MUST_LEARN) or (be == e - 1 and ty in Balance.MUST_LEARN):
			out.append(ty)
	return out


## 노인들이 하늘을 올려다본다 — 편지 한 장 + 연대기 한 줄 (거인이 없어도: 돌아오면 편지가 기다린다. 계시는 거인만 — GD 14).
## 난수를 쓰지 않는다 (다른 흐름을 흔들지 않게)
func _revelation_notice() -> void:
	var seers := _sky_watchers()
	var who: Resident = seers[0] if not seers.is_empty() else chief()
	revelation = {"t": t, "from": who.id if who != null else -1, "name": who.name if who != null else "",
		"text": "하늘이 무언가를 알려 주실 것 같아요. 노인들이 자꾸 하늘을 올려다봐요."}
	log_line("노인들이 자꾸 하늘을 올려다보았다. {w:이/가} 무언가를 알려 주실 것만 같았다.")
	_revelation_murmur()


## 기다리는 동안 가끔 (깨어 있는 노인 한둘이 하늘을 보며)
func _revelation_murmur() -> void:
	_rev_say_t = t + Balance.REV_MURMUR
	if not is_watching():
		return
	var lines := ["하늘이 무언가를 알려 주실 것 같아요", "하늘을 보게. 무언가 다가오고 있어", "{w:이/가} 곧 무언가 보여 주실 게야"]
	var seers := _sky_watchers()
	for i in mini(2, seers.size()):
		var r: Resident = seers[i]
		if not r.sleeping:
			speak(r, lines[(int(t / HOUR) + i) % lines.size()], 7)


## 하늘을 보는 사람: 노인부터 (나이 많은 순), 없으면 나이 많은 어른 — 아기·앓는 사람 빼고
func _sky_watchers() -> Array[Resident]:
	var out: Array[Resident] = []
	for r in people:
		if not r.is_baby() and r.sick_left <= 0.0 and r.age >= Balance.AGE_ADULT:
			out.append(r)
	out.sort_custom(func(a: Resident, b: Resident) -> bool: return a.age > b.age if a.age != b.age else a.id < b.id)
	var elders: Array[Resident] = []
	for r in out:
		if r.is_elder():
			elders.append(r)
	var pick := elders if not elders.is_empty() else out
	return pick.slice(0, 3)


## 거인의 계시 — 시대 점수가 다 찼을 때만 (6.3). line이 비면 예전 한 줄
func reveal(line := "") -> bool:
	if not era_full():
		return false
	era += 1
	era_t = t
	era_pts = 0.0
	revelation = {}
	bless_all(0.15)
	log_line(line if line != "" else "{w}의 계시가 내렸다. 우리는 '%s'%s 되었다." % [Balance.ERAS[era], josa(Balance.ERAS[era], "이", "가")])
	return true


## 거인이 [계시]를 누름 (A5): 연대기 "거인이 새 시대를 열었다 — 마을" · 광장 축제 · 깨어 있는 사람은 그 자리에서 무릎 꿇고 하늘을 봄 →
## 시대가 오른다 (촌장이 새 집 양식·새 건물을 짓기 시작). 거인이 보고 있을 때만 — 비운 동안엔 저절로 오지 않는다 (GD 14)
func giant_reveal() -> bool:
	if not era_full() or not is_watching():
		return false
	begin_giant()
	var nx: String = Balance.ERAS[era + 1]
	var un := Array(era_unlocks(era + 1)).filter(func(ty: String) -> bool: return not Production.knows(self, ty))   # 이미 아는 것 (설계도 · 스스로 깨침)은 빼고
	log_line("{w:이/가} 새 시대를 열었다 — %s" % nx)
	reveal("하늘에서 한 줄기 빛이 광장으로 내려왔다. 사람들은 무릎을 꿇고 하늘을 올려다보았다. 이제 우리는 '%s'%s." % [nx, josa(nx, "이다", "다")])
	festival_t = t
	var spoke := 0
	for r in people:
		if r.sleeping or r.is_baby() or r.sick_left > 0.0:
			continue
		r.steps.push_front(ResidentAI.act(Balance.REV_KNEEL, "pray"))
		if spoke < 3 and r.age >= 2.5:
			speak(r, ["빛이다…!", "{w:이/가} 길을 여셨다", "새 시대가 왔어!"][spoke], 8)
			spoke += 1
	if not un.is_empty():
		log_line("이제 %s%s 지을 수 있게 되었다." % ["·".join(un.slice(0, 6).map(Balance.label)), josa(Balance.label(un[mini(5, un.size() - 1)]), "을", "를")])
	end_giant()
	return true


func _update_belief(dt: float) -> void:
	if not aware:                         # 거인을 모르면 믿음도 없다 (6.5)
		for p in people:
			p.belief = 0.0
		faith = 0.0
		return
	var w := is_watching()
	var sum := 0.0
	for p in people:
		if w:
			p.belief += dt * p.f("belief_up") / (DAY * Balance.BELIEF_UP_DAYS)
		else:
			p.belief -= dt * p.f("belief_down") / (DAY * (Balance.BELIEF_DOWN_CHILD_DAYS if p.is_child() else Balance.BELIEF_DOWN_ADULT_DAYS))
		p.belief = clampf(p.belief, 0.0, 1.0)
		sum += p.belief
	faith = sum / people.size() * 100.0 if not people.is_empty() else 0.0
	# 부락의 두려움(0~100) = 주민 두려움 평균 × 100 — sim/health.gd가 사람마다 내린다 (HEALTH.md 4)


## 믿음을 모두에게 — 깨닫기 전엔 아무 일 없음 (design/gdd/giant-touch.md R5 · 사용자 결정 ⑤: 깨닫기 전 손짓은 경이만)
func bless_all(d: float) -> void:
	if not aware:
		return
	for p in people:
		p.belief = minf(1.0, p.belief + d)


## 부락의 신앙 상태 (RESIDENT_AI 2.3)
func faith_state() -> String:
	if not aware:
		return ""
	if fear >= 50.0:
		return "경외" if faith >= 60.0 else "공포"
	if faith >= 60.0:
		return "경건"
	if faith < 30.0:
		return "무관심"
	return ""


func doubters() -> int:
	var n := 0
	for p in people:
		if p.belief < Balance.DOUBT_BELOW and p.age >= 2.5:
			n += 1
	return n


func _update_happiness() -> void:
	var variety := food_types() >= 3
	var fest := t - festival_t < Balance.FESTIVAL_DAYS * DAY or VillageEra.wedding_on(self)
	var tea := flora != null and flora.tea_on(self)
	var pz := VillageEra.first_built(self, "광장")        # 반경 행복 (A6 — BUILDINGS 6)
	var gyd := VillageEra.first_built(self, "묘지")
	var gm := Balance.GRIEF_GRAVE if gyd != null else 1.0
	var cheer := {}               # 집 → 그 집 '명랑' 식구 몫의 합
	for p in people:
		var hh := p.f("house_happy", 0.0)
		if hh != 0.0 and p.home >= 0:
			cheer[p.home] = float(cheer.get(p.home, 0.0)) + hh
	for p in people:
		var h := Balance.HAPPY_BASE
		h += Balance.HAPPY_HOME if p.home >= 0 else Balance.HAPPY_NO_HOME
		if variety:
			h += Balance.HAPPY_VARIETY
		if p.hunger > 0.5:
			h += Balance.HAPPY_HUNGRY
		if fest:
			h += Balance.HAPPY_FESTIVAL * _festival_mult * p.f("festival")
		if t < p.grief_until:
			h += Balance.HAPPY_GRIEF * gm                 # 묘지가 있으면 슬픔이 덜하다
		if pz != null or gyd != null:
			h += VillageEra.place_happy(self, p, pz, gyd)
		h += p.f("happiness", 0.0)
		h += Production.food_happy(self)                  # v5: 빵을 먹은 날 + · 죽만 먹은 날 −
		if tea:
			h += Balance.TEA_HAPPY                        # [하늘의 것] 민들레 꽃차 (WORLD_EVENTS 2.7)
		h += Wildlife.happy(self, p)                      # [들짐승] 물가에서 낚싯대를 드리운 날 (WILDLIFE 2)
		h += FoundObjects.happy(self, p)                  # [떨어진 물건] 잔치 각설탕이 있는 동안 아이들 (E3-16)
		h += Immigrants.mood(self)                        # [이주민] 축제처럼 맞이 ↑ · 경계 ↓ (기획서 11.2 — 하루 동안)
		h += Balance.FEAR_HAPPY * p.fear                  # 행복 −0.1 × 두려움 (HEALTH.md 4)
		if p.home >= 0 and not cheer.is_empty():
			h += float(cheer.get(p.home, 0.0)) - p.f("house_happy", 0.0)      # 같은 집 식구의 '명랑' (자기 몫은 빼고)
		p.happiness = clampf(h, 0.0, 1.0)


func avg_happiness() -> float:
	if people.is_empty():
		return 0.0
	var s := 0.0
	for p in people:
		s += p.happiness
	return s / people.size()


## 출산 환경 배율 = 식량 × 행복 × 축제 (기획서 7.3 — 이 셋만)
func birth_env() -> float:
	var f: float = Balance.ENV_FOOD[1]
	if t - last_short_t < Balance.STARVED_RECENT:
		f = Balance.ENV_FOOD[0]
	elif food_types() >= 3:
		f = Balance.ENV_FOOD[2]
	var hp := avg_happiness()
	var h: float = Balance.ENV_HAPPY[0] if hp < Balance.HAPPY_LOW else (Balance.ENV_HAPPY[2] if hp > Balance.HAPPY_HIGH else Balance.ENV_HAPPY[1])
	var fe := Balance.ENV_FESTIVAL if t - festival_t < Balance.FESTIVAL_DAYS * DAY else 1.0
	return f * h * fe


# ───────────────────────── 건물 ─────────────────────────
func _update_building(b: Building, dt: float) -> void:
	if not b.built:
		return
	if b.type == "농장" and b.ready_at < 0.0:
		b.ready_at = t + Balance.GROW_FIRST
	var d := b.def()
	var chain: bool = d.get("job", false) and d.has("out") and not d.get("gather", false) and b.upgrade_to == ""   # 막힘 판정 대상 (production-chain States)
	if b.worker < 0:
		if chain:
			Production.stall_tick(self, b, &"no_worker")
		return                        # 일꾼이 없으면 아래에서도 그냥 돌아간다 (빠른 길)
	# 생산·가공: 일꾼이 배정돼 있으면 밤에도 돌아간다 (RESIDENT_AI 9장). 채집형만 일꾼이 직접 걸어가서 일함
	if not d.get("job", false) or not d.has("out") or d.get("gather", false) or b.worker < 0:
		return
	var w := person(b.worker)
	if w != null and w.sick_left > 0.0:
		if chain:
			Production.stall_tick(self, b, &"no_worker")
		return                        # 일꾼이 앓아누우면 일터가 쉰다 (HEALTH.md 2)
	if b.type == "소금밭":
		_update_salt_works(b, dt, w)
		return
	if b.type == "농장" and t < b.ready_at:
		return
	var outs: Dictionary = d["out"]
	var all_full := true
	var waiting := float(b.out.get("밀", 0.0))
	if b.type == "농장":                # (걸음 다시 2026-11-07) 밭이 여럿이면 다른 밭 앞에서 나르기를 기다리는 밀도 센다
		for o in buildings:
			if o != b and o.type == "농장":
				waiting += float(o.out.get("밀", 0.0))
	for k in outs:
		if not (float(stock.get(k, 0.0)) + (waiting if k == "밀" else float(b.out.get(k, 0.0))) >= enough(k)):     # 좋아하시는 물건은 더 (×1.5) · 밀도 넉넉하면 멈춤 (BALANCE v4-4)
			all_full = false
			break
	if all_full:
		if chain:
			Production.stall_tick(self, b, &"")     # 넉넉해서 쉼은 막힘이 아니다
		return
	var ins: Dictionary = d.get("in", {})
	if not _inputs_ready(b, ins):
		if chain:
			Production.stall_tick(self, b, &"no_input")
		return
	if chain:
		Production.stall_tick(self, b, &"")
	var place := 1.0
	if b.type == "농장":
		if b.farm_mult < 0.0:
			b.farm_mult = farm_mult(b.x, b.y)
		place = b.farm_mult * Flora.weed_mult(self, b)     # [하늘의 것] 밭에 내려앉은 꽃씨 = 잡초 ×0.8 (WORLD_EVENTS 2.7)
		place *= SkyDrops.fert_mult(self, b.x, b.y)       # [상점] 앰플 탑 둘레 비옥한 땅 ×1.5 (WORLD_EVENTS 4.4)
		place *= Wildlife.field_mult(self, b)             # [들짐승] 토끼가 넘치면 밭 −10~−30% (울타리 ×0.3 — WILDLIFE 3)
		place *= SmallCrises.farm_mult(self, b)          # [작은 위기] 먼지 뭉치가 덮은 밭은 자람이 멈춤 (WORLD_EVENTS 2.2)
		place *= GiantHand.farm_mult(self, b)            # [거인의 손] 커튼·유리의 먼지막·물을 반긴 마른 밭·냉해 (GD 6.4 · WE 4.2)
		place *= Health.season_grow(self)                # [철] 추운 철엔 밀이 더디 자람 (BALANCE v5-0 — 겨울의 빠듯함)
		place *= LeanSeasons.farm_mult(self)             # [빠듯한 철] 푸른 밀 고개·애벌레 많은 해 (BALANCE B-1)
		place *= CoreWarmth.farm_mult(self, b)           # [핵] 병의 따뜻함 — 밀 자람 · 이슬 · 마른 철 (A28b, 보통 별은 1)
	if (b.type == "빵집" or b.type == "화덕") and mold.koji_tamed:     # [곰팡이·뚜껑] 길들인 누룩곰팡이 → 빵 ×1.3 (WORLD_EVENTS 2.1)
		place *= Balance.KOJI_BREAD
	if b.type == "빵집" or b.type == "화덕":
		place *= Discovery.bread_mult(self)          # 발견 F5 효모 — 부푼 빵 ×1.2 (DISCOVERIES 3.3)
	b.timer += dt * (w.job_speed(b.type) if w != null else 1.0) * place * _singer_aura(b, w)
	var cyc: float = d["cycle"]
	while b.timer >= cyc:
		b.timer -= cyc
		if not _inputs_ready(b, ins):
			b.timer = 0.0
			break
		for k in ins:
			b.in_buf[k] = float(b.in_buf[k]) - float(ins[k])
			if b.gift_in.has(k):                       # v5: 거인이 준 재료로 만든 몫은 가공품도 거인 몫 (제물로 안 나감)
				var gu := minf(float(b.gift_in[k]), float(ins[k]))
				b.gift_in[k] = float(b.gift_in[k]) - gu
				if float(b.gift_in[k]) <= 1e-6:
					b.gift_in.erase(k)
				for ko in outs:
					Production.gift_add(self, ko, gu * float(outs[ko]) / float(ins[k]))
		for k in outs:
			b.out[k] = float(b.out.get(k, 0.0)) + float(outs[k])
		Production.first_made(self, b, w)            # first_harvest · first_flour · first_bread 사건 (한 번씩)
		if b.type == "농장" and w != null:
			harvest_check(w)
		if b.type == "빵집" or b.type == "화덕":
			Discovery.on_bake(self)
			Kitchen.on_bake(self, b, w)               # 씨앗 반죽 빵 +5% · 단물·씨앗 우유·기름 = 좋은 빵 (E3-14)
			if int(stats.get("first_bread", 0)) == 0:
				stats["first_bread"] = 1
				log_line("공용 화덕에서 처음으로 빵이 구워졌다. 고소한 냄새에 온 마을이 모여들었다.")                 # F5 효모: 첫 빵의 시각


## '노래꾼'이 근처에서 일하고 있으면 그 일터 +3% (자기 일터 포함, 본인 제외)
func _singer_aura(b: Building, w: Resident) -> float:
	if _singers.is_empty():
		return 1.0
	for s: Resident in _singers:
		if s != w and not s.dead and s.action == "work" and Vector2(s.x - b.x, s.y - b.y).length() < Bloodlines.SINGER_RANGE:
			return 1.0 + s.f("work_aura", 0.0)
	return 1.0


func _inputs_ready(b: Building, ins: Dictionary) -> bool:
	for k in ins:
		if float(b.in_buf.get(k, 0.0)) < float(ins[k]):
			return false
	return true


func _update_salt_works(b: Building, dt: float, w: Resident) -> void:
	if float(stock["소금"]) + float(b.out.get("소금", 0.0)) >= Balance.ENOUGH["소금"]:
		return
	b.timer += dt
	if b.timer < float(b.def()["cycle"]):
		return
	b.timer = 0.0
	var got := 0.0
	for k in water.cells_near(Vector2(b.x, b.y), 3.5):
		if got >= 0.0005:
			break
		if water.depth(k) < 0.004 and water.salt_k(k) > 0.0004:
			var tk := minf(water.salt_k(k), 0.0005 - got)
			water.take_salt(k, tk)
			got += tk
	if got >= 0.00045:
		b.out["소금"] = float(b.out.get("소금", 0.0)) + 1.0
		if stats.get("first_salt", 0) == 0:
			stats["first_salt"] = 1
			var nm := w.name if w != null else "누군가"
			log_line("%s%s 마른 호수 바닥에서 흰 소금을 긁어 모았다. 소금에 절인 생선은 겨울을 난다." % [nm, josa(nm, "이", "가")])


func on_built(b: Building) -> void:
	stats["built"] += 1

	reveal_building(b)
	b.built_t = t
	if b.upgrade_to != "":
		var was := b.label()
		var house := b.is_house()
		b.type = b.upgrade_to
		b.upgrade_to = ""
		b.timer = 0.0
		stats["upgrades"] += 1
		if house:
			log_line("작은 옛 집을 %s%s 넓혀 지었다." % [b.label(), josa(b.label(), "으로", "로")])
		else:
			log_line("%s%s %s%s 넓혀 지었다." % [was, josa(was, "을", "를"), b.label(), josa(b.label(), "으로", "로")])
		return
	b.built = true
	if b.type == Awakening.ALTAR:          # 깨달음 뒤 주민이 지은 제단 → 첫 기도 (A4b)
		Awakening.on_altar_built(self, b)
		return
	if b.type == "농장":
		b.ready_at = t + Balance.GROW_FIRST
		log_line("밭을 갈았다. 첫 곡식이 여물려면 반나절은 걸리겠지.")
	elif b.is_house():
		log_line("%s 한 채가 다 지어졌다. 이제 한 가족이 지붕 아래에서 잔다." % b.label())
	elif b.wished:
		log_line("소원을 빌었던 %s%s 다 지어졌다. 사람들은 {w:이/가} 들어주셨다며 기뻐했다." % [b.label(), josa(b.label(), "이", "가")])
	else:
		log_line("%s%s 다 지어졌다." % [b.label(), josa(b.label(), "이", "가")])
	VillageEra.on_built(self, b)          # 망루 안개·세상 끝 · 묘지·교회·광장·나루터 한 줄 (A6)
	if in_opening() or (int(stats.get("thanks", 0)) == 0 and t < Balance.THANKS_END and not chief_off and b.type != Awakening.ALTAR):     # (A28) 첫 한 시간 뒤에 선 첫 건물도
		thanksgiving(b)
	if b.is_house() and not chief_off and Balance.FIRST_BIRTH_GUARANTEE and int(stats.get("born", 0)) == 0 and t >= Balance.FIRST_BIRTH_AT and t < 2.0 * DAY:
		_births(0.0)      # (2026-11-09 1.2) 첫 아기 보장: 새 집이 서는 그 순간 아이 낳을 가족이 먼저 들어간다 — 집 배정(20초마다)이 먼저 돌면
		#                   혼자 사는 어른이 빈자리를 채워 첫 아기가 하루를 넘기던 차례 경쟁 (첫 오두막 완공 시각이 자리에 따라 몇 분 달라지면 갈림)


# ───────────────────────── 일자리·집 ─────────────────────────
## 일자리 배정 (20초마다). 바꿀 것이 없으면 (일하는 아이 없음 · 빈 일터에 들어갈 사람이나 도구 없음 · 떠난 일꾼 없음) 바로 돌아간다 — 같은 결과
func assign_jobs() -> void:
	var free_adult := false
	var free_well := false                # (Q7-c) … 그 가운데 앓지 않는 사람이 있는가 — 앓는 밭지기·맷돌지기·화덕지기의 자리를 맡을 사람
	var baby_homes := {}                  # v5: 걸음마 전 아기가 있는 집 (돌보는 부모는 일터를 내놓는다)
	for q in people:
		if q.age < Balance.CARE_DAYS and q.home >= 0:
			baby_homes[q.home] = true
	for p in people:
		if p.job >= 0:
			if not p.is_adult():
				_assign_jobs()
				return
			if baby_homes.has(p.home) and Production.caring_for(self, p) != null:
				_assign_jobs()
				return
		elif p.is_adult() and (not free_adult or (not free_well and p.sick_left <= 0.0)) and (not baby_homes.has(p.home) or Production.caring_for(self, p) == null):
			free_adult = true             # 일터에 넣을 수 있는 사람 (_assign_jobs의 후보 — 아기를 돌보는 사람은 빼고)
			if p.sick_left <= 0.0:
				free_well = true
	var tools := float(stock["도구"]) >= 1.0     # 도구가 없으면 빈 일터에 아무도 넣지 못한다 (_assign_jobs가 건너뜀) — 헛돌지 않게 (따라잡기 속도)
	var swap := -1                         # 옮겨 올 일꾼이 있는가 (_job_swap — 한 번만 셈): -1 모름 · 0 없음 · 1 있음
	for b in buildings:
		if not b.built:
			continue
		if b.worker >= 0:
			var bw := person(b.worker)
			if bw == null and b.def().get("job", false):
				_assign_jobs()
				return
			if b.type == "채석장" and quarry_no_rock(b):     # (Q12) 다 캔 채석장 — 석수가 일터를 내려놓는다
				_assign_jobs()
				return
			if Balance.JOB_STAND_IN and free_well and bw != null and bw.sick_left > 0.0 and int(Balance.JOB_FIRST.get(b.type, 50)) < 10:     # (Q7-c) 먹을 것 일터의 일꾼이 앓아누웠고 맡을 사람이 있다
				_assign_jobs()
				return
		elif tools and b.def().get("job", false) and not (b.type == "채석장" and quarry_no_rock(b)):     # (Q12) 캘 바위가 없는 채석장에는 사람을 넣지 않는다 (헛돌지 않게 여기서도 뺀다)
			if free_well if (Balance.JOB_STAND_IN and int(Balance.JOB_FIRST.get(b.type, 50)) < 10) else free_adult:     # (Q7-c) 먹을 것 일터에는 앓는 사람을 넣지 않는다
				_assign_jobs()
				return
			if int(Balance.JOB_FIRST.get(b.type, 50)) < 10:     # v5: 먹을 것 일터가 비면 사람을 옮겨서라도 (_job_swap) — 옮겨 올 사람이 있을 때만
				if swap < 0:
					swap = 1 if _job_swap_from() != null else 0
				if swap == 1:
					_assign_jobs()
					return


func _assign_jobs() -> void:
	for p in people:
		if p.job >= 0 and p.is_adult() and Production.caring_for(self, p) != null:     # v5 (GD 7.3): 아기를 돌보는 동안 일터는 다른 사람에게
			var cb := bld(p.job)
			if cb != null:
				cb.worker = -1
			p.job = -1
			stock["도구"] = float(stock["도구"]) + 1.0
			continue
		if p.job >= 0 and not p.is_adult():
			var b := bld(p.job)
			if b != null:
				b.worker = -1
			p.job = -1
			stock["도구"] = float(stock["도구"]) + 1.0     # 일을 내려놓으면 도구는 창고로 (정함 — 도구 닳음은 아직 없음)
			if p.is_elder():
				log_line("%s%s 늙어서 일을 내려놓았다." % [p.name, josa(p.name, "은", "는")])
	if Balance.JOB_STAND_IN:
		_hand_over_sick()
	_leave_spent_quarries()
	var order := buildings.duplicate()      # v5: 먹을 것 일터부터 사람을 넣는다 (밭 → 화덕 → 맷돌 → …) — 일손이 모자라면 빵 사슬이 비지 않게
	order.sort_custom(func(a: Building, c: Building) -> bool:
		var pa := int(Balance.JOB_FIRST.get(a.type, 50))
		var pc := int(Balance.JOB_FIRST.get(c.type, 50))
		return pa < pc if pa != pc else a.id < c.id)
	for b: Building in order:
		if not b.built or not b.def().get("job", false):
			continue
		if b.worker >= 0 and person(b.worker) == null:
			b.worker = -1
		if b.worker >= 0:
			continue
		if float(stock["도구"]) < 1.0:
			continue
		if b.type == "채석장" and quarry_no_rock(b):     # (Q12) 둘레에 캘 바위가 없는 채석장은 비워 둔다 — 거인의 자갈(회색 돌멩이)이 닿는 곳에 떨어지면 다시 사람이 선다
			continue
		# 후보 점수 = 해당 숙련 × 2 − 거리 (RESIDENT_AI 5.1, 특징·현재 직업 숙련은 아직 없음)
		var best: Resident = null
		var bs := -1.0e9
		var food_job := Balance.JOB_STAND_IN and int(Balance.JOB_FIRST.get(b.type, 50)) < 10
		for p in people:
			if not p.is_adult() or p.job >= 0 or Production.caring_for(self, p) != null:
				continue
			if food_job and p.sick_left > 0.0:     # (Q7-c) 먹을 것 일터에는 앓는 사람을 넣지 않는다 (일꾼이 앓으면 일터가 쉰다 — _update_building)
				continue
			var hm := bld(p.home)                  # v5: 걸음이 느려 집 가까운 일터를 고른다 (집이 없으면 지금 자리)
			var from := Vector2(hm.x, hm.y) if hm != null else Vector2(p.x, p.y)
			var s := float(p.skills.get(b.type, 0.0)) * 2.0 - Vector2(from.x - b.x, from.y - b.y).length() * 0.25
			if s > bs:
				bs = s
				best = p
		if best == null:
			best = _job_swap(b)               # v5: 먹을 것 일터가 비면 덜 급한 일터의 사람을 옮긴다
			if best == null:
				continue
			stock["도구"] = float(stock["도구"]) + 1.0
		best.job = b.id
		b.worker = best.id
		stock["도구"] = float(stock["도구"]) - 1.0
		speak(best, "오늘부터 %s에서 일해요" % b.label(), 5)


## (2026-11-11 Q12 ① · GAME_DESIGN 8.1) 다 캔 채석장의 석수는 그 자리에 서 있지 않는다: 둘레(Balance.GATHER_RANGE)에 캘 바위가 없으면 일터를 내려놓는다
## (연장은 창고로) — 일터 없는 어른이 되어 바로 아래 배정에서 새 채석장을 맡거나, 일터가 없으면 나르기·짓기를 한다 (ResidentAI의 보통 차례).
## 들고 오던 마지막 돌은 그대로 창고에 내려놓는다 (하던 걸음을 끊지 않는다). 말·연대기 줄 없음 · 난수를 쓰지 않는다 · 저장하는 값 없음 (지금 상태만 봄)
func _leave_spent_quarries() -> void:
	for b in buildings:
		if b.type != "채석장" or not b.built or b.worker < 0 or not quarry_no_rock(b):
			continue
		var w := person(b.worker)
		b.worker = -1
		if w != null:
			w.job = -1
			stock["도구"] = float(stock["도구"]) + 1.0


## (2026-11-11 Q7-c · docs/measure/growth_2026-11-11.md) 먹을 것 일터(밭·화덕·맷돌간 — JOB_FIRST < 10)의 일꾼이 앓아누우면, 일터 없는 성한 어른이 있을 때
## 앓는 사람은 일을 내려놓는다 (연장은 창고로) — 바로 아래 배정이 성한 사람을 그 자리에 세운다. 나은 사람은 일터 없는 어른으로 돌아가 다음 빈 일터를 맡는다.
## 맡을 사람이 없으면 그대로 둔다 (일터가 쉰다 — 예전과 같음). 난수를 쓰지 않는다
func _hand_over_sick() -> void:
	var well := 0
	for p in people:
		if p.is_adult() and p.job < 0 and p.sick_left <= 0.0 and Production.caring_for(self, p) == null:
			well += 1
	if well <= 0:
		return
	for b in buildings:
		if well <= 0:
			break
		if not b.built or b.worker < 0 or int(Balance.JOB_FIRST.get(b.type, 50)) >= 10:
			continue
		var w := person(b.worker)
		if w == null or w.sick_left <= 0.0:
			continue
		b.worker = -1
		w.job = -1
		stock["도구"] = float(stock["도구"]) + 1.0
		stats["stand_in"] = int(stats.get("stand_in", 0)) + 1
		well -= 1


## 먹을 것 일터(JOB_FIRST < 10)가 비었는데 놀고 있는 어른이 없으면 가장 덜 급한 일터(10 이상)의 일꾼을 빼 온다 — 그 사람 (없으면 null)
func _job_swap(b: Building) -> Resident:
	if int(Balance.JOB_FIRST.get(b.type, 50)) >= 10:
		return null
	var from := _job_swap_from()
	if from == null:
		return null
	var w := person(from.worker)
	from.worker = -1
	if w != null:
		ResidentAI.cancel(self, w)
		w.job = -1
	return w


## _job_swap이 일꾼을 빼 올 일터 (가장 덜 급한 일터 — 없으면 null)
func _job_swap_from() -> Building:
	var from: Building = null
	var fp := 9
	for q in buildings:
		if q.worker < 0 or not q.built:
			continue
		var pq := int(Balance.JOB_FIRST.get(q.type, 50))
		if pq > fp and pq < 50:            # 약초사·사제 같은 특별한 일(표에 없는 것)은 빼 오지 않는다
			fp = pq
			from = q
	return from


func household_of(p: Resident) -> Array[Resident]:
	## 부부 + 둘의 아직 성인 아닌 아이들
	var ids := {p.id: true}
	if p.partner >= 0:
		ids[p.partner] = true
	var out: Array[Resident] = [p]
	if p.partner >= 0 and person(p.partner) != null:
		out.append(person(p.partner))
	for q in people:
		if q.is_child() and not ids.has(q.id) and q.parents.size() == 2 and (ids.has(q.parents[0]) or ids.has(q.parents[1])):
			out.append(q)
	return out


func occupants(b: Building) -> int:
	var n := 0
	for p in people:
		if p.home == b.id:
			n += 1
	return n


func houses() -> Array[Building]:
	var out: Array[Building] = []
	for b in buildings:
		if b.built and b.is_house():
			out.append(b)
	return out


func occupancy() -> Dictionary:
	var occ := {}
	for p in people:
		if p.home >= 0:
			occ[p.home] = int(occ.get(p.home, 0)) + 1
	return occ


func _set_home(p: Resident, h: int, occ: Dictionary) -> void:
	if p.home >= 0:
		occ[p.home] = int(occ.get(p.home, 0)) - 1
	p.home = h
	if h >= 0:
		occ[h] = int(occ.get(h, 0)) + 1


func _lives_with_parent(p: Resident) -> bool:
	for pid in p.parents:
		var q := person(pid)
		if q != null and q.home == p.home:
			return true
	return false


## 집 배정이 읽는 것 전부 (사람 순서·id·집·짝·어른인지 + 건물 순서·id·지어졌나·종류) — 부모는 사람마다 정해져 있다
func _homes_state() -> PackedInt64Array:
	var sig := PackedInt64Array()
	sig.resize(people.size() * 4 + buildings.size() * 2 + 2)
	var i := 0
	sig[i] = people.size()
	i += 1
	for p in people:
		sig[i] = p.id
		sig[i + 1] = p.home
		sig[i + 2] = p.partner
		sig[i + 3] = 1 if p.age >= Balance.AGE_ADULT else 0
		i += 4
	sig[i] = buildings.size()
	i += 1
	for b in buildings:
		sig[i] = b.id
		sig[i + 1] = 1 if b.built else 0
		i += 2
	return sig


func _homes_type_list() -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(buildings.size())
	for i in buildings.size():
		out[i] = buildings[i].type
	return out


## 집 배정 (20초마다). 지난번에 아무것도 바꾸지 않았던 상태 그대로면 이번에도 바꿀 것이 없다 → 건너뜀 (같은 결과, 계산만 덜)
func assign_homes() -> void:
	var sig := _homes_state()
	var types := _homes_type_list()
	if sig == _homes_sig and types == _homes_types:
		return
	_assign_homes()
	if _homes_state() == sig:
		_homes_sig = sig
		_homes_types = types
	else:
		_homes_sig = PackedInt64Array()


func _assign_homes() -> void:
	var hs := houses()
	var occ := occupancy()
	for p in people:
		if p.home >= 0 and bld(p.home) == null:
			_set_home(p, -1, occ)
	for p in people:
		if p.home < 0 and (p.partner >= 0 or p.age >= Balance.AGE_ADULT):
			var hh := household_of(p).filter(func(q: Resident) -> bool: return q.home < 0)
			for h in hs:
				if h.cap() - int(occ.get(h.id, 0)) >= hh.size():
					for q: Resident in hh:
						_set_home(q, h.id, occ)
					break
	# 다 자란 미혼 자녀는 집이 꽉 차면 빈자리 있는 집으로 독립
	for p in people:
		if p.age >= Balance.AGE_ADULT and p.partner < 0 and p.parents.size() == 2 and p.home >= 0 and _lives_with_parent(p):
			var h := bld(p.home)
			if int(occ.get(h.id, 0)) < h.cap():
				continue
			var to: Building = null
			var best := 1 << 30
			for b in hs:
				var o := int(occ.get(b.id, 0))
				if b.id != h.id and o < b.cap() and o < best:
					best = o
					to = b
			if to != null:
				_set_home(p, to.id, occ)
				log_line("%s%s 부모 집을 나와 따로 살기 시작했다." % [p.name, josa(p.name, "이", "가")])
	# 집 없는 아이는 부모 집으로
	for p in people:
		if p.home < 0 and p.parents.size() == 2:
			var par := person(p.parents[0])
			if par == null or par.home < 0:
				par = person(p.parents[1])
			if par != null and par.home >= 0:
				var h := bld(par.home)
				if int(occ.get(h.id, 0)) < h.cap():
					_set_home(p, h.id, occ)


# ───────────────────────── 생로병사 (밸런스 v2) ─────────────────────────
func life_events(dt: float) -> void:
	_singers = people.filter(func(q: Resident) -> bool: return q.f("work_aura", 0.0) > 0.0)
	_festival_mult = 1.0
	for s: Resident in _singers:
		_festival_mult = maxf(_festival_mult, s.f("festival"))
	_marriages(dt)
	_births(dt)
	_deaths(dt)
	_wild_grow(dt)


# ───────────────────────── 맨손 채집 (design/gdd/daily-schedule.md R4.6 · 2026-11-10) ─────────────────────────
## 철에 따라 들이 내는 몫 (FORAGE_WINTER ~ 1) — 밭 자람(Health.season_grow)이 1 아래로 내려가는 만큼 줄어든다
func forage_season() -> float:
	var g := Health.season_grow(self)
	var k := clampf((g - Balance.SEASON_GROW_MIN) / (1.0 - Balance.SEASON_GROW_MIN), 0.0, 1.0)
	return lerpf(Balance.FORAGE_WINTER, 1.0, k)


## 마을 둘레(모닥불에서 FORAGE_RANGE 안)가 병 하루에 내는 먹을 것 — 들 + 서 있는 나무(숲 바닥), 철에 따라
func forage_day() -> float:
	var n := 0
	var r2 := Balance.FORAGE_RANGE * Balance.FORAGE_RANGE
	for tr: Dictionary in trees:
		if tr["s"] == "tree" and Vector2(float(tr["x"]) - fire.x, float(tr["y"]) - fire.y).length_squared() <= r2:
			n += 1
			if n >= Balance.FORAGE_TREES_MAX:
				break
	return (Balance.FORAGE_GROUND + Balance.FORAGE_PER_TREE * n) * forage_season()


## 둘레의 먹을 것이 자란다 — 거두지 않으면 FORAGE_KEEP_DAYS 날치에서 멈춘다 (주사위 없음)
func _wild_grow(dt: float) -> void:
	if dt <= 0.0:
		return
	var day := forage_day()
	wild_food = minf(wild_food + day * dt / DAY, day * Balance.FORAGE_KEEP_DAYS)


## 맨손 채집을 나갈 때인가: 일터 없는 어른이 남은 연장보다 많고 (연장이 모자람), 창고 먹을 것이 FORAGE_ENOUGH_DAYS 날치에 못 미친다.
## 첫 며칠 (2026-11-11 Q7-b · Production.forage_first): 연장은 남아 있어도 쥘 일터가 아직 없다 — 먹을 것이 반나절치 아래면 연장 수와 상관없이 연다.
## 같은 걸음 안에서는 한 번만 센다
func forage_open() -> bool:
	if _fg_t == t:
		return _fg_ok
	_fg_t = t
	_fg_ok = false
	var idle := 0
	for p in people:
		if p.is_adult() and p.job < 0 and Production.caring_for(self, p) == null:
			idle += 1
	if float(idle) > float(stock.get("도구", 0.0)):
		_fg_ok = food_total() < Balance.FORAGE_ENOUGH_DAYS * Production.day_need(self)
	if not _fg_ok and idle > 0:
		_fg_ok = Production.forage_first(self)
	return _fg_ok


func _siblings(a: Resident, b: Resident) -> bool:
	for x in a.parents:
		if x in b.parents:
			return true
	return false


## 걸음 dt 동안 '병 하루 비율' rate인 일이 일어날 확률 — 1 − exp(−rate × dt / DAY) (population.md F2·F3: 늘 0~1, 걸음 크기와 무관)
static func day_rate_p(rate: float, dt: float) -> float:
	return 1.0 - exp(-maxf(0.0, rate) * maxf(0.0, dt) / DAY)


## 아이를 낳을 수 있는 부부 수 (population.md R4-2 · 사용자 결정 2026-11-08) — 아내 BIRTH_WIFE_MIN ≤ 나이 < BIRTH_WIFE_MAX, 남편 어른.
## 보지 않을 때 위기 죽음 아끼기(OFFLINE_MIN_COUPLES)와 분가(남길 부부)가 센다 — 늙은 부부는 빠진다
func fertile_couples() -> int:
	var n := 0
	for w in people:
		if w.sex != "f" or w.partner < 0 or w.age < Balance.BIRTH_WIFE_MIN or w.age >= Balance.BIRTH_WIFE_MAX:
			continue
		var h := person(w.partner)
		if h != null and not h.dead and h.age >= Balance.AGE_ADULT:
			n += 1
	return n


## 혼인: 성인(4일)~20일 미혼 남녀 짝마다 병 하루 비율 MARRY_RATE (남매 제외). 짝은 sim_life.py처럼 섞어서 한 명씩 맞춘다
func _marriages(dt: float) -> void:
	var men: Array[Resident] = []
	var women: Array[Resident] = []
	for p in people:
		if p.partner < 0 and p.age >= Balance.MARRY_MIN and p.age < Balance.MARRY_MAX:
			(men if p.sex == "m" else women).append(p)
	if men.is_empty() or women.is_empty():
		return
	_shuffle(men)
	_shuffle(women)
	Social.pair_up(self, men, women)  # [마을의 삶] 서로 좋아하는 둘이 같은 자리에 (확률·짝 수는 그대로)
	for i in mini(men.size(), women.size()):
		var a := men[i]
		var b := women[i]
		if _siblings(a, b):
			continue
		if rng.randf() < day_rate_p(Balance.MARRY_RATE, dt):
			marry(a, b)
			Social.on_marry(self, a, b)
			if a.home != b.home:
				a.home = -1
				b.home = -1
			if not VillageEra.wedding(self, a, b):       # 교회가 있으면 교회에서 혼례 잔치 (A6)
				log_line("%s%s %s%s 모닥불 앞에서 혼인을 약속했다." % [a.name, josa(a.name, "과", "와"), b.name, josa(b.name, "이", "가")])
			speak(a, "{w}, 저희를 지켜봐 주세요" if aware else "우리 오래오래 함께해요", 6)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## 출산: 부부(아내 4~18일) + 집에 빈자리. 꽉 차면 '가족 + 1명'이 들어갈 집으로 옮겨야 낳는다 (집 크기 병목 — 의도한 규칙)
func _births(dt: float) -> void:
	var env := birth_env()
	var guarantee: bool = Balance.FIRST_BIRTH_GUARANTEE and stats["born"] == 0 and t >= Balance.FIRST_BIRTH_AT and t < 2.0 * DAY
	var food_ok := food_total() >= Balance.BIRTH_FOOD_DAYS * Production.day_need(self)     # v5: 먹을 것이 모자라면 아이를 미룬다 (성장이 스스로 멈춤)
	var fed := guarantee or food_ok
	var littles := 0                      # 마을의 어린것 (아기 + 아이) — MAX명이면 다음 아기는 기다린다 (population.md F3a · 2026-11-10 '어린것은 늘 넷에서 여섯')
	for q in people:
		if q.age < Balance.AGE_ADULT:
			littles += 1
	if fed and not guarantee:             # v5 · F3a: 걸음마 전 아기 × CARE_CAP < 어른이어야 (돌보는 부모가 일손의 3분의 1을 넘지 않게) — 한꺼번에 태어나 밭이 비지 않게
		var babies := 0
		var adults := 0
		for q in people:
			if q.age < Balance.CARE_DAYS:
				babies += 1
			elif q.is_adult():
				adults += 1
		fed = babies * Balance.CARE_CAP < adults
	var occ := {}                         # 집마다 사는 사람 수 (occupants()와 같은 값 — 한 번 세고 옮길 때마다 고침)
	var hs: Array[Building] = []
	var counted := false
	for w in people.duplicate():
		if not (w.sex == "f" and w.partner >= 0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX):
			continue
		if not counted:
			counted = true
			occ = occupancy()
			hs = houses()
		var h := bld(w.home) if w.home >= 0 else null
		if h == null or int(occ.get(h.id, 0)) >= h.cap():
			var hh := household_of(w)
			var to: Building = null
			for b in hs:
				if (h == null or b.id != h.id) and b.cap() - int(occ.get(b.id, 0)) >= hh.size() + 1:
					to = b
					break
			if to == null:
				continue
			for q in hh:
				if q.home >= 0:
					occ[q.home] = int(occ.get(q.home, 0)) - 1
				q.home = to.id
				occ[to.id] = int(occ.get(to.id, 0)) + 1
			h = to
			stats["moves"] += 1
			log_line("%s의 가족이 더 넓은 집으로 옮겼다." % w.name)
		var rate: float = Balance.BIRTH_RATE * w.fert * env
		# F3: λ가 1을 넘어도 (따라잡기 큰 걸음) p ≤ 1. 어린것 상한은 굴린 뒤에 본다 — 난수를 뽑는 자리·차례가 예전과 같게 (첫 출생 보장은 상한을 보지 않는다)
		if guarantee or (dt > 0.0 and fed and rng.randf() < day_rate_p(rate, dt) and littles < Balance.BIRTH_LITTLE_MAX):
			guarantee = false
			_give_birth(w, h)
			occ[h.id] = int(occ.get(h.id, 0)) + 1     # 아기도 그 집에 산다
			littles += 1
	# 어린것이 드물면: 먹을 것 문이 닫혀 있어도 한 집이 아기를 맞는다 — 병 하루에 하나까지 (2026-11-10 메인 판단 — 사용자 위임. BIRTH_LITTLE_MIN 0이면 꺼짐)
	if dt > 0.0 and not food_ok and littles < Balance.BIRTH_LITTLE_MIN and people.size() >= Balance.BIRTH_LITTLE_MIN_POP \
			and (birth_floor_t < 0.0 or t - birth_floor_t >= Balance.BIRTH_LITTLE_REST_DAYS * DAY):
		var w := _quiet_lane_mother()
		if w != null:
			if birth_floor_t < 0.0 or t - birth_floor_t >= Balance.BIRTH_LITTLE_NOTE_DAYS * DAY:
				log_line("골목에 아이 웃음소리가 드물어졌다. %s네는 살림이 빠듯해도 아기를 맞기로 했다." % w.name)
			birth_floor_t = t
			_give_birth(w, bld(w.home))


## 어린것이 드물 때 아기를 맞을 집: 아이를 낳을 수 있는 아내 가운데 제 집에 빈자리가 있고 살아 있는 아이가 가장 적은 사람 (같으면 먼저 온 사람 — 난수를 쓰지 않는다. 이사는 하지 않는다)
func _quiet_lane_mother() -> Resident:
	var n := {}                           # 엄마 id → 살아 있는 아이 수
	for p in people:
		if p.parents.size() == 2:
			n[p.parents[0]] = int(n.get(p.parents[0], 0)) + 1
	var occ := occupancy()
	var best: Resident = null
	var best_n := 1 << 30
	for w in people:
		if not (w.sex == "f" and w.partner >= 0 and w.fert > 0.0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX):
			continue
		var h := bld(w.home) if w.home >= 0 else null
		if h == null or int(occ.get(h.id, 0)) >= h.cap():
			continue
		var c := int(n.get(w.id, 0))
		if c < best_n:
			best_n = c
			best = w
	return best


func _give_birth(w: Resident, h: Building) -> void:
	var occ := occupants(h)
	birth_log.append({"t": t, "home": h.id, "occ_before": occ, "cap": h.cap()})
	if occ >= h.cap():
		violations.append("출생 때 집이 꽉 참 (%s, %d/%d)" % [fmt_time(t), occ, h.cap()])
	var sex := "m" if rng.randf() < 0.5 else "f"
	var pool: Array = Balance.NAMES_M if sex == "m" else Balance.NAMES_F
	var nm: String = pool[rng.randi() % pool.size()]
	var dad := person(w.partner)
	var baby := add_person(nm, sex, 0.0, "", h.x, h.y, w, dad if dad != null else w)
	baby.parents = PackedInt32Array([w.id, w.partner])
	baby.home = h.id
	Health.inherit_immunity(baby, w, t)     # 엄마의 면역을 1일 동안 (HEALTH.md 2.3)
	stats["born"] += 1
	log_line("%s%s %s%s 낳았다. 아이는 '%s' 아이였다." % [w.name, josa(w.name, "이", "가"), nm, josa(nm, "을", "를"), baby.trait_name])
	if Genetics.piebald(baby.genes):
		log_line("눈송이 아이가 태어났다. 사람들은 %s%s '하늘의 눈송이가 내려앉은 아이'라 부르며 귀하게 여겼다." % [nm, josa(nm, "을", "를")])
	speak(w, "%s, 반가워!" % nm, 7)
	emit(&"born", {"who": baby.id, "at": Vector2(h.x, h.y), "v": {"first": int(stats["born"]) == 1, "mom": w.id, "home": h.id}})   # 연출은 화면이 (EVENTS_STAGING 4)


func _deaths(dt: float) -> void:
	var couples := fertile_couples()      # 아끼기는 아이를 낳을 수 있는 부부만 센다 (population.md R4-2)
	for p in people.duplicate():
		var why := ""
		var la: float = p.age / p.f("lifespan")          # 혈통 '장수' ×1.15 · '단명' ×0.8 → 늙는 빠르기로 (노환 확률·상한 나이)
		if la >= Balance.DEATH_FROM:
			var pd: float = Balance.DEATH_BASE + Balance.DEATH_SLOPE * (la - Balance.DEATH_FROM)
			if rng.randf() < pd * dt / (DAY * Balance.age_k(p.age)) or la > Balance.DEATH_MAX_AGE:
				why = "노환"
		if why == "" and p.health <= 0.0:
			# 거인이 없을 때: 위기 사망(굶주림·병·추위·더위)은 하루 1명까지, 가임 부부 OFFLINE_MIN_COUPLES쌍 이하면 일어나지 않음 (멸망 방지)
			if not is_watching() and (couples <= Balance.OFFLINE_MIN_COUPLES or _starve_day == day_no()):
				p.health = 0.05
				stats["spared"] = int(stats.get("spared", 0)) + 1
			else:
				why = Health.death_cause(p)
				var ill := Health.is_illness(why)        # 병이면 병 이름 (HEALTH.md 2.4)
				var what: String = (why + Health.ro(why)) if ill else {"굶주림": "굶주림으로", "추위": "추위에", "더위": "더위에"}.get(why, "굶주림으로")
				crisis("starve" if why == "굶주림" else ("sick" if ill else why), "%s%s %s 쓰러졌다" % [p.name, josa(p.name, "이", "가"), what])
				_starve_day = day_no()
				if why == "굶주림":
					stats["starved"] += 1
				var key: String = "died_sick" if ill else {"추위": "died_cold", "더위": "died_heat"}.get(why, "")
				if key != "":
					stats[key] = int(stats.get(key, 0)) + 1
		if why != "":
			kill(p, why)


func kill(p: Resident, why: String) -> void:
	ResidentAI.cancel(self, p)
	p.dead = true
	p.death_t = t
	p.death_why = why
	stats["died"] += 1
	if p.job >= 0:
		var b := bld(p.job)
		if b != null:
			b.worker = -1
		stock["도구"] = float(stock["도구"]) + 1.0
	if p.partner >= 0:
		var q := person(p.partner)
		if q != null:
			q.partner = -1
	# 가족 슬픔
	for q in people:
		if q.id == p.partner or q.id in p.parents or p.id in q.parents:
			q.grief_until = t + Balance.GRIEF_DAYS * DAY
	people.erase(p)
	_people_by_id.erase(p.id)
	dead.append(p)
	var age := p.shown_age()
	var ga := josa(p.name, "이", "가")
	var nb := josa(p.name, "은", "는")
	match ("질병" if Balance.DISEASES.has(why) else why):
		"질병":      # "한스가 기침병으로 숨을 거두었다." (이번 유행의 이름 — HEALTH.md 2.4·2.5)
			var dn := p.disease_name if p.disease_name != "" else why
			log_line("%s(%d세)%s %s%s 숨을 거두었다." % [p.name, age, ga, dn, Health.ro(dn)])
		"노환":
			log_line("%s(%d세)%s 잠들 듯 숨을 거두었다." % [p.name, age, ga])
		"병":
			log_line("%s(%d세)%s 앓아누운 끝에 끝내 일어나지 못했다." % [p.name, age, ga])
		"추위":
			var ssn: String = jar_date()["season"]
			log_line("%s, %s(%d세)%s 끝내 따뜻해지지 못했다." % ["그 겨울" if ssn == "겨울" else "그 추운 날", p.name, age, nb])
		"더위":
			var ssn: String = jar_date()["season"]
			log_line("%s, %s(%d세)%s 끝내 더위를 이기지 못했다." % ["그 여름" if ssn == "여름" else "그 무더운 날", p.name, age, nb])
		_:
			log_line("%s(%d세)%s 굶주림 끝에 숨을 거두었다." % [p.name, age, ga])
	# 두려움: 가족(부모·자식·배우자·형제) +0.2, 반경 6칸에서 본 사람 +0.05 (HEALTH.md 4)
	for q in people:
		if q.id == p.partner or q.id in p.parents or p.id in q.parents or _siblings(p, q):
			raise_fear(q, Balance.FEAR_FAMILY_DEATH)
		elif Vector2(q.x - p.x, q.y - p.y).length() <= Balance.FEAR_SAW_R and not q.sleeping:
			raise_fear(q, Balance.FEAR_SAW_DEATH)
	recalc_fear()
	VillageEra.on_death(self, p)          # 무덤 · 장례 행렬 · 발견 '장례' (A6 — DISCOVERIES P4)
	# 사건 &"died" (event-kinds.md — E1-5): 무덤이 생긴 다음. 난수를 쓰지 않고, 지켜보는지 읽지 않는다 (연출은 화면이 — EVENTS_STAGING 5)
	if not graves.is_empty() and int((graves[graves.size() - 1] as Dictionary)["id"]) == p.id:
		var gr: Dictionary = graves[graves.size() - 1]
		emit(&"died", {"who": p.id, "at": Vector2(float(gr["x"]), float(gr["y"])),
			"v": {"first": graves.size() == 1, "name": p.name, "grave": p.id, "why": why}})


func idle_chatter() -> void:
	_idle_chatter_main()
	Immigrants.say_hints(self)             # 조각을 지닌 이주민이 말풍선이 빌 때 한 번 (난수 없음 — 다른 흐름을 흔들지 않게)


func _idle_chatter_main() -> void:
	var awake := people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5)
	if awake.is_empty():
		return
	if not aware:                         # 거인을 모른다 — 믿음·의심 말은 아직 없다
		return
	var dbt := awake.filter(func(q: Resident) -> bool: return q.belief < Balance.DOUBT_BELOW)
	if not dbt.is_empty() and rng.randf() < 0.6:
		var kid: Resident = dbt[0]
		for q: Resident in dbt:
			if q.age < 6.0:
				kid = q
				break
		speak(kid, Balance.LINES_DOUBT[rng.randi() % Balance.LINES_DOUBT.size()], 6)
		var elder: Resident = null
		for q: Resident in awake:
			if q.age >= 15.0 and q.belief > 0.5 and (elder == null or q.age > elder.age):
				elder = q
		if elder != null:
			speak(elder, Balance.LINE_ELDER_SCOLD, 6)
		return
	var p: Resident = awake[rng.randi() % awake.size()]
	if is_watching() and rng.randf() < 0.4:
		speak(p, Balance.LINES_WATCHED[rng.randi() % Balance.LINES_WATCHED.size()], 5)
	elif deficit > 0.0:
		speak(p, "창고가 비었어…", 5)


# ───────────────────────── 자율 건설 — 촌장 (RESIDENT_AI 6.2 · 9장) ─────────────────────────
func chief() -> Resident:
	var c: Resident = null
	for p in people:
		if p.age >= Balance.AGE_ADULT and (c == null or p.age > c.age):
			c = p
	return c


## v5-0: 시간당 먹을 것 (촌장의 어림) = 밭의 밀 × 철 자람 — 그중 맷돌간·화덕이 빻고 구울 수 있는 몫은 빵(×1.5), 나머지는 죽(×0.75)
func food_rate() -> float:
	var w := farm_rate() * Health.season_grow(self) * CoreWarmth.grow(self)     # [핵] 늘 그런 병의 밀 자람 (A28b — 이슬·마른 철은 지나가는 것이라 뺌)
	var mill := 0.0
	var oven := 0.0
	for b in buildings:
		if not b.built:
			continue
		if b.type == "맷돌간" or b.type == "방앗간":
			mill += HOUR / float(b.def()["cycle"])
		elif b.type == "화덕" or b.type == "빵집":
			oven += HOUR / float(b.def()["cycle"])
	var flour := minf(w, minf(mill, oven))
	return flour * Balance.BREAD_YIELD + (w - flour) * Balance.PORRIDGE_YIELD


## v5-0: 빵을 굽고 있나 = 일꾼이 있는 맷돌간(방앗간)과 화덕(빵집)이 다 있다 — 일손이 모자라 비면 밭은 죽 값으로만 먹인다
func bakes_now() -> bool:
	var mill := false
	var oven := false
	for b in buildings:
		if b.built and b.worker >= 0:
			if b.type == "맷돌간" or b.type == "방앗간":
				mill = true
			elif b.type == "화덕" or b.type == "빵집":
				oven = true
	return mill and oven


func count_type(type: String) -> int:
	var n := 0
	for b in buildings:
		if b.type == type:
			n += 1
	return n


func farm_rate(staffed := false) -> float:
	## 농장들의 시간당 밀 (농사 배율 포함). staffed = 일꾼이 있는 밭만 (v5)
	var s := 0.0
	for b in buildings:
		if b.type == "농장" and (not staffed or (b.built and b.worker >= 0)):
			if b.farm_mult < 0.0:
				b.farm_mult = farm_mult(b.x, b.y)
			s += 3600.0 / float(Balance.B["농장"]["cycle"]) * b.farm_mult
	return s


func house_capacity() -> int:
	var c := 0
	for b in buildings:
		if b.is_house():
			c += int(Balance.B[b.site_type()]["cap"])
	return c


func _owed(k: String) -> int:
	var s := 0
	for b in buildings:
		if b.is_site():
			s += maxi(0, b.need(k) - int(b.delivered[k]) - int(b.incoming[k]))
	return s


## 들어준 소원 중 지금 지을 수 있는 것 (시대가 열린 것) — 없으면 ""
func _wish_now() -> String:
	for w: String in wishes:
		if Balance.B.has(w) and VillageEra.can_build(self, w):
			return w
	return ""


## 거인님이 좋아하시는 물건을 만드는 일터 (아직 2채 미만) — 없으면 ""
func _fav_want() -> String:
	var goods := favourites.keys().filter(func(k: String) -> bool: return is_favourite(k) and Balance.PRODUCER.has(k))
	goods.sort_custom(func(a: String, b: String) -> bool: return float(favourites[a]) > float(favourites[b]))
	for g: String in goods:
		var ty: String = Balance.PRODUCER[g]
		var also: Array = Balance.PRODUCER_ALSO.get(g, [])
		var bigger := false
		for ta: String in also:
			if count_type(ta) > 0:
				bigger = true                 # v5: 방앗간·빵집이 있으면 맷돌간·화덕을 더 짓지 않는다
		if bigger:
			continue
		if not VillageEra.can_build(self, ty) or count_type(ty) >= 2:
			continue
		if ty == "소금밭" and (not salt_known or salt_flat_near() == null):
			continue
		return ty
	return ""


## 집이 필요한가 (2026-11-09 — design/gdd/mayor-decisions.md F2·F8(새) · BALANCE HOUSE_BUFFER). 짓는 중인 집 터도 정원에 넣는다 (터가 서는 동안 또 짓지 않게).
## free = 빈 침대 (정원 − 집 있는 사람) · need = 집 없는 사람 + 곧 태어날 아기(아이 낳을 부부 중 집에 빈자리가 없는 부부) + HOUSE_BUFFER.
## 돌려줌: short (free < need) · homeless (집 없는 가족이 들 자리 모자람: 침대 수 또는 한 집에 함께 들 자리) ·
##   crowded (아이 낳을 부부가 지금 집이 꽉 찼고 어느 집(터 포함)에도 가족 + 1 자리가 없음 — 새 집이 그 가족을 품을 때만) ·
##   fit_homeless · fit_crowded (새 집이 품어야 할 가족 크기, 없으면 1) · free · need
func house_need() -> Dictionary:
	var room := {}                        # 집(터 포함) → 남은 자리
	var cap := 0
	for b in buildings:
		if b.is_house():
			var c := int(Balance.B[b.site_type()]["cap"])
			room[b.id] = c
			cap += c
	for p in people:
		if p.home >= 0 and room.has(p.home):
			room[p.home] = int(room[p.home]) - 1
	var max_room := 0
	for k: int in room:
		max_room = maxi(max_room, int(room[k]))
	var era_cap := int(Balance.B[Balance.ERA_HOUSE[mini(era, 3)]]["cap"])
	var homeless := 0
	var hh_fit := 0                       # 한 집에 들 자리가 없는 집 없는 가족 중 가장 큰 크기
	var seen := {}
	for p in people:
		if p.home >= 0 or seen.has(p.id):
			continue
		homeless += 1
		if not (p.partner >= 0 or p.age >= Balance.AGE_ADULT):
			continue                      # 아이는 부모 집으로 (부모와 함께 셈)
		var hh := household_of(p).filter(func(q: Resident) -> bool: return q.home < 0)
		for q: Resident in hh:
			seen[q.id] = true
		if hh.size() > max_room:
			hh_fit = maxi(hh_fit, hh.size())
	var births := 0
	var crowd_fit := 0
	for w in people:
		if w.sex != "f" or w.partner < 0 or w.age < Balance.BIRTH_WIFE_MIN or w.age >= Balance.BIRTH_WIFE_MAX or w.home < 0:
			continue
		if int(room.get(w.home, 0)) > 0:
			continue                      # 지금 집에 아기 자리가 있다
		var n := household_of(w).size() + 1
		if n > era_cap:
			continue                      # 이 시대 어떤 집에도 못 드는 큰 가족 (집 크기 병목 — 의도한 규칙)
		births += 1
		if n > max_room:
			crowd_fit = maxi(crowd_fit, n)
	var free := cap - (people.size() - homeless)     # 빈 침대 (짓는 터 포함)
	var need := homeless + births + Balance.HOUSE_BUFFER
	return {"free": free, "need": need, "short": free < need,
		"homeless": homeless > 0 and (free < homeless or hh_fit > 0),
		"crowded": crowd_fit > 0, "fit_homeless": maxi(1, hh_fit), "fit_crowded": maxi(1, crowd_fit)}


func chief_build() -> void:
	Production.self_learn(self)          # 새로 배워야 하는 건물을 스스로 깨쳤나 (시대가 열린 지 MUST_LEARN_SELF_DAYS — 연대기 한 줄)
	_chief_build({})


## 촌장의 한 번 — skip: 돌이 들어올 길이 없어 지금은 못 짓는 바람들 (그 아래 바람을 보려고 다시 부를 때만 채워진다 — GD 9장 · growth 바).
## 보통은 비어 있고, 비어 있으면 예전과 한 줄도 다르지 않다.
func _chief_build(skip: Dictionary) -> void:
	var pending := 0
	for b in buildings:
		if b.is_site():
			pending += 1
	var wish := _wish_now()
	if pending >= (3 if wish != "" else 2):       # 들어준 소원은 짓는 중인 터가 있어도 하나 더
		return
	var pop := people.size()
	var cap := house_capacity()
	var homeless := 0
	var idle := 0
	for p in people:
		if p.home < 0 and p.age >= Balance.AGE_ADULT:
			homeless += 1
		if p.is_adult() and p.job < 0:
			idle += 1
	var era_house: String = Balance.ERA_HOUSE[mini(era, 3)]
	var era_cap := int(Balance.B[era_house]["cap"])
	var house_fit := 1                    # 새 집이 품어야 할 가족 크기
	var hn := house_need()                # 집은 필요할 때만 (빈 침대 < 필요 · 한 집에 들 자리가 없는 가족) — 남발 막기 (2026-11-09)
	var n_houses := 0
	for b in buildings:
		if b.is_house():
			n_houses += 1
	var basics := count_type("농장") > 0 and count_type("나무꾼") > 0
	# v5: 밭이 먹이는 양 = 밀 × (빵을 굽게 되면 1.5, 아니면 죽 0.75). 창고 먹을 것이 이틀치 아래로 떨어져도 먹을 것부터
	var bakes := bakes_now()
	var yld := Balance.BREAD_YIELD if bakes else Balance.PORRIDGE_YIELD
	var food_low := food_total() < Balance.BIRTH_FOOD_DAYS * Production.day_need(self)
	var fr := food_rate()                 # v5-0: 철(겨울엔 더디 자람)과 맷돌·화덕이 빻고 굽는 만큼까지 센 시간당 먹을 것
	var food_short := fr < pop * (HOUR / Balance.FOOD_IV) * Balance.FARM_SAFETY or (food_low and fr < pop * (HOUR / Balance.FOOD_IV) * Balance.FARM_SAFETY * 1.5)
	var mill_n := count_type("맷돌간") + count_type("방앗간") * 3
	var oven_n := count_type("화덕") + count_type("빵집") * 3
	var want := ""
	var fav := _fav_want()
	var spent := quarry_spent()           # 채석장은 있는데 어느 채석장 둘레에도 캘 돌 바위가 없다
	var dry := spent and stone_rocks_left() and not skip.has("채석장")     # … 그런데 병 안에는 바위가 남아 있다
	# (2026-11-11 Q13 ① · GAME_DESIGN 8.1) 다음 채석장은 창고의 돌이 바닥나기 전에: 둘레를 다 캔 그때부터 바란다 (예전엔 돌이 6 아래 · 다른 바람이 없을 때, 또는 돌이 모자라 못 지을 때 —
	# 그 사이 남은 돌을 다 써 버려 하루 이틀 돌이 끊겼다). 판자가 될 때만 — 안 되면 예전처럼 그 아래 바람을 본다 (막지 않는다). 손이 빈 어른 둘을 기다리지 않는다: 다 캔 채석장은
	# 석수를 내려놓았으니 (Q12) 새 일터가 느는 것이 아니라 같은 일터가 자리를 옮기는 것. 주사위 · 저장하는 값 · 새 균형 값 없음
	var next_quarry := dry and _affordable("채석장")
	if wish != "" and not skip.has(wish):
		want = wish                   # 들어준 소원이 우선순위 맨 위 (기획서 6.7)
	elif count_type("농장") == 0 and n_houses >= 1 and not skip.has("농장"):
		want = "농장"
	elif count_type("나무꾼") == 0 and n_houses >= 1 and not skip.has("나무꾼"):
		want = "나무꾼"
	elif int(stats.get("died", 0)) > 0 and count_type("묘지") == 0 and VillageEra.can_build(self, "묘지") and not skip.has("묘지"):
		want = "묘지"                 # 첫 죽음 뒤 (슬픔 — 묻을 곳부터)
	elif homeless > 0 and bool(hn["homeless"]) and not skip.has("집"):
		want = "집"
		house_fit = int(hn["fit_homeless"])                   # 집 없는 사람이 들 자리가 모자람 (침대 수 또는 한 집에 함께 들 자리)
	elif count_type("농장") > 0 and mill_n == 0 and not skip.has("맷돌간"):
		want = "맷돌간"               # v5: 첫 수확이 다가오면 밀을 빻을 곳 (A22 — 날밀은 못 먹는다)
	elif count_type("농장") > 0 and oven_n == 0 and not skip.has("화덕"):
		want = "화덕"                 # 모닥불 곁 공용 화덕
	elif food_low and food_short and count_type("농장") < 2 and n_houses >= 1 and not skip.has("농장"):
		want = "농장"                 # v5: 시작 건량은 하루치 — 밭이 모자라면 둘째 밭을 집보다 먼저 (첫 며칠 굶주림 막기)
	elif (food_short or (food_low and count_type("농장") * Balance.FARM_FEEDS * yld / Balance.PORRIDGE_YIELD < pop + 6)) and not skip.has("농장"):
		want = "농장"                 # v5: 창고 먹을 것이 이틀치 아래면 촌장은 밭부터 (집보다 먼저) — v5-0: 밭 하나가 먹이는 사람 수는 빵을 구우면 두 배 (죽 기준 6명)
	elif next_quarry:
		want = "채석장"               # (Q13) 있는 채석장 둘레를 다 캤고 병 안에 바위가 남았다 → 남은 바위 곁에 하나 더, 돌이 남아 있을 때 미리 (먹을 것 · 묻을 곳 · 집 없는 사람 다음, 돌이 드는 집보다 먼저)
	elif (bool(hn["short"]) or (bool(hn["crowded"]) and basics and not food_low)) and not skip.has("집"):
		house_fit = 1 if bool(hn["short"]) else int(hn["fit_crowded"])
		want = "집"                   # v5: 먹을 것이 모자라면 아이 낳을 큰 집은 미룬다
	elif count_type("농장") > 0 and mill_n * Balance.MILL_PER < maxi(pop, 1) and not skip.has("맷돌간"):
		want = "맷돌간"
	elif count_type("농장") > 0 and oven_n * Balance.OVEN_PER < maxi(pop, 1) and not skip.has("화덕"):
		want = "화덕"
	elif fav != "" and not skip.has(fav):
		want = fav                    # 거인님이 좋아하시는 물건의 일터 (받은 제물, 11.1)
	elif _want_picker() and not skip.has("버섯꾼"):
		want = "버섯꾼"               # [하늘의 것] 큰 버섯이 여럿 서 있으면 베어 올 사람 (WORLD_EVENTS 2.6)
	elif count_type("우물") == 0 and not skip.has("우물"):
		want = "우물"
	elif count_type("나무꾼") < 2 and not skip.has("나무꾼"):
		want = "나무꾼"
	elif float(stock["판자"]) < 12.0 and count_type("제재소") == 0 and not skip.has("제재소"):
		want = "제재소"
	elif float(stock["돌"]) < 6.0 and (count_type("채석장") == 0 or (dry and idle >= Balance.IDLE_FOR_NEW_JOB)) and not skip.has("채석장"):
		want = "채석장"               # 하나도 없을 때 · 있는 채석장 둘레를 다 캤는데 병 안에 바위가 남았을 때 (남은 바위 곁에 하나 더 — GD 9장)
	elif _standing_trees() < Balance.FOREST_MIN and count_type("산림관") == 0 and not skip.has("산림관"):
		want = "산림관"
	elif salt_known and count_type("소금밭") == 0 and salt_flat_near() != null and not skip.has("소금밭"):
		want = "소금밭"
	elif VillageEra.want_early(self) != "" and not skip.has(VillageEra.want_early(self)):
		want = VillageEra.want_early(self)    # 첫 죽음 뒤 묘지 · 자주 앓으면 약초꾼 (A6)
	elif era >= 1 and count_type("방앗간") == 0 and _upgradable("맷돌간") != null and not skip.has("방앗간"):
		want = "방앗간"               # 풍차가 맷돌간을 대신 (넓혀 지음)
	elif era >= 2 and count_type("빵집") == 0 and _upgradable("화덕") != null and not skip.has("빵집"):
		want = "빵집"                 # 읍내: 공용 화덕을 빵집으로
	elif Wildlife.want(self) != "" and not skip.has(Wildlife.want(self)):
		want = Wildlife.want(self)            # [들짐승] 식량 다양성 — 물고기가 사는 호숫가 어부 · 사슴 무리 쪽 사냥꾼 (WILDLIFE 6)
	else:
		want = VillageEra.want_late(self)     # 치료소 → 교회 → 광장 → 망루 → 나루터 (A6 — RESIDENT_AI 6.2)
	var spare := false
	if want == "":
		want = spare_want(skip)               # (Q26) 다른 바람이 하나도 없는데 일손이 남는다 → 쓸모 있는 일터 하나 더 (먹을 것 → 땔감 → 재료)
		spare = want != ""
	if want == "" or skip.has(want):
		return
	var token := want                     # 이 바람의 이름 (집은 "집" — 못 지으면 이 이름으로 건너뜀)
	var upgrade: Building = null
	if want == "집":
		want = era_house
		# 땅이 한계: 집 정원 합계는 품을 수 있는 인구 × 1.1까지. 넘으면 작은 옛 집을 그 시대 집으로 넓혀 짓는다
		if cap + era_cap > land_capacity() * Balance.HOUSE_SLACK:
			upgrade = upgrade_candidate(cap, era_cap, land_capacity() * Balance.HOUSE_SLACK)
			if upgrade == null:
				return
	if upgrade == null and want == era_house and not _affordable(want) and _affordable("오두막") and int(Balance.B["오두막"]["cap"]) >= house_fit:
		want = "오두막"          # 판자가 모자라면 작은 집이라도 (프로토타입) — 기다리는 가족이 들어갈 크기일 때만 (안 들어가면 오두막만 늘어남 — 2026-11-09)
	if not _affordable(want):
		# 자재가 모자라 못 지으면 그 자재를 만드는 일터부터 (교착 방지 — 정함)
		var free_plank := float(stock["판자"]) - _owed("판자")
		var free_stone := float(stock["돌"]) - _owed("돌")
		var need_p := int(Balance.B[want]["plank"]) + (0 if (want == "나무꾼" or want == "제재소") else Balance.PLANK_RESERVE)
		if free_plank < need_p and count_type("제재소") == 0 and _affordable("제재소"):
			want = "제재소"
			upgrade = null
		elif count_type("채석장") == 0 and _affordable("채석장"):
			want = "채석장"
			upgrade = null
		elif dry and free_stone < int(Balance.B[want]["stone"]) and _affordable("채석장") and idle >= Balance.IDLE_FOR_NEW_JOB:
			want = "채석장"          # 돌이 모자란데 있는 채석장 둘레는 다 캤다 → 남은 바위 곁에 하나 더 (보통 건물과 같은 값 · 같은 규칙)
			upgrade = null
		elif spent and free_stone < int(Balance.B[want]["stone"]):
			# 돌이 들어올 길이 지금은 없다 (창고에 없고, 캘 바위도 닿지 않고, 채석장을 더 지을 수도 없다) → 이 바람은 두고 그 아래 것을 본다.
			# '아직 나르지 않은' 것(채석장 둘레에 바위가 남음)이나 채석장이 아예 없을 때는 여기 오지 않는다 — 예전처럼 기다린다.
			var next := skip.duplicate()
			next[token] = true
			_chief_build(next)
			return
		else:
			return
	var d: Dictionary = Balance.B[want]
	if not VillageEra.can_build(self, want):      # 시대가 안 열렸거나 아직 못 짓는 건물 (어부·목장 … — Balance.B_LOCKED)
		return
	# 촌장은 직장 없는 성인이 2명 이상일 때만 새 일터 (식량 부족 시 농장 · 빵 사슬 예외 · 들어준 소원은 그래도 짓는다)
	var food_job := (want == "농장" and (food_short or food_low)) or want in ["맷돌간", "화덕", "방앗간", "빵집"]
	if d.get("job", false) and idle < Balance.IDLE_FOR_NEW_JOB and not food_job and want != wish and not (want == "채석장" and next_quarry):
		return                                    # (Q13) 다 캔 채석장을 잇는 채석장은 예외 — 옮겨 짓는 일터
	if upgrade == null and d.has("replaces"):     # v5: 방앗간·빵집은 맷돌간·화덕을 넓혀 짓는다 (일꾼·자리 그대로)
		upgrade = _upgradable(String(d["replaces"]))
	var c := chief()
	var cn := c.name if c != null else ""
	if upgrade != null:
		if want == wish:
			wishes.erase(wish)
			upgrade.wished = true
		upgrade.upgrade_to = want
		upgrade.prog = 0.0
		upgrade.delivered = {"판자": 0, "돌": 0}
		upgrade.incoming = {"판자": 0, "돌": 0}
		var what := "작은 옛 집" if upgrade.is_house() else upgrade.label()
		log_line("촌장 %s%s %s%s %s%s 넓히기로 했다." % [cn, josa(cn, "이", "가"), what, josa(what, "을", "를"), Balance.label(want), josa(Balance.label(want), "으로", "로")])
		return
	var trees_was := trees                # 자리 찾기는 고른 자리의 나무·민들레·내려앉은 꽃씨를 치운다 (_clear_trees — 새 배열로 바꿔 넣음) — 그 자리를 버리면 되돌린다 (아래)
	var dands_was: Array = flora.dands if flora != null else []
	var pending_was: Array = flora.pending if flora != null else []
	var spot: Variant = find_spot(want)
	if want == "채석장" and spent and (spot == null or not stone_in_reach((spot as Vector2).x, (spot as Vector2).y)):
		# 하나 더 짓는 채석장인데 자리가 없거나 고른 자리에서 남은 바위가 닿지 않는다 (바위가 영역 밖 · 물 건너) → 짓지 않고, 채석장 없이 그 아래 바람을 본다
		trees = trees_was
		if flora != null:                 # (Q12 ③) 접은 자리의 민들레·꽃씨도 되돌린다 — 접은 자리는 흔적이 없다 (주사위는 쓰지 않음)
			flora.dands = dands_was
			flora.pending = pending_was
		var no_quarry := skip.duplicate()
		no_quarry["채석장"] = true
		_chief_build(no_quarry)
		return
	if spot == null:
		return
	var sp: Vector2 = spot
	var nb := add_building(want, sp.x, sp.y, false)
	if want == wish:
		nb.wished = true
		wishes.erase(wish)
		log_line("촌장 %s%s {w:이/가} 들어주신 %s 자리부터 정했다." % [cn, josa(cn, "이", "가"), Balance.label(want)])
		return
	if spare:
		log_line("손이 노는 사람들이 늘자 촌장 %s%s %s 자리를 하나 더 정했다." % [cn, josa(cn, "이", "가"), Balance.label(want)])
		return
	log_line("촌장 %s%s %s 자리를 정했다." % [cn, josa(cn, "이", "가"), Balance.label(want)])


## 땅 한계일 때 그 시대 집으로 넓혀 지을 작은 옛 집 — 바꿔도 정원 합계(cap_total - 옛 정원 + era_cap)가 limit 안인 첫 집.
## (예전엔 첫 작은 집 하나만 보고 멈춤 → 그 집이 맞지 않으면 다른 집이 맞아도 못 고름 — buildings 시험 5)
func upgrade_candidate(cap_total: int, era_cap: int, limit: float) -> Building:
	for b in buildings:
		if b.built and b.is_house() and b.upgrade_to == "" and b.cap() < era_cap:
			if cap_total + era_cap - b.cap() <= limit:
				return b
	return null


## 넓혀 지을 수 있는 그 종류의 건물 (다 지었고 개축 중이 아님) — 없으면 null
func _upgradable(type: String) -> Building:
	for b in buildings:
		if b.built and b.type == type and b.upgrade_to == "":
			return b
	return null


## (2026-11-13 Q26 · design/gdd/mayor-decisions.md F2 13번 칸) 일손이 남을 때 더 지을 일터 — 없으면 "".
## 촌장의 차례 맨 끝에서만 부른다 (다른 바람이 하나도 없을 때). 병 SPARE_FROM_DAY 날 뒤 · 일터 없는 성한 어른 SPARE_IDLE 명 이상 ·
## 빈 일터(캘 바위 없는 채석장 빼고, 짓는 일터 터 포함)가 창고 연장 수보다 적을 때 (연장이 없으면 빈 일터가 하나도 없을 때만 — 그 하나가 비면
## '연장이 모자라요' 신호가 켜진다, Q25). 먹을 것 → 땔감 → 재료 차례 (Balance.SPARE_ORDER)로 그 시대에 아는 · 자재가 되는 · 쓸모 있는 첫 종류.
## 읽기만 한다 (난수 · 상태 변경 없음)
func spare_want(skip := {}) -> String:
	if t < Balance.SPARE_FROM_DAY * DAY:
		return ""
	var hands := 0
	for p in people:
		if ToolShort.idle_hand(self, p):
			hands += 1
	if hands < Balance.SPARE_IDLE:
		return ""
	var empty := 0
	for b in buildings:
		if not b.def().get("job", false) or (b.built and b.worker >= 0):
			continue
		if b.type == "채석장" and quarry_no_rock(b):
			continue
		empty += 1                        # 다 지었는데 빈 일터 · 짓는 일터 터
	if empty >= maxi(1, floori(float(stock.get("도구", 0.0)))):
		return ""
	for ty: String in Balance.SPARE_ORDER:
		if skip.has(ty) or not VillageEra.can_build(self, ty) or not _affordable(ty):
			continue
		if Balance.SPARE_CAP.has(ty) and count_type(ty) >= int(Balance.SPARE_CAP[ty]):
			continue
		if _spare_useful(ty):
			return ty
	return ""


## 일손이 남을 때 이 일터가 쓸모 있나 (spare_want)
func _spare_useful(ty: String) -> bool:
	match ty:
		"농장":             # 창고 먹을 것이 SPARE_FOOD_DAYS 날치 아래 · 밭이 죽으로 먹일 사람(FARM_FEEDS)이 식구보다 적을 때만 (제물이 남는 먹을 것을 가져가 창고는 늘 2일치 남짓 — 날치만 보면 밭이 끝없이 는다)
			return food_total() < Balance.SPARE_FOOD_DAYS * Production.day_need(self) \
				and count_type("농장") * Balance.FARM_FEEDS < people.size()
		"어부":
			return Wildlife.fish_near(self)
		"버섯꾼":
			return flora != null and flora.trust and flora.edible_mature() >= 2
		"나무꾼":
			return _standing_trees() >= Balance.FOREST_MIN     # 벨 갈대 · 꽃대가 넉넉할 때만 (모자라면 산림관부터 — 예전 차례)
		"제재소":             # 켤 통나무가 쌓여 있고 돌이 넉넉할 때만 (병의 돌은 끝이 있다 — 일손 때문에 밭 · 집 몫의 돌을 쓰지 않게)
			return float(stock.get("통나무", 0.0)) >= float(Balance.ENOUGH["통나무"]) \
				and float(stock.get("돌", 0.0)) - _owed("돌") >= float(Balance.ENOUGH["돌"])
		"산림관":
			return count_type("나무꾼") >= 3                  # 벌목장이 늘었으면 묘목원도 하나 더
	return false


## [하늘의 것] 버섯꾼을 둘 만한가: 하늘의 것에 익숙해졌고 다 자란 먹는 버섯이 둘 넘게 서 있다
func _want_picker() -> bool:
	return flora != null and flora.trust and count_type("버섯꾼") == 0 and flora.edible_mature() >= 2


## 캘 것이 남은 돌 바위인가 (회색 바위 — 하얀 광맥 바위는 소금이라 세지 않는다)
func _stone_rock(rk: Dictionary) -> bool:
	return float(rk["amt"]) > 0.0 and String(rk.get("ore", "돌")) == "돌"


## 이 자리에 선 채석장의 둘레(Balance.GATHER_RANGE — ResidentAI.work_task가 석수를 보내는 범위)에 캘 돌 바위가 있나
func stone_in_reach(x: float, y: float) -> bool:
	for rk: Dictionary in rocks:
		if _stone_rock(rk) and Vector2(float(rk["x"]) - x, float(rk["y"]) - y).length() <= Balance.GATHER_RANGE:
			return true
	return false


## 이 채석장의 석수가 캘 바위가 둘레에 하나도 없나 — ResidentAI.work_task가 석수를 보내는 것과 같은 잣대
## (남은 양이 있고 캘 줄 아는 바위: 돌, 소금을 알면 하얀 광맥 바위도 · Balance.GATHER_RANGE 안). 다른 석수가 잠깐 맡아 둔 바위(res)도 '있는 것'으로 센다
func quarry_no_rock(b: Building) -> bool:
	for rk: Dictionary in rocks:
		if float(rk["amt"]) > 0.0 and SkyDrops.rock_minable(self, rk) and Vector2(float(rk["x"]) - b.x, float(rk["y"]) - b.y).length() <= Balance.GATHER_RANGE:
			return false
	return true


## 병 안에 캘 돌 바위가 하나라도 남았나 (닫힌 병 — 바위는 창조 때 정해지고 거인이 자갈을 떨어뜨릴 때만 는다, SHOP 2.4)
func stone_rocks_left() -> bool:
	for rk: Dictionary in rocks:
		if _stone_rock(rk):
			return true
	return false


## 채석장은 있는데 (짓는 터 포함) 어느 채석장 둘레에도 캘 돌 바위가 없다 — 돌이 더 들어올 길이 지금은 없다.
## 채석장이 하나도 없으면 false (첫 채석장은 예전 규칙대로). 저장하는 값 없이 지금 상태만 본다 (옛 저장 그대로).
func quarry_spent() -> bool:
	var any := false
	for b in buildings:
		if b.type == "채석장":
			any = true
			if stone_in_reach(b.x, b.y):
				return false
	return any


## 자재가 넉넉한가 — 짓고 있는 현장에 줄 몫을 빼고, 비상용 판자 4장은 남긴다 (나무꾼·제재소 제외, 9장)
func _affordable(type: String) -> bool:
	var d: Dictionary = Balance.B[type]
	var free_plank := float(stock["판자"]) - _owed("판자")
	var free_stone := float(stock["돌"]) - _owed("돌")
	var reserve := 0 if (type == "나무꾼" or type == "제재소") else Balance.PLANK_RESERVE
	return free_plank - int(d["plank"]) >= reserve and free_stone - int(d["stone"]) >= 0


func _standing_trees() -> int:
	var n := 0
	for tr: Dictionary in trees:
		if tr["s"] == "tree":
			n += 1
	return n


func is_free(x: float, y: float, size: float) -> bool:
	if not water.inside(x, y, size + 1.2):
		return false
	if not in_territory(x, y, size):           # 영역 안에만 짓는다 (기획서 3.1)
		return false
	if Vector2(altar_pos.x - x, altar_pos.y - y).length() < size + ALTAR_CLEAR:
		return false
	if water_at(x, y):
		return false
	for a in 6:
		if water_at(x + cos(a) * (size + 0.4), y + sin(a) * (size + 0.4)):
			return false
	for b in buildings:
		if Vector2(b.x - x, b.y - y).length() < b.size() + size + 0.6:
			return false
	if Vector2(fire.x - x, fire.y - y).length() < size + 1.2:
		return false
	for r: Dictionary in rocks:
		if Vector2(r["x"] - x, r["y"] - y).length() < size + 0.8:
			return false
	if flora != null and flora.blocks(x, y, size):    # [하늘의 것] 큰 버섯의 굵은 대 둘레에는 짓지 않는다
		return false
	if VillagePlan.blocks(self, x, y, size):           # [배치] 광장·큰길 위에는 짓지 않는다 (sim/village_plan.gd)
		return false
	if SkyDrops.blocks(self, x, y, size):              # [상점] 하늘에서 내려온 물건·앰플 탑 자리
		return false
	if GreatTrees.blocks(water, x, y, size):           # 큰 나무 다섯의 줄기 둘레 (GD 3.0 — 베지 않음)
		return false
	if GiantPlants.blocks(water, x, y, size):          # 해바라기 줄기 둘레 (flower-forest R3 SF_TRUNK_R)
		return false
	return true


## 마을 중심에서 가까운 빈 땅부터 나선형으로. 나무꾼은 숲 옆, 채석장은 바위 옆, 농장은 따뜻하고 촉촉한 곳
## 자리 찾기 동안은 건물이 바뀌지 않는다 → 영역 반지름(건물을 모두 도는 계산)을 이 마을·이웃 무리마다 한 번만 (is_free가 수백 번 묻는다 — 같은 값)
func find_spot(type: String) -> Variant:
	var fixed: Array[Village] = [self]
	for o: Village in peers:
		if o != self and o._tr_fix < 0.0:
			fixed.append(o)
	if _tr_fix >= 0.0:
		fixed.erase(self)
	for q: Village in fixed:
		q._tr_fix = q.territory_r()
	var out: Variant = _find_spot(type)
	for q: Village in fixed:
		q._tr_fix = -1.0
	return out


func _find_spot(type: String) -> Variant:
	var planned: Variant = VillagePlan.find_spot(self, type)      # [배치] 광장·큰길 계획 (sim/village_plan.gd) — 계획 밖 종류면 null → 아래 옛 방식
	if planned != null:
		return planned
	var size: float = Balance.B[type]["size"]
	var c := center
	if type == "나루터":                       # 물가 (건너편이 보이는 곳 — A6)
		var fp: Variant = VillageEra.ferry_spot(self)
		if fp != null:
			_clear_trees(fp, size)
		return fp
	if Siting.is_resource_type(type) and Siting.active(self):          # [자리 잡기] 일터는 재료 곁 — 점수로 고름 (sim/siting.gd · BUILDINGS.md '자리 잡기 다시')
		var rs: Variant = Siting.resource_spot(self, type)
		if rs != null:
			_clear_trees(rs, size)
			return rs
	var ec: Variant = VillageEra.spot_center(self, type)     # 약초꾼 = 습한 숲가 · 묘지 = 마을 끝 · 망루 = 안개 쪽
	if ec != null:
		c = ec
	if type == "버섯꾼" and flora != null:     # [하늘의 것] 큰 버섯 곁
		var best: Dictionary = {}
		for s: Dictionary in flora.shrooms:
			if flora.mature(s) and (best.is_empty() or Vector2(s["x"], s["y"]).distance_to(center) < Vector2(best["x"], best["y"]).distance_to(center)):
				best = s
		if not best.is_empty():
			c = center + (Vector2(best["x"], best["y"]) - center) * 0.7
	elif type == "나무꾼" or type == "산림관":
		var best: Dictionary = {}
		for tr: Dictionary in trees:
			if tr["s"] == "tree" and (best.is_empty() or Vector2(tr["x"], tr["y"]).distance_to(center) < Vector2(best["x"], best["y"]).distance_to(center)):
				best = tr
		if not best.is_empty():
			c = center + (Vector2(best["x"], best["y"]) - center) * 0.85
	elif type == "채석장":
		var best: Dictionary = {}
		for r: Dictionary in rocks:
			if r["amt"] > 0 and SkyDrops.rock_minable(self, r) and (best.is_empty() or Vector2(r["x"], r["y"]).distance_to(center) < Vector2(best["x"], best["y"]).distance_to(center)):
				best = r
		if not best.is_empty():
			c = center + (Vector2(best["x"], best["y"]) - center) * 0.8
	elif type == "농장":
		var best_p: Variant = null
		var bv := 0.0
		var graves := VillageEra.has_graves(self)      # (Q8 ⑧) 무덤·묘지를 가리지 않는 자리부터 — 없으면 예전 규칙 (주사위 수는 그대로)
		var clear_p: Variant = null
		var cv := 0.0
		for k in 200:
			var a := rng.randf() * TAU
			var d := 3.0 + rng.randf() * 14.0
			var x := center.x + cos(a) * d
			var y := center.y + sin(a) * d
			var val := farm_mult(x, y) - d * 0.02
			if val > bv and is_free(x, y, size):
				bv = val
				best_p = Vector2(x, y)
			if graves and val > cv and not VillageEra.field_by_grave(self, Vector2(x, y)) and is_free(x, y, size):
				cv = val
				clear_p = Vector2(x, y)
		if clear_p != null:
			best_p = clear_p
		if best_p != null:
			_clear_trees(best_p, size)
			return best_p
	elif type == "소금밭":
		var f: Variant = salt_flat_near()
		if f != null:
			var fv: Vector2 = f
			var d := 0.0
			while d < 6.0:
				for a in 12:
					var p := fv + Vector2(cos(a / 2.0), sin(a / 2.0)) * d
					if is_free(p.x, p.y, size):
						_clear_trees(p, size)
						return p
				d += 0.5
	var tr_r := territory_r()
	for pass_i in (2 if type == "묘지" else 1):       # (Q8 ⑨) 묘지는 먼저 밭 안·밭 바로 뒤가 아닌 자리를 찾고, 없으면 예전 규칙대로
		var rad := 2.0
		while rad < tr_r:
			for k in 24:
				var a := k / 24.0 * TAU + rad
				var p := c + Vector2(cos(a), sin(a)) * rad
				if is_free(p.x, p.y, size) and (type != "묘지" or pass_i == 1 or not VillageEra.yard_by_field(self, p)):
					_clear_trees(p, size)
					return p
			rad += 0.8
	return null


func _clear_trees(p: Vector2, size: float) -> void:
	trees = trees.filter(func(tr: Dictionary) -> bool: return Vector2(tr["x"] - p.x, tr["y"] - p.y).length() > size + 0.4)
	if flora != null:
		flora.clear_at(p, size)       # [하늘의 것] 짓는 자리의 민들레


# ───────────────────────── 호수·소금의 발견 ─────────────────────────
func lake_watch() -> void:
	for i in water.basins.size():
		var b: Dictionary = water.basins[i]
		var a0: int = b["area0"]
		if a0 <= 0:
			continue
		if _fog_on and (not water.revealed(b["x"], b["y"], sid) or Vector2(b["x"], b["y"]).distance_to(center) > WorldCfg.LAKE_WATCH_R):
			continue
		var f := float(water.basin_area(b)) / a0
		var nm: String = b["name"]
		if basins_said[i] < 1 and f < 0.8:
			basins_said[i] = 1
			log_line("%s의 물가가 조금씩 물러난다. 이 호수로 흘러드는 강이 없다." % nm)
		if basins_said[i] < 2 and f < 0.5:
			basins_said[i] = 2
			crisis("lake", "%s%s 절반 넘게 말랐다" % [nm, josa(nm, "이", "가")])
			log_line("%s%s 절반 넘게 말랐다. 드러난 호수 바닥에 흰 소금기가 번진다." % [nm, josa(nm, "이", "가")])
			var elder: Resident = null
			for q in people:
				if q.age >= 15.0 and (elder == null or q.age > elder.age):
					elder = q
			if elder != null:
				speak(elder, "내가 어릴 적엔 저기까지 물이었지", 7)
		if basins_said[i] < 3 and f < 0.12:
			basins_said[i] = 3
			crisis("lake", "%s%s 사라졌다" % [nm, josa(nm, "이", "가")])
			log_line("%s%s 마침내 사라졌다. 그 자리에 하얀 소금 들판이 남았다. 아이들은 그곳에 호수가 있었다는 걸 믿지 않는다." % [nm, josa(nm, "이", "가")])


## 소금의 발견: 하얀 들판이 넓게 드러나면 곁을 지나던 누군가(주로 아이)가 맛본다 (기획서 4.5)
func salt_discovery() -> void:
	if salt_known:
		return
	var flat := 0
	var fc := Vector2.ZERO
	if water is WorldWater:               # 넓은 세상: 같은 값을 빠르게 (소금 없는 거친 칸은 건너뜀)
		var sc: Array = (water as WorldWater).salt_flat_scan(center, view_r * 1.5, 0.004, 0.003)
		flat = sc[0]
		fc = sc[1]
	else:
		for k in water.village_cells(center, view_r * 1.5):
			if water.depth(k) < 0.004 and water.salt_k(k) > 0.003:
				flat += 1
				fc += Vector2(water.cx(k), water.cy(k))
	if flat < 45:
		return
	fc /= flat
	var near := people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5 and Vector2(q.x, q.y).distance_to(fc) < 12.0)
	if near.is_empty() and rng.randf() > 0.25:
		return
	var who: Resident = null
	for q: Resident in near:
		if q.age < 8.0:
			who = q
			break
	if who == null and not near.is_empty():
		who = near[0]
	if who == null:
		var any := people.filter(func(q: Resident) -> bool: return q.age >= 2.5)
		if any.is_empty():
			return
		who = any[rng.randi() % any.size()]
	Discovery.make(self, "salt", who, "", Balance.SALT_DISCOVERY_PTS)     # 도감 · 시대 점수 · 연대기 · "짜다!" (sim/codex.gd 표)
	salt_known = true
	# 해석 (DISCOVERIES 1.6) — 깨닫기 전에는 거인 이야기가 없다
	if not aware:
		log_line("사람들은 짠 흙을 조금씩 모아 두었다. 고기와 생선에 뿌리면 오래 간다는 것을 곧 알게 되었다.")
	else:
		log_line("어떤 이는 {w:이/가} 호수를 소금으로 바꾸셨다 하고, 어떤 이는 그냥 물이 마른 것뿐이라 했다." if doubters() > 0 else "사람들은 {w:이/가} 호수를 거두어 소금을 남기셨다고 믿었다.")


# ───────────────────────── 판매가 (기획서 11장 — 판매는 거인만, 여기선 값 계산만) ─────────────────────────
## 판매가 = 100지폐 × 등급 × (0.5 + 0.1 × 가장 높은 숙련) × 나이(1.0/0.8/0.6) × 혈통 × 건강 × 0.95^(n−1)
static func sale_price(r: Resident, nth := 1, lineage := false, sick := false) -> float:
	if r.is_child():
		return 0.0
	var age_m: float = Balance.PRICE_AGE[0]
	if r.age >= Balance.PRICE_AGE_OLD:
		age_m = Balance.PRICE_AGE[2]
	elif r.age >= Balance.AGE_ELDER:
		age_m = Balance.PRICE_AGE[1]
	var p: float = Balance.PRICE_BASE * Balance.GRADE_MULT[r.grade] * (Balance.PRICE_SKILL_BASE + Balance.PRICE_SKILL_STEP * r.best_skill()) * age_m
	if lineage:
		p *= Balance.PRICE_LINEAGE
	if sick:
		p *= Balance.PRICE_SICK
	return p * pow(Balance.PRICE_REPEAT, nth - 1)


# ───────────────────────── 오솔길 ─────────────────────────
## 한 번이라도 밟힌 칸 목록 (오솔길 옅어짐이 16,384칸을 다 돌지 않게). 저장하지 않고 처음 쓸 때 paths에서 다시 만든다
func _path_rebuild_nz() -> void:
	_pnz = PackedInt32Array()
	_pnz_in = PackedByteArray()
	_pnz_in.resize(paths.size())
	for i in paths.size():
		if paths[i] != 0.0:
			_pnz.append(i)
			_pnz_in[i] = 1
	_pnz_ok = true


func _path_touch(i: int) -> void:
	if _pnz_ok and _pnz_in[i] == 0:
		_pnz_in[i] = 1
		_pnz.append(i)


func mark_path(x: float, y: float, amt: float) -> void:
	var gx := floori((x - center.x + path_r) / (2.0 * path_r) * path_n)
	var gy := floori((y - center.y + path_r) / (2.0 * path_r) * path_n)
	if gx >= 0 and gy >= 0 and gx < path_n and gy < path_n:
		var pi := gy * path_n + gx
		paths[pi] = minf(60.0, paths[pi] + amt)
		_path_touch(pi)
	if _fog_on:
		_reveal_walk(x, y)


## 걸은 선분 a → b 위의 칸마다 오솔길을 남긴다 (몰아서 계산하는 긴 걸음도 끊기지 않게 — 칸 크기 간격)
func mark_path_seg(a: Vector2, b: Vector2) -> void:
	var ln := a.distance_to(b)
	var cell := 2.0 * path_r / path_n
	var n := maxi(1, ceili(ln / cell))
	var amt := ln / n
	for i in n:
		var p := a.lerp(b, float(i + 1) / n)
		var gx := floori((p.x - center.x + path_r) / (2.0 * path_r) * path_n)
		var gy := floori((p.y - center.y + path_r) / (2.0 * path_r) * path_n)
		if gx >= 0 and gy >= 0 and gx < path_n and gy < path_n:
			var pi := gy * path_n + gx
			paths[pi] = minf(60.0, paths[pi] + amt)
			_path_touch(pi)
	if _fog_on:
		_reveal_walk(b.x, b.y)


## 그 자리의 오솔길 값 (걸은 거리, 0~60). 격자 밖이면 0
func path_at(x: float, y: float) -> float:
	var gx := floori((x - center.x + path_r) / (2.0 * path_r) * path_n)
	var gy := floori((y - center.y + path_r) / (2.0 * path_r) * path_n)
	if gx >= 0 and gy >= 0 and gx < path_n and gy < path_n:
		return paths[gy * path_n + gx]
	return 0.0


## 흙길인가 (기획서 6.7 '길은 발길이 만든다' — 많이 밟은 칸, 안 다니면 옅어진다)
func is_road(x: float, y: float) -> bool:
	return path_at(x, y) >= Balance.PATH_AT


## 걸음 배율 — 흙길 위는 빠르다
func path_mult(x: float, y: float) -> float:
	return Balance.PATH_SPEED if path_at(x, y) >= Balance.PATH_AT else 1.0


# ───────────────────────── 등불 옮기기 (기획서 4.6 · A11 — sim/lamp.gd) ─────────────────────────
## 등불(해)을 병 둘레 네 자리 중 dir (0~3)로 옮긴다. 이미 그 자리면 false.
## 넓은 세상: 데이터는 그대로, 빛만 돈다 (WorldWater.rotate_jar) — 같은 병의 모든 무리가 함께 겪는다.
## 소형 병: 물·지형과 병 안의 모든 것이 (x, y) → (−y, x)로 돈다 (JarWater.rotate_jar — 같은 뜻).
## 그날 LAMP_FREE_PER_DAY(1)번까지는 두렵지 않고, 2번째부터 두려움↑ (한 번 옮기기 = 한 번 — 몇 칸을 건너든, 톡과 따로 셈 —
## design/gdd/giant-touch.md R4 · F2). 깨달은 뒤엔 믿음↑, 깨닫기 전에는 목격(경이)만.
func move_lamp(dir: int) -> bool:
	dir = posmod(dir, 4)
	var steps := posmod(dir - Lamp.spot(water), 4)
	if steps == 0:
		return false
	var vills: Array = [self] + others if water is WorldWater else [self]
	var pv := Lamp.preview(vills, water, dir)      # 옮기기 전에 셈한 변화 (연대기 한 줄)
	if water is WorldWater:
		for i in steps:
			water.rotate_jar()
	else:
		for i in steps:
			_turn_data()
	for v: Village in vills:
		v._after_lamp(pv)
	giant_acted()
	return true


## 옛 이름 (병 돌리기 = 등불을 다음 자리로 한 칸) — 옛 시험·도구가 부름
func rotate_jar() -> void:
	move_lamp(Lamp.spot(water) + 1)


## 소형 병: 병 안의 모든 것을 90° 돌림 (데이터)
func _turn_data() -> void:
	water.rotate_jar()
	var rp := func(o: Dictionary) -> void:
		var x: float = o["x"]
		o["x"] = -float(o["y"])
		o["y"] = x
	for list: Array in [trees, rocks, manna, drops, towers, algae, graves, veins]:     # [상점] 하늘에서 내려온 것 · 무덤도 병과 함께 돈다
		for o: Dictionary in list:
			rp.call(o)
	for b in buildings:
		var x := b.x
		b.x = -b.y
		b.y = x
		if b.has_link:
			var lx := b.link_x
			b.link_x = -b.link_y
			b.link_y = lx
		if b.has_spot:
			var sx := b.spot_x
			b.spot_x = -b.spot_y
			b.spot_y = sx
	for p in people:
		var x := p.x
		p.x = -p.y
		p.y = x
		for s: Dictionary in p.steps:
			if s["k"] == "walk":
				rp.call(s)
	fire = JarWater.rot_pt(fire)
	altar_pos = JarWater.rot_pt(altar_pos)
	mold.rotate()                     # [곰팡이·뚜껑] 털뭉치도 병과 함께 돈다
	smalls.rotate()                   # [작은 위기] 날벌레·물방울·먼지 뭉치도
	hand.rotate()                     # [거인의 손] 적신 자리
	flora.rotate()                    # [하늘의 것] 버섯·민들레·꽃씨도
	if owns_water and wild != null:
		wild.rotate()                 # [들짐승] 무리 자리도
	var np := PackedFloat32Array()
	np.resize(PATH_N * PATH_N)
	for j in PATH_N:
		for i in PATH_N:
			np[i * PATH_N + (PATH_N - 1 - j)] = paths[j * PATH_N + i]
	paths = np
	_pnz_ok = false


## 옮긴 뒤 (무리마다): 두려움 규칙 · 믿음 · 밭 배율 다시 · 연대기 · 목격 · "해가 옮겨갔다!"
func _after_lamp(pv: Dictionary) -> void:
	_fear_rotate()
	for b in buildings:
		b.farm_mult = -1.0
	if aware:                             # 깨닫기 전엔 경이만 (giant-touch R5)
		bless_all(0.06)
	lamp_moved_t = t
	Discovery.on_lamp(self)               # 발견 S3 해의 길 — 이때 있던 노인들
	lamp_last = {"from": int(pv.get("from", 0)), "to": int(pv.get("to", 0)), "up": int(pv.get("up", 0)) + int(pv.get("new", 0)),
		"down": int(pv.get("down", 0)) + int(pv.get("gone", 0)), "t": t}
	stats["lamp_moves"] = int(stats.get("lamp_moves", 0)) + 1
	log_line(Lamp.chronicle(pv))
	Awakening.witness(self, "lamp")
	var scared := int(_rots[1]) > Balance.LAMP_FREE_PER_DAY
	touch_event(&"lamp", int(_rots[1]), not scared)
	var said := 0
	for r in people:
		if said >= 2:
			break
		if r.sleeping or r.is_baby() or r.age < 2.5:
			continue
		speak(r, Balance.LINE_LAMP_FEAR if scared else (Balance.LINE_LAMP_MOVED if said == 0 else "그림자가 돌아누웠어!"), 7)
		said += 1


## 등불을 처음 옮기려 할 때 노인의 귀띔 (GD 4.6 — 한 번만): {who: 주민, text}. 이미 들었거나 말할 사람이 없으면 {}
func lamp_hint() -> Dictionary:
	if lamp_hinted:
		return {}
	lamp_hinted = true
	var elder: Resident = null
	for r in people:
		if r.is_elder() and not r.is_baby() and r.sick_left <= 0.0 and (elder == null or r.age > elder.age):
			elder = r
	if elder == null:
		elder = chief()
	if elder == null:
		return {}
	var txt := WatcherName.fill(self, Balance.LINE_LAMP_HINT) if aware else Balance.LINE_LAMP_HINT_UNAWARE
	return {"who": elder, "text": txt}


# ───────────────────────── 제단·제물·소원·분가 (기획서 3.1 · 6.7 · 11.1, RESIDENT_AI 2.1 · 6.2) ─────────────────────────
## 소원 편지의 말 (주민 말 — 금지어 없음)
const WISH_REASON := {
	"농장": "밭을 일구고 싶어요. 하늘 낟알이 언제까지나 내리진 않을 테니까요.",
	"우물": "물 길으러 너무 멀리 가요… 우물을 파고 싶어요.",
	"나무꾼": "나무를 더 베어 올 나무꾼 오두막을 짓고 싶어요.",
	"제재소": "통나무를 판자로 켜는 제재소를 짓고 싶어요.",
	"채석장": "바위에서 돌을 캐는 채석장을 짓고 싶어요.",
	"산림관": "숲이 줄어요. 나무를 심는 산림관을 두고 싶어요.",
	"소금밭": "하얀 들판에서 소금을 긁는 소금밭을 만들고 싶어요.",
	"방앗간": "밀을 빻는 방앗간을 짓고 싶어요.",
	"맷돌간": "밀을 날로는 못 먹어요. 맷돌로 가루를 빻고 싶어요.",
	"화덕": "모닥불 곁에 다 같이 빵을 굽는 공용 화덕을 짓고 싶어요.",
	"빵집": "빵 굽는 냄새가 나는 빵집을 짓고 싶어요.",
	"버섯꾼": "하늘에서 솟은 큰 버섯을 베어 올 버섯꾼을 두고 싶어요.",
}


func _economy_tick() -> void:
	if not altar_built:                   # 제단 전에는 제물도 소원 편지도 없다 (6.5 · 11.1). 분가는 그래도 (땅이 차면)
		_check_split()
		return
	_expire_offerings()
	var ok := _prayer_key()
	if _offer_key < 0 and ok % 2 == 0:    # 처음 확인이 아침이면 그 아침은 지나간 것으로 (도착한 아침엔 기도 모임 없음 — 첫 저녁부터)
		_offer_key = ok
	elif ok > _offer_key:                 # v5: 아침·저녁 기도 (반나절치씩)
		_offer_key = ok
		evening_offering()
	if t >= _next_wish_t:
		_next_wish_t = t + econ_rng.randf_range(Balance.WISH_EVERY[0], Balance.WISH_EVERY[1])
		if write_wish().is_empty():
			_next_wish_t = t + 2.0 * HOUR     # 바랄 것이 없으면 조금 뒤 다시
	for l: Dictionary in letters:
		if l["kind"] == "wish" and l["state"] == "open" and t - float(l["t"]) > Balance.WISH_KEEP:
			l["state"] = "done"           # 들어주지 않아도 언젠가 스스로 짓는다
	_check_split()


func _starving() -> bool:
	return deficit > 0.0 or t - last_short_t < Balance.STARVED_RECENT


func _has_built(type: String) -> bool:
	for b in buildings:
		if b.built and b.type == type:
			return true
	return false


## 거인님이 좋아하신다고 믿는 물건 (받은 제물)
func is_favourite(item: String) -> bool:
	return float(favourites.get(item, 0.0)) >= Balance.FAV_MIN


## 짓는 속도 배율 — 들어준 소원은 ×1.5 (기획서 6.7)
func build_mult(b: Building) -> float:
	return (Balance.WISH_SPEED if b.wished else 1.0) * SkyDrops.site_boost(self, b) * Notebook.first_build_mult(self, b)     # [거인의 수첩] 하늘에서 내려온 통나무를 터로 나름


## 아직 열려 있는 편지
func open_letters(kind := "") -> Array:
	return letters.filter(func(l: Dictionary) -> bool: return l["state"] == "open" and (kind == "" or l["kind"] == kind))


# ── 소원 편지 ──
func _wish_pick() -> String:
	var taken := {}
	for w: String in wishes:
		taken[w] = true
	for l: Dictionary in open_letters("wish"):
		taken[l["type"]] = true
	var c: Array[String] = []
	if count_type("농장") == 0:
		c.append("농장")
	if count_type("우물") == 0:
		c.append("우물")
	if count_type("나무꾼") < 2:
		c.append("나무꾼")
	if count_type("제재소") == 0:
		c.append("제재소")
	if count_type("채석장") == 0:
		c.append("채석장")
	if count_type("농장") > 0 and count_type("맷돌간") + count_type("방앗간") == 0:
		c.append("맷돌간")
	if count_type("농장") > 0 and count_type("화덕") + count_type("빵집") == 0:
		c.append("화덕")
	if era >= 1 and count_type("방앗간") == 0:
		c.append("방앗간")
	if era >= 2 and count_type("빵집") == 0:
		c.append("빵집")
	if salt_known and count_type("소금밭") == 0 and salt_flat_near() != null:
		c.append("소금밭")
	if count_type("산림관") == 0 and _standing_trees() < Balance.FOREST_MIN * 2:
		c.append("산림관")
	if _want_picker():
		c.append("버섯꾼")
	if count_type("농장") < 3 and farm_rate() < people.size() * (HOUR / Balance.FOOD_IV) * Balance.FARM_SAFETY * 1.3:
		c.append("농장")
	c = c.filter(func(ty: String) -> bool: return not taken.has(ty))
	if c.is_empty():
		return ""
	return c[econ_rng.randi() % mini(2, c.size())]


## 주민이 소원 편지를 보낸다 (하루 1~2통) — type을 주면 그 건물로 (테스트·튜토리얼)
func write_wish(type := "") -> Dictionary:
	var ty := type if type != "" else _wish_pick()
	if ty == "":
		return {}
	var adults := people.filter(func(q: Resident) -> bool: return q.age >= Balance.AGE_ADULT)
	if adults.is_empty():
		return {}
	var who: Resident = adults[econ_rng.randi() % adults.size()]
	_letter_id += 1
	var text: String = WISH_REASON.get(ty, "%s%s 짓고 싶어요." % [Balance.label(ty), josa(Balance.label(ty), "을", "를")])
	var l := {"id": _letter_id, "kind": "wish", "t": t, "from": who.id, "name": who.name, "type": ty, "text": text, "state": "open"}
	letters.append(l)
	speak(who, "{w}, 소원이 있어요", 6)
	return l


## [들어준다] — 믿음↑, 그 건물이 우선순위 맨 위, 짓는 속도 ×1.5 (비용 없음)
func grant_wish(id: int) -> bool:
	for l: Dictionary in letters:
		if int(l["id"]) != id or l["kind"] != "wish" or l["state"] != "open":
			continue
		if ToolShort.is_tool_wish(l):
			return false                  # (Q25) '연장이 모자라요'는 연장 꾸러미를 떨어뜨려야 이루어진다 (ToolShort.given)
		if StoneShort.is_stone_wish(l):
			return false                  # (Q30) '돌이 모자라요'는 자갈 한 알 · 회색 돌멩이를 떨어뜨려야 이루어진다 (StoneShort.given)
		l["state"] = "granted"
		var ty: String = l["type"]
		if not Production.knows(self, ty):
			blueprints[ty] = t                # v5: 들어준 소원 = 거인이 짓는 법을 일러 줌 (설계도 없이도)
		var site: Building = null
		for b in buildings:
			if b.is_site() and b.site_type() == ty and not b.wished:
				site = b
				break
		if site != null:
			site.wished = true
		else:
			wishes.append(ty)
		bless_all(Balance.WISH_BELIEF)
		_update_belief(0.0)
		var who := person(int(l["from"]))
		if who != null:
			speak(who, "{w:이/가} 들어주셨다!", 7)
		log_line("{w:이/가} %s의 소원을 들어주셨다. 사람들은 %s부터 짓기로 했다." % [l["name"], Balance.label(ty)])
		emit(&"wish_granted", {"who": int(l["from"]), "v": {"id": id, "how": &"help", "type": ty}})   # 연출은 화면이 (EVENTS_STAGING 6)
		giant_acted()
		Notebook.on(self, "wish")          # [거인의 수첩]
		return true
	return false


# ── 제물 ──
## 지금까지 지난 마지막 기도의 번호 (달력 날 × 2 + 아침 0 · 저녁 1) — 첫 기도 전이면 그 전 저녁
func _prayer_key() -> int:
	var h := hour_now()
	var d := cal_day(t)
	if h >= float(Balance.OFFER_HOURS[1]):
		return d * 2 + 1
	if h >= float(Balance.OFFER_HOURS[0]):
		return d * 2
	return d * 2 - 1


## 밭(빵을 굽게 되면 ×1.5, 아니면 죽 ×0.75)이 마을이 먹는 만큼 거두나
func _food_steady() -> bool:
	var bakes := bakes_now()
	var yld := Balance.BREAD_YIELD if bakes else Balance.PORRIDGE_YIELD
	return farm_rate(true) * yld * 24.0 >= Production.day_need(self)


## 이 물건을 마을이 만드나 (그 일터나 그 일을 대신하는 더 큰 건물이 있다 · 일터 없이 만드는 것)
func makes(item: String) -> bool:
	if item in Balance.OFFER_EXTRA:
		return true
	if _has_built(String(Balance.PRODUCER.get(item, ""))):
		return true
	for ty: String in Balance.PRODUCER_ALSO.get(item, []):
		if _has_built(ty):
			return true
	return false


## 남는 물건 {물건: 개수} — 마을이 만드는 물건만, 거인이 준 몫은 빼고 (되팔기 막기 — v5).
## 넉넉한 양의 절반(인구에 맞게 늘어남)·짓는 데 줄 몫·먹을 것 OFFER_FOOD_KEEP_DAYS일치는 남긴다. 값진 것부터 (빵 → … → 밀)
func surplus() -> Dictionary:
	var out := {}
	var food_spare := food_total() - Production.day_need(self) * Balance.OFFER_FOOD_KEEP_DAYS
	if not _food_steady():
		food_spare = 0.0                  # v5: 밭이 먹는 만큼 못 거두면 먹을 것은 바치지 않는다 (굶주림 멸망 막기)
	var items: Array = Balance.PRODUCER.keys() + Balance.OFFER_EXTRA
	items.sort_custom(func(a: String, b: String) -> bool:
		var pa := float(Balance.PRICE.get(a, 0.0))
		var pb := float(Balance.PRICE.get(b, 0.0))
		return pa > pb if pa != pb else a < b)
	for item: String in items:
		if not makes(item):
			continue
		var have := Production.own_stock(self, item)
		var s := 0.0
		if item in Balance.FOODS:
			s = clampf(food_spare, 0.0, have)
			food_spare -= s
		elif item == Balance.PORRIDGE:       # 밀: 죽 값으로 남는 몫 (먹을 몫을 다 남긴 뒤)
			s = clampf(food_spare / Balance.PORRIDGE_YIELD, 0.0, have)
			food_spare -= s * Balance.PORRIDGE_YIELD
		else:
			s = have - enough(item) * Balance.OFFER_KEEP
			if item == "판자" or item == "돌":
				s -= _owed(item)
		if s >= 1.0:
			out[item] = s
	return out


## 바치는 비율 = 0.3 + 0.7 × 마을 믿음 (좋아하시는 물건은 +0.2)
func offer_factor(item := "") -> float:
	var f := Balance.OFFER_BASE + Balance.OFFER_FAITH * faith / 100.0
	if item != "" and is_favourite(item):
		f += Balance.OFFER_FAV_BONUS
	return clampf(f, 0.0, 1.0)


## 기도 (아침·저녁) — 제단에 제물을 올린다. 올린 것 {물건: 개수}.
## v5: 한 번에 남는 물건 × OFFER_SHARE × 비율. 제단이 가득 차거나 다시 짓는 중이면 기도만 하고 올리지 않는다 (sim/altar.gd)
func evening_offering() -> Dictionary:
	if not altar_built:
		return {}
	_expire_offerings()
	_offer_day = cal_day(t)
	var by := PackedInt32Array()
	for p in people:
		if p.age >= Balance.AGE_ADULT:
			by.append(p.id)
	if by.is_empty():
		return {}
	var starving := _starving()
	var got := {}
	var om := VillageEra.offer_mult(self)     # 교회 = 큰 제단 ×1.3 (A6)
	VillageEra.evening_bell(self)
	var room := not Altar.full(self) and not Altar.rebuilding(self)
	if not room and int(stats.get("altar_full", 0)) == 0 and Altar.full(self):
		log_line("제단에 더 놓을 자리가 없었다. 사람들은 남는 것을 창고에 둔 채 기도만 드렸다.")
	if not room:
		stats["altar_full"] = int(stats.get("altar_full", 0)) + 1
	var sp := surplus() if room else {}
	var key := _prayer_key()
	var budget := people.size() * Balance.OFFER_VALUE_PER * 0.5 * offer_factor() * om     # v5: 바치는 값의 상한 (사람 수 × 믿음)
	var order: Array = sp.keys()          # 값진 것부터 (좋아하시는 것은 ×1.3로 쳐서 조금 앞으로)
	order.sort_custom(func(a: String, b: String) -> bool:
		var pa := float(Balance.PRICE.get(a, 1.0)) * (1.3 if is_favourite(a) else 1.0)
		var pb := float(Balance.PRICE.get(b, 1.0)) * (1.3 if is_favourite(b) else 1.0)
		return pa > pb if pa != pb else a < b)
	for item: String in order:
		if item in Balance.FOODS or item == Balance.PORRIDGE:
			if starving and fear < Balance.OFFER_FEAR_FOOD:
				continue                      # 굶주리는 마을은 식량을 바치지 않는다
		var price := maxf(0.1, float(Balance.PRICE.get(item, 1.0)))
		var amt := mini(floori(float(sp[item]) * Balance.OFFER_SHARE * offer_factor(item) * om), floori(Production.own_stock(self, item)))
		amt = mini(amt, floori(budget / price))
		if amt < 1:
			continue
		budget -= amt * price
		stock[item] = float(stock[item]) - amt
		_put_offering(item, amt, by, key)
		got[item] = amt
	if room and got.is_empty() and int(stats.get("offered", 0)) == 0 and not starving:
		_first_token(by, got)            # 첫 저녁 기도: 남는 게 없어도 만든 것 몇 개 (OPENING T3 — BALANCE v4-4)
	if not in_opening():
		Awakening.gather_ring(self, Awakening.EVENING_RING, "저녁 기도하는 중" if hour_now() >= 12.0 else "아침 기도하는 중", true)     # 일손을 놓은 사람들이 제단 둘레에 모여 제단을 바라봄
	if room and starving and fear >= Balance.OFFER_FEAR_FOOD:     # 두려움이 높은 마을은 굶으면서도 바친다 (연대기의 어두운 이야기)
		var dark := false
		for item: String in ["빵", "밀", "건량"]:
			var amt := floori(Production.own_stock(self, item) * Balance.OFFER_FEAR_FOOD_SHARE)
			if amt >= 1:
				stock[item] = float(stock[item]) - amt
				_put_offering(item, amt, by, key)
				got[item] = int(got.get(item, 0)) + amt
				dark = true
		if dark:
			log_line("굶주리는 저녁에도 사람들은 마지막 곡식을 제단에 올렸다. {w:이/가} 노하실까 두려웠다.")
	if not got.is_empty():
		if int(stats.get("offered", 0)) == 0:
			var first: String = got.keys()[0]
			log_line("저녁 기도 때 사람들이 모닥불 곁 돌 제단에 남는 %s%s 바쳤다." % [first, josa(first, "을", "를")])
		stats["offered"] = int(stats.get("offered", 0)) + 1
		var who := person(by[econ_rng.randi() % by.size()])
		if who != null and not who.sleeping:
			speak(who, "{w}, 받아 주세요", 6)
	return got


## 첫 저녁 기도에 남는 물건이 없으면 마을이 만드는 물건 중 가장 많은 것을 몇 개 (FIRST_OFFER_TOKEN) — '첫 제물'이 늘 생기게.
## (A29 걸음 0.7칸/초 — 첫날 통나무가 바닥날 수 있어) 만드는 것이 없으면 창고의 다른 자재(판자·돌 등, 하늘에서 온 몫은 빼고)라도 한 개부터
func _first_token(by: PackedInt32Array, got: Dictionary) -> void:
	var best := ""
	var bh := 0.0
	var any_work := Balance.PRODUCER.keys().any(func(k: String) -> bool: return makes(k))     # 일터가 하나도 없는 마을은 대신 바치지 않음 (만들지 않는 물건은 바치지 않는다)
	for pass_made: bool in ([true, false] if any_work else [true]):
		for item: String in Balance.PRODUCER:
			if (pass_made and not makes(item)) or item in Balance.FOODS or item == Balance.PORRIDGE:
				continue
			var h := Production.own_stock(self, item)
			if h > bh:
				bh = h
				best = item
		if bh >= 1.0:
			break
	var amt := mini(Balance.FIRST_OFFER_TOKEN, maxi(1, floori(bh * 0.5)))
	if best == "" or bh < 1.0:
		return
	stock[best] = float(stock[best]) - amt
	_put_offering(best, amt, by, _prayer_key())
	got[best] = amt


func _put_offering(item: String, amt: int, by: PackedInt32Array, key := -1) -> void:
	var o := {"item": item, "amt": amt, "t": t, "by": by, "k": key if key >= 0 else _prayer_key()}
	if altar_hold:
		o["away"] = true
	altar.append(o)


## 이틀이 지난 제물은 창고로 돌아간다 ("거인님이 받지 않으셨다").
## 단 거인이 비운 동안(altar_hold) 바친 것은 그대로 쌓여 기다린다 (SAVE.md 3.1) — 돌아온 뒤엔 다시 평소대로
func _expire_offerings() -> void:
	if altar.is_empty():
		return
	var keep: Array = []
	var back := false
	for o: Dictionary in altar:
		if t - float(o["t"]) >= Balance.OFFER_DAYS - HOUR and not (altar_hold and o.get("away", false)):
			stock[o["item"]] = float(stock.get(o["item"], 0.0)) + float(o["amt"])
			back = true
		else:
			keep.append(o)
	altar = keep
	if back and int(stats.get("offer_back", 0)) == 0:
		log_line("{w:이/가} 받지 않으신 제물을 사람들이 조용히 창고로 되돌렸다.")
	if back:
		stats["offer_back"] = int(stats.get("offer_back", 0)) + 1


## 제단의 제물 {물건: 개수}
func altar_items() -> Dictionary:
	var out := {}
	for o: Dictionary in altar:
		out[o["item"]] = int(out.get(o["item"], 0)) + int(o["amt"])
	return out


## [받기] — 그 물건을 모두 거인의 장터에 판다 → 받은 지폐. 바친 사람 믿음↑, 그 물건은 '좋아하시는 것'
func take_offering(item: String) -> float:
	var amt := 0
	var givers := {}
	var keep: Array = []
	for o: Dictionary in altar:
		if o["item"] == item:
			amt += int(o["amt"])
			for id in (o["by"] as PackedInt32Array):
				givers[id] = true
		else:
			keep.append(o)
	if amt <= 0:
		return 0.0
	altar = keep
	var got := Market.sell(item, amt)
	if not Market.first_paid:            # 거인이 처음 받는 제물 — 장터가 웃돈을 얹는다 (BALANCE v4-4 · OPENING T3 → T4 우물 600지폐)
		Market.first_paid = true
		Market.notes += Balance.FIRST_OFFER_BONUS
		got += Balance.FIRST_OFFER_BONUS
	var was := is_favourite(item)
	favourites[item] = float(favourites.get(item, 0.0)) + amt
	var seen: Resident = null
	for id: int in givers:
		var p := person(id)
		if p != null:
			p.belief = minf(1.0, p.belief + Balance.OFFER_BELIEF)
			if seen == null and not p.sleeping:
				seen = p
	_update_belief(0.0)
	if seen != null:
		speak(seen, "{w:이/가} 받으셨다!", 6)
	if int(stats.get("taken", 0)) == 0:
		log_line("제단의 %s%s 하늘로 사라졌다. 사람들은 \"{w:이/가} 받으셨다!\" 하고 외쳤다." % [item, josa(item, "이", "가")])
	stats["taken"] = int(stats.get("taken", 0)) + 1
	if not was and is_favourite(item):
		log_line("사람들은 {w:이/가} %s%s 좋아하신다고 믿게 되었다." % [item, josa(item, "을", "를")])
	giant_acted()
	Notebook.on(self, "take")             # [거인의 수첩]
	return got


## [모두 받기]
func take_all() -> float:
	var s := 0.0
	begin_giant()
	for item: String in altar_items().keys():
		s += take_offering(item)
	end_giant()
	return s


## [강제로 거두기] 전에 보여 줄 '마을에 생기는 일' (UI 문구)
func force_preview(item: String, amt: int) -> String:
	var have := float(stock.get(item, 0.0))
	amt = mini(amt, floori(have))
	var line := ""
	if item in Balance.STORE_FOODS:
		var day_need := maxf(1.0, _food_people() * DAY / Balance.FOOD_IV)
		var left := (food_total() - amt) / day_need
		if left < 1.0:
			line = "먹을 것이 하루치도 안 남아요"
		elif left < 2.0:
			line = "먹을 것이 하루치밖에 안 남아요"
		elif left < 3.0:
			line = "먹을 것이 이틀치밖에 안 남아요"
		else:
			line = "먹을 것이 %d일치 남아요" % int(left)
		if _starving():
			line += " — 굶주리는 중이라 두려움이 크게 늘어요"
	else:
		var left := have - amt
		var owed := _owed(item) if (item == "판자" or item == "돌") else 0
		if owed > left:
			line = "%s%s 모자라 짓던 건물이 늦어져요" % [item, josa(item, "이", "가")]
		elif Balance.ENOUGH.has(item) and left < float(Balance.ENOUGH[item]) * 0.25:
			line = "%s%s 거의 남지 않아요" % [item, josa(item, "이", "가")]
		else:
			line = "%s %d개가 남아요" % [item, int(left)]
	return line + ". 믿음이 줄고 두려움이 늘어요."


## [강제로 거두기] — 창고에서 직접 가져감 → 지폐. 100지폐어치마다 모두 믿음 −0.01 · 두려움 +0.02 (굶주릴 때 식량이면 ×3)
func force_take(item: String, amt: int) -> float:
	amt = mini(amt, floori(float(stock.get(item, 0.0))))
	if amt <= 0 or not Balance.PRICE.has(item):
		return 0.0
	var food := item in Balance.STORE_FOODS
	var starving := _starving()
	stock[item] = float(stock[item]) - amt
	var worth := Market.sell(item, amt)
	var k := worth / Balance.FORCE_PER * (Balance.FORCE_FOOD_STARVING if food and starving else 1.0)
	for p in people:
		p.belief = clampf(p.belief - Balance.FORCE_BELIEF * k, 0.0, 1.0)
		raise_fear(p, Balance.FORCE_FEAR * k)
	recalc_fear()
	if food:
		on_food_taken()                 # HEALTH.md 4: 굶주릴 때 식량을 거두면 모두 +0.1
	_update_belief(0.0)
	stats["forced"] = int(stats.get("forced", 0)) + 1
	log_line("창고의 %s%s 하늘로 사라졌다. 사람들은 \"{w:이/가} 노하셨나…\" 하고 수군거렸다." % [item, josa(item, "이", "가")])
	var awake := people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5)
	if not awake.is_empty():
		speak(awake[econ_rng.randi() % awake.size()], "{w:이/가} 노하셨나…", 6)
	giant_acted()
	return worth


# ── 건물 사 주기 ──
## 지폐로 산 건물을 거인이 고른 자리(spot — 비우면 촌장이 고를 자리)에 완성된 채 내려놓는다 = 기적 (RESIDENT_AI 2.1)
## 건물 사 주기 — paid = 이미 지폐를 냈다 (상점에서 사서 거인의 손에 든 것 — SkyDrops.place_building)
func buy_building(type: String, spot: Variant = null, paid := false) -> Building:
	if not Balance.SHOP.has(type) or int(Balance.B[type]["era"]) > era:
		return null
	var cost := 0.0 if paid else float(Balance.SHOP[type]) * Balance.WISH_DROP_MULT     # v5: 다 지은 건물 = 소원의 기적 (설계도 값 × 2.5)
	if not Market.can_pay(cost):
		return null
	var p: Vector2
	if spot == null:
		var s: Variant = find_spot(type)
		if s == null:
			return null
		p = s
	else:
		p = spot
		var size: float = Balance.B[type]["size"]
		if not is_free(p.x, p.y, size):
			return null
		_clear_trees(p, size)
	Market.pay(cost)
	var b := add_building(type, p.x, p.y, true)
	b.bought = true
	stats["bought"] = int(stats.get("bought", 0)) + 1
	reveal_building(b)
	bless_all(Balance.BOUGHT_BELIEF)
	_update_belief(0.0)
	wishes.erase(type)
	blueprints[type] = blueprints.get(type, t)     # 내려온 건물을 보고 짓는 법도 안다
	for l: Dictionary in letters:
		if l["kind"] == "wish" and l["type"] == type and l["state"] != "done":
			l["state"] = "done"
	log_line("하늘에서 %s%s 통째로 내려왔다! 사람들은 기적이라며 무릎을 꿇었다." % [Balance.label(type), josa(Balance.label(type), "이", "가")])
	Awakening.witness(self, "drop")
	var near := people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5)
	near.sort_custom(func(a: Resident, c: Resident) -> bool: return Vector2(a.x, a.y).distance_squared_to(p) < Vector2(c.x, c.y).distance_squared_to(p))
	for i in mini(2, near.size()):
		speak(near[i], "기적이다!" if i == 0 else "하늘에서 %s%s 내려왔어!" % [Balance.label(type), josa(Balance.label(type), "이", "가")], 7)
	giant_acted()
	return b


# ── 분가 (기획서 3.1 · 13.1) ──
func _check_split() -> void:
	if territory_full() < Balance.SPLIT_FULL:
		_full_since = -1.0
		return
	if _full_since < 0.0:
		_full_since = t
		return
	if t - _full_since < Balance.SPLIT_AFTER or not open_letters("split").is_empty():
		return
	var movers := split_movers()
	if movers.is_empty():
		return
	var who: Resident = movers[0]
	_letter_id += 1
	letters.append({"id": _letter_id, "kind": "split", "t": t, "from": who.id, "name": who.name, "type": "",
		"text": "새 땅으로 떠나고 싶어요. 여기는 이제 집 지을 땅이 없어요.", "state": "open"})
	speak(who, "새 땅으로 떠나고 싶어요", 7)
	log_line("집 지을 땅이 바닥나자 젊은 부부들이 안개 너머의 새 땅을 이야기하기 시작했다.")


## 떠날 사람들 = 젊은 부부 1~3쌍 + 그 아이들 (촌장 가족·탐험 중인 사람은 남고, 옛 마을에 부부 둘은 남긴다)
func split_movers() -> Array[Resident]:
	var c := chief()
	var wives: Array[Resident] = []
	var couples := fertile_couples()      # 옛 마을에 남길 부부도 가임 부부로 센다 (population.md R4-2)
	for w in people:
		if w.sex != "f" or w.partner < 0:
			continue
		var h := person(w.partner)
		if h == null or w.age < Balance.AGE_ADULT or w.age >= Balance.BIRTH_WIFE_MAX or h.age < Balance.AGE_ADULT:
			continue
		if c != null and (w.id == c.id or h.id == c.id):
			continue
		if w.id == explorer or h.id == explorer:
			continue
		wives.append(w)
	var n := mini(mini(int(Balance.SPLIT_COUPLES[1]), wives.size()), couples - Balance.OFFLINE_MIN_COUPLES)
	var out: Array[Resident] = []
	if n < int(Balance.SPLIT_COUPLES[0]):
		return out
	wives.sort_custom(func(a: Resident, b: Resident) -> bool: return a.age < b.age)
	for i in n:
		for q in household_of(wives[i]):
			if not q in out:
				out.append(q)
	return out


## 떠나는 사람 몫의 창고 물자 (옛 창고에서 덜어 냄)
func split_stock(n_movers: int) -> Dictionary:
	var share := float(n_movers) / maxf(1.0, float(people.size())) * Balance.SPLIT_STOCK_SHARE
	# 첫 집 한 채·이틀 먹을 몫은 챙겨 간다 (옛 창고의 절반까지) — (정함)
	var food2 := n_movers * DAY / Balance.FOOD_IV * 2.0
	var least := {"판자": 10.0, "돌": 4.0, "도구": 2.0, "건량": food2, "밀": food2, "빵": food2}
	var out := {}
	for k: String in stock:
		var have := float(stock[k])
		var take := floorf(maxf(have * share, minf(have * 0.5, float(least.get(k, 0.0)))))
		stock[k] = have - take
		out[k] = take
	return out


## 사람들을 새 무리 nv로 옮긴다 (JarWorld.split_out이 부름)
func move_people_to(nv: Village, movers: Array[Resident]) -> void:
	for r in movers:
		ResidentAI.cancel(self, r)
		if r.job >= 0:
			var b := bld(r.job)
			if b != null:
				b.worker = -1
			nv.stock["도구"] = float(nv.stock.get("도구", 0.0)) + 1.0     # 쓰던 도구는 들고 간다
			r.job = -1
		r.home = -1
		if explorer == r.id:
			explorer = -1
		people.erase(r)
		_people_by_id.erase(r.id)
		r.x = nv.fire.x + econ_rng.randf_range(-1.5, 1.5)
		r.y = nv.fire.y + econ_rng.randf_range(-1.5, 1.5)
		r.px = r.x
		r.py = r.y
		nv.people.append(r)
		nv._people_by_id[r.id] = r
	nv.assign_homes()
	assign_homes()
	met[nv.sid] = t
	nv.met[sid] = t
	stats["split"] = int(stats.get("split", 0)) + 1
	for l: Dictionary in letters:
		if l["kind"] == "split" and l["state"] == "open":
			l["state"] = "done"
	_full_since = -1.0
	var nm: String = movers[0].name
	for r in movers:                      # 연대기 '사람들' — 분가로 떠남 (UI 07)
		departed.append({"id": r.id, "name": r.name, "sex": r.sex, "age": r.shown_age(), "t": t, "to": nv.settlement_name, "to_sid": nv.sid})
	log_line("%s의 가족을 비롯한 %d명이 새 땅을 찾아 떠났다. 남은 사람들은 마을 어귀까지 배웅했다." % [nm, movers.size()])
	nv.log_line("%s의 가족을 비롯한 %d명이 옛 마을을 떠나 이 땅에 처음으로 불을 피웠다." % [nm, movers.size()])
	recalc_fear()
	nv.recalc_fear()
	_update_belief(0.0)
	nv._update_belief(0.0)


# ───────────────────────── 점검 (테스트용) ─────────────────────────
func check_invariants() -> PackedStringArray:
	var bad := PackedStringArray()
	for k in stock:
		var v := float(stock[k])
		if is_nan(v) or v < -1e-6:
			bad.append("창고 %s = %f" % [k, v])
	for b in buildings:
		for dct: Dictionary in [b.out, b.in_buf, b.in_inc]:
			for k in dct:
				var v := float(dct[k])
				if is_nan(v) or v < -1e-6:
					bad.append("%s %s = %f" % [b.type, k, v])
		if b.built and b.is_house() and occupants(b) > b.cap():
			bad.append("%s 정원 초과 %d/%d" % [b.type, occupants(b), b.cap()])
	for p in people:
		for v: float in [p.x, p.y, p.hunger, p.health, p.belief, p.age]:
			if is_nan(v):
				bad.append("%s NaN" % p.name)
		if p.hunger < 0.0 or p.belief < 0.0:
			bad.append("%s 음수" % p.name)
	for m: Dictionary in manna:
		if float(m["amt"]) < 0.0:
			bad.append("낟알 음수")
	return bad


# ───────────────────────── 6단계 — 넓은 세상의 무리 (키트) ─────────────────────────
var _fog_on := false
var last_explore_t := -1.0e9
var explorer := -1                    # 지금 탐험 중인 주민 id
var peers: Array = []                 # 같은 세상의 모든 무리 (자기 포함 — JarWorld가 채움)
var kit: Dictionary = {}


## 거인이 세상 지도에서 고른 자리 spot에 키트를 푼다 (JarWorld.place_kit이 부름). 좌표는 세상 좌표.
static func new_settlement(ww: WorldWater, spot: Vector2, kit_def: Dictionary, seed_v: int, sid_v: int, ev: EventStream = null) -> Village:
	var v := Village.new()
	if ev != null:
		v.events = ev                     # 한 병의 무리들이 사건 줄 하나를 함께 (도착 사건부터)
	v._init_world(ww, spot, kit_def, seed_v, sid_v)
	return v


func _init_world(ww: WorldWater, spot: Vector2, kit_def: Dictionary, seed_v: int, sid_v: int) -> void:
	rng.seed = seed_v
	gene_rng.seed = seed_v * 7919 + 101
	econ_rng.seed = seed_v * 6151 + 29
	_init_health(seed_v)
	water = ww
	kit = kit_def
	next_id = int(kit_def.get("id_base", 1))      # 분가: 옛 마을 사람 번호와 겹치지 않게
	sid = sid_v
	layout_seed = VillagePlan.make_layout_seed(seed_v, sid_v)     # 키트 건물을 광장 둘레로 옮기기(VillagePlan.found) 전에
	center = spot
	start_clock = ww.start_clock
	path_r = 64.0
	path_n = 256
	view_r = 40.0
	explore_on = true
	_fog_on = true
	stock = Kits.stock(kit_def)
	paths.resize(path_n * path_n)
	paths.fill(0.0)
	_pnz_ok = false
	var fo: Array = kit_def["fire"]
	fire = spot + Vector2(fo[0], fo[1])
	altar_pos = fire + ALTAR_OFFSET
	# 숲: 둘레 숲 무리를 나무 하나하나로 (키트 자리 바로 곁은 치움)
	for f: Dictionary in ww.forests:
		var fc := Vector2(f["x"], f["y"])
		var fr: float = f["r"]
		if fc.distance_to(spot) > WorldCfg.KIT_TREES_R + fr:
			continue
		var cnt := int(PI * fr * fr * float(f["dens"]) * 0.32)
		for i in cnt:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * fr
			var x := fc.x + cos(a) * d
			var y := fc.y + sin(a) * d * 0.9
			var p := Vector2(x, y)
			if p.distance_to(spot) < WorldCfg.KIT_CLEAR_R or p.distance_to(spot) > WorldCfg.KIT_TREES_R:
				continue
			if not ww.inside(x, y, 1.5) or ww.depth(ww.idx(x, y)) >= 0.005:
				continue
			if GreatTrees.blocks(ww, x, y, 0.0):
				continue
			trees.append({"x": x, "y": y, "s": "tree", "g": 0.0, "res": 0})
	for rp in ww.rock_spots:
		if rp.distance_to(spot) < WorldCfg.KIT_ROCKS_R and ww.depth(ww.idx(rp.x, rp.y)) < 0.005:
			rocks.append({"x": rp.x, "y": rp.y, "amt": 20, "res": 0})
	var guard := 0
	while rocks.size() < 2 and guard < 50:      # 고른 자리가 추천 자리가 아니어도 바위 둘은
		guard += 1
		var a := rng.randf() * TAU
		var p := spot + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 18.0)
		if ww.inside(p.x, p.y, 2.0) and ww.depth(ww.idx(p.x, p.y)) < 0.005:
			rocks.append({"x": p.x, "y": p.y, "amt": 20, "res": 0})
	for b: Dictionary in ww.basins:
		basins_said.append(0)
	for bd: Array in kit_def["buildings"]:
		var b := add_building(bd[0], spot.x + float(bd[1]), spot.y + float(bd[2]), true)
		if bd[0] == "창고":
			b.is_store = true
		_clear_trees(Vector2(b.x, b.y), b.size())
	VillagePlan.found(self)                   # [배치] 키트 건물을 광장 둘레로 (sim/village_plan.gd)
	altar_pos = pick_altar_pos()              # 키트 건물을 피해 모닥불 곁 (제단 돌 단이 창고에 묻히지 않게)
	_clear_trees(altar_pos, ALTAR_CLEAR)
	var ids: Array[Resident] = []
	var looks := Kits.looks(kit_def)
	for f: Array in Kits.people(kit_def):
		var r := add_person(f[0], f[1], f[2], f[3], fire.x + (rng.randf() - 0.5) * 3.0, fire.y + (rng.randf() - 0.5) * 3.0, null, null)
		if ids.size() < looks.size() and looks[ids.size()] is Dictionary:      # 거인이 고른 겉모습 (숨은 열성 유전자는 무작위)
			r.genes = Genetics.from_look(gene_rng, looks[ids.size()])
		ids.append(r)
	if ids.size() >= 7:
		marry(ids[0], ids[1])
		for k in [2, 3]:
			ids[k].parents = PackedInt32Array([ids[0].id, ids[1].id])
		marry(ids[4], ids[5])
		ids[6].parents = PackedInt32Array([ids[4].id, ids[5].id])
		for k: int in [2, 3, 6]:
			var g := ids[k].genes
			_inherit_look(ids[k], ids[0] if k < 6 else ids[4], ids[1] if k < 6 else ids[5])     # 아이는 부모를 닮는다 (추천값)
			if k < looks.size() and looks[k] is Dictionary:
				ids[k].genes = g                  # 고른 겉모습이 있으면 그대로
	# 키트 혈통: 가족 전원이 같은 혈통 (기본 키트는 없음). 키트로 오는 사람에게 나쁜 혈통은 없다
	var kb := Kits.blood(kit_def)
	for r in ids:
		set_blood(r, kb, "kit")
		r.parent_blood = kb.duplicate() if r.parents.size() > 0 else PackedStringArray()
		r.parent_blood_sex = {}
		if r.parents.size() > 0:
			for id in kb:
				r.parent_blood_sex[id] = "m"
	stats["marriages"] = 0
	if people.all(func(p: Resident) -> bool: return p.grade == 0) and ids.size() > 4:
		ids[4].grade = 1
	assign_homes()
	if kit_def.get("split", false):       # 분가 — 사람은 JarWorld.split_out이 옛 마을에서 옮겨 온다. 하늘 낟알은 없다
		_arrival_manna = true
		manna_ended = true
		first_harvest_t = 0.0
		stats["thanks"] = 1               # 분가한 무리는 첫 한 시간 대본이 없다
	else:
		_arrive_fed()
		Awakening.start(self)
		if aware:
			log_line("어느 아침, {w}의 손이 하늘에서 내려와 우리 조상 %d명과 오두막 두 채를 이 땅에 내려놓았다." % people.size())
		else:                             # 아직 거인을 모른다 (6.5) — 어떻게 왔는지 아무도 모른다
			log_line("어느 아침, 우리 조상 %d명이 오두막 두 채 곁에서 눈을 떴다. 어떻게 이 땅에 왔는지 기억하는 사람은 없었다." % people.size())
		log_line("사방은 하얀 안개다. 안개 너머가 어디까지 이어지는지 아무도 모른다. 하늘의 물방울이 똑, 똑 떨어지는 곳에는 마르지 않는 호수가 있다.")
	_reveal_at(center, WorldCfg.REVEAL_KIT, null, true)


func salt_flat_near() -> Variant:
	return water.salt_flat_in(center, view_r * 1.5)


## 걷는 주민 둘레의 안개를 걷는다 (mark_path가 부름 — 안개 칸이 바뀔 때만 실제로 일함)
## 한 걸음이 길면 (몰아서 계산 30초 = 37칸) 걸음 시작점부터 안개 칸 크기 간격으로 걷는다
func _reveal_walk(x: float, y: float) -> void:
	var to := Vector2(x, y)
	if _walker != null:
		var from := Vector2(_walker.px, _walker.py)
		var d := from.distance_to(to)
		var n := int(d / WorldWater.FOG)
		for i in n:
			_reveal_at(from.lerp(to, float(i + 1) / (n + 1)), WorldCfg.REVEAL_WALK, _walker)
	_reveal_at(to, WorldCfg.REVEAL_WALK, _walker)



func _reveal_at(p: Vector2, rad: float, who: Resident, force := false) -> void:
	if _fog_on and not force:             # 이미 걷힌 안개 칸 한가운데면 WorldWater.reveal도 아무것도 안 한다 — 미리 보고 돌아감 (같은 결과)
		var fw := water as WorldWater
		if fw.fog_center[fw.fog_idx(p.x, p.y)] & (1 << sid):
			return
	if who != null:
		rad *= who.f("fog")              # 혈통 '탐험가' 안개 반경 +50%
	var ev: Array = water.reveal(sid, p.x, p.y, rad, force)
	if ev.is_empty():
		return
	for e: Dictionary in ev:
		_on_seen(e, who)


func _on_seen(e: Dictionary, who: Resident) -> void:
	var nm: String = (who.name if who != null else "")
	var subj := ("%s%s " % [nm, josa(nm, "이", "가")]) if nm != "" else "우리는 "
	match String(e["kind"]):
		"lake":
			var ln: String = e["name"]
			if nm == "":
				log_line("가까이에 맑은 호수가 있었다. 사람들은 그곳을 '%s'%s 불렀다." % [ln, josa(ln, "이라", "라")])
			else:
				log_line("%s안개 너머에서 처음 보는 호수를 찾았다. 사람들은 그곳을 '%s'%s 불렀다." % [subj, ln, josa(ln, "이라", "라")])
		"river":
			var rn: String = e["name"]
			log_line("%s세상 끝 벽 쪽에서 흘러오는 물줄기를 보았다. 사람들은 그 물을 '%s'%s 불렀다." % [subj, rn, josa(rn, "이라", "라")])
		"salt":
			log_line("%s땅 위로 솟은 하얀 바위를 보았다. 물이 닿는 자리마다 바위가 조금씩 녹아 있었다." % subj)
		"contact":
			_meet(int(e["other"]), who)


## 다른 무리와 처음 만남 (기획서 13.1 '추가 키트' — 서로 모르다 탐험으로 만남)
func _meet(other_sid: int, who: Resident) -> void:
	if met.has(other_sid):
		return
	var o: Village = null
	for q: Village in peers:
		if q.sid == other_sid:
			o = q
	if o == null:
		return
	met[other_sid] = t
	o.met[sid] = t
	var nm := who.name if who != null else "누군가"
	log_line("%s%s 안개 너머에서 낯선 사람들의 연기를 보았다. 이 세상에 우리 말고도 사람이 있었다!" % [nm, josa(nm, "이", "가")])
	o.log_line("우리 땅 가장자리에 낯선 이가 나타났다. 그들도 {w}의 손이 내려놓은 사람들이라고 했다.")
	if who != null:
		speak(who, "저 너머에 사람이 있어요!", 8)


## 탐험할 곳 (안개 가장자리) — 없으면 null
func explore_target() -> Variant:
	return water.fog_target(sid, center, rng, WorldCfg.EXPLORE_MAX)


func can_explore(r: Resident = null) -> bool:
	var every := WorldCfg.EXPLORE_EVERY
	if r != null:
		every /= r.f("explore")          # 혈통 '탐험가'는 더 자주 나선다
	return explore_on and explorer < 0 and t - last_explore_t >= every and not explore_held()


## (2026-11-11 Q7-c) 첫 며칠 먹을 것이 바닥나 가면 안개 너머를 살피러 새로 떠나지 않는다 — 그 어른은 나르고 짓는다 (이미 떠난 사람은 다녀온다).
## 도착하고 FORAGE_FIRST_DAYS 날 안 · 먹을 것(창고·밭 앞 + 창고로 오는 길)이 EXPLORE_HOLD_FOOD_DAYS 날치 아래일 때. 지켜보는지와 상관없다
func explore_held() -> bool:
	if Balance.EXPLORE_HOLD_FOOD_DAYS <= 0.0 or t >= Balance.FORAGE_FIRST_DAYS * DAY:
		return false
	return Production.food_total(self) + Production.food_on_way(self) < Balance.EXPLORE_HOLD_FOOD_DAYS * Production.day_need(self)


## 건물이 다 지어지면 둘레 안개도 걷힌다
func reveal_building(b: Building) -> void:
	if _fog_on:
		_reveal_at(Vector2(b.x, b.y), WorldCfg.REVEAL_BUILD, null, true)


# ───────────────────────── 건강·기후·두려움 (docs/HEALTH.md — 계산은 sim/health.gd) ─────────────────────────
## 병 날짜 {year, month, day, season("봄/여름/가을/겨울")} — 세상을 만든 날 + 병 시계로 흐른 날 수
func jar_date() -> Dictionary:
	return Health.jar_date(self)


## 그 자리의 온도 (°C 느낌) = 기후대 바탕 + 계절 + 낮밤 + 자리(따뜻함 0~1 → +0~+3)
func temperature_at(x: float, y: float) -> float:
	return Health.temperature_at(self, x, y)


## 기후대 (Balance.CLIMATES의 키) — 병(물)이 정한다. 기본 온대
func climate() -> String:
	if climate_override != "":
		return climate_override
	if water != null and Balance.CLIMATES.has(water.climate):
		return water.climate
	return Balance.CLIMATE_DEFAULT


## 창고 물자의 '넉넉함' — 추운 철에는 통나무를 집마다 더 쌓는다 (땔감)
func enough(k: String) -> float:
	var fp := _fp_val if (_fp_t == t and _fp_n == people.size()) else _food_people()     # 성능: 같은 걸음 안에서는 한 번 센 값
	var need := fp * DAY / Balance.FOOD_IV
	if k == "밀":                     # 농장도 넉넉하면 멈춘다 (BALANCE v4-4) — v5: 죽으로 먹을 몫 기준 3일 (좋아하시면 +0.15일)
		var days := Balance.FARM_ENOUGH_DAYS + (Balance.FARM_FAV_DAYS if is_favourite(k) else 0.0)
		return maxf(Balance.FARM_ENOUGH_MIN, need / Balance.PORRIDGE_YIELD * days)
	var e: float = Balance.ENOUGH.get(k, INF)
	if k == "빵":
		e = maxf(e, need * 1.5)       # v5: 빵은 하루 반치까지 굽는다
	elif k == "밀가루":
		e = maxf(e, need * 0.6)
	elif Balance.ENOUGH_PER.has(k):
		e += float(Balance.ENOUGH_PER[k]) * people.size()     # v5: 마을이 크면 더 쌓고 더 바친다
	e *= Discovery.store_mult(self, k)  # 발견 W2 진흙 — 저장 항아리 (식량 ×1.5)
	if is_favourite(k):
		e *= Balance.FAV_ENOUGH       # 거인님이 좋아하시는 물건은 더 만든다 (기획서 11.1)
	if k == "통나무" and cold_season:
		e += houses().size() * Balance.FUEL_STOCK_PER_HOUSE
	return e


func raise_fear(r: Resident, amt: float) -> void:
	r.fear = clampf(r.fear + amt * r.f("fear_rise"), 0.0, 1.0)      # 담대 ×0.5 · 겁 많음 ×1.5 (내려감은 같음)


func raise_fear_all(amt: float) -> void:
	for r in people:
		raise_fear(r, amt)
	recalc_fear()


## 부락의 두려움 0~100 = 주민 두려움 평균 × 100 (신앙 상태가 그대로 쓴다)
func recalc_fear() -> void:
	if people.is_empty():
		fear = 0.0
		return
	var s := 0.0
	for r in people:
		s += r.fear
	fear = s / people.size() * 100.0


## [곰팡이·뚜껑] 뚜껑이 열린다 / 닫힌다 (WORLD_EVENTS 3) — 열린 동안 김·연기·탁한 공기가 빠지고 방 기온이 섞인다.
## 손짓(물 뿌리기·핀셋·내려 주기)이 저절로 열고 화면이 곧 닫는다 (giant-touch R7). 뚜껑은 손짓이 아니다 — 경이 없음 (사용자 결정 ⑤).
## 현실 시간 자동 닫힘은 없앴다 (jar-time E7) — 병 시계 8분 안전장치는 JarAir. 성공하면 true
func open_lid() -> bool:
	var ok := air.open_lid(self)
	giant_acted()
	return ok


func close_lid() -> bool:
	var ok := air.close_lid(self)
	giant_acted()
	return ok


## [하늘의 것] 뚜껑이 열릴 때 들어온 바람 (EVENTS_STAGING 6c-1 — 불기 손짓은 없앴다): dir 쪽으로 다 핀 솜털 공의 꽃씨가 한꺼번에
## (WORLD_EVENTS 2.7) + 먼지 뭉치도 흩어짐 (2.2). 손짓이 아니라 경이 없음 (giant-touch 사용자 결정 ⑤). 날린 꽃씨 수, 닫혀 있으면 −1
func lid_breeze(dir: Vector2) -> int:
	var n := flora.lid_breeze(self, dir)
	if n >= 0:
		smalls.blow_dust(self, dir)
	return n


## 거인이 유리를 톡 친다 (design/gdd/giant-touch.md R4 · F1 — 그날 FEAR_FREE_PER_DAY(3)번까지 무료, 4번째부터 모두 +0.05).
## hard = 크게 친 톡 (지진, 모두 +0.2) — 손짓이 아니다: 개발 키(KEY_T)·시험만 (사용자 결정 ③).
## [작은 위기] 매달린 물방울이 있으면 미리 떨어진다 — at(누른 땅 자리)을 주면 그쪽으로 (WORLD_EVENTS 2.2)
func tap_glass(hard := false, at: Variant = null) -> void:
	smalls.knock(self, at)
	var d := cal_day(t)
	if _taps[0] != d:
		_taps = [d, 0]
	_taps[1] += 1
	if not hard:
		Awakening.witness(self, "tap")     # 하늘이 울렸다 (A4b — 세게 친 톡은 두려움만)
		Notebook.on(self, "tap")           # [거인의 수첩]
	if hard:
		raise_fear_all(Balance.FEAR_TAP_HARD)
	elif _taps[1] > Balance.FEAR_FREE_PER_DAY:
		raise_fear_all(Balance.FEAR_TAP)
	if not hard:
		touch_event(&"tap", int(_taps[1]), int(_taps[1]) <= Balance.FEAR_FREE_PER_DAY)
	giant_acted()


## 손짓이 받아들여짐 → 사건 giant_acted (docs/architecture/event-kinds.md · giant-touch '사건'). v에 숫자·StringName만, 난수 없음
func touch_event(kind: StringName, n_today: int, free: bool) -> void:
	emit(&"giant_acted", {"v": {"kind": kind, "n_today": n_today, "free": free}})


## 손짓이 거절됨 (쿨타임·대상 없음·뚜껑) → 사건 giant_refused
func touch_refused(kind: StringName, why: StringName) -> void:
	emit(&"giant_refused", {"v": {"kind": kind, "why": why}})


## 등불 옮기기의 그날 횟수 (톡과 따로 — LAMP_FREE_PER_DAY(1)번까지 무료, 2번째부터 두려움 — giant-touch F2)
func _fear_rotate() -> void:
	var d := cal_day(t)
	if _rots[0] != d:
		_rots = [d, 0]
	_rots[1] += 1
	if _rots[1] > Balance.LAMP_FREE_PER_DAY:
		raise_fear_all(Balance.FEAR_ROTATE * Discovery.lamp_fear_mult(self))     # 발견 S3 해의 길 — 두려움 ×0.5


## 거인이 식량을 거둠 — 굶주리는 때면 모두 +0.1 (기획서 11.1)
func on_food_taken() -> void:
	if deficit > 0.0 or t - last_short_t < Balance.STARVED_RECENT:
		raise_fear_all(Balance.FEAR_TAKE_FOOD)


## [작은 위기 · 거인의 손] 거인의 핀셋 (뚜껑을 연 채 — WORLD_EVENTS 4.3): 누른 자리의 날벌레·먼지 뭉치·떨어진 물건·바위를 집음.
## to를 주면 짧은 거리만 옮겨 놓음. 서툴면 곁의 집이 부서짐 → {ok, why, picked, moved, kind, crushed}
func tweeze(p: Vector2, to: Variant = null) -> Dictionary:
	var r := hand.tweeze(self, p, to)
	giant_acted()
	return r


## [거인의 손] 물 뿌리기 (뚜껑을 연 채 — WORLD_EVENTS 4.3 · 기획서 6.3) → {ok, why, water, fields, fires_out, flood, hit}
func spray_water(p: Vector2) -> Dictionary:
	var r := hand.spray(self, p)
	if bool(r.get("ok", false)) and not bool(r.get("flood", false)):
		Notebook.on_spray(self, p)         # [거인의 수첩] 첫 밭에 물
	return r


## [거인의 손] 유리 닦기 (병 밖 — WORLD_EVENTS 4.2) → {ok, why, fog, dust, bright}
func wipe_glass() -> Dictionary:
	var r := hand.wipe(self)
	if bool(r.get("ok", false)):
		Notebook.on(self, "wipe")          # [거인의 수첩]
	return r


## 물 뿌리기가 집을 잠기게 함 — 반경 안 주민 +0.15
func on_house_flooded(x: float, y: float, radius: float) -> void:
	for r in people:
		if Vector2(r.x - x, r.y - y).length() <= radius:
			raise_fear(r, Balance.FEAR_FLOOD)
	recalc_fear()


# ───────────────────────── 저장 (docs/SAVE.md 1 · 6) ─────────────────────────
## 객체를 가리키는 변수 — 아래에서 직접 다룬다 (나머지 스크립트 변수는 SaveCodec이 이름 그대로)
const SAVE_SKIP := ["social_events", "water", "buildings", "people", "dead", "air", "mold", "smalls", "hand", "flora", "wild", "dogs", "caterpillars", "kitchen", "lean", "warmth", "direct_route", "_stall", "_walker", "_singers", "others", "peers",
	"_people_by_id", "_bld_by_id", "book", "_homes_sig", "_homes_types", "_fp_val", "_fp_n", "_fp_t", "_fg_t", "_fg_ok", "_pnz", "_pnz_in", "_pnz_ok", "_tr_fix", "events", "tools_signal_off", "stone_signal_off"]


## 이 마을 전부 → 사전. with_book = 연대기 포함 (저장 파일은 연대기를 따로 쓴다), with_water = 물 격자 포함 (넓은 세상은 JarWorld가 한 번만)
func to_dict(with_book := true, with_water := true) -> Dictionary:
	var d := SaveCodec.props(self, SAVE_SKIP)
	if with_water:
		d["water"] = water.to_dict()
	d["air"] = air.to_dict()
	d["mold"] = mold.to_dict()
	d["smalls"] = smalls.to_dict()
	d["hand"] = hand.to_dict()
	d["flora"] = flora.to_dict()
	if dogs != null:
		d["dogs"] = dogs.to_dict()    # [강아지]
	if caterpillars != null:
		d["caterpillars"] = caterpillars.to_dict()
	if kitchen != null:
		d["kitchen"] = kitchen.to_dict()
	if owns_water and wild != null:
		d["wild"] = wild.to_dict()    # [들짐승] 병 하나에 한 번 (다른 무리는 첫 무리 것을 함께 — JarWorld.from_dict)
	var bl := []
	for b in buildings:
		bl.append(b.to_dict())
	d["buildings"] = bl
	var lists := SaveCodec.ref_lists(self)
	var orphans: Array = []
	var pl := []
	for r in people:
		var rd := r.to_dict()
		rd["steps"] = SaveCodec.enc_steps(r.steps, lists, orphans)
		pl.append(rd)
	d["people"] = pl
	var dl := []
	for r in dead:
		var rd := r.to_dict()
		rd["steps"] = SaveCodec.enc_steps(r.steps, lists, orphans)
		dl.append(rd)
	d["dead"] = dl
	var ol := []
	for o: Dictionary in orphans:
		ol.append(SaveCodec.enc(o))
	d["_orphans"] = ol
	var si := []
	for r: Resident in _singers:
		si.append(r.id)
	d["_singers"] = si
	if with_book:
		d["book"] = SaveCodec.enc(book)
	return d


## 사전 → 마을. water_obj를 주면 그 물을 쓴다 (넓은 세상), book이 없으면 빈 연대기 (SaveManager가 연대기 파일에서 채움)
static func from_dict(d: Dictionary, water_obj: JarWater = null) -> Village:
	var v := Village.new()
	SaveCodec.apply(v, d, SAVE_SKIP)
	v.water = water_obj if water_obj != null else JarWater.from_dict(d["water"])
	v.air = JarAir.from_dict(d["air"])
	v.mold = Mold.from_dict(d["mold"])
	v.smalls = SmallCrises.from_dict(d["smalls"]) if d.has("smalls") else SmallCrises.new(int(v.rng.seed % 100000))   # 옛 저장: 작은 위기 없이
	v.hand = GiantHand.from_dict(d["hand"]) if d.has("hand") else GiantHand.new()     # 옛 저장: 손을 쓴 기록 없이
	v.flora = Flora.from_dict(d["flora"])
	v.dogs = Dogs.from_dict(d["dogs"]) if d.has("dogs") else Dogs.new(int(v.rng.seed % 100000))     # 옛 저장: 처음 걸음에서 강아지를 놓는다
	v.caterpillars = Caterpillars.from_dict(d["caterpillars"]) if d.has("caterpillars") else Caterpillars.new()   # 옛 저장: 처음 걸음에서 꽃 무리를 놓는다
	v.kitchen = Kitchen.from_dict(d["kitchen"]) if d.has("kitchen") else Kitchen.new()     # 옛 저장: 목장·알 없이 (E3-14)
	v.wild = Wildlife.from_dict(d["wild"]) if d.has("wild") else Wildlife.new(int(v.rng.seed % 100000))   # 옛 저장: 처음 걸음에서 무리를 놓는다
	for bd: Dictionary in d.get("buildings", []):
		var b := Building.from_dict(bd)
		v.buildings.append(b)
		v._bld_by_id[b.id] = b
	for rd: Dictionary in d.get("people", []):
		var r := Resident.from_dict(rd)
		v.people.append(r)
		v._people_by_id[r.id] = r
	for rd: Dictionary in d.get("dead", []):
		v.dead.append(Resident.from_dict(rd))
	var lists := SaveCodec.ref_lists(v)
	var orphans: Array = []
	for od: Variant in d.get("_orphans", []):
		orphans.append(SaveCodec.dec(od))
	var pl: Array = d.get("people", [])
	for i in pl.size():
		v.people[i].steps = SaveCodec.dec_steps(pl[i].get("steps", []), v, lists, orphans)
	var dl: Array = d.get("dead", [])
	for i in dl.size():
		v.dead[i].steps = SaveCodec.dec_steps(dl[i].get("steps", []), v, lists, orphans)
	var by_id := {}
	for r in v.dead:
		by_id[r.id] = r
	for r in v.people:
		by_id[r.id] = r
	for id: Variant in d.get("_singers", []):
		if by_id.has(int(id)):
			v._singers.append(by_id[int(id)])
	v.book = SaveCodec.dec(d.get("book", []))
	if v.aware and v.watcher == "":
		v.watcher = WatcherName.pick(WatcherName.key_of(v))     # N2: 옛 저장(부르는 말 칸 없음) — 마을 씨앗으로 정함
	if v.altar_built and Awakening.altar_site(v) == null and not v.altar_spot_ok(v.altar_pos):
		v.altar_pos = v.pick_altar_pos()      # 옛 저장: 제단이 창고에 묻혀 있던 자리 → 모닥불 곁 빈자리로 (A4b — 보이게)
	return v
