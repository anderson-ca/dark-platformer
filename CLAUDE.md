# Dark Platformer — CLAUDE.md

## Project Overview
2D precision platformer built in Godot 4.6 using GDScript. Dark fantasy aesthetic. Pixel art at 32×32 base resolution.

---

## Golden Rules

- **ONE change per prompt.** Never combine unrelated changes.
- **Never touch nodes you weren't explicitly told to change.**
- **Always print diagnostics BEFORE making changes.**
- **Commit after every successful change.**

---

## Asset Folder Structure

```
assets/
├── backgrounds/
│   └── dark_forest/           # Parallax layers
│
├── props/
│   └── room_1/
│       ├── shared/            # Assets used across zones
│       │   ├── foreground/    # z_index 2
│       │   ├── midground/     # z_index 0
│       │   └── background/    # z_index -1
│       ├── zone_1/
│       ├── zone_2/
│       └── zone_3/
│
├── effects/                   # Animated FX sprite sheets
├── sprites/player/            # Player animations
└── ui/
```

---

## Asset Naming Convention

**Pattern:** `[layer]_[type]_[description]_[size].png`

| Prefix | z_index | Meaning |
|--------|---------|---------|
| `fg_` | 2 | Foreground — in front of player |
| `mg_` | 0 | Midground — same depth as player |
| `bg_` | -1 | Background — behind player |

| Suffix | Size |
|--------|------|
| `_sm` | Small |
| `_md` | Medium |
| `_lg` | Large |
| `_xl` | Extra large |

---

## Z-Index Reference

| Layer | z_index | Contents |
|-------|---------|----------|
| Background | -1 | bg_ assets, distant props |
| Midground | 0 | mg_ assets, player, interactive props |
| Foreground | 2 | fg_ assets, framing vegetation |

---

## Godot 4 Syntax — NEVER Use Godot 3

| Wrong (Godot 3) | Correct (Godot 4) |
|-----------------|-------------------|
| `export var` | `@export var` |
| `onready var` | `@onready var` |
| `KinematicBody2D` | `CharacterBody2D` |
| `yield()` | `await` |

---

## What Claude Code Does

- Writing and modifying GDScript code
- Setting up nodes programmatically when needed
- Fixing bugs and errors
- File operations (rename, move, organize)
- Git operations

## What Claude Code Does NOT Do

- **Asset placement** — User places assets manually in Godot editor
- **Visual composition decisions** — User handles all artistic choices
- **Adjusting positions for aesthetic reasons** — User does this visually

---

## Do NOT Touch (Unless Explicitly Asked)

- Player movement code or physics values
- ParallaxBackground layers
- Rain particles
- Camera settings
- Ground collision
- Any node not mentioned in the current task

---

## Scene Tree Structure

```
World (Node2D)
├── ParallaxBackground
├── Background (Node2D, z_index -1)
├── Midground (Node2D, z_index 0)
├── Player (CharacterBody2D)
├── Foreground (Node2D, z_index 2)
├── Ground (StaticBody2D)
├── Rain (CPUParticles2D)
└── UI (CanvasLayer)
```

---

## Script Structure

```
scripts/
├── enemies/
│   └── ghoul.gd
├── skills/
│   ├── base_projectile.gd
│   ├── base_summon.gd
│   ├── [individual summon scripts]
│   └── [individual projectile scripts]
├── utils/
│   └── vfx_utils.gd
├── player.gd
├── player_input.gd
├── player_animation.gd
├── player_dust.gd
├── world.gd
├── room_data.gd
├── hud.gd
├── moving_platform.gd
└── crumbling_platform.gd
```

---

## Debugging Checklist

Before reporting "it's broken":
1. `print_tree_pretty()` to see node structure
2. Print specific node properties
3. Check z_index values
4. Check position values
5. Check if texture loaded (not null)

---

## Git Workflow

- `git status` before any work
- `git add -A && git commit -m "message"` after each change
- Commit messages: say WHAT changed, not HOW