---
name: Tarmeem Design System
colors:
  surface: '#faf9f6'
  surface-dim: '#dbdad7'
  surface-bright: '#faf9f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f1'
  surface-container: '#efeeeb'
  surface-container-high: '#e9e8e5'
  surface-container-highest: '#e3e2e0'
  on-surface: '#1a1c1a'
  on-surface-variant: '#404847'
  inverse-surface: '#2f312f'
  inverse-on-surface: '#f2f1ee'
  outline: '#707977'
  outline-variant: '#bfc8c6'
  surface-tint: '#316763'
  primary: '#003633'
  on-primary: '#ffffff'
  primary-container: '#134e4a'
  on-primary-container: '#87beb8'
  inverse-primary: '#9ad1cb'
  secondary: '#006a63'
  on-secondary: '#ffffff'
  secondary-container: '#99efe5'
  on-secondary-container: '#006f67'
  tertiary: '#4c2600'
  on-tertiary: '#ffffff'
  tertiary-container: '#6d3800'
  on-tertiary-container: '#ff9c42'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b5ede7'
  primary-fixed-dim: '#9ad1cb'
  on-primary-fixed: '#00201e'
  on-primary-fixed-variant: '#144f4b'
  secondary-fixed: '#9cf2e8'
  secondary-fixed-dim: '#80d5cb'
  on-secondary-fixed: '#00201d'
  on-secondary-fixed-variant: '#00504a'
  tertiary-fixed: '#ffdcc3'
  tertiary-fixed-dim: '#ffb77d'
  on-tertiary-fixed: '#2f1500'
  on-tertiary-fixed-variant: '#6e3900'
  background: '#faf9f6'
  on-background: '#1a1c1a'
  surface-variant: '#e3e2e0'
typography:
  display-lg:
    fontFamily: bricolageGrotesque
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 44px
  display-lg-mobile:
    fontFamily: bricolageGrotesque
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 38px
  headline-lg:
    fontFamily: bricolageGrotesque
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: bricolageGrotesque
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 30px
  headline-sm:
    fontFamily: bricolageGrotesque
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-lg:
    fontFamily: workSans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: workSans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: workSans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: workSans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: workSans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: workSans
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  unit-2xs: 0.25rem
  unit-xs: 0.5rem
  unit-sm: 0.75rem
  unit-md: 1rem
  unit-lg: 1.25rem
  unit-xl: 1.5rem
  unit-2xl: 2rem
  unit-3xl: 3rem
  screen-margin-mobile: 1rem
  screen-margin-tablet: 1.5rem
  touch-target-min: 3rem
---

## Brand & Style

This design system delivers a tactile, serene, and grounded workshop companion tailored for independent craftspeople and repair specialists across the Arabic-speaking world—ranging from horologists and jewelers to electronics, appliance, and mobile technicians.

### Brand Personality & Tone
- **Dignified Craftsmanship (صنعة متقنة):** Balances practical utility with an appreciation for restorative trade work.
- **Calm & Unhurried (هدوء وتأني):** Replaces high-stress ticketing anxiety with tranquil deep teals and gentle warm cream backdrops.
- **Immediate Clarity (وضوح وسلاسة):** Built natively for Right-to-Left (RTL) glanceability, accommodating one-handed operation on busy workshop counters.

### Design Movement
**Modern Workshop Craft:** Merges the tactile warmth of physical atelier stationery with high-efficiency ergonomic pill contours. Interfaces utilize subtle warm surface stratification, large non-fatiguing touch targets (minimum 48px), and crisp Arabic-first information architecture.

## Colors

The palette is tuned to diminish eye strain in fluorescent or windowless repair benches while maintaining strict contrast compliance.

### Core Tonal Logic
- **Primary (`#134E4A`):** Deep Forest Teal anchoring primary actions, key active navigation states, and dominant brand headers.
- **Secondary (`#0F766E`):** Bright Deep Teal for secondary interactive elements, selected segments, and focus outlines.
- **Tertiary (`#D97706`):** Warm Amber used for pending diagnostic signals and critical temporal notices.
- **Background & Canvas (`#FAF9F6`):** Warm workshop cream replacing harsh digital whites to prevent optical exhaustion.
- **Surface Elevation (`#FFFFFF`):** Pure elevated card faces to create subtle visual depth against the cream canvas.

### Operational Status Tokens
- **In Diagnosis (قيد الفحص):** Ochre Amber text `#D97706`, container fill `#FEF3C7`, border `#FDE68A`.
- **Waiting for Part (بانتظار قطعة):** Deep Slate Indigo text `#4F46E5`, container fill `#EEF2FF`, border `#C7D2FE`.
- **Ready for Pickup (جاهز للاستلام):** Forest Emerald text `#059669`, container fill `#D1FAE5`, border `#A7F3D0`.
- **Delivered / Completed (تم التسليم):** Neutral Charcoal Slate text `#4B5563`, container fill `#F3F4F6`, border `#E5E7EB`.

## Typography

The type system prioritizes balanced vertical alignment and legible tracking for Arabic glyph scripts across RTL viewports.

### RTL Typesetting Directives
- **Font Integration:** Primary typographic rules pair display personality with neutral body clarity. When localized strictly to system Arabic fallbacks, `IBM Plex Sans Arabic`, `Cairo`, or `Noto Sans Arabic` are systematically injected via `@font-face` cascades while retaining geometric baseline proportions.
- **Numbers:** Use Western Arabic (`1, 2, 3`) or Eastern Arabic (`١, ٢, ٣`) consistently according to regional merchant preferences, styled with tabular figures (`tnum`) for invoice amounts and serial tallies.
- **Line Heights:** Arabic typography requires an additional 20–25% vertical clearance compared to Latin scripts to accommodate ascenders, descenders, and accent marks (*tashkeel*). Never set line height below `1.4` on continuous body copy.

## Layout & Spacing

A 4px baseline rhythm dictates all spacing, optimized for mobile-first handheld usage on the workshop floor.

### Layout Rules
- **Margins & Gutters:** Mobile viewports operate on a 4-column layout with `16px` side margins and `12px` gutters. Tablet counter-stands expand to an 8-column layout with `24px` margins.
- **One-Handed Ergonomics:** Primary navigation, action drawers, and ticket status switchers sit in the lower 40% of the screen ("The Thumb Zone"). Secondary filters and search sit at the top.
- **RTL Fluidity:** Horizontal margins, padding, and alignments automatically flip across the directional axis (`margin-inline-start`, `padding-inline-end`).

## Elevation & Depth

This system avoids synthetic neon glows or overly harsh dropshadows. Depth mimics physical card tags resting on a clean wooden or linoleum work surface.

### Elevation Levels
- **Level 0 (Floor):** Color `#FAF9F6`. Base canvas container.
- **Level 1 (Work Card):** Color `#FFFFFF`. Flat surface with border `1px solid rgba(19, 78, 74, 0.08)` and ambient shadow `0 2px 8px rgba(19, 78, 74, 0.04)`.
- **Level 2 (Active Item / Floating Card):** Color `#FFFFFF`. Ambient warm shadow `0 8px 24px rgba(19, 78, 74, 0.08)`.
- **Level 3 (Modal Sheet / Bottom Drawer):** Pure surface with upward diffusion `0 -8px 32px rgba(19, 78, 74, 0.12)`.

## Shapes

The interface embraces a pill-shaped ergonomic system (Level 3 roundedness). This tactile styling gives the software an approachable, non-intimidating tool aesthetic.

### Geometry Hierarchy
- **Status Badges & Pill Buttons:** Fully rounded corners (`9999px`) for quick tactile thumb confirmation.
- **Cards & Modal Trays:** Rounded borders utilizing large curvature (`1.5rem` to `2rem` / `rounded-2xl` to `rounded-3xl`) creating a friendly card-stationery look.
- **Input Fields:** Soft pill containers (`1rem` / `rounded-xl`) offering spacious visual rest for scanned device serial numbers.

## Components

### Buttons
- **Primary:** Background `#134E4A`, Text `#FFFFFF`, Pill-shaped (`rounded-full`), min-height `48px`, horizontal padding `24px`. Pressed state scales subtly to `0.98`.
- **Secondary / Ghost:** Transparent background, border `1.5px solid #134E4A`, text `#134E4A`.
- **Icon Placement:** Icons sit on the inline-start side (right side in RTL layouts) with `8px` spacing to text.

### Status Badges (شارة الحالة)
- **Geometry:** Height `28px`, Pill shape (`rounded-full`), horizontal padding `12px`.
- **Typography:** `label-md` bold weight.
- **Structure:** Leading status dot (`6px` diameter circle) followed by status text:
  - *قيد الفحص*: Dot `#D97706`, Text `#92400E`, Background `#FEF3C7`.
  - *بانتظار قطعة*: Dot `#4F46E5`, Text `#3730A3`, Background `#EEF2FF`.
  - *جاهز للاستلام*: Dot `#059669`, Text `#065F46`, Background `#D1FAE5`.
  - *تم التسليم*: Dot `#4B5563`, Text `#374151`, Background `#F3F4F6`.

### Cards (بطاقة تذكرة الإصلاح)
- **Container:** Background `#FFFFFF`, border-radius `24px`, padding `16px`, border `1px solid rgba(19, 78, 74, 0.07)`.
- **Header:** Repair ticket number and date stacked on the inline-start (right), status pill aligned inline-end (left).
- **Body:** Device model title in `headline-sm`, customer name and contact in `body-md` secondary muted tint.
- **Footer:** Cost summary and quick action buttons ("اتصال" / "تحديث الحالة") with clear divider.

### Input Fields
- **Container:** Height `52px`, background `#FFFFFF`, border `1.5px solid #E5E7EB`, border-radius `16px`, horizontal padding `16px`.
- **Focus State:** Border `#0F766E`, shadow ring `0 0 0 3px rgba(15, 118, 110, 0.15)`.
- **Text Alignment:** Right-aligned native Arabic input with left-aligned Latin alphanumeric toggles for serial numbers (IMEI / Part SKU).

### Lists & Quick Filters
- **Segmented Filter Bar:** Horizontally scrolling pill rail with `#FAF9F6` background. Selected pill uses `#134E4A` fill with `#FFFFFF` text; unselected pills use `#FFFFFF` fill with `#4B5563` text and subtle outline.