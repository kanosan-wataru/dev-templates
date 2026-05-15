# Custom Templates

Place your own HTML slide files here as style references.

When generating a new deck, Claude will detect these files in Phase 0 and ask whether to use them. If selected, the visual design (colors, fonts, header/footer, decorative elements) is extracted and used as the primary style guide.

## How to use

### Single template set

1. Copy your HTML slide files directly into this directory
2. Run `/slidekit-create` as usual
3. Claude will ask if you want to use the template

### Multiple template sets

1. Create subdirectories for each template set (e.g., `navy-gold/`, `modern-tech/`)
2. Place HTML slide files inside each subdirectory
3. Run `/slidekit-create` as usual
4. Claude will list the available template sets and ask which one to use

```
templates/
├── navy-gold/
│   ├── 001.html
│   ├── 002.html
│   ├── 003.html
│   └── images/
│       ├── bg_cover.png
│       └── logo.png
├── modern-tech/
│   ├── 001.html
│   └── 002.html
└── README.md
```

## Rules

- **HTML files and images** — `.html` files are read as style references; image files (`.jpg`, `.png`, `.webp`, `.svg`) in the `images/` subdirectory are included as template assets. Other file types are ignored
- **Max 5 HTML files per template set** — if more than 5 exist, only the first 5 (alphabetical) are read
- Files should follow the 1280x720px slide format for best results
- Text content in templates is ignored — only the visual style is extracted
- All Mandatory Constraints from SKILL.md still apply to generated output
- **Image assets** are automatically copied to the output directory's `images/` folder and referenced via relative paths in generated HTML
- **Image role detection** — the role of each image (background, logo, content) is inferred from `<img>` tag attributes in template HTML (`position`, `z-index`, size)
