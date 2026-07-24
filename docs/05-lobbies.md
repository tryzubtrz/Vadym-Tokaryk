# 05 — Как сделать красивые уникальные лобби

## 5.1 Принцип

Каждое лобби = **отдельный мир** + свой палитра-гайд + свои NPC/голограммы/звуки.  
Запрещено: копипаст спавна Survival в BedWars с перекраской шерсти.

**Hero budget лобби:** бренд + 1 слоган + селектор/CTA + доминантная декорация. Без стат-карточек в лицо.

## 5.2 Main Lobby — «Neon Harbor»

| Element | Spec |
|---------|------|
| Theme | Ночной порт + стекло + тёплый янтарь/бирюза (не фиолетовый дефолт) |
| Center | Большой логотип FunnyNetwork (build + custom font hologram) |
| Path | Круговая набережная → пирсы = режимы |
| Palette | `#0B1C24` deep, `#1F6F8B` teal, `#F2C14E` gold accents |
| Music | Soft electronic loop zones (NoteBlockAPI) |
| Motion | Waterfall particles, rotating logo armorstands, lighthouse beam |
| NPCs | Mode captains along pier |

## 5.3 Survival Lobby — «Medieval Fantasy»

| Element | Spec |
|---------|------|
| Theme | Каменный замок, знамёна, кузница, конюшни |
| Spawn | Двор замка, тронный NPC «Хранитель» |
| Palette | Slate gray, forest green, torch amber |
| Ambience | Village sounds, anvil, distant horn |
| Decor | Horses, armor stands knights, hanging chains |
| CTA | Gate portal → surv servers |
| Build refs | Fantasy RPG hub, not modern glass |

## 5.4 BedWars Lobby — «Neon Orbit»

| Element | Spec |
|---------|------|
| Theme | Футуризм, неон, обсерватория, арены в голограммах |
| Palette | Cyan `#00F5D4`, magenta `#FF2E63`, void black (neon OK here — mode identity) |
| Floor | Glass over void stars (particle map) |
| NPCs | Robot vendors, map holograms rotating |
| Sound | Soft synth + ender pearl whoosh on click |
| CTA | Queue pedestals Solo/Duo/Trio/Quad |

## 5.5 SkyBlock Lobby — «Floating Archipelago»

| Element | Spec |
|---------|------|
| Theme | Парящие острова, водопады в void, мосты из лозы |
| Palette | Sky blue, leaf green, waterfall white |
| Motion | Waterfall, butterflies (Mythic/IA), cloud particles |
| Center | Giant floating oak with island preview |
| CTA | Launch pads to `sb-*` |

## 5.6 Anarchy Lobby — «Ash Ruins»

| Element | Spec |
|---------|------|
| Theme | Пост-апок, разрушенный спавн, дым, ржавчина |
| Palette | Charcoal, rust `#B7410E`, toxic green accents |
| Ambience | Thunder distant, campfire, wither ambient low |
| Decor | Cracked concrete (IA), burned wood, warning signs |
| CTA | Broken portal → ana servers; rules hologram красный |

## 5.7 SkyWars Lobby — «Storm Isles»

- Грозовое небо, клетки-превью карт, wind particles.
- Palette: steel + electric yellow.

## 5.8 SkyPvP Lobby — «Crystal Spire»

- Вертикальные шпили, PvP showcase bots (Mythic), clan war board.

## 5.9 HungerGames Lobby — «Capitol Terrace»

- Трибуны, рог изобилия скульптура, карта арены голограммой.

## 5.10 Creative Lobby — «Gallery White»

- Чистая галерея, light wood + white concrete, plot of the week frames.

## 5.11 Prison Lobby — «Industrial Yard»

- Шахтные клети, конвейеры (IA), ore displays, prestige ladder hologram.

## 5.12 Farm Lobby — «Golden Barn»

- Поля, мельница, животные, sell-wand demo NPC.

---

## 5.13 NPC + Hologram pipeline

1. Build location → set Citizens NPC (`/npc create`, skin, look close).
2. FancyHolograms above: line1 mode name, line2 `%funny_online_<mode>%`, line3 `§a▶ Играть`.
3. Interaction: DeluxeMenus or `funny transfer <mode>`.
4. Idle: `effect` potion particles every 40t; sound `block.note_block.chime` on click.
5. ModelEngine only for 1–2 hero NPCs (perf).

### Hologram skeleton

```yaml
# FancyHolograms
id: npc_bedwars
position: world:128.5:72: -64.5
lines:
  - "<gradient:#00F5D4:#FF2E63><bold>BEDWARS</bold></gradient>"
  - "<gray>Онлайн: <white>%funny_online_bw%</white></gray>"
  - "<green>Нажми NPC чтобы играть</green>"
billboard: center
update_interval: 40
```

## 5.14 DeluxeMenus selector skeleton

См. `configs/deluxemenus/mode_selector.yml`.

Требования:
- 1 кнопка = 1 режим
- Lore: описание + онлайн + твой рейтинг
- Click: `[close]` + `[console] funny transfer %player_name% bw`

## 5.15 Resource pack rules

- Custom fonts for mode titles in holograms/menus.
- Furniture per theme (don't mix medieval chairs into BW neon).
- Keep pack < 50MB compressed; split optional overlays.

## 5.16 Performance budgets per lobby

| Metric | Max |
|--------|-----|
| Entities in spawn 64r | < 80 |
| Citizens NPCs | < 25 |
| Holograms | < 40 |
| View distance | 8 |
| Simulation | 4 |
| Particles continuous | low |

## 5.17 Builder checklist (DoD visual)

- [ ] Screenshot main spawn without UI — brand recognizable
- [ ] Mode lobbies distinguishable in 1 second
- [ ] Night/day cycle locked or themed per world
- [ ] No floating random heads / emoji spam
- [ ] Pathing obvious: spawn → CTA < 10 seconds walk
- [ ] Mobile-friendly (1.20.4+): no 1-wide maze only
