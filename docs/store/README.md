# 스토어 등록 자료

[docs/ONESTORE_RELEASE.md](../ONESTORE_RELEASE.md) 체크리스트 **⑧ 스토어 등록 자료**에 쓰는 이미지입니다.

| 파일 | 규격 | 용도 | 상태 |
|------|------|------|------|
| [icon-512.png](icon-512.png) | 512 × 512 | 대표 아이콘 | ✅ |
| [graphic-1024x578.png](graphic-1024x578.png) | 1024 × 578 | 그래픽 이미지 | ✅ |
| 스크린샷 | 2 ~ 8장 | 스토어 상세 | ⬜ **아직 없음** |

두 이미지 모두 **알파 채널 없는 RGB**입니다 — 스토어가 투명 배경을 거부하는 경우가 있어 맞춰 뒀습니다.

## 🔴 스크린샷이 남았습니다 — 서버 주소 확정 뒤에 찍어야 합니다

**지금 찍으면 안 됩니다.** `API_BASE_URL`이 빌드 타임에 APK 안으로 구워지므로([ONESTORE_RELEASE.md](../ONESTORE_RELEASE.md)), 서버를 옮기기 전에 찍은 화면은 **곧 죽을 주소를 가리키는 앱**의 화면입니다. 순서는 이렇습니다.

```
서버 이전 → 주소 확정 → 그 주소로 APK 재빌드 → 그 APK 로 스크린샷 → 스토어 등록
```

찍을 화면(스팟이 실제로 깔린 지역에서):

1. **안개 덮인 지도** — 이 앱이 무엇인지 한 장으로 보여주는 화면
2. **스팟 근접 알림 + 방문 인증** — 핵심 루프
3. **안개가 걷힌 뒤 정복률** — 보상
4. **발자취 팝업** — 길 위의 글귀
5. **동행 추천** — 성향 매칭

수집된 지역이 **서울·부산·제주**(`TOUR_COLLECT_AREA_CODES=1,6,39`)뿐이라, 그 밖에서 찍으면 **빈 지도가 나옵니다.**

## 이미지를 다시 만들려면

`Pillow`만 있으면 됩니다. 색·문구를 바꿀 때 소스에서 고쳐 다시 뽑으세요 —
[tools/store_assets/](../../tools/store_assets/)에 생성 스크립트가 있습니다.

```bash
pip install Pillow

# 런처 아이콘(5개 밀도) + 스토어 512
python tools/store_assets/make_icon.py app/android/app/src/main/res docs/store/icon-512.png

# 그래픽 이미지 (스크립트 폴더에서 실행 — make_icon 을 import 합니다)
cd tools/store_assets && python make_graphic.py ../../docs/store/graphic-1024x578.png
```

> 그래픽 이미지는 한글 폰트로 **맑은 고딕**(`C:\Windows\Fonts\malgun*.ttf`)을 씁니다.
> Windows 밖에서 돌리려면 `make_graphic.py`의 `BOLD`·`REGULAR` 경로를 바꾸세요.

## 디자인 근거

안개(짙은 남색) 속에서 **한 곳만 걷혀 밝아지고 그 자리에 핀이 서 있는** 그림입니다. 이 앱이 하는 일 자체입니다.

앰버 `#F2B84B`는 임의로 고른 색이 아니라 **지도 위 발자취 도형과 같은 값**입니다(`footprint_marker_controller.dart`) — 스토어에서 본 색이 앱을 열었을 때 그대로 나옵니다.

런처 아이콘은 48px(mdpi)에서도 읽혀야 해서 요소를 **배경·걷힌 원·핀** 셋으로 제한했습니다.
