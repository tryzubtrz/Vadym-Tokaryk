# MyMasyaAI — Architecture (Step 1)

## Goal

Cross-platform Flutter companion app (Talking Tom–class UX) with growth 4→60+,
local AI, dual currency, rooms, friends, photo & code unlocks.

## Feature-first layout

```
lib/
  main.dart
  app.dart
  core/           # constants, theme, router, l10n, utils, network, errors
  shared/         # reusable widgets, providers, extensions
  data/           # shared DTOs, Hive, secure storage, repositories
  domain/         # shared entities & services
  features/
    <feature>/
      data/         # feature DTOs / local sources
      domain/       # feature use-cases / entities
      presentation/ # pages & UI
      providers/    # Riverpod notifiers
      widgets/      # feature-only widgets
```

## Features (Step 1 scaffold)

| Feature | Responsibility |
|---------|----------------|
| onboarding | language, age, character pick, name |
| auth | email/Apple/Google |
| home | main Tom-style shell |
| character | age stages, Rive, needs (Step 2) |
| kitchen / bathroom / bedroom | care rooms (Step 4) |
| games | 9 minigames (Step 6) |
| chat | companion chat + local LLM port (Step 7) |
| photo / code | age-gated rooms (Step 8) |
| growth | XP curve (Step 5) |
| models_ai | on-device model cache ≤2 |
| pet / friends / economy / news / settings | systems (Step 9) |
| wardrobe | skins/outfits UI |
| storage / offline / time_guard | sync & anti-time-travel |
| widget_home | home-screen widget (25%) |

## Stack

- Flutter stable
- Riverpod (`flutter_riverpod` + `riverpod_annotation` / generator)
- go_router
- Hive + flutter_secure_storage
- Rive (character animations — Step 2)
- freezed + json_serializable (models from Step 2+)

## Build order (strict)

1. **Structure** ✅
2. **Character + Rive** ✅ (fallback until `.riv` art)
3. **Home screen (Tom UX)** ✅
4. **Kitchen / Bath / Bedroom** ← current
5. Growth XP
6. Minigames
7. Chat + LLM interface stub
8. Photo + Code
9. Friends, pet, settings, economy, offline, time guard

## Visual UX (Outfit7 reference, own IP)

- Character 60–70% center on room background
- Top-left age ring, top currencies, bottom circular actions
- Soft 3D friendly look — **Rive / real 3D assets**, not flat CustomPainter as final art
