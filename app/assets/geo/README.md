# 대한민국 경계 데이터

`kr_provinces.json` — 통계청 SGIS **2013 시/도 경계 17개**. `{ "provinces": [ { "name", "rings": [[[경도, 위도], …], …] } ] }`
형태로, 시/도마다 외곽 고리가 여럿(본토 조각 + 섬)이다. 좌표는 GeoJSON 순서 `[경도, 위도]`, 소수점 4자리.

세 곳이 **같은 파일**을 쓴다 — 그래야 셋이 한 경계로 보인다:

- [FogOverlayController](../../lib/services/fog_overlay_controller.dart) — 안개 폴리곤(고리마다 landmass 하나)
- [ProvinceBoundaryOverlay](../../lib/services/province_boundary_overlay.dart) — 지도 위 시/도 경계선
- [KoreaChoroplethMap](../../lib/widgets/korea_choropleth_map.dart) — 탐험 현황의 시/도 단계구분도

2013 기준이라 그 뒤 통합된 시/도(광주·전남)는 폴리곤이 따로다 — 화면 쪽이 이름으로 묶는다.

**독도는 원본에 없어서 직접 넣었다** — 경상북도 세 번째 고리, 동도·서도를 함께 감싸는 작은 사각형
(위도 37.2365–37.2485, 경도 131.858–131.876). 없으면 안개도 안 덮이고, 국외 덮개(`OutsideKoreaMask`)가
바다색으로 지워 버린다(시진, 09-15).

**출처**: [southkorea-maps](https://github.com/southkorea/southkorea-maps) `kostat/2013/json/skorea_provinces_geo_simple.json`
(통계청 SGIS). 이름만 남기고 좌표를 4자리로 줄였다.

**라이선스**: KOSTAT — "Free to share or remix" (저장소 README).

> 예전 `kr_boundary.json`(Natural Earth 해안선, Public Domain)은 안개가 시/도 경계선과 어긋나
> 보이고 매립지(송도)가 빠져 있어 이 파일로 바꿨다(09-14).
