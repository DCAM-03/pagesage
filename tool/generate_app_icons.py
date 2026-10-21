#!/usr/bin/env python3
"""Regenerates the PageSage app icon for every platform from one geometry.

The mark is deliberately drawn here as plain polygons instead of being exported
from a design tool: the whole icon set has to agree pixel for pixel, and a
checked-in script is the only way to guarantee that after the next tweak.

Design (v3, 2026-10-21): two sharp page planes meeting at a narrow gutter — a
book read from above, with nothing illustrative about it. Ink and paper swap
between the light and dark builds so the icon never depends on the desktop
theme it lands on; the accent (coral on paper, lime on ink) is the only hue.

Run from the repository root:

    python3 tool/generate_app_icons.py

It needs Pillow only. Rendering is supersampled 4x and downsampled with
Lanczos, which is what keeps the diagonal page edges clean at 16 px.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs" / "generated"
BRAND = ROOT / "assets" / "images" / "brand"
LINUX_ICONS = ROOT / "linux" / "icons"

# Palette. Field and mark are the two "modes"; the accent is the single hue
# that differs between them.
PAPER_FIELD = "#F2EFE7"
INK_MARK = "#14171A"
CORAL = "#E8502C"

INK_FIELD = "#121416"
PAPER_MARK = "#F6F3EA"
LIME = "#C9F24F"

# Geometry in the 1024-unit design frame. The two planes are mirrored about
# x=512 and separated by a 40-unit gutter, which reads as the spine.
LEFT_PLANE = [(188, 316), (492, 240), (492, 808), (188, 728)]
RIGHT_PLANE = [(836, 316), (532, 240), (532, 808), (836, 728)]

DESIGN = 1024
CORNER_RADIUS = 232
SUPERSAMPLE = 4


def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def render(field: str, mark: str, accent: str, size: int, rounded: bool = True) -> Image.Image:
    """One icon at `size` pixels: field, then the two planes."""
    big = size * SUPERSAMPLE
    scale = big / DESIGN
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    if rounded:
        draw.rounded_rectangle(
            (0, 0, big - 1, big - 1),
            radius=int(CORNER_RADIUS * scale),
            fill=_hex(field) + (255,),
        )
    else:
        draw.rectangle((0, 0, big - 1, big - 1), fill=_hex(field) + (255,))

    for points, colour in ((LEFT_PLANE, mark), (RIGHT_PLANE, accent)):
        draw.polygon(
            [(x * scale, y * scale) for x, y in points],
            fill=_hex(colour) + (255,),
        )

    return image.resize((size, size), Image.LANCZOS)


def render_mark(size: int, mark: str, accent: str) -> Image.Image:
    """The planes alone on transparency, for Android's adaptive foreground."""
    big = size * SUPERSAMPLE
    scale = big / DESIGN
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for points, colour in ((LEFT_PLANE, mark), (RIGHT_PLANE, accent)):
        draw.polygon(
            [(x * scale, y * scale) for x, y in points],
            fill=_hex(colour) + (255,),
        )
    return image.resize((size, size), Image.LANCZOS)


def svg(field: str, mark: str, accent: str) -> str:
    def points(shape):
        return " ".join(f"{x},{y}" for x, y in shape)

    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n'
        f'  <rect width="1024" height="1024" rx="{CORNER_RADIUS}" fill="{field}"/>\n'
        f'  <polygon points="{points(LEFT_PLANE)}" fill="{mark}"/>\n'
        f'  <polygon points="{points(RIGHT_PLANE)}" fill="{accent}"/>\n'
        "</svg>\n"
    )


# Light and dark builds. Names follow what the platform expects; the pair is
# what lets the desktop icon match the desktop.
LIGHT = (PAPER_FIELD, INK_MARK, CORAL)
DARK = (INK_FIELD, PAPER_MARK, LIME)


def write(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}  {image.width}x{image.height}")


def write_ico(path: Path, image: Image.Image) -> None:
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="ICO", sizes=sizes)
    print(f"  {path.relative_to(ROOT)}  ico {len(sizes)} sizes")


def main() -> None:
    print("Brand masters")
    write(BRAND / "app-icon-source.png", render(*LIGHT, 1024))
    write(BRAND / "app-icon-source-dark.png", render(*DARK, 1024))
    (BRAND / "app-icon-source.svg").write_text(svg(*LIGHT))
    (BRAND / "app-icon-source-dark.svg").write_text(svg(*DARK))
    print(f"  {BRAND / 'app-icon-source.svg'}")

    # Shown at 36 px in the library header. Kept at 512 so a 3x display still
    # has real pixels to draw.
    write(BRAND / "app-logo-mark.png", render(*LIGHT, 512))
    write(BRAND / "app-logo-mark-dark.png", render(*DARK, 512))

    # In-app brand mark: the planes alone, no field. A header already sits on
    # the app's own surface, so a tile of its own colour would either double up
    # or disappear. The field is for launchers and taskbars, which do not know
    # what they are drawing on.
    write(BRAND / "app-mark-light.png", render_mark(512, INK_MARK, CORAL))
    write(BRAND / "app-mark-dark.png", render_mark(512, PAPER_MARK, LIME))

    print("Linux desktop (hicolor sizes)")
    # Outside assets/: `assets/images/brand/` is declared wholesale in
    # pubspec.yaml, and eight launcher sizes have no business inside the app's
    # own bundle.
    for size in (16, 24, 32, 48, 64, 128, 256, 512):
        write(
            LINUX_ICONS / f"dev.pagesage.pagesage-{size}.png",
            render(*LIGHT, size),
        )

    print("Android launcher")
    densities = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in densities.items():
        write(
            ROOT / "android/app/src/main/res" / f"mipmap-{density}" / "ic_launcher.png",
            render(*LIGHT, size),
        )
    # Adaptive icon: the launcher masks this itself, so the foreground is the
    # mark alone on the background colour below.
    write(
        ROOT / "android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png",
        render_mark(432, INK_MARK, CORAL),
    )

    print("Windows")
    write_ico(
        ROOT / "windows/runner/resources/app_icon.ico",
        render(*LIGHT, 256),
    )

    print("Web")
    write(ROOT / "web/favicon.png", render(*LIGHT, 32))
    write(ROOT / "web/icons/Icon-192.png", render(*LIGHT, 192))
    write(ROOT / "web/icons/Icon-512.png", render(*LIGHT, 512))
    write(ROOT / "web/icons/Icon-maskable-192.png", render(*LIGHT, 192, rounded=False))
    write(ROOT / "web/icons/Icon-maskable-512.png", render(*LIGHT, 512, rounded=False))

    print("Docs gallery")
    DOCS.mkdir(parents=True, exist_ok=True)
    for name, spec in (("light", LIGHT), ("dark", DARK)):
        write(DOCS / f"app-icon-v3-{name}.png", render(*spec, 1024))
    print("done")


if __name__ == "__main__":
    main()
