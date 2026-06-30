import os

from PIL import Image, ImageDraw

PROJECT = "/Users/yannbaglinbunod/Documents/Projects/Personal/FretBoardCrazies"
SRC = os.path.join(PROJECT, "art/app-icon.png")
OUT = os.path.join(PROJECT, "audio_listen/Assets.xcassets/AppIcon.appiconset")
MASTER = 1024
TOP = (255, 138, 61, 255)
BOTTOM = (255, 178, 62, 255)
MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def gradient_canvas():
    column = Image.new("RGBA", (1, MASTER))
    for y in range(MASTER):
        t = y / (MASTER - 1)
        column.putpixel(
            (0, y),
            (
                int(TOP[0] * (1 - t) + BOTTOM[0] * t),
                int(TOP[1] * (1 - t) + BOTTOM[1] * t),
                int(TOP[2] * (1 - t) + BOTTOM[2] * t),
                255,
            ),
        )
    return column.resize((MASTER, MASTER), Image.BILINEAR)


def with_guitar(canvas):
    guitar = Image.open(SRC).convert("RGBA")
    target = int(MASTER * 0.72)
    scale = target / max(guitar.size)
    guitar = guitar.resize(
        (int(guitar.width * scale), int(guitar.height * scale)), Image.LANCZOS
    )
    canvas.alpha_composite(
        guitar, ((MASTER - guitar.width) // 2, (MASTER - guitar.height) // 2)
    )
    return canvas


def rounded_master():
    mask = Image.new("L", (MASTER, MASTER), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, MASTER - 1, MASTER - 1], radius=int(MASTER * 0.2237), fill=255
    )
    canvas = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    canvas.paste(gradient_canvas(), (0, 0), mask)
    return with_guitar(canvas)


def ios_master():
    return with_guitar(gradient_canvas()).convert("RGB")


def main():
    rounded = rounded_master()
    for size in MAC_SIZES:
        rounded.resize((size, size), Image.LANCZOS).save(
            os.path.join(OUT, f"icon_{size}.png")
        )
        print(f"wrote icon_{size}.png")
    ios_master().save(os.path.join(OUT, "icon_ios_1024.png"))
    print("wrote icon_ios_1024.png")


main()
