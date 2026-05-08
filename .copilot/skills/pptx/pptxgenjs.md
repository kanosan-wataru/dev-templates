# PptxGenJS Tutorial

## Setup & Basic Structure

```javascript
const pptxgen = require("pptxgenjs");

let pres = new pptxgen();
pres.layout = 'LAYOUT_16x9';  // or 'LAYOUT_16x10', 'LAYOUT_4x3', 'LAYOUT_WIDE'
pres.author = 'Your Name';
pres.title = 'Presentation Title';

let slide = pres.addSlide();
slide.addText("Hello World!", { x: 0.5, y: 0.5, fontSize: 36, color: "363636" });

pres.writeFile({ fileName: "Presentation.pptx" });
```

## Layout Dimensions

Slide dimensions (coordinates in inches):
- `LAYOUT_16x9`: 10" × 5.625" (default)
- `LAYOUT_16x10`: 10" × 6.25"
- `LAYOUT_4x3`: 10" × 7.5"
- `LAYOUT_WIDE`: 13.3" × 7.5"

---

## Text & Formatting

```javascript
// Basic text
slide.addText("Simple Text", {
  x: 1, y: 1, w: 8, h: 2, fontSize: 24, fontFace: "Arial",
  color: "363636", bold: true, align: "center", valign: "middle"
});

// Character spacing (use charSpacing, not letterSpacing which is silently ignored)
slide.addText("SPACED TEXT", { x: 1, y: 1, w: 8, h: 1, charSpacing: 6 });

// Rich text arrays
slide.addText([
  { text: "Bold ", options: { bold: true } },
  { text: "Italic ", options: { italic: true } }
], { x: 1, y: 3, w: 8, h: 1 });

// Multi-line text (requires breakLine: true)
slide.addText([
  { text: "Line 1", options: { breakLine: true } },
  { text: "Line 2", options: { breakLine: true } },
  { text: "Line 3" }  // Last item doesn't need breakLine
], { x: 0.5, y: 0.5, w: 8, h: 2 });

// Text box margin (internal padding)
slide.addText("Title", {
  x: 0.5, y: 0.3, w: 9, h: 0.6,
  margin: 0  // Use 0 when aligning text with other elements like shapes or icons
});
```

**Tip:** Text boxes have internal margin by default. Set `margin: 0` when you need text to align precisely with shapes, lines, or icons at the same x-position.

---

## Lists & Bullets

```javascript
// ✅ CORRECT: Multiple bullets
slide.addText([
  { text: "First item", options: { bullet: true, breakLine: true } },
  { text: "Second item", options: { bullet: true, breakLine: true } },
  { text: "Third item", options: { bullet: true } }
], { x: 0.5, y: 0.5, w: 8, h: 3 });

// ❌ WRONG: Never use unicode bullets
slide.addText("• First item", { ... });  // Creates double bullets

// Sub-items and numbered lists
{ text: "Sub-item", options: { bullet: true, indentLevel: 1 } }
{ text: "First", options: { bullet: { type: "number" }, breakLine: true } }
```

---

## Shapes

```javascript
slide.addShape(pres.shapes.RECTANGLE, {
  x: 0.5, y: 0.8, w: 1.5, h: 3.0,
  fill: { color: "FF0000" }, line: { color: "000000", width: 2 }
});

slide.addShape(pres.shapes.OVAL, { x: 4, y: 1, w: 2, h: 2, fill: { color: "0000FF" } });

slide.addShape(pres.shapes.LINE, {
  x: 1, y: 3, w: 5, h: 0, line: { color: "FF0000", width: 3, dashType: "dash" }
});

// With transparency
slide.addShape(pres.shapes.RECTANGLE, {
  x: 1, y: 1, w: 3, h: 2,
  fill: { color: "0088CC", transparency: 50 }
});

// Rounded rectangle (rectRadius only works with ROUNDED_RECTANGLE, not RECTANGLE)
// ⚠️ Don't pair with rectangular accent overlays — they won't cover rounded corners. Use RECTANGLE instead.
slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
  x: 1, y: 1, w: 3, h: 2,
  fill: { color: "FFFFFF" }, rectRadius: 0.1
});

// With shadow
slide.addShape(pres.shapes.RECTANGLE, {
  x: 1, y: 1, w: 3, h: 2,
  fill: { color: "FFFFFF" },
  shadow: { type: "outer", color: "000000", blur: 6, offset: 2, angle: 135, opacity: 0.15 }
});
```

Shadow options:

| Property | Type | Range | Notes |
|----------|------|-------|-------|
| `type` | string | `"outer"`, `"inner"` | |
| `color` | string | 6-char hex (e.g. `"000000"`) | No `#` prefix, no 8-char hex — see Common Pitfalls |
| `blur` | number | 0-100 pt | |
| `offset` | number | 0-200 pt | **Must be non-negative** — negative values corrupt the file |
| `angle` | number | 0-359 degrees | Direction the shadow falls (135 = bottom-right, 270 = upward) |
| `opacity` | number | 0.0-1.0 | Use this for transparency, never encode in color string |

To cast a shadow upward (e.g. on a footer bar), use `angle: 270` with a positive offset — do **not** use a negative offset.

**Note**: Gradient fills are not natively supported. Use a gradient image as a background instead.

---

## Images

### Image Sources

```javascript
// From file path
slide.addImage({ path: "images/chart.png", x: 1, y: 1, w: 5, h: 3 });

// From URL
slide.addImage({ path: "https://example.com/image.jpg", x: 1, y: 1, w: 5, h: 3 });

// From base64 (faster, no file I/O)
slide.addImage({ data: "image/png;base64,iVBORw0KGgo...", x: 1, y: 1, w: 5, h: 3 });
```

### Image Options

```javascript
slide.addImage({
  path: "image.png",
  x: 1, y: 1, w: 5, h: 3,
  rotate: 45,              // 0-359 degrees
  rounding: true,          // Circular crop
  transparency: 50,        // 0-100
  flipH: true,             // Horizontal flip
  flipV: false,            // Vertical flip
  altText: "Description",  // Accessibility
  hyperlink: { url: "https://example.com" }
});
```

### Image Sizing Modes

```javascript
// Contain - fit inside, preserve ratio
{ sizing: { type: 'contain', w: 4, h: 3 } }

// Cover - fill area, preserve ratio (may crop)
{ sizing: { type: 'cover', w: 4, h: 3 } }

// Crop - cut specific portion
{ sizing: { type: 'crop', x: 0.5, y: 0.5, w: 2, h: 2 } }
```

### Calculate Dimensions (preserve aspect ratio)

```javascript
const origWidth = 1978, origHeight = 923, maxHeight = 3.0;
const calcWidth = maxHeight * (origWidth / origHeight);
const centerX = (10 - calcWidth) / 2;

slide.addImage({ path: "image.png", x: centerX, y: 1.2, w: calcWidth, h: maxHeight });
```

### Supported Formats

- **Standard**: PNG, JPG, GIF (animated GIFs work in Microsoft 365)
- **SVG**: Works in modern PowerPoint/Microsoft 365

---

## Icons

Use react-icons to generate SVG icons, then rasterize to PNG for universal compatibility.

### Setup

```javascript
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const { FaCheckCircle, FaChartLine } = require("react-icons/fa");

function renderIconSvg(IconComponent, color = "#000000", size = 256) {
  return ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComponent, { color, size: String(size) })
  );
}

async function iconToBase64Png(IconComponent, color, size = 256) {
  const svg = renderIconSvg(IconComponent, color, size);
  const pngBuffer = await sharp(Buffer.from(svg)).png().toBuffer();
  return "image/png;base64," + pngBuffer.toString("base64");
}
```

### Add Icon to Slide

```javascript
const iconData = await iconToBase64Png(FaCheckCircle, "#4472C4", 256);

slide.addImage({
  data: iconData,
  x: 1, y: 1, w: 0.5, h: 0.5  // Size in inches
});
```

**Note**: Use size 256 or higher for crisp icons. The size parameter controls the rasterization resolution, not the display size on the slide (which is set by `w` and `h` in inches).

### Icon Libraries

Install: `npm install -g react-icons react react-dom sharp`

Popular icon sets in react-icons:
- `react-icons/fa` - Font Awesome
- `react-icons/md` - Material Design
- `react-icons/hi` - Heroicons
- `react-icons/bi` - Bootstrap Icons

---

## Slide Backgrounds

```javascript
// Solid color
slide.background = { color: "F1F1F1" };

// Color with transparency
slide.background = { color: "FF3399", transparency: 50 };

// Image from URL
slide.background = { path: "https://example.com/bg.jpg" };

// Image from base64
slide.background = { data: "image/png;base64,iVBORw0KGgo..." };
```

---

## Tables

```javascript
slide.addTable([
  ["Header 1", "Header 2"],
  ["Cell 1", "Cell 2"]
], {
  x: 1, y: 1, w: 8, h: 2,
  border: { pt: 1, color: "999999" }, fill: { color: "F1F1F1" }
});

// Advanced with merged cells
let tableData = [
  [{ text: "Header", options: { fill: { color: "6699CC" }, color: "FFFFFF", bold: true } }, "Cell"],
  [{ text: "Merged", options: { colspan: 2 } }]
];
slide.addTable(tableData, { x: 1, y: 3.5, w: 8, colW: [4, 4] });
```

---

## Charts

```javascript
// Bar chart
slide.addChart(pres.charts.BAR, [{
  name: "Sales", labels: ["Q1", "Q2", "Q3", "Q4"], values: [4500, 5500, 6200, 7100]
}], {
  x: 0.5, y: 0.6, w: 6, h: 3, barDir: 'col',
  showTitle: true, title: 'Quarterly Sales'
});

// Line chart
slide.addChart(pres.charts.LINE, [{
  name: "Temp", labels: ["Jan", "Feb", "Mar"], values: [32, 35, 42]
}], { x: 0.5, y: 4, w: 6, h: 3, lineSize: 3, lineSmooth: true });

// Pie chart
slide.addChart(pres.charts.PIE, [{
  name: "Share", labels: ["A", "B", "Other"], values: [35, 45, 20]
}], { x: 7, y: 1, w: 5, h: 4, showPercent: true });
```

### Better-Looking Charts

Default charts look dated. Apply these options for a modern, clean appearance:

```javascript
slide.addChart(pres.charts.BAR, chartData, {
  x: 0.5, y: 1, w: 9, h: 4, barDir: "col",

  // Custom colors (match your presentation palette)
  chartColors: ["0D9488", "14B8A6", "5EEAD4"],

  // Clean background
  chartArea: { fill: { color: "FFFFFF" }, roundedCorners: true },

  // Muted axis labels
  catAxisLabelColor: "64748B",
  valAxisLabelColor: "64748B",

  // Subtle grid (value axis only)
  valGridLine: { color: "E2E8F0", size: 0.5 },
  catGridLine: { style: "none" },

  // Data labels on bars
  showValue: true,
  dataLabelPosition: "outEnd",
  dataLabelColor: "1E293B",

  // Hide legend for single series
  showLegend: false,
});
```

**Key styling options:**
- `chartColors: [...]` - hex colors for series/segments
- `chartArea: { fill, border, roundedCorners }` - chart background
- `catGridLine/valGridLine: { color, style, size }` - grid lines (`style: "none"` to hide)
- `lineSmooth: true` - curved lines (line charts)
- `legendPos: "r"` - legend position: "b", "t", "l", "r", "tr"

---

## Slide Masters

```javascript
pres.defineSlideMaster({
  title: 'TITLE_SLIDE', background: { color: '283A5E' },
  objects: [{
    placeholder: { options: { name: 'title', type: 'title', x: 1, y: 2, w: 8, h: 2 } }
  }]
});

let titleSlide = pres.addSlide({ masterName: "TITLE_SLIDE" });
titleSlide.addText("My Title", { placeholder: "title" });
```

---

## Common Pitfalls

⚠️ These issues cause file corruption, visual bugs, or broken output. Avoid them.

1. **NEVER use "#" with hex colors** - causes file corruption
   ```javascript
   color: "FF0000"      // ✅ CORRECT
   color: "#FF0000"     // ❌ WRONG
   ```

2. **NEVER encode opacity in hex color strings** - 8-char colors (e.g., `"00000020"`) corrupt the file. Use the `opacity` property instead.
   ```javascript
   shadow: { type: "outer", blur: 6, offset: 2, color: "00000020" }          // ❌ CORRUPTS FILE
   shadow: { type: "outer", blur: 6, offset: 2, color: "000000", opacity: 0.12 }  // ✅ CORRECT
   ```

3. **Use `bullet: true`** - NEVER unicode symbols like "•" (creates double bullets)

4. **Use `breakLine: true`** between array items or text runs together

5. **Avoid `lineSpacing` with bullets** - causes excessive gaps; use `paraSpaceAfter` instead

6. **Each presentation needs fresh instance** - don't reuse `pptxgen()` objects

7. **NEVER reuse option objects across calls** - PptxGenJS mutates objects in-place (e.g. converting shadow values to EMU). Sharing one object between multiple calls corrupts the second shape.
   ```javascript
   const shadow = { type: "outer", blur: 6, offset: 2, color: "000000", opacity: 0.15 };
   slide.addShape(pres.shapes.RECTANGLE, { shadow, ... });  // ❌ second call gets already-converted values
   slide.addShape(pres.shapes.RECTANGLE, { shadow, ... });

   const makeShadow = () => ({ type: "outer", blur: 6, offset: 2, color: "000000", opacity: 0.15 });
   slide.addShape(pres.shapes.RECTANGLE, { shadow: makeShadow(), ... });  // ✅ fresh object each time
   slide.addShape(pres.shapes.RECTANGLE, { shadow: makeShadow(), ... });
   ```

8. **Don't use `ROUNDED_RECTANGLE` with accent borders** - rectangular overlay bars won't cover rounded corners. Use `RECTANGLE` instead.
   ```javascript
   // ❌ WRONG: Accent bar doesn't cover rounded corners
   slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 1, y: 1, w: 3, h: 1.5, fill: { color: "FFFFFF" } });
   slide.addShape(pres.shapes.RECTANGLE, { x: 1, y: 1, w: 0.08, h: 1.5, fill: { color: "0891B2" } });

   // ✅ CORRECT: Use RECTANGLE for clean alignment
   slide.addShape(pres.shapes.RECTANGLE, { x: 1, y: 1, w: 3, h: 1.5, fill: { color: "FFFFFF" } });
   slide.addShape(pres.shapes.RECTANGLE, { x: 1, y: 1, w: 0.08, h: 1.5, fill: { color: "0891B2" } });
   ```

9. **Post-generation fix: PptxGenJS v4 known bugs** — PptxGenJS v4.x has multiple bugs that cause PowerPoint to show a "repair" dialog. **Always run the fix script after `writeFile()`.**

   Known bugs fixed:
   - **Phantom slideMasters**: Registers one `slideMaster` per slide in `[Content_Types].xml` but only creates `slideMaster1.xml`
   - **Invalid `adj` on `rect`**: When `rectRadius` is used with `addShape("rect", ...)`, the output XML uses `prst="rect"` with an `adj` adjustment guide, but the OOXML spec only allows `adj` on `roundRect`
   - **Missing `<a:effectLst/>`**: `<p:bgPr>` (slide background) omits the `<a:effectLst/>` element. While technically optional in the XSD, PowerPoint strictly requires it
   - **Empty `<a:ln>`**: Shapes without explicit line settings get empty `<a:ln></a:ln>` elements, which PowerPoint interprets as invalid. Must be `<a:ln><a:noFill/></a:ln>`
   - **Misplaced `<a:pPr>`**: Paragraph properties (`<a:pPr>`) sometimes appear between `<a:r>` runs instead of as the first child of `<a:p>`, violating OOXML schema
   - **Missing slideMaster background**: `slideMaster1.xml` omits `<p:bg>` element required by PowerPoint
   - **Missing `<p:sldSz>` type**: Slide size element lacks `type="screen16x9"` attribute
   - **Incorrect element order in presentation.xml**: `<p:notesMasterIdLst>` must appear before `<p:sldIdLst>` per OOXML schema
   - **Unused Default extensions**: `[Content_Types].xml` declares extensions (jpeg, svg, gif, etc.) for files that don't exist
   - **Empty runs in notes**: `<a:r><a:t></a:t></a:r>` empty text runs in notesSlide XML
   - **Invalid `prst="oval"`**: PptxGenJS outputs `prst="oval"` but the OOXML spec requires `prst="ellipse"`. PowerPoint falls back to `prst="line"` for unknown presets, destroying all circle/oval shapes
   - **Shared notesMaster theme**: notesMaster references the presentation's theme1.xml but PowerPoint requires it to have its own separate theme file (theme2.xml)
   - **Duplicate images**: PptxGenJS creates separate media files for identical images (e.g., same icon used multiple times). PowerPoint deduplicates during repair, triggering "some content was deleted" dialog

   The complete fix script is at the bottom of this file. **Always run it immediately after `writeFile()`.**

   ```python
   #!/usr/bin/env python3
   """fix_pptx.py — Fix PptxGenJS v4 known issues (comprehensive).

   Bugs fixed:
    1. Phantom slideMaster entries in [Content_Types].xml
    2. Invalid adj guide on rect preset (should be roundRect)
    3. Missing <a:effectLst/> in <p:bgPr>
    4. Empty directories (charts/, embeddings/)
    5. Empty <a:ln/> on shapes → <a:ln><a:noFill/></a:ln>
    6. Misplaced <a:pPr> between <a:r> runs (must be first child of <a:p>)
    7. Missing <p:bg> in slideMaster1.xml
    8. Missing type="screen16x9" on <p:sldSz> in presentation.xml
    9. Element ordering in presentation.xml (notesMasterIdLst before sldIdLst)
   10. Unused Default extensions in [Content_Types].xml
   11. Empty <a:r><a:t/></a:r> in notesSlide XML
   12. Invalid prst="oval" (OOXML requires "ellipse")
   13. Shared notesMaster theme (needs its own theme2.xml)
   14. Duplicate images triggering "content deleted" dialog
   """
   import zipfile, os, shutil, re, sys
   import xml.etree.ElementTree as ET


   def fix_pptx(src, dst=None):
       dst = dst or src
       tmp = "/tmp/_pptx_fix"
       if os.path.exists(tmp):
           shutil.rmtree(tmp)
       with zipfile.ZipFile(src, "r") as z:
           z.extractall(tmp)

       fixes = {
           "phantom_overrides": 0, "rect_to_roundRect": 0,
           "bgPr_effectLst": 0, "empty_dirs": [],
           "empty_ln_fixed": 0, "misplaced_pPr": 0,
           "slideMaster_bg": 0, "sldSz_type": 0,
           "presentation_order": 0, "unused_defaults": 0,
           "empty_runs": 0, "oval_to_ellipse": 0,
           "notesMaster_theme": 0, "image_dedup": 0,
       }

       # Fix 1 & 10: [Content_Types].xml
       ct = os.path.join(tmp, "[Content_Types].xml")
       ns = "http://schemas.openxmlformats.org/package/2006/content-types"
       ET.register_namespace("", ns)
       tree = ET.parse(ct)
       root = tree.getroot()

       for ov in list(root.findall(f"{{{ns}}}Override")):
           part = ov.get("PartName")
           if not os.path.exists(os.path.join(tmp, part.lstrip("/"))):
               root.remove(ov)
               fixes["phantom_overrides"] += 1

       actual_exts = set()
       for dirpath, _, filenames in os.walk(tmp):
           for fn in filenames:
               ext = fn.rsplit(".", 1)[-1].lower() if "." in fn else ""
               if ext:
                   actual_exts.add(ext)

       for default in list(root.findall(f"{{{ns}}}Default")):
           ext = default.get("Extension", "").lower()
           if ext and ext not in actual_exts:
               root.remove(default)
               fixes["unused_defaults"] += 1

       tree.write(ct, xml_declaration=True, encoding="utf-8")

       # Fix 2, 3, 5, 6, 12: Slide XML fixes
       slides_dir = os.path.join(tmp, "ppt", "slides")
       if os.path.exists(slides_dir):
           for fname in sorted(os.listdir(slides_dir)):
               if not fname.endswith(".xml"):
                   continue
               fpath = os.path.join(slides_dir, fname)
               with open(fpath, "r", encoding="utf-8") as f:
                   content = f.read()

               modified = False

               # Fix 12: oval → ellipse
               new_content = content.replace('prst="oval"', 'prst="ellipse"')
               if new_content != content:
                   fixes["oval_to_ellipse"] += content.count('prst="oval"')
                   content = new_content
                   modified = True

               # Fix 2: rect + adj → roundRect
               pattern = r'(<a:prstGeom prst=")rect(">\s*<a:avLst>\s*<a:gd name="adj")'
               new_content, count = re.subn(pattern, r'\1roundRect\2', content)
               if count > 0:
                   content = new_content
                   modified = True
                   fixes["rect_to_roundRect"] += count

               # Fix 3: Add <a:effectLst/> to <p:bgPr> if missing
               def add_effectlst(m):
                   if 'a:effectLst' not in m.group(2):
                       fixes["bgPr_effectLst"] += 1
                       return m.group(1) + m.group(2) + '<a:effectLst/>' + m.group(3)
                   return m.group(0)
               new_content = re.sub(
                   r'(<p:bgPr>)(.*?)(</p:bgPr>)', add_effectlst,
                   content, flags=re.DOTALL
               )
               if new_content != content:
                   content = new_content
                   modified = True

               # Fix 5: Empty <a:ln/> or <a:ln></a:ln> → <a:ln><a:noFill/></a:ln>
               new_content = content.replace('<a:ln/>', '<a:ln><a:noFill/></a:ln>')
               if new_content != content:
                   fixes["empty_ln_fixed"] += content.count('<a:ln/>')
                   content = new_content
                   modified = True
               new_content = content.replace('<a:ln></a:ln>', '<a:ln><a:noFill/></a:ln>')
               if new_content != content:
                   fixes["empty_ln_fixed"] += content.count('<a:ln></a:ln>')
                   content = new_content
                   modified = True

               # Fix 6: Remove misplaced <a:pPr> between <a:r> runs
               ppr_between = re.compile(
                   r'(</a:r>\s*)<a:pPr[^>]*>.*?</a:pPr>(\s*<a:r[ >])',
                   re.DOTALL
               )
               new_content, count = ppr_between.subn(r'\1\2', content)
               if count > 0:
                   content = new_content
                   modified = True
                   fixes["misplaced_pPr"] += count

               ppr_between_sc = re.compile(
                   r'(</a:r>\s*)<a:pPr[^/]*/>\s*(<a:r[ >])',
                   re.DOTALL
               )
               new_content, count = ppr_between_sc.subn(r'\1\2', content)
               if count > 0:
                   content = new_content
                   modified = True
                   fixes["misplaced_pPr"] += count

               if modified:
                   with open(fpath, "w", encoding="utf-8") as f:
                       f.write(content)

       # Fix 7: Add <p:bg> to slideMaster1.xml if missing
       sm_path = os.path.join(tmp, "ppt", "slideMasters", "slideMaster1.xml")
       if os.path.exists(sm_path):
           with open(sm_path, "r", encoding="utf-8") as f:
               sm_content = f.read()
           if '<p:bg>' not in sm_content:
               bg_elem = (
                   '<p:bg><p:bgRef idx="1001">'
                   '<a:schemeClr val="bg1"/>'
                   '</p:bgRef></p:bg>'
               )
               sm_new = sm_content.replace(
                   '<p:cSld><p:spTree>',
                   f'<p:cSld>{bg_elem}<p:spTree>'
               )
               if sm_new == sm_content:
                   sm_new = re.sub(
                       r'(<p:cSld>)\s*(<p:spTree>)',
                       rf'\1{bg_elem}\2', sm_content
                   )
               if sm_new != sm_content:
                   with open(sm_path, "w", encoding="utf-8") as f:
                       f.write(sm_new)
                   fixes["slideMaster_bg"] = 1

       # Fix 8 & 9: presentation.xml fixes
       pres_path = os.path.join(tmp, "ppt", "presentation.xml")
       if os.path.exists(pres_path):
           with open(pres_path, "r", encoding="utf-8") as f:
               pres_content = f.read()
           pres_modified = False

           if '<p:sldSz' in pres_content and 'type=' not in re.search(
               r'<p:sldSz[^>]*>', pres_content
           ).group(0):
               pres_content = re.sub(
                   r'(<p:sldSz\s+cx="9144000"\s+cy="5143500")\s*/>',
                   r'\1 type="screen16x9"/>', pres_content
               )
               pres_content = re.sub(
                   r'(<p:sldSz\s+cx="9144000"\s+cy="5143500")(\s*>)',
                   r'\1 type="screen16x9"\2', pres_content
               )
               fixes["sldSz_type"] = 1
               pres_modified = True

           notes_match = re.search(
               r'(<p:notesMasterIdLst>.*?</p:notesMasterIdLst>)',
               pres_content, re.DOTALL
           )
           sld_match = re.search(r'(<p:sldIdLst>)', pres_content)
           if notes_match and sld_match and notes_match.start() > sld_match.start():
               notes_block = notes_match.group(1)
               pres_content = (
                   pres_content[:notes_match.start()]
                   + pres_content[notes_match.end():]
               )
               pres_content = re.sub(r'\n\s*\n', '\n', pres_content)
               sld_match2 = re.search(r'(<p:sldIdLst>)', pres_content)
               if sld_match2:
                   pres_content = (
                       pres_content[:sld_match2.start()]
                       + notes_block
                       + pres_content[sld_match2.start():]
                   )
               fixes["presentation_order"] = 1
               pres_modified = True

           if pres_modified:
               with open(pres_path, "w", encoding="utf-8") as f:
                   f.write(pres_content)

       # Fix 11: Remove empty <a:r><a:t/></a:r> from notesSlide XML
       notes_dir = os.path.join(tmp, "ppt", "notesSlides")
       if os.path.exists(notes_dir):
           for fname in sorted(os.listdir(notes_dir)):
               if not fname.endswith(".xml"):
                   continue
               fpath = os.path.join(notes_dir, fname)
               with open(fpath, "r", encoding="utf-8") as f:
                   content = f.read()
               new_content = re.sub(
                   r'\s*<a:r>\s*<a:rPr[^/]*/>\s*<a:t/?>\s*(</a:t>\s*)?</a:r>',
                   '', content
               )
               if new_content != content:
                   fixes["empty_runs"] += 1
                   with open(fpath, "w", encoding="utf-8") as f:
                       f.write(new_content)

       # Fix 13: Create separate theme for notesMaster
       nm_rels_path = os.path.join(
           tmp, "ppt", "notesMasters", "_rels", "notesMaster1.xml.rels"
       )
       theme_dir = os.path.join(tmp, "ppt", "theme")
       theme2_path = os.path.join(theme_dir, "theme2.xml")
       if os.path.exists(nm_rels_path) and not os.path.exists(theme2_path):
           theme1_path = os.path.join(theme_dir, "theme1.xml")
           if os.path.exists(theme1_path):
               shutil.copy2(theme1_path, theme2_path)
               with open(nm_rels_path, "r", encoding="utf-8") as f:
                   rels_content = f.read()
               rels_content = rels_content.replace(
                   'Target="../theme/theme1.xml"',
                   'Target="../theme/theme2.xml"'
               )
               with open(nm_rels_path, "w", encoding="utf-8") as f:
                   f.write(rels_content)
               tree2 = ET.parse(ct)
               root2 = tree2.getroot()
               has_theme2 = any(
                   ov.get("PartName") == "/ppt/theme/theme2.xml"
                   for ov in root2.findall(f"{{{ns}}}Override")
               )
               if not has_theme2:
                   ET.SubElement(root2, f"{{{ns}}}Override", {
                       "PartName": "/ppt/theme/theme2.xml",
                       "ContentType": "application/vnd.openxmlformats-officedocument.theme+xml"
                   })
                   tree2.write(ct, xml_declaration=True, encoding="utf-8")
               fixes["notesMaster_theme"] = 1

       # Fix 14: Deduplicate identical images in ppt/media/
       media_dir = os.path.join(tmp, "ppt", "media")
       if os.path.exists(media_dir):
           import hashlib
           hash_to_file = {}
           rename_map = {}
           dedup_count = 0

           for fn in sorted(os.listdir(media_dir)):
               fp = os.path.join(media_dir, fn)
               if not os.path.isfile(fp):
                   continue
               with open(fp, "rb") as f:
                   h = hashlib.md5(f.read()).hexdigest()
               if h in hash_to_file:
                   rename_map[fn] = hash_to_file[h]
                   os.remove(fp)
                   dedup_count += 1
               else:
                   hash_to_file[h] = fn

           if rename_map:
               rels_dirs = [
                   os.path.join(tmp, "ppt", "slides", "_rels"),
                   os.path.join(tmp, "ppt", "notesSlides", "_rels"),
               ]
               for rels_dir in rels_dirs:
                   if not os.path.exists(rels_dir):
                       continue
                   for fn in os.listdir(rels_dir):
                       if not fn.endswith(".rels"):
                           continue
                       fp = os.path.join(rels_dir, fn)
                       with open(fp, "r", encoding="utf-8") as f:
                           content = f.read()
                       modified_rels = False
                       for old_name, new_name in rename_map.items():
                           if old_name in content:
                               content = content.replace(
                                   f"../media/{old_name}",
                                   f"../media/{new_name}"
                               )
                               modified_rels = True
                       if modified_rels:
                           with open(fp, "w", encoding="utf-8") as f:
                               f.write(content)
           fixes["image_dedup"] = dedup_count

       # Fix 4: Remove empty directories
       for d in ["ppt/charts", "ppt/embeddings"]:
           p = os.path.join(tmp, d)
           if os.path.exists(p) and not any(f for _, _, f in os.walk(p) if f):
               shutil.rmtree(p)
               fixes["empty_dirs"].append(d)

       # Repack
       with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
           for r, _, files in os.walk(tmp):
               for f in files:
                   fp = os.path.join(r, f)
                   z.write(fp, os.path.relpath(fp, tmp))
       shutil.rmtree(tmp)
       return fixes

   if __name__ == "__main__":
       path = sys.argv[1] if len(sys.argv) > 1 else "presentation.pptx"
       fixes = fix_pptx(path)
       print(f"Fixed: {path}")
       for k, v in fixes.items():
           if k != "empty_dirs":
               print(f"  {k}: {v}")
       if fixes["empty_dirs"]:
           print(f"  empty_dirs: {', '.join(fixes['empty_dirs'])}")
   ```

   **Usage** (run immediately after generating the PPTX):
   ```bash
   python fix_pptx.py presentation.pptx
   ```

   Without this fix, PowerPoint (and Keynote) will show a repair/recovery dialog every time the file is opened.

---

## Quick Reference

- **Shapes**: RECTANGLE, OVAL, LINE, ROUNDED_RECTANGLE
- **Charts**: BAR, LINE, PIE, DOUGHNUT, SCATTER, BUBBLE, RADAR
- **Layouts**: LAYOUT_16x9 (10"×5.625"), LAYOUT_16x10, LAYOUT_4x3, LAYOUT_WIDE
- **Alignment**: "left", "center", "right"
- **Chart data labels**: "outEnd", "inEnd", "center"
