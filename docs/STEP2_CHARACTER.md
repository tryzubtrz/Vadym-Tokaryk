# Step 2 — Character system

## Status: done (code) — awaiting `.riv` art

1. **Domain** ✅
   - `AgeAppearance` catalog + rive/fallback asset keys
   - `CharacterAnimationState` / `CharacterAnimationNotifier`
2. **Animation** ✅
   - `RiveCharacterView`: loads `assets/rive/{stage}_{type}.riv` when present
   - State machine: `Character` + tap/stroke/poke/shake/talking/sleeping/mood
   - `FallbackCharacterAnimator`: breathe / sway / blink cutouts
3. **Touch** ✅ — tap / long-press / double-tap / pan → mood via `react()`
4. **Wire** ✅ — `TomRoomStage` → `CharacterStageView`; chat → `RiveCharacterView`
5. **Tests** ✅ — `test/age_appearance_test.dart`

## Rive asset contract (designer)

| File | Stage | Type |
|------|-------|------|
| `assets/rive/child_masya.riv` | 4–9 | Masya |
| `assets/rive/child_syryk.riv` | 4–9 | Syryk |
| `assets/rive/teen_*.riv` | 10–17 | … |
| `assets/rive/young_adult_*.riv` | 18–29 | … |
| `assets/rive/adult_*.riv` | 30–49 | … |
| `assets/rive/senior_*.riv` | 50+ | Syryk beard flag |

State machine name: `Character`
Inputs: `Number mood`, `Boolean talking`, `Trigger tap`, `Trigger stroke`, `Trigger poke`, `Trigger shake`, `Boolean sleeping`
