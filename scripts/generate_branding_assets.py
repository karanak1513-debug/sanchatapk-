import os
import math
from PIL import Image, ImageDraw, ImageFont

def create_brand_logo(size=1024):
    """
    Renders the canonical Sanchat logo:
    - Sleek Obsidian Chat Bubble Glyph (#0F172A -> #1E293B)
      Top-left, top-right, bottom-right radius: 36%
      Bottom-left radius: 10% (speech bubble tail)
    - Center Emerald Vault Medallion (#10B981 -> #059669) circle (58% size)
    - Crisp white bold ₹ glyph
    """
    # 2x supersampling for ultra-crisp antialiasing
    scale = 2
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = int(canvas_size * 0.08)
    box_w = canvas_size - 2 * pad
    box_h = canvas_size - 2 * pad
    x0, y0 = pad, pad
    x1, y1 = pad + box_w, pad + box_h

    # Create mask for obsidian bubble
    mask = Image.new("L", (canvas_size, canvas_size), 0)
    mask_draw = ImageDraw.Draw(mask)

    # Radii
    r_tl = int(box_w * 0.36)
    r_tr = int(box_w * 0.36)
    r_br = int(box_w * 0.36)
    r_bl = int(box_w * 0.10)

    # Draw rounded rectangle with custom corners
    # We can draw the pie slices and rectangles into mask
    # Top-Left corner
    mask_draw.pieslice([x0, y0, x0 + 2*r_tl, y0 + 2*r_tl], 180, 270, fill=255)
    # Top-Right corner
    mask_draw.pieslice([x1 - 2*r_tr, y0, x1, y0 + 2*r_tr], 270, 360, fill=255)
    # Bottom-Right corner
    mask_draw.pieslice([x1 - 2*r_br, y1 - 2*r_br, x1, y1], 0, 90, fill=255)
    # Bottom-Left corner
    mask_draw.pieslice([x0, y1 - 2*r_bl, x0 + 2*r_bl, y1], 90, 180, fill=255)

    # Fill internal rectangles
    mask_draw.rectangle([x0 + r_tl, y0, x1 - r_tr, y1], fill=255)
    mask_draw.rectangle([x0, y0 + r_tl, x0 + r_tl, y1 - r_bl], fill=255)
    mask_draw.rectangle([x1 - r_tr, y0 + r_tr, x1, y1 - r_br], fill=255)

    # Gradient for obsidian body (from #0F172A to #1E293B)
    obsidian_top = (15, 23, 42, 255)
    obsidian_bot = (30, 41, 59, 255)
    bubble = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    for y in range(canvas_size):
        ratio = y / canvas_size
        r = int(obsidian_top[0] + (obsidian_bot[0] - obsidian_top[0]) * ratio)
        g = int(obsidian_top[1] + (obsidian_bot[1] - obsidian_top[1]) * ratio)
        b = int(obsidian_top[2] + (obsidian_bot[2] - obsidian_top[2]) * ratio)
        draw_b = ImageDraw.Draw(bubble)
        draw_b.line([(0, y), (canvas_size, y)], fill=(r, g, b, 255))

    img.paste(bubble, (0, 0), mask)

    # Center Medallion (circle, 58% of box_w)
    medallion_diam = int(box_w * 0.58)
    cx = canvas_size // 2
    cy = canvas_size // 2
    mx0 = cx - medallion_diam // 2
    my0 = cy - medallion_diam // 2
    mx1 = mx0 + medallion_diam
    my1 = my0 + medallion_diam

    medallion_mask = Image.new("L", (canvas_size, canvas_size), 0)
    m_mask_draw = ImageDraw.Draw(medallion_mask)
    m_mask_draw.ellipse([mx0, my0, mx1, my1], fill=255)

    # Emerald gradient (#10B981 to #059669)
    emerald_top = (16, 185, 129, 255)
    emerald_bot = (5, 150, 105, 255)
    medallion = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    for y in range(canvas_size):
        ratio = y / canvas_size
        r = int(emerald_top[0] + (emerald_bot[0] - emerald_top[0]) * ratio)
        g = int(emerald_top[1] + (emerald_bot[1] - emerald_top[1]) * ratio)
        b = int(emerald_top[2] + (emerald_bot[2] - emerald_top[2]) * ratio)
        draw_m = ImageDraw.Draw(medallion)
        draw_m.line([(0, y), (canvas_size, y)], fill=(r, g, b, 255))

    img.paste(medallion, (0, 0), medallion_mask)

    # Delicate white outline border for medallion
    draw = ImageDraw.Draw(img)
    draw.ellipse([mx0, my0, mx1, my1], outline=(255, 255, 255, 90), width=max(2, int(canvas_size * 0.004)))

    # Draw ₹ Rupee Symbol in Center
    font_size = int(medallion_diam * 0.58)
    font = None
    # Try finding system fonts that support ₹
    possible_fonts = [
        "C:\\Windows\\Fonts\\arial.ttf",
        "C:\\Windows\\Fonts\\segoeui.ttf",
        "C:\\Windows\\Fonts\\seguiemj.ttf",
        "C:\\Windows\\Fonts\\calibri.ttf",
    ]
    for fpath in possible_fonts:
        if os.path.exists(fpath):
            try:
                test_font = ImageFont.truetype(fpath, font_size)
                # check if glyph exists
                bbox = test_font.getbbox("₹")
                if bbox and (bbox[2] - bbox[0] > 0):
                    font = test_font
                    break
            except Exception:
                pass

    if font is None:
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except Exception:
            font = ImageFont.load_default()

    # Draw ₹ centered
    bbox = draw.textbbox((0, 0), "₹", font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    # adjust vertical optical centering
    tx = cx - text_w / 2 - bbox[0]
    ty = cy - text_h / 2 - bbox[1] - int(canvas_size * 0.008)

    draw.text((tx, ty), "₹", font=font, fill=(255, 255, 255, 255))

    # Resize down with high-quality Lanczos resampling
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

def generate_svg(size=512):
    return f"""<svg width="{size}" height="{size}" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="obsidianGrad" x1="40" y1="40" x2="472" y2="472" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#0F172A"/>
      <stop offset="100%" stop-color="#1E293B"/>
    </linearGradient>
    <linearGradient id="emeraldGrad" x1="156" y1="156" x2="356" y2="356" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#10B981"/>
      <stop offset="100%" stop-color="#059669"/>
    </linearGradient>
    <filter id="subtleGlow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="8" stdDeviation="16" flood-color="#0F172A" flood-opacity="0.35"/>
    </filter>
  </defs>

  <!-- Obsidian Chat Bubble -->
  <path d="M 195 40 
           L 357 40 
           A 155 155 0 0 1 512 195 
           L 512 357 
           A 155 155 0 0 1 357 512 
           L 195 512 
           A 43 43 0 0 1 152 469 
           L 40 469
           A 40 40 0 0 1 40 429
           L 40 195 
           A 155 155 0 0 1 195 40 Z"
        fill="url(#obsidianGrad)"
        filter="url(#subtleGlow)"/>

  <!-- Emerald Savings Vault Medallion -->
  <circle cx="256" cy="256" r="125" fill="url(#emeraldGrad)" stroke="rgba(255,255,255,0.35)" stroke-width="2"/>

  <!-- Rupee Symbol -->
  <text x="256" y="298" 
        font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Inter', sans-serif" 
        font-size="142" 
        font-weight="900" 
        fill="#FFFFFF" 
        text-anchor="middle">₹</text>
</svg>"""

def create_og_image(logo_img):
    # 1200x630 Social Preview Card
    w, h = 1200, 630
    og = Image.new("RGBA", (w, h), (15, 23, 42, 255))
    draw = ImageDraw.Draw(og)

    # Ambient decorative emerald glow circle
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([800, -100, 1400, 500], fill=(16, 185, 129, 25))
    og.paste(glow, (0, 0), glow)

    # Paste scaled logo
    scaled_logo = logo_img.resize((320, 320), Image.Resampling.LANCZOS)
    og.paste(scaled_logo, (120, (h - 320) // 2), scaled_logo)

    # Try font
    font_large = None
    font_sub = None
    for fpath in ["C:\\Windows\\Fonts\\segoeui.ttf", "C:\\Windows\\Fonts\\arial.ttf"]:
        if os.path.exists(fpath):
            try:
                font_large = ImageFont.truetype(fpath, 64)
                font_sub = ImageFont.truetype(fpath, 30)
                break
            except Exception:
                pass
    if font_large is None:
        font_large = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    draw.text((490, 200), "SANCHAT", font=font_large, fill=(255, 255, 255, 255))
    draw.text((490, 280), "Smart Personal Finance & Savings Vault", font=font_sub, fill=(16, 185, 129, 255))
    draw.text((490, 330), "Your Money. Your Control. Your Sanchat.", font=font_sub, fill=(148, 163, 184, 255))

    return og

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    branding_dir = os.path.join(base_dir, "assets", "branding")
    os.makedirs(branding_dir, exist_ok=True)

    print("Generating Master 1024x1024 Sanchat Logo...")
    logo_1024 = create_brand_logo(1024)
    logo_1024.save(os.path.join(branding_dir, "sanchat_logo.png"), "PNG")

    print("Generating Sanchat SVG...")
    with open(os.path.join(branding_dir, "sanchat_logo.svg"), "w", encoding="utf-8") as f:
        f.write(generate_svg(512))

    print("Generating 512x512 Sanchat Icon...")
    icon_512 = logo_1024.resize((512, 512), Image.Resampling.LANCZOS)
    icon_512.save(os.path.join(branding_dir, "sanchat_icon.png"), "PNG")
    # Also update assets/images/app_logo.png for backward compatibility
    icon_512.save(os.path.join(base_dir, "assets", "images", "app_logo.png"), "PNG")

    print("Generating Adaptive Icons...")
    # Foreground: logo with padding
    fg = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    fg_logo = logo_1024.resize((360, 360), Image.Resampling.LANCZOS)
    fg.paste(fg_logo, ((512 - 360) // 2, (512 - 360) // 2), fg_logo)
    fg.save(os.path.join(branding_dir, "sanchat_icon_foreground.png"), "PNG")

    # Background: clean obsidian slate (#0F172A)
    bg = Image.new("RGBA", (512, 512), (15, 23, 42, 255))
    bg.save(os.path.join(branding_dir, "sanchat_icon_background.png"), "PNG")

    print("Generating Social Preview (OG)...")
    og_img = create_og_image(logo_1024)
    og_img.save(os.path.join(branding_dir, "sanchat_og.png"), "PNG")

    # Android mipmaps
    android_res = os.path.join(base_dir, "android", "app", "src", "main", "res")
    mipmaps = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in mipmaps.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        out_path = os.path.join(folder_path, "ic_launcher.png")
        resized = logo_1024.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"Saved {folder}/ic_launcher.png ({px}x{px})")

    # Web icons
    web_dir = os.path.join(base_dir, "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)

    logo_1024.resize((64, 64), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), "PNG")
    logo_1024.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
    logo_1024.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
    logo_1024.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")
    logo_1024.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")
    print("Web favicon and icons updated.")
    print("All canonical branding assets successfully generated!")

if __name__ == "__main__":
    main()
