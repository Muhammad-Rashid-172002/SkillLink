# SkillNova Design System — MASTER

Source of truth for the mobile app (`lib/design_system/`) and the admin console
(`skilllink_admin/lib/theme/admin_design.dart`). Direction came from the UI UX Pro Max
skill ("Trust & Authority" pattern, flat style, service/pharmacy green palette,
Poppins/Open Sans pairing), then adapted for SkillNova. All text colours were
checked for WCAG AA (4.5:1).

## Palette — "Trusted Green"

| Token | Light | Dark | Notes |
|---|---|---|---|
| primary | `#15803D` | `#4ADE80` | 5.0:1 on white · on-primary dark is `#052E16` (8.5:1) |
| primaryDark | `#14532D` | — | text on `primarySoft` (8.3:1) |
| primarySoft | `#DCFCE7` | `#123B24` | containers, chips |
| worker accent | `#0F766E` | — | 5.5:1 on white |
| background | `#F6FAF7` | `#07130D` | green-tinted neutral |
| surface | `#FFFFFF` | `#0E1D15` | cards |
| textPrimary | `#0F1A14` | `#EEF5F0` | 16.9:1 |
| textSecondary | `#52615A` | `#A9BDB1` | 6.2:1 / 8.8:1 |
| textTertiary | `#8A988F` | — | decorative/disabled only (3:1) |
| success | `#067647` | — | distinct from brand green |
| warning | `#B45309` | — | 5.0:1 (was `#DC6803`, which failed AA) |
| error | `#D92D20` | — | |
| info | `#0369A1` | — | 5.9:1 |
| rating star | `#F59E0B` | — | icon only |

## Typography

- Headings (display / headline / titleLarge): **Poppins** 600–700.
- Body, labels, buttons: **Inter**, base 16 px, line height ≥ 1.4.
- Do not go below 12 px for any readable text.

## Spacing, radius, motion

- Spacing scale 4/8/12/16/20/24/32/40/48/64, gutter 20 on phones.
- Radius 8/10/16/20/28, pills 999.
- Motion 150/250/400 ms, `easeOutCubic`. Respect "reduce motion"
  (`SkillNovaMotion.of`). The live-tracking marker glides over 1.2 s and snaps
  instantly when reduce motion is on.

## Rules for every screen

1. Colours only from `Theme.of(context).colorScheme` / `SkillNovaColors` tokens.
2. Touch targets ≥ 48 dp. Icon-only buttons need a tooltip / semantic label.
3. Use plain words and short sentences (many users are new to smartphones). Say
   what happens next ("Tracking starts when your worker taps 'On my way'").
4. Every list has loading (skeleton), empty, and error states with a retry.
5. No emoji as icons — Material Symbols (rounded) only.
6. Payments/credits do not exist in this release; never show prices as charges.
