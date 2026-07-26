# Step 3 — Home shell (Talking Tom UX)

## Goal

Main room reads as one Tom-style composition:

1. Full-bleed empty living room
2. Character ~60–70% width, center-bottom
3. HUD overlays only: age ring (TL), currencies (TR), side fabs, circular bottom actions

## Layout rules

- No cards in the hero / room plane
- No dense need meters on the first read — only **critical** need pips
- Bottom actions: Shop · Smile(chat) · Food · Toilet · Sleep
- Side: Games · Friends · Wardrobe
- 2–3 entrance motions (HUD fade, actions rise, soft character settle)

## Status ✅

- Age ring (`LevelBadge`) with year progress + «років»
- Currency chips → economy
- Critical-only `TomNeedsPips`
- Circular bottom actions + side fabs with entrance motion
- Character via Step 2 `CharacterStageView` (~68% width)
