"""Generates the Android launcher icon vectors and the feature graphic's SVG from the same
geometry as OlaBallTests/AppIconTests.swift (AppIconArt) and Views/HUD.swift (GameBackground,
Wordmark), so the two platforms' art cannot drift apart. Edit the numbers in the Swift, mirror
them here, run this, then ./render.sh for the PNGs.

  python3 android/play/icon_vectors.py

Writes:
  android/app/src/main/res/drawable/ic_launcher_{background,foreground,monochrome}.xml
  android/play/feature-graphic.svg
  icon-preview.svg in $ICON_PREVIEW_DIR (default: the system temp dir): the adaptive icon on
  its full canvas with the 72dp mask and 66dp safe circle drawn, under a circular mask, and the
  monochrome layer on a themed-icon disc. Open it, or `qlmanage -t -s 1024 -o . icon-preview.svg`.
"""
import math
import os
import tempfile

PLAY = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(PLAY))
DRAWABLE = f"{ROOT}/android/app/src/main/res/drawable"
PREVIEW_DIR = os.environ.get("ICON_PREVIEW_DIR", tempfile.gettempdir())

# Theme colours (identical in Views/Theme.swift and ui/theme/Theme.kt).
HIS = "#2F56BF"
HERS = "#D6406F"
INK = "#1D1A33"
GOLD = "#EDB240"
GOLD_DEEP = "#B97F0C"
NIGHT = "#1A1B4B"
NIGHT_DEEP = "#0E0F2E"
VIOLET = "#4F3DB0"
CREAM = "#FFF3D9"
WHITE = "#FFFFFF"


def mix(a, b, t):
    """Theme.swift's Color.mix: straight sRGB blend toward b."""
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(a, b))


BACKDROP = mix(VIOLET, NIGHT, 0.30)      # #3F3392, the game's violet pulled toward night
assert BACKDROP == "#3F3392", BACKDROP


def argb(hex_rgb, alpha):
    """Android colour string with an alpha byte in front."""
    return f"#{round(alpha * 255):02X}{hex_rgb[1:]}"


def n(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def pt(x, y):
    return f"{n(x)},{n(y)}"


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def circle(cx, cy, r):
    return (f"M{pt(cx - r, cy)} a{n(r)},{n(r)} 0 1,0 {n(2 * r)},0 "
            f"a{n(r)},{n(r)} 0 1,0 {n(-2 * r)},0 z")


def wedge(cx, cy, r, a0, a1):
    """Wedge from a0 to a1 degrees (y-down, clockwise positive), same as the Swift Wedge shape."""
    x0, y0 = polar(cx, cy, r, a0)
    x1, y1 = polar(cx, cy, r, a1)
    return f"M{pt(cx, cy)} L{pt(x0, y0)} A{n(r)},{n(r)} 0 0,1 {pt(x1, y1)} z"


def sector(cx, cy, ro, ri, a0, a1, gap):
    """Annular sector between radii ri..ro whose straight edges sit `gap` inside the rays a0 and a1,
    so eight of them leave a clean transparent divider between neighbours (monochrome wheel)."""
    r0, r1 = math.radians(a0), math.radians(a1)
    u0, n0 = (math.cos(r0), math.sin(r0)), (-math.sin(r0), math.cos(r0))
    u1, n1 = (math.cos(r1), math.sin(r1)), (-math.sin(r1), math.cos(r1))
    to, ti = math.sqrt(ro * ro - gap * gap), math.sqrt(ri * ri - gap * gap)
    a = (cx + to * u0[0] + gap * n0[0], cy + to * u0[1] + gap * n0[1])
    b = (cx + to * u1[0] - gap * n1[0], cy + to * u1[1] - gap * n1[1])
    c = (cx + ti * u1[0] - gap * n1[0], cy + ti * u1[1] - gap * n1[1])
    d = (cx + ti * u0[0] + gap * n0[0], cy + ti * u0[1] + gap * n0[1])
    return (f"M{pt(*a)} A{n(ro)},{n(ro)} 0 0,1 {pt(*b)} L{pt(*c)} "
            f"A{n(ri)},{n(ri)} 0 0,0 {pt(*d)} z")


def rotated_rect(cx, cy, hw, y0, y1, deg):
    """A rectangle x in [-hw, hw], y in [y0, y1] about (cx, cy), rotated `deg` clockwise (Swift's rotationEffect)."""
    t = math.radians(deg)
    out = []
    for x, y in ((-hw, y0), (hw, y0), (hw, y1), (-hw, y1)):
        out.append((cx + x * math.cos(t) - y * math.sin(t), cy + x * math.sin(t) + y * math.cos(t)))
    return "M" + " L".join(pt(*p) for p in out) + " z"


def star(cx, cy, outer):
    """Swift's Star shape: ten points, inner radius 0.44 of outer, first point straight up."""
    inner = outer * 0.44
    pts = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        pts.append(polar(cx, cy, r, i * 36 - 90))
    return "M" + " L".join(pt(*p) for p in pts) + " z"


def triangle(cx, top, w, h):
    """Swift's Triangle: a downward-pointing triangle filling a w x h frame."""
    return f"M{pt(cx - w / 2, top)} L{pt(cx + w / 2, top)} L{pt(cx, top + h)} z"


def rays(cx, cy, radius, count, start_deg=0.0):
    """Swift's Rays: `count` rays, each one step wide with a step gap, from the centre."""
    step = 360.0 / (count * 2)
    parts = []
    for i in range(0, count * 2, 2):
        a0 = start_deg + i * step
        parts.append(f"M{pt(cx, cy)} L{pt(*polar(cx, cy, radius, a0))} L{pt(*polar(cx, cy, radius, a0 + step))} z")
    return " ".join(parts)


# ----------------------------------------------------------------------------------------------
# Adaptive icon geometry. The iOS icon is authored on a square of side s; here s maps to K dp of
# the 108dp viewport. K = 76 is the largest scale at which the wheel-plus-pointer group (0.83s
# tall, pointer corners included) stays inside the 66dp safe circle, with ~0.4dp to spare.
# ----------------------------------------------------------------------------------------------
K = 76.0
CX, CY = 54.0, 54.0
SLICES = 8
SLICE = 360.0 / SLICES


def icon(x, y):
    """Icon fraction (0..1 of s) -> viewport dp."""
    return CX + (x - 0.5) * K, CY + (y - 0.5) * K


d = 0.70 * K                      # wheel diameter
r = d / 2
WX, WY = icon(0.5, 0.535)         # wheel centre (the Swift wheel is offset y by 0.035s)
TILT = -11                        # wheel tilt; the hub is rotated back so the star stays upright

# Layers of the coloured foreground -----------------------------------------------------------
shadow = circle(WX, WY + d * 0.035, r)
rim = circle(WX, WY, r)
wedge_r = r - d * 0.055            # .padding(d * 0.055) on a d-wide frame
his_wedges = " ".join(wedge(WX, WY, wedge_r, i * SLICE - 90, (i + 1) * SLICE - 90) for i in range(SLICES) if i % 2 == 0)
hers_wedges = " ".join(wedge(WX, WY, wedge_r, i * SLICE - 90, (i + 1) * SLICE - 90) for i in range(SLICES) if i % 2 == 1)
dividers = " ".join(rotated_rect(WX, WY, d * 0.018 / 2, -r * 0.9, 0, i * SLICE) for i in range(SLICES))
outline_w = d * 0.022
outline = circle(WX, WY, r - outline_w / 2)          # strokeBorder: the stroke sits inside the circle

hub_r = d * 0.30 / 2
hub_shadow = circle(WX, WY + d * 0.012, hub_r)
hub = circle(WX, WY, hub_r)
hub_outline_w = d * 0.018
hub_outline = circle(WX, WY, hub_r - hub_outline_w / 2)
star_outer = (d * 0.30 - 2 * d * 0.075) / 2         # .padding(d * 0.075) inside the 0.30d hub frame
star_path = star(WX, WY, star_outer)
star_stroke_w = d * 0.010

pw = 0.17 * K
ph = pw * 0.92
_, PY = icon(0.5, 0.5 - 0.335)                        # pointer centre
p_top = PY - ph / 2
pointer_shadow = triangle(CX, p_top + pw * 0.06, pw, ph)
pointer = triangle(CX, p_top, pw, ph)
pointer_stroke_w = pw * 0.07

# Background ------------------------------------------------------------------------------------
bg_rays = rays(CX, CY, 80, 16)
vignette_r0, vignette_r1 = 0.30 * K, 0.75 * K

# Monochrome silhouette -----------------------------------------------------------------------
mono_gap = 1.6
mono_ring = circle(WX, WY, r) + " " + circle(WX, WY, r - 2.2)
mono_wedge_ro = r - 2.2 - mono_gap
mono_wedge_ri = hub_r + mono_gap
mono_wedges = " ".join(sector(WX, WY, mono_wedge_ro, mono_wedge_ri, i * SLICE - 90, (i + 1) * SLICE - 90, mono_gap / 2)
                       for i in range(SLICES))
mono_hub = hub + " " + star_path
# The pointer stops inside the ring band instead of poking through the divider gap into the
# wedges, which at themed-icon size would read as a smudge rather than a pointer.
mono_pointer = f"M{pt(CX - pw / 2, p_top)} L{pt(CX + pw / 2, p_top)} L{pt(CX, WY - r + 2.2)} z"


# ----------------------------------------------------------------------------------------------
# Writers
# ----------------------------------------------------------------------------------------------
def check_safe_zone():
    """Assert the coloured foreground sits inside the 66dp safe circle."""
    worst = 0.0
    half_stroke = pointer_stroke_w / 2
    for x, y in ((CX - pw / 2 - half_stroke, p_top - half_stroke), (CX + pw / 2 + half_stroke, p_top - half_stroke)):
        worst = max(worst, math.hypot(x - CX, y - CY))
    t = math.radians(TILT)
    sx, sy = WX - d * 0.035 * math.sin(t), WY + d * 0.035 * math.cos(t)   # shadow centre after the tilt
    worst = max(worst, math.hypot(sx - CX, sy - CY) + r)
    worst = max(worst, math.hypot(WX - CX, WY - CY) + r)
    print(f"safe zone: farthest foreground point {worst:.2f}dp from centre (limit 33)")
    assert worst <= 33, worst


def vector_open(extra_ns=""):
    return (f'<vector xmlns:android="http://schemas.android.com/apk/res/android"{extra_ns}\n'
            '    android:width="108dp"\n    android:height="108dp"\n'
            '    android:viewportWidth="108"\n    android:viewportHeight="108">\n')


def path(data, fill=None, stroke=None, stroke_w=None, join=None, fill_type=None, indent=4):
    pad = " " * indent
    attrs = []
    if fill:
        attrs.append(f'android:fillColor="{fill}"')
    if fill_type:
        attrs.append(f'android:fillType="{fill_type}"')
    if stroke:
        attrs.append(f'android:strokeColor="{stroke}"')
        attrs.append(f'android:strokeWidth="{n(stroke_w)}"')
    if join:
        attrs.append(f'android:strokeLineJoin="{join}"')
    lines = [f"{pad}<path"] + [f"{pad}    {a}" for a in attrs] + [f'{pad}    android:pathData="{data}" />']
    return "\n".join(lines) + "\n"


def write_background():
    xml = '<?xml version="1.0" encoding="utf-8"?>\n'
    xml += ("<!--\n"
            "  Launcher icon, background layer: the same violet-toward-night backdrop the game uses,\n"
            "  with sunburst rays and a vignette. Mirrors AppIconArt in OlaBallTests/AppIconTests.swift;\n"
            "  the launcher's own mask shows the middle 72dp of this 108dp canvas and may parallax it.\n"
            "-->\n")
    xml += vector_open(' xmlns:aapt="http://schemas.android.com/aapt"')
    xml += "    <!-- Violet mixed 30 percent toward night. -->\n"
    xml += path("M0,0h108v108h-108z", fill=BACKDROP)
    xml += "    <!-- Sixteen rays from the centre, white at 7 percent. -->\n"
    xml += path(bg_rays, fill=argb(WHITE, 0.07))
    xml += ("    <!-- Vignette: clear to night at 55 percent, from 0.30 to 0.75 of the icon side. -->\n"
            '    <path android:pathData="M0,0h108v108h-108z">\n'
            '        <aapt:attr name="android:fillColor">\n'
            '            <gradient\n'
            '                android:type="radial"\n'
            f'                android:centerX="{n(CX)}"\n'
            f'                android:centerY="{n(CY)}"\n'
            f'                android:gradientRadius="{n(vignette_r1)}">\n'
            f'                <item android:offset="0" android:color="{argb(NIGHT, 0)}" />\n'
            f'                <item android:offset="{n(vignette_r0 / vignette_r1)}" android:color="{argb(NIGHT, 0)}" />\n'
            f'                <item android:offset="1" android:color="{argb(NIGHT, 0.55)}" />\n'
            '            </gradient>\n'
            '        </aapt:attr>\n'
            '    </path>\n')
    xml += "</vector>\n"
    with open(f"{DRAWABLE}/ic_launcher_background.xml", "w") as f:
        f.write(xml)


def write_foreground():
    xml = '<?xml version="1.0" encoding="utf-8"?>\n'
    xml += ("<!--\n"
            "  Launcher icon, foreground layer: a his-blue and her-pink prize wheel with a gold pointer.\n"
            "  The wheel is the \"spin\" in Spinola; the two colours are His World and Her World. No\n"
            "  lettering, because text is unreadable at home-screen size. Mirrors AppIconArt in\n"
            "  OlaBallTests/AppIconTests.swift, scaled so the whole wheel-plus-pointer group sits inside\n"
            "  the 66dp safe circle (Android masks the icon into whatever shape the launcher likes).\n"
            "-->\n")
    xml += vector_open()
    xml += f"    <!-- Wheel, tilted {TILT} degrees about its centre. -->\n"
    xml += f'    <group android:rotation="{TILT}" android:pivotX="{n(WX)}" android:pivotY="{n(WY)}">\n'
    xml += "        <!-- Drop shadow, the sticker look used throughout the app. -->\n"
    xml += path(shadow, fill=argb(INK, 0.45), indent=8)
    xml += "        <!-- Rim. -->\n"
    xml += path(rim, fill=WHITE, indent=8)
    xml += "        <!-- Slices, alternating His and Her. -->\n"
    xml += path(his_wedges, fill=HIS, indent=8)
    xml += path(hers_wedges, fill=HERS, indent=8)
    xml += "        <!-- White dividers between slices. -->\n"
    xml += path(dividers, fill=WHITE, indent=8)
    xml += "        <!-- Ink outline. -->\n"
    xml += path(outline, stroke=INK, stroke_w=outline_w, indent=8)
    xml += "    </group>\n"
    xml += ("    <!-- Hub: brass disc with a star, like the in-game wheel. Drawn upright: on iOS it is\n"
            "         rotated back by the wheel's tilt so the star stays level. -->\n")
    xml += path(hub_shadow, fill=GOLD_DEEP)
    xml += path(hub, fill=GOLD)
    xml += path(hub_outline, stroke=INK, stroke_w=hub_outline_w)
    xml += path(star_path, fill=WHITE, stroke=INK, stroke_w=star_stroke_w)
    xml += "    <!-- Pointer: gold with a goldDeep shadow and an ink outline. -->\n"
    xml += path(pointer_shadow, fill=GOLD_DEEP)
    xml += path(pointer, fill=GOLD, stroke=INK, stroke_w=pointer_stroke_w, join="round")
    xml += "</vector>\n"
    with open(f"{DRAWABLE}/ic_launcher_foreground.xml", "w") as f:
        f.write(xml)


def write_monochrome():
    xml = '<?xml version="1.0" encoding="utf-8"?>\n'
    xml += ("<!--\n"
            "  Launcher icon, monochrome layer (Android 13 themed icons): the wheel's silhouette in one\n"
            "  colour. The system keeps only the alpha and tints it, so the rim, the eight slices, the\n"
            "  hub with its star and the pointer are separated by transparent gaps instead of colour.\n"
            "-->\n")
    xml += vector_open()
    xml += "    <!-- Rim. -->\n"
    xml += path(mono_ring, fill=INK, fill_type="evenOdd")
    xml += f"    <!-- Slices, tilted {TILT} degrees like the coloured wheel. -->\n"
    xml += f'    <group android:rotation="{TILT}" android:pivotX="{n(WX)}" android:pivotY="{n(WY)}">\n'
    xml += path(mono_wedges, fill=INK, indent=8)
    xml += "    </group>\n"
    xml += "    <!-- Hub with the star cut out. -->\n"
    xml += path(mono_hub, fill=INK, fill_type="evenOdd")
    xml += "    <!-- Pointer. -->\n"
    xml += path(mono_pointer, fill=INK)
    xml += "</vector>\n"
    with open(f"{DRAWABLE}/ic_launcher_monochrome.xml", "w") as f:
        f.write(xml)


# ----------------------------------------------------------------------------------------------
# SVG previews of the very same path data (SVG and VectorDrawable share the path grammar).
# ----------------------------------------------------------------------------------------------
def svg_path(data, fill="none", stroke=None, stroke_w=None, join=None, fill_rule=None, opacity=None):
    a = [f'd="{data}"', f'fill="{fill}"']
    if fill_rule:
        a.append(f'fill-rule="{fill_rule}"')
    if opacity is not None:
        a.append(f'fill-opacity="{opacity}"')
    if stroke:
        a += [f'stroke="{stroke}"', f'stroke-width="{n(stroke_w)}"']
    if join:
        a.append(f'stroke-linejoin="{join}"')
    return "<path " + " ".join(a) + "/>\n"


def preview_background_svg():
    s = f'<rect width="108" height="108" fill="{BACKDROP}"/>\n'
    s += svg_path(bg_rays, fill=WHITE, opacity=0.07)
    s += ('<defs><radialGradient id="v" gradientUnits="userSpaceOnUse" '
          f'cx="{n(CX)}" cy="{n(CY)}" r="{n(vignette_r1)}">'
          f'<stop offset="0" stop-color="{NIGHT}" stop-opacity="0"/>'
          f'<stop offset="{n(vignette_r0 / vignette_r1)}" stop-color="{NIGHT}" stop-opacity="0"/>'
          f'<stop offset="1" stop-color="{NIGHT}" stop-opacity="0.55"/></radialGradient></defs>\n')
    s += '<rect width="108" height="108" fill="url(#v)"/>\n'
    return s


def preview_foreground_svg():
    s = f'<g transform="rotate({TILT} {n(WX)} {n(WY)})">\n'
    s += svg_path(shadow, fill=INK, opacity=0.45)
    s += svg_path(rim, fill=WHITE)
    s += svg_path(his_wedges, fill=HIS)
    s += svg_path(hers_wedges, fill=HERS)
    s += svg_path(dividers, fill=WHITE)
    s += svg_path(outline, stroke=INK, stroke_w=outline_w)
    s += "</g>\n"
    s += svg_path(hub_shadow, fill=GOLD_DEEP)
    s += svg_path(hub, fill=GOLD)
    s += svg_path(hub_outline, stroke=INK, stroke_w=hub_outline_w)
    s += svg_path(star_path, fill=WHITE, stroke=INK, stroke_w=star_stroke_w)
    s += svg_path(pointer_shadow, fill=GOLD_DEEP)
    s += svg_path(pointer, fill=GOLD, stroke=INK, stroke_w=pointer_stroke_w, join="round")
    return s


def preview_monochrome_svg(colour):
    s = svg_path(mono_ring, fill=colour, fill_rule="evenodd")
    s += f'<g transform="rotate({TILT} {n(WX)} {n(WY)})">\n' + svg_path(mono_wedges, fill=colour) + "</g>\n"
    s += svg_path(mono_hub, fill=colour, fill_rule="evenodd")
    s += svg_path(mono_pointer, fill=colour)
    return s


def write_previews():
    # Three tiles: full 108 canvas with the 72 mask and 66 safe circle drawn; the icon under a
    # circular mask; the monochrome layer on a themed-icon disc.
    tile = 108
    # Quick Look lays SVGs out on a 750pt page and crops the rest, so the document is 750 wide.
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="750" height="250" '
           f'viewBox="0 0 {tile * 3} {tile}">\n')
    svg += '<rect width="324" height="108" fill="#F4EFE4"/>\n'
    svg += '<defs><clipPath id="mask"><circle cx="54" cy="54" r="36"/></clipPath></defs>\n'
    svg += "<g>\n" + preview_background_svg() + preview_foreground_svg() + "</g>\n"
    svg += (f'<circle cx="{n(CX)}" cy="{n(CY)}" r="36" fill="none" stroke="#FFFFFF" stroke-width="0.4" stroke-dasharray="1.5 1"/>\n'
            f'<circle cx="{n(CX)}" cy="{n(CY)}" r="33" fill="none" stroke="{GOLD}" stroke-width="0.4" stroke-dasharray="1.5 1"/>\n')
    svg += '<g transform="translate(108 0)" clip-path="url(#mask)">\n' + preview_background_svg() + preview_foreground_svg() + "</g>\n"
    svg += '<g transform="translate(216 0)">\n'
    svg += '<circle cx="54" cy="54" r="36" fill="#DCE1F3"/>\n'
    svg += preview_monochrome_svg("#3A3F63")
    svg += "</g>\n</svg>\n"
    out = f"{PREVIEW_DIR}/icon-preview.svg"
    with open(out, "w") as f:
        f.write(svg)
    print("preview:", out)


# ----------------------------------------------------------------------------------------------
# Feature graphic, 1024x500: the game's backdrop (GameBackground in Views/HUD.swift), the
# Wordmark (two stacked world chips with the VS badge on the seam) and the tagline.
# ----------------------------------------------------------------------------------------------
def sunburst(w, h, rays_n=18):
    """GameBackground's Sunburst: rays from a point just above the top edge."""
    cx, cy, radius = w / 2, -h * 0.08, h * 2.4
    return rays(cx, cy, radius, rays_n)


def halftone(w, h, scale):
    """GameBackground's Halftone: a band of dots that grow toward the bottom edge."""
    spacing = 13 * scale
    start_y = h * 0.58
    out = []
    y, row = start_y, 0
    while y < h + spacing:
        t = (y - start_y) / max(1, h - start_y)
        rad = (0.5 + 4.6 * t * t) * scale
        x = 0 if row % 2 == 0 else spacing / 2
        while x < w + spacing:
            out.append(f'<circle cx="{n(x)}" cy="{n(y)}" r="{n(rad)}"/>')
            x += spacing
        y += spacing * 0.87
        row += 1
    return "\n".join(out)


def chip_svg(text, colour, x, y, k):
    """Wordmark.chip: 270x66 rounded chip with a dark offset, a top gloss, an ink stroke and logo type."""
    w, h, rad = 270 * k, 66 * k, 18 * k
    s = f'<rect x="{n(x)}" y="{n(y + 6 * k)}" width="{n(w)}" height="{n(h)}" rx="{n(rad)}" fill="{mix(colour, "#000000", 0.3)}"/>\n'
    s += f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" rx="{n(rad)}" fill="{colour}"/>\n'
    s += f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" rx="{n(rad)}" fill="url(#gloss)"/>\n'
    s += (f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" rx="{n(rad)}" fill="none" '
          f'stroke="{INK}" stroke-width="{n(3 * k)}"/>\n')
    size = 36 * k
    s += (f'<text x="{n(x + w / 2)}" y="{n(y + h / 2 + size * 0.36)}" text-anchor="middle" '
          f'font-family="Rockwell, \'American Typewriter\', serif" font-weight="bold" font-size="{n(size)}" '
          f'fill="{WHITE}">{text}</text>\n')
    return s


def write_feature_graphic():
    W, H = 1024, 500
    k = 2.0                                  # wordmark scale: chips 540x132
    chip_w, chip_h, gap = 270 * k, 66 * k, 8 * k
    block_h = chip_h * 2 + gap
    top = 56
    left = (W - chip_w) / 2
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
           "<!-- Spinola feature graphic. Backdrop from GameBackground, wordmark from Wordmark (Views/HUD.swift). -->\n"
           "<defs>\n"
           f'  <radialGradient id="vignette" gradientUnits="userSpaceOnUse" cx="{W / 2}" cy="{H / 2}" r="620">\n'
           f'    <stop offset="0.38" stop-color="{NIGHT_DEEP}" stop-opacity="0"/>\n'
           f'    <stop offset="1" stop-color="{NIGHT_DEEP}" stop-opacity="0.5"/>\n'
           "  </radialGradient>\n"
           '  <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">\n'
           f'    <stop offset="0" stop-color="{WHITE}" stop-opacity="0.18"/>\n'
           f'    <stop offset="0.5" stop-color="{WHITE}" stop-opacity="0"/>\n'
           "  </linearGradient>\n"
           "</defs>\n")
    svg += f'<rect width="{W}" height="{H}" fill="{BACKDROP}"/>\n'
    svg += f'<path d="{sunburst(W, H)}" fill="{WHITE}" fill-opacity="0.07"/>\n'
    svg += f'<g fill="{NIGHT_DEEP}" fill-opacity="0.28">\n{halftone(W, H, 2.0)}\n</g>\n'
    svg += f'<rect width="{W}" height="{H}" fill="url(#vignette)"/>\n'
    # Wordmark.
    svg += chip_svg("HIS WORLD", HIS, left, top, k)
    svg += chip_svg("HER WORLD", HERS, left, top + chip_h + gap, k)
    vs_cx, vs_cy, vs_r = W / 2, top + chip_h + gap / 2, 24 * k
    svg += f'<g transform="rotate(-8 {n(vs_cx)} {n(vs_cy)})">\n'
    svg += f'<circle cx="{n(vs_cx)}" cy="{n(vs_cy + 3 * k)}" r="{n(vs_r)}" fill="{GOLD_DEEP}"/>\n'
    svg += f'<circle cx="{n(vs_cx)}" cy="{n(vs_cy)}" r="{n(vs_r)}" fill="{GOLD}" stroke="{INK}" stroke-width="{n(3 * k)}"/>\n'
    svg += (f'<text x="{n(vs_cx)}" y="{n(vs_cy + 18 * k * 0.36)}" text-anchor="middle" '
            f'font-family="Rockwell, \'American Typewriter\', serif" font-weight="bold" font-size="{n(18 * k)}" '
            f'fill="{INK}">VS</text>\n')
    svg += "</g>\n"
    # Tagline, in the slab serif the app reads in.
    tag_y = top + block_h + 6 * k + 84
    svg += (f'<text x="{W / 2}" y="{n(tag_y)}" text-anchor="middle" '
            f'font-family="Rockwell, \'American Typewriter\', serif" font-weight="bold" font-size="52" '
            f'fill="{CREAM}">Trivia for two</text>\n')
    svg += "</svg>\n"
    os.makedirs(PLAY, exist_ok=True)
    with open(f"{PLAY}/feature-graphic.svg", "w") as f:
        f.write(svg)


if __name__ == "__main__":
    check_safe_zone()
    write_background()
    write_foreground()
    write_monochrome()
    write_previews()
    write_feature_graphic()
    print("wheel centre", n(WX), n(WY), "diameter", n(d), "pointer top", n(p_top))
