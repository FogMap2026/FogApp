"""FogApp 런처 아이콘 · 스토어 아이콘을 «완성된 원본 이미지»에서 뽑는다.

make_icon.py 는 아이콘을 코드로 «그렸다». 지금 아이콘은 그림(docs/store/icon-source.png)이
원본이라, 여기서는 자르고 줄이기만 한다.

원본은 흰 바탕 위에 모서리가 둥근 사각형이 놓인 모양이다. 그대로 줄이면 런처에서
흰 테두리와 흰 모서리가 보이므로:

  1. 흰색이 아닌 영역(둥근 사각형)을 찾는다
  2. 둥근 모서리의 흰 자투리가 안 들어오게 «안쪽으로» 조금 더 잘라 꽉 찬 정사각형을 만든다
     — 반경 r 인 모서리에서 흰 부분을 완전히 빼려면 각 변을 r·(1 − 1/√2) ≈ 0.293r 만큼 들이면 된다
  3. 런처(5개 밀도)는 make_icon.py 와 같은 규칙으로 둥근 모서리 알파(반경 = 크기 × 0.22)를 씌운다
  4. 스토어 512 는 알파 없는 RGB — 스토어가 투명 배경을 거부하는 경우가 있다(docs/store/README.md)
"""
import math
import os
import sys

from PIL import Image, ImageDraw

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
LAUNCHER_RADIUS_RATIO = 0.22   # make_icon.py 와 같은 값 — 기존 아이콘과 모서리 모양을 맞춘다
WHITE_THRESHOLD = 735          # R+G+B 가 이 이상이면 바탕(흰색)으로 본다
SAFETY_MARGIN = 8              # 흰 자투리가 안티에일리어싱으로 번진 만큼 더 들인다(원본 픽셀)


def _is_white(p):
    return sum(p[:3]) >= WHITE_THRESHOLD


def _content_box(img):
    """흰 바탕을 뺀 둥근 사각형의 경계 상자."""
    px = img.load()
    w, h = img.size
    rows = [y for y in range(h) if any(not _is_white(px[x, y]) for x in range(0, w, 2))]
    cols = [x for x in range(w) if any(not _is_white(px[x, y]) for y in range(0, h, 2))]
    if not rows or not cols:
        raise SystemExit('원본에서 흰색이 아닌 영역을 못 찾았습니다')
    return cols[0], rows[0], cols[-1], rows[-1]


def _corner_radius(img, box):
    """윗변·왼변에서 흰색이 끝나는 거리로 모서리 반경을 잰다(둘 중 큰 값)."""
    px = img.load()
    left, top, right, bottom = box
    along_top = next(x for x in range(left, right) if not _is_white(px[x, top + 1])) - left
    along_left = next(y for y in range(top, bottom) if not _is_white(px[left + 1, y])) - top
    return max(along_top, along_left)


def full_bleed_square(src_path):
    img = Image.open(src_path).convert('RGB')
    left, top, right, bottom = _content_box(img)
    radius = _corner_radius(img, (left, top, right, bottom))
    inset = math.ceil(radius * (1 - 1 / math.sqrt(2))) + SAFETY_MARGIN

    side = min(right - left, bottom - top) - 2 * inset
    cx, cy = (left + right) / 2, (top + bottom) / 2
    x0, y0 = round(cx - side / 2), round(cy - side / 2)
    square = img.crop((x0, y0, x0 + side, y0 + side))
    print(f'원본 {img.size} · 둥근 사각형 {left},{top}-{right},{bottom} · 반경 {radius}px '
          f'· 안쪽으로 {inset}px · 결과 정사각형 {side}px')
    return square


def _rounded_mask(size, radius):
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def launcher(square, size):
    # 크게 만든 마스크를 줄여 모서리 경계를 매끄럽게 한다(make_icon.py 의 슈퍼샘플링과 같은 이유).
    ss = 8
    big = square.resize((size * ss, size * ss), Image.LANCZOS).convert('RGBA')
    big.putalpha(_rounded_mask(size * ss, round(size * ss * LAUNCHER_RADIUS_RATIO)))
    return big.resize((size, size), Image.LANCZOS)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('사용: python make_icon_from_image.py <원본.png> <android res 폴더> <스토어 512 출력.png>')
    src, res_dir, store_path = sys.argv[1:]
    square = full_bleed_square(src)

    for density, size in DENSITIES.items():
        out = os.path.join(res_dir, 'mipmap-' + density, 'ic_launcher.png')
        launcher(square, size).save(out, 'PNG', optimize=True)
        print(f'{out} ({size}px)')

    square.resize((512, 512), Image.LANCZOS).convert('RGB').save(store_path, 'PNG', optimize=True)
    print(f'{store_path} (512px, RGB)')


if __name__ == '__main__':
    main()
