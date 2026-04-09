# Figma Setup Guide

## 1) File structure

Create pages:

1. `01 Foundations`
2. `02 Components`
3. `03 Sections`
4. `04 Concepts`
5. `05 Hybrid`

## 2) Frame presets

- Desktop: `1440 x Auto` (12 cols, margin 80, gutter 24)
- Tablet: `1024 x Auto` (8 cols, margin 48, gutter 20)
- Mobile: `390 x Auto` (4 cols, margin 20, gutter 12)

## 3) Variables

Create variable collections:

- `theme/color` (`light`, `dark`)
- `theme/spacing`
- `theme/radius`
- `theme/shadow`

## 4) Components to build first

- Navbar
- Hero block
- KPI cards
- Problem card
- Steps card
- Pricing card
- Trust strip
- FAQ accordion
- CTA footer

## 5) How to bring these markdown concepts into Figma

Option A (manual, fastest):

1. Open one concept file from `docs/design/landing-concepts`.
2. Copy section list and headings.
3. Build each section as one Frame in `04 Concepts`.

Option B (with AI in Figma):

1. Paste the concept content into Figma AI prompt.
2. Ask it to generate a responsive landing wireframe with given sections.
3. Apply your tokens.

Option C (FigJam planning first):

1. Create FigJam board.
2. Paste section order and copy blocks.
3. Convert to design frames in Figma file.
