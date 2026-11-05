# 나의 작은 지구 — 콘셉트 아트 프롬프트 모음 (v2 — 기획서 v3.0 기준)

> [기획서 v3.0](GAME_DESIGN.md)에서 **확정된 내용만** 그림으로 옮기기 위한 프롬프트. 그림이 기획서와 다르면 **기획서가 맞다** (특히 4장 '병의 자연'). 이미지 생성 AI(Midjourney, DALL·E, Stable Diffusion, Imagen 등)에 그대로 붙여 넣어 쓴다.
> 영어 프롬프트가 대부분의 모델에서 결과가 안정적이라 영어로 쓰고, 각 장면에 한국어 설명을 붙였다.
> 모든 프롬프트는 맨 앞에 **[공통 스타일]**을 붙여서 쓴다 → 그림들이 한 게임처럼 보인다.

---

## 0. 공통 스타일 (모든 프롬프트 앞에 붙이기)

```
cozy miniature diorama, low-poly 3D with soft hand-painted textures, tilt-shift depth of field,
warm natural window light, gentle glass refraction and condensation, muted earthy palette
(moss green, cream, soil brown, evening amber), small medieval European villagers with
realistic proportions (not chibi), calm and healing mood, high detail, clean composition
```

**네거티브 프롬프트** (지원하는 모델에서)
```
text, watermark, logo, UI, modern objects, cars, guns, blood, gore, horror, neon colors,
oversaturated, chibi, anime big eyes, photorealistic humans close-up, fantasy elves, dragons,
sea, ocean, beach, waves
```

**규칙**
- 실존 작가 이름·다른 게임 이름을 스타일로 넣지 않는다 (저작권·표절 방지).
- 바다는 없다 → 항상 *no sea* 유지. 물은 호수·강·물방울뿐.
- 주민은 **중세 유럽풍 평민 복식, 사실적인 비율**의 작은 사람.
- 빛은 항상 **한쪽(거인의 창가)**에서 들어온다.
- 땅은 평평한 원반이지만 **완만한 언덕·골짜기·분지**가 있다 (높낮이 있음).
- 물방울은 **뚜껑 안쪽 돌기**에서만, 강은 **유리벽을 타고 흘러내린 물**에서만 시작한다. 호수에서 강이 흘러나가지 않는다. 넓게 내리는 비는 '거인의 물 뿌리기'뿐이다.

| 용도 | 비율 |
|---|---|
| 대표 이미지·스토어 | 16:9, 9:16 |
| 화면 콘셉트 (세로 게임) | 9:16 |
| 캐릭터·건물 시트 | 1:1, 3:2 |

---

## 1. 대표 이미지 (키 아트)

### 1-1. 병 시점 — 선반 위의 세상
*나무 선반 위 메이슨 자 하나. 옆면으로 땅속 단면(핵·암반·광맥)이 보이고, 위쪽엔 작은 중세 마을. 창가에서 빛이 비스듬히 들어온다.*
```
a glass mason jar terrarium standing on a wooden shelf by a window, inside it a tiny medieval
village on a flat round land with gentle hills, forests and a small lake, the jar's side shows a
cross-section of soil layers, grey and black rock layers with a seam of white salt rock, a tiny
miner's tunnel, a glowing red core at the bottom center, condensation
on the inner glass, two large water droplets hanging from bumps under the lid, warm sunlight from
the left window, dust motes, 9:16
```

### 1-2. 지구 시점 — 병 안의 평평한 세상
*병 안으로 들어가면 지평선까지 펼쳐진 둥글고 평평한 대지. 하늘은 유리 돔, 세상 끝은 희미하게 빛나는 유리벽.*
```
view from inside a terrarium: a wide flat round world stretching to the horizon, the sky is a
huge curved glass dome with faint reflections, the edge of the world is a softly glowing glass
wall, a medieval hamlet with thatched cottages and dirt paths, wheat fields, forests, a calm lake
under a giant water droplet falling from the dome, a river starting from water trickling down the
glass wall, tiny villagers carrying sacks, morning light from one side, 16:9
```

---

## 2. 창조 단계 (오프닝 9단계)

| # | 장면 | 프롬프트 |
|---|---|---|
| 2-1 | **핵 넣기** — 어두운 방, 빈 병, 손바닥 위 붉게 맥동하는 구슬 | `a giant gentle hand holding a small glowing red-orange core sphere above an empty glass jar, dark room, soft rim light, the core pulses like a heartbeat, magical but calm, 9:16` |
| 2-2 | **암반 쌓기** — 돌 컵 4개(회색=철, 검정=석탄, 반짝이=금, 하양=암염) | `four small cups of pebbles beside an empty glass jar: grey stones, black stones, glittering gold stones, and white salt-crystal stones, pebbles pouring into the jar forming visible colored strata around a glowing core, side cross-section view, 3:2` |
| 2-3 | **흙 덮기** — 손가락으로 산·골짜기·깊은 분지를 빚음 | `a fingertip sculpting soft brown soil inside a glass jar, shaping hills, valleys and one deep long basin, soil particles, a faint glowing circle marking the future village site on flat ground, top-down three-quarter view, 9:16` |
| 2-4 | **물 붓기** — 파 놓은 곳부터 물이 차오름 | `water being poured from a small glass bottle into a terrarium, water filling the low basins first forming a long deep lake like a narrow inland lake, no sea, ripples, light caustics, 9:16` |
| 2-5 | **태양 맞추기** — 반원 궤도 위 6자리, 온대만 밝고 나머지는 안개 | `a small warm lamp sun being placed on a semicircular track above a glass jar, six positions on the track, only one position glowing, the other five hidden in soft fog, gentle and mysterious, 9:16` |
| 2-6 | **뚜껑 닫기 + 물방울 돌기** — 뚜껑 안쪽을 찍어 돌기를 만들고 잠금 | `the inside of a glass jar lid seen from below, a fingertip pressing two small bumps into it, condensation gathering on the bumps into large drops, then the lid twisting shut onto the jar, close-up, 3:2` |
| 2-7 | **타임랩스** — 수천 년이 몇 초에 | `time-lapse feeling inside a sealed terrarium: first drops falling from lid bumps, lakes filling, rivers forming from water trickling down the glass walls, day and night streaking across, motion blur of light, epic yet cozy, 16:9` |
| 2-8 | **생명의 씨앗** — 숨구멍으로 이끼·풀·도토리를 뿌림 | `seeds of moss, grass and tiny acorns sprinkled through a small air hole in a jar lid, below them moss spreading and a forest growing in time-lapse, deer and rabbits appearing at the forest edge, 9:16` |
| 2-9 | **첫 인간** — 해 질 녘 숲 가장자리의 작은 불빛, 10명 | `dusk inside a terrarium world, a tiny campfire at the edge of a forest, ten small medieval villagers in two families with bundles and a handcart sitting around it, a child looking up at the sky and waving, warm orange firelight against blue dusk, 9:16` |

---

## 3. 세상의 자연 (병의 설계)

| # | 장면 | 프롬프트 |
|---|---|---|
| 3-1 | **물방울 호수** — 뚜껑 돌기에서 거대한 물방울이 똑, 강 없는 호수 | `a giant water droplet falling from a bump on the glass sky dome into a calm round lake below, concentric ripples, no rivers flowing in or out, misty morning, tiny fishermen on the shore look up, 16:9` |
| 3-2 | **유리벽의 강** — 그늘 쪽 유리벽을 타고 흘러내린 물이 강이 됨 | `water trickling down the inside of a curved glass wall at the edge of a tiny world, gathering at the base into a small stream that winds inward across meadows, shaded cool side, moss and ferns, 9:16` |
| 3-3 | **창가 쪽 vs 그늘 쪽** — 한 세상 안의 기후 차이 | `split lighting across a flat round terrarium world: one side sunlit, warm and dry with pale yellow-green grass, the other side shaded, cool and lush with dark moss and forests, sunlight beam from a window on the left, top-down three-quarter view, 16:9` |
| 3-4 | **말라가는 큰 호수** — 물가가 물러나고 하얀 소금기 | `a long inland lake slowly drying in a terrarium world, receding shoreline rings, white salt crust spreading on the exposed lakebed, an old villager pointing at where the water used to be, a child doubtful, golden afternoon, 16:9` |
| 3-5 | **소금의 발견** — 아이가 하얀 흙을 찍어 맛봄 | `a small medieval village girl kneeling on a white salt flat, touching the white ground with her finger and tasting it, surprised face, other villagers walking toward her, white crystals sparkling, warm light, 3:2` |
| 3-6 | **병 돌리기** — 해가 하늘을 건너감 | `a giant hand gently turning a glass terrarium jar on a shelf, inside the tiny world the sunlight sweeps across the land, villagers looking up in awe, light shifting from one side to the other, 9:16` |
| 3-7 | **하늘 낟알** — 첫 수확 전, 새벽 들판의 흰 낟알 | `dawn in a tiny medieval world, white grains scattered on the meadow like dew, villagers with baskets gathering them, a child shouting with joy, soft pink morning light through the glass dome, 16:9` |
| 3-9 | **넘치는 호수와 새 강** — 지형을 따라 물이 흘러 고이고, 가득 찬 분지가 넘쳐 새 물길이 열림 | `top-down three-quarter view of a terrarium world with gentle hills and valleys, water flowing downhill from the glass wall into a basin, the basin full and spilling over its lowest rim to carve a new small stream, freshly wet soil, villagers watching from a hill, contour-like terraces, 16:9` |
| 3-10 | **땅속 단면** — 병 옆면으로 보이는 핵·암반·광맥·암염·광부의 굴 | `side cross-section through the glass of a terrarium: topsoil with grass and tiny houses on top, below that brown soil, grey iron-bearing rock, black coal seam, a thin glittering gold vein, a white rock-salt seam, a tiny miner with a lantern in a tunnel, a glowing red core at the very bottom, educational diorama style, 9:16` |
| 3-8 | **거인의 물 뿌리기 (기적)** | `sudden water pouring from the bright sky dome onto a dry field at noon, villagers kneeling in awe, rainbow mist, a doubtful child staring with an open mouth, 16:9` |

---

## 4. 주민

| # | 장면 | 프롬프트 |
|---|---|---|
| 4-1 | **주민 캐릭터 시트** (온대) | `character sheet of small medieval European villagers with realistic proportions: blacksmith with leather apron and hammer, baker woman with flour on sleeves, farmer with sickle, woodcutter with axe, old man with a cane, two children, front and side views, simple low-poly 3D style, neutral background, 3:2` |
| 4-2 | **기후별 복식** | `six small medieval villagers side by side dressed for different climates: temperate wool tunic, taiga fur-lined coat, mediterranean linen and straw hat, tropical light cotton, tundra heavy furs, desert loose robes and head wrap, neutral background, 3:2` |
| 4-3 | **고유 특징이 보이는 아이들** | `four small medieval children each with a visible quirk: one humming while carrying water, one following a cat, one holding a pebble collection, one pointing at the sky claiming she saw a giant finger, playful, 3:2` |
| 4-4 | **의심하는 아이 vs 꾸짖는 노인** | `a medieval village child shrugging and saying there is no giant, an old woman pointing up at a huge faint shadow on the glass sky dome, evening campfire, 3:2` |
| 4-5 | **귀환 축제** | `festival night in a tiny medieval village celebrating, villagers dancing around a bonfire, children crying with joy and waving at a giant shadow returning over the glass sky dome, lanterns, 16:9` |

---

## 5. 건물 (개척기·마을 시대)

```
isometric sheet of small low-poly medieval buildings on a neutral background: hut with thatched roof,
storehouse, well with wooden frame, woodcutter's hut with log pile, forester's hut with saplings,
quarry with stone blocks, sawmill with plank stacks, farm with wheat field, salt works on a white
salt flat with rakes and salt mounds, windmill, bakery with chimney smoke, timber-framed house,
consistent lighting from the upper left, 3:2
```

**기후별 건축 양식**
```
six small medieval houses in different climate styles: temperate timber-framed cottage, taiga log
longhouse, mediterranean stone house with terracotta roof, tropical stilt house, tundra sod-roof hut,
desert mud-brick house, isometric, neutral background, 3:2
```

---

## 6. 병 밖 — 거인의 세계

| # | 장면 | 프롬프트 |
|---|---|---|
| 6-1 | **선반과 여러 병** — 병 사이의 거인의 다리 | `a wooden shelf with three glass terrariums of different shapes (mason jar, fish bowl, cloche dome), a tiny wooden bridge connecting two jars from lid to lid, one jar in ruins with a few flowers placed, warm room light, 16:9` |
| 6-2 | **거인의 종이배** — 나루터에서 떠나는 주민 | `a white paper boat at a tiny wooden pier on a lake inside a terrarium, a medieval villager with a bundle boarding it, family waving goodbye, the boat drifting toward the glowing glass wall at the edge of the world, bittersweet, 16:9` |
| 6-3 | **거인의 상점 물건의 크기감** | `a sugar cube and a pair of wooden chopsticks dropped into a tiny medieval village, the sugar cube looks like a huge white boulder and the chopsticks like giant logs, villagers gathering around in wonder, 16:9` |
| 6-4 | **유적 (멸망한 병)** | `an abandoned terrarium world in ruins, collapsed cottages overgrown with moss, a small graveyard with stone markers and fresh flowers, soft melancholic light through dusty glass, 16:9` |

---

## 7. UI·문서 소재

| # | 소재 | 프롬프트 |
|---|---|---|
| 7-1 | **연대기 양피지** | `an old parchment page texture with handwritten-style lines, warm beige, subtle stains, empty space for text, top-down, no readable text, 3:4` |
| 7-2 | **지구 카드** (폴라로이드) | `a polaroid-style card showing a glass terrarium world, blank caption area, on a wooden table, soft light, no text, 3:4` |
| 7-3 | **앱 아이콘** | `app icon, a small glass jar with a tiny glowing village inside and a single water droplet hanging under the lid, simple shapes, warm colors, centered, no text, 1:1` |

---

## 8. 쓰는 순서 (추천)

1. **1-1 병 시점 키 아트**로 공통 스타일을 먼저 확정한다 (여러 번 뽑아 가장 마음에 드는 1장 고르기).
2. 고른 그림을 **참조 이미지**로 넣고(지원하는 모델에서) 나머지를 뽑는다 → 색감·질감 통일.
3. 주민 시트(4-1)와 건물 시트(5)를 뽑아 3D 모델링 참고 자료로 쓴다.
4. 마음에 든 결과는 `design/concept/`에 저장하고, 모델·시드는 `design/concept/log.csv`에 기록한다. 에이전트(Codex 등)에게 맡길 때는 루트의 `AGENTS.md`와 `design/concept/prompts.json`(이 문서에서 `python3 tools/gen_art_list.py`로 생성)을 쓴다.

> 주의: 생성 이미지는 콘셉트 참고용. 출시용 아트는 아티스트가 이 방향으로 새로 그리거나 모델링한다 (생성 이미지의 상업적 이용 조건은 쓰는 모델의 약관을 확인).
