# C 단계 교차 검증 (2026-11-16)

| 검사 | 결과 |
|---|---|
| 루프 단계 → 시스템(C3) | ①~⑤ 모두 매핑됨 (C3 표) |
| 시스템 → 데이터(C5) | S1~S14 모두 설정·저장 데이터가 있음. S6은 PoseDef, S13은 SoundDef, S14는 별도 로그 |
| 시스템 → 화면(C4) | S1 P1·P9 / S2 P1·P2 / S3 P1 / S4는 화면 없음(S6이 표시) / S5 P0 / S6 P1 / S7 P4·P5·P6·Q1·Q2 / S8 P1·Q3 / S9 P3·Q4 / S10 P7·P8 / S11 화면 없음 / S12 Q6 / S13 효과 / S14 P10 |
| 화면 → 데이터 출처 | P1: placement, visits_now, pending_gifts, food_bowls, wallet, 환경(파생) / P3: ShopItemDef, wallet, inventory / P4·P5·P6: collection, SpiritDef, SceneArtDef / P7: photos / P9: settings, weather_cache |
| 우선순위 = MVP(D7) | 일치 (C6 게이트) |

**결과:** 통과. 막힌 항목 없음.
