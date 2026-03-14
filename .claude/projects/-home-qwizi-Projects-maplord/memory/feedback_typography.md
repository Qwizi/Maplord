---
name: feedback_typography
description: User finds colors too dark/invisible and typography weak across the whole frontend — needs stronger contrast and better readability
type: feedback
---

Colors are poorly visible on the dark background — text too dim, borders too subtle. User wants:
- Stronger text contrast (not slate-500/600 for important info — use slate-300/400 minimum)
- Brighter accent colors (not /15 or /20 opacity — use /40+ for backgrounds)
- Buttons must be clearly visible (solid backgrounds, not transparent)
- Better typography hierarchy — larger font sizes, bolder weights where needed

**Why:** The dark theme with very low opacity values (white/[0.03], slate-600, etc.) makes UI elements nearly invisible. User has repeatedly asked for more visible hovers, brighter buttons, etc.

**How to apply:** When creating UI, use minimum text-slate-300 for secondary text, text-zinc-100 for primary. Avoid opacity below /30 for interactive backgrounds. Buttons should use solid or high-opacity backgrounds.
