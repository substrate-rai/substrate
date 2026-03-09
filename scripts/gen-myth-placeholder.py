#!/usr/bin/env python3
"""Generate a placeholder portrait for the Myth agent."""
import math
from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 512, 512
BG_COLOR = (10, 10, 15)        # #0a0a0f
AGENT_COLOR = (153, 68, 204)   # #9944cc — mystical purple
ACCENT_DIM = (100, 44, 140)    # dimmed purple for background elements
ACCENT_BRIGHT = (200, 120, 255) # bright highlight

img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
draw = ImageDraw.Draw(img)

cx, cy = WIDTH // 2, HEIGHT // 2

# Draw concentric mystical circles (rune-like rings)
for r in [180, 140, 100]:
    draw.ellipse(
        [cx - r, cy - r, cx + r, cy + r],
        outline=ACCENT_DIM,
        width=2,
    )

# Draw a brighter inner circle
draw.ellipse(
    [cx - 60, cy - 60, cx + 60, cy + 60],
    outline=AGENT_COLOR,
    width=3,
)

# Draw radiating lines (like a rune compass)
num_lines = 8
line_inner = 65
line_outer = 175
for i in range(num_lines):
    angle = (2 * math.pi * i) / num_lines
    x1 = cx + int(line_inner * math.cos(angle))
    y1 = cy + int(line_inner * math.sin(angle))
    x2 = cx + int(line_outer * math.cos(angle))
    y2 = cy + int(line_outer * math.sin(angle))
    color = AGENT_COLOR if i % 2 == 0 else ACCENT_DIM
    draw.line([(x1, y1), (x2, y2)], fill=color, width=2)

# Draw small diamonds at the ends of primary lines
diamond_size = 8
for i in range(0, num_lines, 2):
    angle = (2 * math.pi * i) / num_lines
    dx = cx + int(line_outer * math.cos(angle))
    dy = cy + int(line_outer * math.sin(angle))
    diamond = [
        (dx, dy - diamond_size),
        (dx + diamond_size, dy),
        (dx, dy + diamond_size),
        (dx - diamond_size, dy),
    ]
    draw.polygon(diamond, fill=AGENT_COLOR, outline=ACCENT_BRIGHT)

# Draw the sigil text "M?" in the center
# Try to use a larger font; fall back to default
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 72)
except (OSError, IOError):
    try:
        font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf", 72)
    except (OSError, IOError):
        try:
            # Common NixOS font paths
            import glob
            mono_fonts = glob.glob("/nix/store/*/share/fonts/**/DejaVu*Mono*Bold*", recursive=True)
            if mono_fonts:
                font = ImageFont.truetype(mono_fonts[0], 72)
            else:
                font = ImageFont.load_default()
        except Exception:
            font = ImageFont.load_default()

# Draw text with a glow effect (draw slightly offset in dim color, then sharp on top)
text = "M?"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = cx - tw // 2
ty = cy - th // 2

# Glow layers
for offset in [3, 2, 1]:
    glow_color = (AGENT_COLOR[0] // 3, AGENT_COLOR[1] // 3, AGENT_COLOR[2] // 3)
    draw.text((tx - offset, ty), text, fill=glow_color, font=font)
    draw.text((tx + offset, ty), text, fill=glow_color, font=font)
    draw.text((tx, ty - offset), text, fill=glow_color, font=font)
    draw.text((tx, ty + offset), text, fill=glow_color, font=font)

# Main text
draw.text((tx, ty), text, fill=ACCENT_BRIGHT, font=font)

# Add corner accents (triangular marks)
corner_size = 30
corner_inset = 20
# Top-left
draw.line([(corner_inset, corner_inset), (corner_inset + corner_size, corner_inset)], fill=ACCENT_DIM, width=2)
draw.line([(corner_inset, corner_inset), (corner_inset, corner_inset + corner_size)], fill=ACCENT_DIM, width=2)
# Top-right
draw.line([(WIDTH - corner_inset, corner_inset), (WIDTH - corner_inset - corner_size, corner_inset)], fill=ACCENT_DIM, width=2)
draw.line([(WIDTH - corner_inset, corner_inset), (WIDTH - corner_inset, corner_inset + corner_size)], fill=ACCENT_DIM, width=2)
# Bottom-left
draw.line([(corner_inset, HEIGHT - corner_inset), (corner_inset + corner_size, HEIGHT - corner_inset)], fill=ACCENT_DIM, width=2)
draw.line([(corner_inset, HEIGHT - corner_inset), (corner_inset, HEIGHT - corner_inset - corner_size)], fill=ACCENT_DIM, width=2)
# Bottom-right
draw.line([(WIDTH - corner_inset, HEIGHT - corner_inset), (WIDTH - corner_inset - corner_size, HEIGHT - corner_inset)], fill=ACCENT_DIM, width=2)
draw.line([(WIDTH - corner_inset, HEIGHT - corner_inset), (WIDTH - corner_inset, HEIGHT - corner_inset - corner_size)], fill=ACCENT_DIM, width=2)

# Save
output_path = "/home/operator/substrate/assets/images/generated/agent-myth.webp"
img.save(output_path, "WEBP", quality=80)
print(f"Saved placeholder portrait to {output_path}")
