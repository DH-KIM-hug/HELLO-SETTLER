# Art Bible: 나의 작은 지구 (My Little Earth)

> **Status**: Draft
> **Owned By**: art-director
> **Last Updated**: 2026-11-07
> **Art Director Sign-Off (AD-ART-BIBLE)**: [Not yet reviewed]

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

> 사용자 확정 2026-11-07 (/art-bible). 기준점: 「꽃그늘 아래」 + 안개는 칠하지 않은 스케치 + 손때 묻은 살림의 재료 (game-concept.md Visual Identity Anchor).

### 한 줄 규칙
**큰 것은 말없이 그늘을 드리우고, 작은 것은 손때로 말한다. 눈은 언제나 주민에게 남는다.**

판정 순서 (앞이 뒤보다 먼저): ① 주민이 읽히는가 → ② 큰 것이 몸이 아니라 그늘로 들어와 있는가 → ③ 색의 임자가 맞는가.

### 원칙 1. 크기는 높이가 아니라 밀도로 말한다 — 기둥: 작은 세상의 실감
큰 자연(꽃·풀대·다섯 나무)은 크고 단순한 곡선, 면은 2톤, 질감·이음매 없음. 소인의 것(집·수레·짐·옷)은 묶음 자국·겹친 꽃잎 줄·조각 이음매처럼 촘촘한 작은 반복. 화면에서는 꽃을 줄여 그리므로(FloraLook.K) 크기감은 밀도 차이·그림자 길이·느린 흔들림에서 나온다.
- **시험**: 크기가 모호하면 "주민이 만지거나 걸치거나 지는가?" → 그렇다면 이음매를 보이고, 아니면 세부를 덜어낸다.
- **구현**: 이음매는 텍스처가 아니라 모델 띠·정점 색 (RENDERING 2.5 '텍스처 최소'). 큰 자연에서 아낀 폴리곤을 소인 쪽에.

### 원칙 2. 색은 임자가 있다 — 기둥: 안개 너머의 설렘 (보조: 스스로 살고 나를 알아보는 사람들)
| 임자 | 쓰는 색 |
|---|---|
| 피어 있는 꽃 | 고채도 (유일한 고채도) |
| 주민이 꺾어 온 꽃잎 (지붕·치마) | 같은 색상, **채도·명도 한 단계 낮춘 '마른 꽃잎' 색** (사용자 확정) |
| 주민이 주운 재료 | 마른 풀·흙·조약돌의 저채도 |
| 주민이 물들인 것 | 옷 한 색 |
| 아직 모르는 땅 | 색 없음 — 종이 톤 + 선 (주민이 밟으면 1~2초에 걸쳐 잉크처럼 불규칙하게 색이 번짐) |
- **시험**: 색이 모호하면 "지금 피어 있나, 주민이 가져온 것인가?" → 가져왔으면 한 단계 마르게, 아무도 모르면 색을 뺀다.
- **구현**: 마른 꽃잎 = 정점 색 + 셰이더 채도 배율 하나. 안개 = 저해상도 R8 마스크(약 256²) + 노이즈 임계값을 땅·소품 셰이더에, 선은 기존 outline_post. 새 렌더 패스 없음.

### 원칙 3. 눈길은 명도와 그늘로 끌고, 순백·은청색은 거인만 — 기둥: 의미 있는 손길 (보조: 보는 것이 곧 재미)
주민은 가장 짙은 외곽선 + 가장 밝은 크림색의 명도 대비로 읽힌다 (채도로 꽃과 경쟁하지 않음). 꽃 그늘은 청록에 그 꽃 색을 약하게 섞은 평면 한 단계 (장미 아래 분홍 청록). 거인의 손길(물·낟알·유리 톡·핀셋)만 유리의 순백·은청색 + 얇은 곡선 하이라이트 1~2줄·동심원·위에서 내려오는 움직임.
- **시험**: 둘이 눈을 다투면 주민 행동과 이어진 쪽이 이긴다. 주목을 더하려면 선·색을 늘리지 말고 명도 대비·그늘 모양을 고친다. 순백·은청이 필요하면 "거인의 손길인가?" → 아니면 따뜻한 쪽으로.
- **자연의 흰색**(민들레 솜털·은방울꽃·데이지)은 따뜻한 크림 흰색 + 잔털 무늬 + 그늘 단계. 순백·차가운 흰색은 거인 몫으로 비워 둔다.
- **구현**: 꽃별 그늘 색은 그림자 맵으로 안 됨 → 꽃 아래 곱하기(multiply) 평면 한 장 (비용은 technical-artist 확인).

### 열린 충돌의 규칙 — 「주민은 가려지지도, 사라지지도 않는다. 큰 것은 그늘로 들어온다」 (4겹, 사용자 확정)
- **겹 0 — 작아서 사라지지 않게**: 확대를 줄여도 주민 화면 키 하한 약 18px (1080 폭 기준, 실측 전 출발점). 하한에 닿으면 몸을 키우고 외곽선 두께는 유지. 지붕은 마른 꽃잎 색.
- **겹 1 — 배치**: 마을 활동 반경(건물·길·밭·나루)에는 큰 꽃 머리·넓은 잎 뭉치를 두지 않는다. 큰 꽃(해바라기·장미 덤불·수국)은 가장자리·바깥 띠, 줄기는 바깥쪽으로 휘게 — 몸은 밖, 그늘만 안. 반경 안에는 가는 풀대(코스모스·억새)와 낮은 풀·이끼만.
- **겹 2 — 가리면 비운다**: 따라가는 주민·화면 중앙 시야를 가리는 꽃 머리·넓은 잎·큰 나무 잎 덩어리는 디더(screen-door)로 비움, 외곽선은 남김. 줄기·나무 몸통·화면 가장자리 꽃은 비우지 않음. 큰 나무는 시야 중심에 둥근 잎 구멍. (안개 스케치와 구분: 비운 꽃은 색이 그대로이고 구멍만 — 구현 뒤 눈으로 확인)
- **겹 3 — 비울 수 없는 것 뒤**: 건물·바위 뒤 주민은 깊이 무시 짙은 청록 실루엣 (비용이 크면 따라가는 주민·이름 붙은 주민만).
- **대가**: 마을 반경 안에서는 꽃숲이 자유롭게 자라지 못한다. 한 화면의 고채도 면적은 약 15% 안팎을 목표 (제안값, 실측으로 조정).

## 2. Mood & Atmosphere

[To be designed] — for each major game state (exploration, combat, victory,
defeat, menus — whichever this game has): the emotional target, lighting
character (time of day, colour temperature, contrast), 3–5 atmospheric
descriptors, and energy level. Each state must look distinct from the others.

## 3. Shape Language

[To be designed] — character silhouette philosophy (readable at thumbnail
size, one distinguishing trait per archetype), environment geometry, UI shape
grammar, and hero versus supporting shapes.

## 4. Color System

[To be designed] — a primary palette of 5–7 colours with their meaning in this
world, semantic colour usage, per-area colour temperature rules, the UI palette
and where it diverges, and colourblind safety: which semantic colours need a
shape, icon or sound backup.

## 5. Character Design Direction

[To be designed] — the player character's visual archetype, how players tell
enemies, NPCs and allies apart at a glance, expression and pose style, and how
much detail survives at game camera distance (LOD philosophy).

## 6. Environment Design Language

[To be designed] — architectural style and its tie to the world's culture,
texture philosophy (painted, PBR or stylised, and why), prop density rules per
area type, and environmental storytelling guidelines.

## 7. UI/HUD Visual Direction

[To be designed] — diegetic versus screen-space HUD, typography (personality,
weight, size hierarchy, minimum readable size), iconography style, UI animation
feel, and any art-direction versus readability conflict and how it was decided.

## 8. Asset Standards

[To be designed] — file formats, naming convention, texture resolution tiers,
LOD levels, export settings, and the engine's hard limits (poly budgets per
asset category, texture memory, material slots). Where an art preference and a
technical limit disagree, record both and the trade-off chosen.

## 9. Reference Direction

[To be designed] — 3–5 references (games, films, art styles or artists). For
each: the specific element to take from it, and what to avoid so the result
does not read as a copy.
