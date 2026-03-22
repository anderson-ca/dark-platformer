# Dark Platformer — CLAUDE.md

## Project Overview
2D precision platformer built in Godot 4.6 using GDScript. Dark fantasy / post-apocalyptic aesthetic. Pixel art at 32×32 base resolution. Target: itch.io web build, $2–5.

---

## IMPORTANT: Golden Rules

- **ONE change per prompt.** Never combine unrelated changes. If asked to do X and Y, do X first, report, then wait for confirmation before Y.
- **Never touch nodes you weren't explicitly told to change.** If fixing a bush, don't touch the player, lighting, rain, parallax, or anything else.
- **Always print diagnostics BEFORE making changes.** Show what you found, what you're about to change, and why.
- **Never change gameplay feel or values** (speeds, gravity, jump height, timings) unless explicitly asked.
- **Commit after every successful change.** Small, atomic commits with clear messages.

---

## Asset Folder Structure

```
assets/
├── backgrounds/
│   └── dark_forest/           # Parallax layers (0.png - 13.png)
│
├── props/
│   └── room_1/
│       ├── zone_1/            # THE WILDS — dense, overgrown, isolation
│       │   ├── foreground/    # z_index 2, player walks BEHIND these
│       │   ├── midground/     # z_index 0, same depth as player
│       │   └── background/    # z_index -1, player walks IN FRONT
│       │
│       ├── zone_2/            # THE CAMP — abandoned, storytelling
│       │   ├── foreground/
│       │   ├── midground/
│       │   │   └── animated/  # Animated props (campfire, torches)
│       │   └── background/
│       │
│       ├── zone_3/            # THE WARNING — danger ahead, dread
│       │   ├── foreground/
│       │   ├── midground/
│       │   │   └── animated/  # Animated props (blood trees, hangers)
│       │   └── background/
│       │
│       └── shared/            # Assets used across multiple zones
│           ├── foreground/
│           │   ├── foliage/   # Bushes, ferns, grass
│           │   └── rocks/     # Small/medium rocks
│           ├── midground/
│           │   ├── foliage/
│           │   ├── rocks/
│           │   └── signs/
│           └── background/
│               ├── foliage/
│               └── rocks/
│
├── effects/                   # Animated FX sprite sheets
│   ├── floor_dash_dust.png
│   ├── jump_land_dust.png
│   └── wall_dust.png
│
├── sprites/
│   └── player/
│       └── basic_player/      # Player animations
│
└── ui/
```

---

## Asset Naming Convention

**Pattern:** `[layer]_[type]_[description]_[size].png`

### Layer Prefixes (REQUIRED)
| Prefix | Layer | z_index | Meaning |
|--------|-------|---------|---------|
| `fg_` | Foreground | 2 | Player walks BEHIND these |
| `mg_` | Midground | 0 | Same depth as player |
| `bg_` | Background | -1 | Player walks IN FRONT of these |

### Size Suffixes (REQUIRED)
| Suffix | Meaning |
|--------|---------|
| `_sm` | Small (under 32px) |
| `_md` | Medium (32-64px) |
| `_lg` | Large (64-128px) |
| `_xl` | Extra large (128px+) |

### Examples
```
fg_bush_dark_md.png      # Foreground dark bush, medium
mg_tent_torn_lg.png      # Midground torn tent, large
bg_tree_pine_xl.png      # Background pine tree, extra large
fg_rock_mossy_sm.png     # Foreground mossy rock, small
mg_sign_wooden_md.png    # Midground wooden sign, medium
```

### Z-Index Rules
- **Read the filename prefix** — it tells you the z_index
- `fg_` = z_index 2 (in front of player)
- `mg_` = z_index 0 (same as player)
- `bg_` = z_index -1 (behind player)
- **NEVER guess z_index.** If the prefix is missing, ASK.

---

## Room 1 Zone Definitions

### Zone 1 — The Wilds (Far Left)
- **Mood:** Dense, overgrown, isolation, "where am I?"
- **Props:** Heavy vegetation, fallen logs, moss, ferns, darkness
- **Story:** Nature has reclaimed everything. No one comes here.
- **Player spawns here** and walks right toward the camp.

### Zone 2 — The Camp (Center)
- **Mood:** Discovery, mystery, "someone was here"
- **Props:** Tents, crates, campfire (purple), signs, barrels, chairs
- **Story:** An abandoned camp. Who left? Why? The purple fire hints at something unnatural.
- **Storytelling:** Sign with a message, scattered supplies, cold campfire or still burning?

### Zone 3 — The Warning (Far Right)
- **Mood:** Dread, danger, "should I keep going?"
- **Props:** Skull-pikes, bones, spikes, broken barriers, blood trees, hanging figures
- **Story:** They tried to protect themselves. It wasn't enough.
- **Leads to:** Room 2 / the danger zone

---

## Placing Assets — Rules for Claude Code

1. **Check the folder path** — it tells you the zone and layer
2. **Check the filename prefix** — it tells you the z_index
3. **Never place an asset at a z_index that contradicts its prefix**
4. **Static props** = Sprite2D node
5. **Animated props** (in `/animated/` folders) = AnimatedSprite2D node
6. **Position props so their base touches the ground** (y ≈ 640 or wherever the floor collision is)
7. **Foreground props** should partially obscure the player — that's the point
8. **Don't cluster identical assets** — vary which props you use

---

## Scene Tree Structure

```
World (Node2D)
├── ParallaxBackground
│   └── [Layers 0-13]
├── Background (Node2D)           # z_index -1, bg_ assets
├── Midground (Node2D)            # z_index 0, mg_ assets
├── Player (CharacterBody2D)      # z_index 0
├── Foreground (Node2D)           # z_index 2, fg_ assets
├── Ground (StaticBody2D)
│   └── CollisionShape2D
├── Rain (CPUParticles2D)
└── UI (CanvasLayer)
```

---

## Godot 4 Syntax — NEVER Use Godot 3

| Wrong (Godot 3) | Correct (Godot 4) |
|-----------------|-------------------|
| `export var` | `@export var` |
| `onready var` | `@onready var` |
| `KinematicBody2D` | `CharacterBody2D` |
| `move_and_slide(velocity)` | `velocity = velocity; move_and_slide()` |
| `is_on_floor()` after move | `is_on_floor()` before move_and_slide |
| `$Node` in _ready | `@onready var node = $Node` |
| `yield()` | `await` |
| `connect("signal", obj, "method")` | `signal.connect(method)` |

---

## 2D Platformer Best Practices

### Movement (already implemented)
- Coyote time: 0.1s window to jump after leaving platform
- Jump buffering: 0.1s window to queue jump before landing
- Variable jump height: release jump early = lower jump
- Wall jump: push away from wall + upward velocity
- Dash: fixed distance, brief invulnerability, cooldown

### Common Bugs to Avoid
- **Dash + wall jump velocity stacking:** Zero out velocity before applying new movement
- **Coyote time infinite jumps:** Reset coyote timer when jump is used
- **Double jump while grounded:** Only allow double jump when airborne
- **Sprite flip breaks collision:** Don't flip CollisionShape2D, only the sprite
- **Animation spam:** Check `if animation.animation != "new_anim"` before play()

### Physics Values (DO NOT CHANGE without permission)
- Gravity: ~1200-1500 (Celeste-like)
- Jump velocity: ~-400 to -500
- Run speed: ~200-300
- Dash speed: ~600-800
- These create the "tight, responsive" feel. Changing them alters the entire game feel.

---

---

## Level Art Direction — Design Rules

You are acting as a world-class environment artist. Follow these principles when placing assets.

### Core Composition Principles

**1. The Rule of Variation**
- NEVER place the same asset twice in a row
- NEVER cluster more than 2 of the same asset type together
- Alternate between sizes: sm → lg → md, not sm → sm → sm
- Alternate between types: bush → rock → fern → bush, not bush → bush → bush
- Use at least 3 different assets in any grouping

**2. Visual Rhythm**
- Create patterns, then break them — regular spacing feels artificial
- Cluster props in groups of 2-3, then leave breathing room
- Dense areas should contrast with sparse areas
- Zone 1 (Wilds): Dense → Zone 2 (Camp): Open clearing → Zone 3 (Warning): Sparse, ominous

**3. Size Hierarchy**
- Large assets anchor the composition (place these first)
- Medium assets fill the space around anchors
- Small assets add detail and ground-level texture (place these last)
- Mix sizes within groups: 1 large + 2 medium + 3-4 small = natural cluster

**4. Depth Through Layering**
- Background (bg_): Large, dark silhouettes, low detail, spaced far apart
- Midground (mg_): Interactive props, storytelling elements, medium spacing
- Foreground (fg_): Small detail props, close together, partially obscure player
- OVERLAP layers — foreground bushes should partially cover midground props

**5. Atmospheric Perspective**
- Background assets: Lighter, less saturated, less detailed
- Foreground assets: Darker, more saturated, more detailed
- This creates depth without parallax

### Placement Rules

**Grounding**
- Every prop's base must visually touch the ground
- No floating assets — y position should place the bottom edge at ground level
- Roots, bases, and bottoms should slightly overlap the ground (1-2 pixels)

**Silhouette Variation**
- Avoid placing assets with similar shapes next to each other
- Tall + short + medium creates interesting skyline
- Round bushes next to angular rocks, not round next to round

**Negative Space**
- Leave intentional empty areas — not every pixel needs decoration
- Empty space around important props makes them stand out
- The camp clearing should feel OPEN compared to the dense forest

**Leading Lines**
- Arrange props to subtly guide the eye left-to-right (player direction)
- Taller elements on edges, shorter toward center
- Create visual "corridors" that suggest where to go

### Zone-Specific Direction

**Zone 1 — The Wilds**
- DENSE vegetation — player should feel enclosed
- Heavy use of foreground bushes and ferns (player partially obscured)
- Background trees create sense of depth
- Colors: Dark greens, muted tones, mossy textures
- Mood: "Nature has reclaimed this place"

**Zone 2 — The Camp**
- OPEN clearing — contrast with Zone 1's density
- Midground focus — tents, crates, campfire, signs at player level
- Sparse foreground (don't obscure the camp props)
- Background trees frame the clearing
- Colors: Warmer tones near campfire, wood browns
- Mood: "Someone lived here"

**Zone 3 — The Warning**
- SPARSE, deliberate placement — each prop tells a story
- Warning props spaced apart for impact (skull-pike... gap... bones... gap... spikes)
- Fewer but larger, darker assets
- Blood trees and hanging figures in background
- Colors: Desaturated, sickly, dark
- Mood: "Turn back"

### Anti-Patterns — NEVER Do These

| Bad | Why | Good |
|-----|-----|------|
| Same asset repeated 3+ times in a row | Looks copy-pasted, artificial | Alternate with variants |
| Perfect grid spacing | Looks mechanical | Organic, irregular spacing |
| All same size | No visual hierarchy | Mix sm/md/lg |
| Symmetrical placement | Unnatural | Asymmetric, organic |
| Assets touching edges exactly | Looks placed, not grown | Slight overlaps |
| Empty zones with no transition | Jarring | Gradient from dense to sparse |
| All props in a straight line | Boring | Stagger y positions, cluster |

### Practical Execution

When placing N assets:
1. Place the 1-2 largest first (anchors)
2. Place medium assets around anchors, varying distance
3. Fill with small detail assets
4. Step back — check for repetition, adjust
5. Add slight y-variation (not perfectly aligned)
6. Ensure overlaps between layers look natural

---

## What NOT to Touch (Unless Explicitly Asked)

- Player movement code or values
- ParallaxBackground layers
- Rain particles
- Camera settings
- Ground collision
- Any node not mentioned in the current task

---

## Debugging Checklist

Before reporting "it's broken":
1. Print the node tree (`print_tree_pretty()`)
2. Print the specific node's properties
3. Check z_index values
4. Check position values
5. Check if the node is visible
6. Check if the texture loaded (not null)
7. Run the game and observe — describe what you SEE

---

## Git Workflow

- `git status` before any work
- `git add -A && git commit -m "descriptive message"` after each successful change
- Commit messages should say WHAT changed, not HOW
- If something breaks badly: `git checkout -- .` to revert uncommitted changes