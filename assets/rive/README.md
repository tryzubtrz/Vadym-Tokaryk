# Rive character assets (Step 2)

Place stage × type files here:

- `child_masya.riv`, `child_syryk.riv`
- `teen_masya.riv`, `teen_syryk.riv`
- `young_adult_masya.riv`, `young_adult_syryk.riv`
- `adult_masya.riv`, `adult_syryk.riv`
- `senior_masya.riv`, `senior_syryk.riv`

State machine: `Character`  
Inputs: `tap`, `stroke`, `poke`, `shake` (Trigger), `talking`, `sleeping` (Bool), `mood` (Number 0–100)

Until files exist, the app uses the animated sprite fallback automatically.
