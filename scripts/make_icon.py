"""Draws the addon icon and logo.

The mark is an enamelled badge: a bronze ring around three role-coloured
quadrants, with a shield, a cross and a sword raised on top. It has to survive two
very different sizes. The addon list draws it around 18 pixels, where only the
tricolour silhouette and the glyph shapes read, while the README and the addon
listing pages show it large, where the material has to hold up. So it is built
from lit gradients and masks at 1024 pixels and downsampled, rather than from flat
fills.

Outputs:
    addon/PartyRoleIcons/Media/Icon.tga  64x64, uncompressed 32-bit, what the
                                         TOC's IconTexture points at. WoW needs
                                         power-of-two, uncompressed TGA or BLP.
    docs/logo.png                        512x512, for the README and the addon
                                         listing pages.

Run:  python scripts/make_icon.py
"""

from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024          # working resolution
OUT = 512            # published logo
ICON = 64            # addon list icon
MASK_SS = 2          # masks are drawn this much larger, then downsampled for AA

# Light comes from the top left, like Blizzard's own frame artwork.
LIGHT = math.radians(225)

# Radii as a fraction of the half canvas.
R_OUTER = 0.97
R_RING_IN = 0.80
R_FIELD = 0.785

# Role colours: deep base, lit highlight. Flat primaries look like clipart, a
# base to highlight ramp reads as enamel.
ROLES = (
    {"name": "tank", "deep": (18, 44, 88), "lit": (108, 178, 248)},
    {"name": "healer", "deep": (10, 68, 38), "lit": (96, 226, 142)},
    {"name": "damage", "deep": (88, 16, 12), "lit": (238, 88, 66)},
)

BRONZE_DEEP = (46, 29, 12)
BRONZE_LIT = (255, 226, 150)
SEAM = (16, 12, 8)

WEDGE_START = -90    # one seam points straight up, so the quadrants sit in a Y


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

def polar() -> tuple[np.ndarray, np.ndarray]:
    """Radius (0 at centre, 1 at the canvas edge) and angle for every pixel."""
    axis = (np.arange(SIZE) - (SIZE - 1) / 2) / ((SIZE - 1) / 2)
    dx, dy = np.meshgrid(axis, axis)
    return np.hypot(dx, dy), np.arctan2(dy, dx)


def mask(draw_shape) -> np.ndarray:
    """Anti-aliased 0..1 mask, by drawing large and shrinking."""
    canvas = Image.new("L", (SIZE * MASK_SS, SIZE * MASK_SS), 0)
    draw_shape(ImageDraw.Draw(canvas), SIZE * MASK_SS)
    canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(canvas, dtype=np.float64) / 255.0


def disc(radius_ratio: float) -> np.ndarray:
    def shape(draw, size):
        inset = size * (1 - radius_ratio) / 2
        draw.ellipse([inset, inset, size - inset, size - inset], fill=255)
    return mask(shape)


def wedge(index: int, radius_ratio: float) -> np.ndarray:
    def shape(draw, size):
        inset = size * (1 - radius_ratio) / 2
        start = WEDGE_START + index * 120
        draw.pieslice([inset, inset, size - inset, size - inset], start, start + 120,
                      fill=255)
    return mask(shape)


def blur(array: np.ndarray, radius: float) -> np.ndarray:
    image = Image.fromarray(np.clip(array * 255, 0, 255).astype(np.uint8), "L")
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius)),
                      dtype=np.float64) / 255.0


def ramp(deep, lit, amount: np.ndarray) -> np.ndarray:
    """Blend between two colours per pixel. amount is 0..1, shape (SIZE, SIZE)."""
    deep = np.array(deep, dtype=np.float64)
    lit = np.array(lit, dtype=np.float64)
    return deep + (lit - deep) * amount[..., None]


def over(base: np.ndarray, colour: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Composite an RGB layer over an RGBA accumulator."""
    src_a = np.clip(alpha, 0, 1)[..., None]
    base_a = base[..., 3:4]
    out_a = src_a + base_a * (1 - src_a)
    safe = np.where(out_a > 0, out_a, 1)
    rgb = (colour * src_a + base[..., :3] * base_a * (1 - src_a)) / safe
    return np.dstack([rgb, out_a])


# ---------------------------------------------------------------------------
# Glyphs
# ---------------------------------------------------------------------------

def shield(draw, box: float) -> None:
    """A heater shield: flat shoulders, sides tapering to a point."""
    cx = cy = box / 2
    half = box * 0.42
    points = [(cx - half, cy - half), (cx + half, cy - half)]
    steps = 24
    span = half * 2
    for step in range(steps + 1):
        t = step / steps
        points.append((cx + half * (1 - t * t), cy - half + span * (0.34 + 0.66 * t)))
    for step in range(steps, -1, -1):
        t = step / steps
        points.append((cx - half * (1 - t * t), cy - half + span * (0.34 + 0.66 * t)))
    draw.polygon(points, fill=255)


def cross(draw, box: float) -> None:
    cx = cy = box / 2
    arm = box * 0.44
    thick = box * 0.30
    draw.rectangle([cx - thick / 2, cy - arm, cx + thick / 2, cy + arm], fill=255)
    draw.rectangle([cx - arm, cy - thick / 2, cx + arm, cy + thick / 2], fill=255)


def single_sword(draw, box: float) -> None:
    """One upright sword, filling the box vertically."""
    cx = box / 2
    half = box * 0.46
    top, bottom = box / 2 - half, box / 2 + half
    blade = box * 0.17
    guard = bottom - box * 0.30
    draw.polygon(
        [
            (cx, top),
            (cx + blade / 2, top + box * 0.16),
            (cx + blade / 2, guard),
            (cx - blade / 2, guard),
            (cx - blade / 2, top + box * 0.16),
        ],
        fill=255,
    )
    draw.rectangle([cx - box * 0.30, guard, cx + box * 0.30, guard + box * 0.085],
                   fill=255)
    draw.rectangle([cx - blade * 0.40, guard + box * 0.085, cx + blade * 0.40, bottom],
                   fill=255)


def glyph_layer(index: int, box: int) -> Image.Image:
    """The glyph on its own square canvas, so the damage mark can be rotated."""
    layer = Image.new("L", (box, box), 0)
    if index == 2:
        # A diagonal blade. Upright it reads as another cross at small sizes; on
        # the slant the silhouette is unmistakable.
        single_sword(ImageDraw.Draw(layer), box)
        layer = layer.rotate(-38, resample=Image.BICUBIC)
    else:
        (shield, cross)[index](ImageDraw.Draw(layer), box)
    return layer


def glyph_mask(index: int) -> np.ndarray:
    """The glyph for wedge `index`, placed at that wedge's centre of mass."""
    angle = math.radians(WEDGE_START + index * 120 + 60)
    canvas_size = SIZE * MASK_SS
    # The rotated pair loses reach in its box, so give it a little more room.
    # The rotated blade loses reach inside its box, so give it a little more room.
    box = int(canvas_size * (0.255 if index == 2 else 0.215))

    layer = glyph_layer(index, box)
    canvas = Image.new("L", (canvas_size, canvas_size), 0)
    cx = (0.5 + math.cos(angle) * 0.215) * canvas_size
    cy = (0.5 + math.sin(angle) * 0.215) * canvas_size
    canvas.paste(layer, (int(cx - box / 2), int(cy - box / 2)), layer)

    canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(canvas, dtype=np.float64) / 255.0


# ---------------------------------------------------------------------------
# The badge
# ---------------------------------------------------------------------------

def build() -> Image.Image:
    radius, angle = polar()
    # How much this pixel faces the light, 0 away from it, 1 straight at it.
    facing = (np.cos(angle - LIGHT) + 1) / 2

    badge = np.zeros((SIZE, SIZE, 4))

    # Bronze ring. The profile across the ring's own width is what sells metal:
    # dark at both edges, a narrow specular ridge towards the outside, and the
    # whole thing modulated by how much the pixel faces the light.
    ring = disc(R_OUTER) * (1 - disc(R_RING_IN))
    across = np.clip((radius - R_RING_IN) / (R_OUTER - R_RING_IN), 0, 1)
    body = np.sin(across * math.pi) ** 0.5
    ridge = np.exp(-(((across - 0.62) / 0.15) ** 2))
    inner_ridge = np.exp(-(((across - 0.14) / 0.10) ** 2))
    brushed = 0.5 + 0.5 * np.sin(radius * 520)
    lit = 0.32 + 0.68 * facing
    metal = np.clip(
        0.06 + 0.50 * body * lit + 0.85 * ridge * lit + 0.30 * inner_ridge * lit
        + 0.06 * brushed * body,
        0, 1)
    badge = over(badge, ramp(BRONZE_DEEP, BRONZE_LIT, metal), ring)

    # Enamel field: each wedge is a dome, lit from the same direction as the ring
    # and falling off hard at the rim so the surface reads as curved.
    field = disc(R_FIELD)
    height = np.clip(radius / R_FIELD, 0, 1)
    dome = np.sqrt(np.clip(1 - height ** 2, 0, 1))
    vignette = 1 - 0.45 * height ** 6
    shade = np.clip((0.05 + 0.32 * dome + 0.90 * dome ** 1.6 * (0.22 + 0.78 * facing))
                    * vignette, 0, 1)
    for index, role in enumerate(ROLES):
        badge = over(badge, ramp(role["deep"], role["lit"], shade),
                     wedge(index, R_FIELD) * field)

    # Seams, engraved rather than drawn: a dark groove with lighter shoulders,
    # at a constant width whatever the radius.
    groove = np.zeros((SIZE, SIZE))
    shoulder = np.zeros((SIZE, SIZE))
    for index in range(3):
        boundary = math.radians(WEDGE_START + index * 120)
        delta = np.abs(((angle - boundary + math.pi) % (2 * math.pi)) - math.pi)
        arc = delta * np.maximum(radius, 1e-6)
        groove = np.maximum(groove, np.clip(1 - arc / 0.010, 0, 1))
        shoulder = np.maximum(shoulder, np.clip(1 - arc / 0.022, 0, 1))
    badge = over(badge, np.full((SIZE, SIZE, 3), 255.0),
                 np.clip(shoulder - groove, 0, 1) * field * 0.16)
    badge = over(badge, np.full((SIZE, SIZE, 3), SEAM, dtype=np.float64),
                 groove * field * 0.85)

    # The enamel sits inside the metal, so darken it against the ring and put a
    # thin catch light on the metal's inner lip.
    inner_shadow = np.clip((radius - R_FIELD * 0.78) / (R_FIELD * 0.22), 0, 1) ** 2
    badge = over(badge, np.zeros((SIZE, SIZE, 3)), inner_shadow * field * 0.62)

    lip = disc(R_RING_IN + 0.012) * (1 - disc(R_RING_IN - 0.004))
    badge = over(badge, ramp(BRONZE_DEEP, BRONZE_LIT, np.clip(0.25 + 0.75 * facing, 0, 1)),
                 lip * 0.8)

    # Glyphs, raised out of the enamel: contact shadow, a silver fill graded along
    # the glyph's own height, a lit top left edge and a shaded bottom right one.
    rows = np.arange(SIZE)[:, None] * np.ones((1, SIZE))
    for index in range(3):
        glyph = glyph_mask(index)
        angle = math.radians(WEDGE_START + index * 120 + 60)
        centre_y = (0.5 + math.sin(angle) * 0.215) * SIZE

        offset = int(SIZE * 0.009)
        shadow = blur(np.roll(np.roll(glyph, offset, axis=0), offset, axis=1),
                      SIZE * 0.012)
        badge = over(badge, np.zeros((SIZE, SIZE, 3)), shadow * 0.60)

        fill = np.clip(0.5 - (rows - centre_y) / (SIZE * 0.30), 0, 1)
        badge = over(badge, ramp((150, 142, 128), (255, 254, 250), fill), glyph)

        step = max(2, int(SIZE * 0.004))
        rim = np.clip(glyph - np.roll(np.roll(glyph, step, axis=0), step, axis=1), 0, 1)
        badge = over(badge, np.full((SIZE, SIZE, 3), 255.0), rim * 0.75)
        shade = np.clip(glyph - np.roll(np.roll(glyph, -step, axis=0), -step, axis=1), 0, 1)
        badge = over(badge, np.full((SIZE, SIZE, 3), 40.0), shade * 0.55)

    # A glass highlight across the top, and grain to break up the gradients.
    def gloss(draw, size):
        draw.ellipse([size * 0.20, size * 0.06, size * 0.80, size * 0.42], fill=255)
    highlight = blur(mask(gloss), SIZE * 0.035) * disc(R_FIELD)
    badge = over(badge, np.full((SIZE, SIZE, 3), 255.0), highlight * 0.16)

    rng = np.random.default_rng(7)
    grain = blur(rng.random((SIZE, SIZE)), 0.6)
    badge[..., :3] *= (0.965 + 0.07 * grain)[..., None]

    # Outer shadow so the badge sits on the page instead of floating.
    body = badge[..., 3]
    drop = blur(np.roll(disc(R_OUTER), int(SIZE * 0.012), axis=0), SIZE * 0.02)
    canvas = over(np.zeros((SIZE, SIZE, 4)), np.zeros((SIZE, SIZE, 3)), drop * 0.45)
    canvas = over(canvas, badge[..., :3], body)

    rgba = np.clip(canvas, 0, 255)
    rgba[..., 3] *= 255
    image = Image.fromarray(rgba.astype(np.uint8), "RGBA")
    return image.resize((OUT, OUT), Image.LANCZOS)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    logo = build()

    docs = os.path.join(root, "docs")
    os.makedirs(docs, exist_ok=True)
    logo.save(os.path.join(docs, "logo.png"))

    media = os.path.join(root, "addon", "PartyRoleIcons", "Media")
    os.makedirs(media, exist_ok=True)
    # WoW only reads uncompressed TGA, and Pillow writes uncompressed by default.
    logo.resize((ICON, ICON), Image.LANCZOS).save(os.path.join(media, "Icon.tga"))

    print("wrote docs/logo.png and addon/PartyRoleIcons/Media/Icon.tga")


if __name__ == "__main__":
    main()
