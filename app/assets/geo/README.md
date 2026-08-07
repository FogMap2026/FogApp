# 대한민국 경계 데이터 (안개 오버레이용)

`kr_boundary.json` — 대한민국 육지(본토+도서) 외곽선. 각 원소는 하나의 landmass(섬 포함)를
나타내는 `[[lat, lng], ...]` 닫힌 폴리곤이며, [FogOverlayController](../../lib/services/fog_overlay_controller.dart)가
이 좌표들로 해안선 모양의 안개 폴리곤을 그린다.

**출처**: [Natural Earth](https://www.naturalearthdata.com) (Admin 0 – Countries, 1:10m) →
[eFrane/admin0](https://github.com/eFrane/admin0) 저장소의 `asia/KR.geojson`을 좌표 순서만
`[lat, lng]`로 변환하고 소수점 4자리로 반올림해 용량을 줄였다.

**라이선스**: Natural Earth 데이터 및 eFrane/admin0의 변환 코드 모두 **Public Domain**
("This data as well as the small piece of code is in the public domain." — eFrane/admin0 README).
