"""원스토어 그래픽 이미지(1024x578) 생성.

런처 아이콘과 같은 모티프 — 안개 속 한 곳이 걷혀 밝아진 자리 — 를 가로로 펼친다.
아이콘·스토어 이미지·앱 화면이 같은 색을 쓰도록 make_icon 의 상수를 그대로 가져온다.
"""
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from make_icon import AMBER, FOG, NAVY_BOTTOM, NAVY_TOP, WHITE, _pin

W, H = 1024, 578
BOLD = r'C:\Windows\Fonts\malgunbd.ttf'
REGULAR = r'C:\Windows\Fonts\malgun.ttf'


def _bg():
    """대각선 그라디언트 — 왼쪽 위가 짙고 오른쪽 아래로 열린다."""
    grad = Image.new('RGB', (W, H))
    px = grad.load()
    for y in range(H):
        for x in range(0, W, 4):
            t = (x / W * 0.45 + y / H * 0.55)
            c = tuple(round(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3))
            for dx in range(4):
                if x + dx < W:
                    px[x + dx, y] = c
    return grad


def _radial(size, cx, cy, outer, peak, gamma=1.5):
    layer = Image.new('L', size, 0)
    draw = ImageDraw.Draw(layer)
    steps = 72
    for i in range(steps, 0, -1):
        r = outer * i / steps
        t = 1 - i / steps
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=round(peak * t ** gamma))
    return layer.filter(ImageFilter.GaussianBlur(outer * 0.06))


def main():
    out = sys.argv[1]

    img = _bg().convert('RGBA')

    # 걷힌 자리 — 핀이 설 곳
    pin_cx, pin_cy = W * 0.235, H * 0.50
    img.paste(Image.new('RGB', (W, H), AMBER), (0, 0),
              _radial((W, H), pin_cx, pin_cy, W * 0.215, 255, gamma=2.0))

    # 안개 — 오른쪽 위·아래 모서리를 덮어 글자 뒤를 차분하게 만든다
    fog = Image.new('L', (W, H), 0)
    for cx, cy, r, p in ((W * 0.95, H * 0.05, W * 0.42, 90),
                         (W * 0.80, H * 1.02, W * 0.45, 70),
                         (W * 0.02, H * 0.98, W * 0.30, 60)):
        fog = Image.eval(
            Image.merge('L', [Image.blend(fog.convert('L'),
                                          _radial((W, H), cx, cy, r, p), 0.5)]),
            lambda v: min(255, int(v * 2)),
        )
    img.paste(Image.new('RGB', (W, H), FOG), (0, 0), fog)

    # 핀 — 아이콘과 같은 도형을 재사용한다
    pin_box = round(H * 0.62)
    pin_layer = _pin(pin_box * 4).resize((pin_box, pin_box), Image.LANCZOS)
    pin_rgba = Image.new('RGBA', (pin_box, pin_box), (0, 0, 0, 0))
    pin_rgba.paste(Image.new('RGB', (pin_box, pin_box), WHITE), (0, 0), pin_layer)
    img.alpha_composite(pin_rgba, (round(pin_cx - pin_box / 2), round(pin_cy - pin_box * 0.52)))

    # 고정 비율로 y 를 잡았더니 제목과 부제가 겹쳤다 — 각 줄을 실제로 재서 쌓는다.
    draw = ImageDraw.Draw(img)
    x = round(W * 0.44)
    lines = [
        ('FogApp', ImageFont.truetype(BOLD, 88), WHITE, 26),
        ('걸어서 안개를 걷어내는', ImageFont.truetype(REGULAR, 36), (206, 216, 230), 10),
        ('탐험형 여행 지도', ImageFont.truetype(REGULAR, 36), (206, 216, 230), 30),
        ('한국관광공사 관광정보 기반', ImageFont.truetype(REGULAR, 25), AMBER, 0),
    ]

    heights = []
    for text, font, _, gap in lines:
        box = draw.textbbox((0, 0), text, font=font)
        heights.append((box[3] - box[1], box[1], gap))
    total = sum(h + gap for h, _, gap in heights)

    y = (H - total) / 2
    for (text, font, color, _), (h, top, gap) in zip(lines, heights):
        draw.text((x, y - top), text, font=font, fill=color)
        y += h + gap

    img.convert('RGB').save(out, 'PNG', optimize=True)
    print('%dx%d  %s' % (W, H, out))


if __name__ == '__main__':
    main()
