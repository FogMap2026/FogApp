"""FogApp 런처 아이콘 생성.

안개(어두운 남색) 속에서 한 곳만 걷혀 밝아지고, 그 자리에 핀이 서 있는 그림.
48px(mdpi)에서도 읽혀야 하므로 요소는 배경/걷힌 원/핀 셋뿐이다.

앰버(#F2B84B)는 지도 위 발자취 도형과 같은 색이다 — 앱 안팎의 톤을 맞춘다.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

SS = 8  # 슈퍼샘플링 배율 — 크게 그린 뒤 줄여서 경계를 매끄럽게 한다

NAVY_TOP = (22, 32, 51)
NAVY_BOTTOM = (38, 58, 88)
AMBER = (242, 184, 75)
FOG = (150, 170, 195)
WHITE = (255, 255, 255)


def _rounded_mask(size, radius):
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def _gradient(size):
    grad = Image.new('RGB', (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        grad.putpixel((0, y), tuple(
            round(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3)
        ))
    return grad.resize((size, size), Image.BILINEAR)


def _cleared_glow(size):
    """안개가 걷힌 자리 — 핀 주위만 환하게 밝은 원.

    이게 이 아이콘의 이야기다. 약하면 그냥 지도 핀이 되어 버리므로 확실히 보이게 한다.
    """
    glow = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(glow)
    cx, cy = size / 2, size * 0.50
    steps = 64
    outer = size * 0.40
    for i in range(steps, 0, -1):
        r = outer * i / steps
        t = 1 - i / steps          # 바깥 0 → 중심 1
        alpha = round(255 * t ** 1.5)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=alpha)
    return glow.filter(ImageFilter.GaussianBlur(size * 0.035))


def _fog_vignette(size):
    """가장자리를 덮은 안개. 중심의 걷힌 자리와 대비를 만든다.

    가로 띠로 그렸더니 사각형 아티팩트처럼 보여서, 모서리로 갈수록 짙어지는
    비네트로 바꿨다 — 안개에 둘러싸였다는 느낌이 훨씬 자연스럽다.
    """
    vig = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(vig)
    cx, cy = size / 2, size * 0.50
    steps = 64
    outer = size * 0.78
    for i in range(steps, 0, -1):
        r = outer * i / steps
        t = i / steps              # 중심 0 → 바깥 1
        alpha = round(150 * max(0.0, (t - 0.45) / 0.55) ** 1.4)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=alpha)
    # 중심에서 바깥으로 갈수록 밝아지는 마스크를 반전해 "바깥이 짙은" 안개로
    return vig.filter(ImageFilter.GaussianBlur(size * 0.05))


def _pin(size):
    """지도 핀 — 원 + 아래로 뾰족한 꼬리. 안쪽은 뚫어 앰버 배경이 비치게 한다."""
    layer = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(layer)
    cx = size / 2
    head_cy = size * 0.435
    head_r = size * 0.163
    tip_y = size * 0.755

    draw.ellipse([cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r], fill=255)
    # 머리 원과 만나는 지점에서 자연스럽게 이어지도록 살짝 위에서 시작한다
    half = head_r * 0.74
    draw.polygon([(cx - half, head_cy + head_r * 0.62),
                  (cx + half, head_cy + head_r * 0.62),
                  (cx, tip_y)], fill=255)
    # 가운데 구멍
    hole_r = head_r * 0.40
    draw.ellipse([cx - hole_r, head_cy - hole_r, cx + hole_r, head_cy + hole_r], fill=0)
    return layer


def render(size):
    s = size * SS
    radius = round(s * 0.22)

    icon = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    icon.paste(_gradient(s), (0, 0))

    # 걷힌 자리 — 앰버 빛. 핀보다 먼저 깔아 핀 구멍으로 이 색이 비친다.
    icon.paste(Image.new('RGB', (s, s), AMBER), (0, 0), _cleared_glow(s))
    # 바깥을 덮은 안개
    icon.paste(Image.new('RGB', (s, s), FOG), (0, 0), _fog_vignette(s))
    # 핀
    icon.paste(Image.new('RGB', (s, s), WHITE), (0, 0), _pin(s))

    icon.putalpha(_rounded_mask(s, radius))
    return icon.resize((size, size), Image.LANCZOS)


# 안드로이드 밀도별 런처 아이콘 크기
DENSITIES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}


def main():
    res_dir = sys.argv[1]
    store_path = sys.argv[2] if len(sys.argv) > 2 else None

    for density, size in DENSITIES.items():
        out = os.path.join(res_dir, 'mipmap-' + density, 'ic_launcher.png')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        render(size).save(out, 'PNG', optimize=True)
        print('%-8s %3dpx  %s' % (density, size, out))

    if store_path:
        os.makedirs(os.path.dirname(store_path), exist_ok=True)
        # 스토어 아이콘은 알파 없이 512×512 (원스토어·구글 공통 요구)
        store = render(512).convert('RGBA')
        flat = Image.new('RGB', store.size, NAVY_TOP)
        flat.paste(store, (0, 0), store)
        flat.save(store_path, 'PNG', optimize=True)
        print('%-8s %3dpx  %s' % ('store', 512, store_path))


if __name__ == '__main__':
    main()
