# Dark Platformer — CLAUDE.md

## Project Overview
2D precision platformer built in Godot 4.6 using GDScript. Dark fantasy / post-apocalyptic aesthetic. Pixel art at 32×32 base resolution. Target: itch.io web build, $2–5.

## IMPORTANT: Golden Rules
- **ONE change per prompt.** Never combine unrelated changes. If asked to do two things, do the first, confirm, then do the second.
- **Never change nodes you were not explicitly told to change.** If asked to fix a bush, touch ONLY that bush.
- **ALWAYS print diagnostics BEFORE making changes.** Show what you found, what you plan to change, and why. Wait for confirmation if the task is ambiguous.
- **If you are unsure, ASK. Do not guess.** Guessing has broken this project multiple times.
- **Never touch the ParallaxBackground or its layers** unless explicitly told to.
- **Never change z_index on any node** unless explicitly told to change that specific node's z_index.
- **Commit-safe changes only.** Every change should leave the game in a runnable state.

## Project Structure
```
dark-platformer/
├── assets/
│   ├── sprites/
│   │   └── player/         # Player animation PNGs (horizontal strips)
│   ├── props/
│   │   ├── foreground/     # z_index >= 2, renders IN FRONT of player
│   │   ├── midground/      # z_index 0, same layer as player
│   │   └── background/     # z_index <= -1, renders BEHIND player
│   ├── tilesets/           # Tileset PNGs (not currently in use)
│   └── parallax/           # Parallax background layers
├── scenes/                 # .tscn scene files
├── scripts/                # .gd script files
└── CLAUDE.md               # This file
```

## Z-Index Convention (CRITICAL)
This is the #1 source of bugs. Follow this EXACTLY:

| Layer | z_index | What goes here |
|-------|---------|----------------|
| Rain / UI overlay | 10 | Rain particles, HUD text |
| Foreground props | 2 | Bushes, rocks, signs, skull-pikes the player walks BEHIND |
| Player | 0 | Player character (default) |
| Midground props | 0 | Camp structures, tents, crates (same level as player) |
| Background props | -1 | Large trees, distant structures |
| Ground | -2 | Ground ColorRect |
| Parallax | auto | ParallaxBackground handles its own layering |

**Rule:** If a prop is in `props/foreground/`, its z_index MUST be 2.
**Rule:** If a prop is in `props/background/`, its z_index MUST be -1.
**Rule:** Never set z_index higher than 10 (reserved for rain/UI).

## Node Naming Convention
- Foreground props: `fg_` prefix (e.g., `fg_bush_01`, `fg_rock_large`)
- Background props: `bg_` prefix (e.g., `bg_tree_01`, `bg_rock_dark`)
- Midground/camp props: `mg_` prefix (e.g., `mg_tent_01`, `mg_crates`)
- Lighting nodes: `light_` prefix (e.g., `light_campfire`, `light_lamppost`)
- Particle systems: `fx_` prefix (e.g., `fx_rain`, `fx_dust_run`)

## Scene Tree Organization
```
World
├── ParallaxBackground/     # DO NOT TOUCH without explicit instruction
├── Ground/                 # Ground geometry and collision
├── BackgroundProps/         # All bg_ nodes go here (z_index -1)
├── MidgroundProps/          # All mg_ nodes go here (z_index 0)
├── Player/                  # Player character (z_index 0)
├── ForegroundProps/         # All fg_ nodes go here (z_index 2)
├── Lighting/                # All light_ nodes
├── Effects/                 # All fx_ nodes (rain, dust, mist)
└── UI/                      # HUD, debug text
```

## Godot / GDScript Rules
- Engine: Godot 4.6, GDScript only. IMPORTANT: Use Godot 4 syntax, NOT Godot 3. Common mistakes: `@onready` not `onready`, `@export` not `export`, `CharacterBody2D` not `KinematicBody2D`, `move_and_slide()` takes no args in Godot 4.
- All sprite assets are pixel art. NEVER use anti-aliasing, smoothing, or filtering on textures. Set `texture_filter` to `NEAREST` everywhere.
- Player animations are horizontal PNG strips. Frame size varies per character. Always read the PNG dimensions and calculate frame count (width ÷ frame_height) before setting up animations.
- Ground collision surface is at y=640. All props sitting on the ground should have their bottom edge at or near y=640.
- The game uses CanvasModulate for darkness and PointLight2D for glow effects. These create the core atmosphere — do not remove or disable them.
- Use `_physics_process(delta)` for movement/physics, `_process(delta)` for visual updates only.
- Access nodes with `$NodeName` or `get_node()` only AFTER `_ready()` — accessing earlier causes null references.
- Signals connected in the editor don't persist across runtime reloads. Connect signals in `_ready()` via code when possible.
- Prefer composition (child nodes) over deep inheritance. Keep scripts focused on one responsibility.
- When loading textures in code, always use `load()` not `preload()` for dynamic paths. Use `preload()` only for known, static paths.

## Scene File (.tscn) Rules
- Godot .tscn files are human-readable text. You CAN and SHOULD edit them directly for simple property changes (z_index, position, scale, visibility) instead of writing GDScript to do it at runtime.
- When editing .tscn files directly: never use `preload()`, `var`, `const`, or `func` — these are GDScript, not scene format. Use `ExtResource("id")` for resources.
- After editing .tscn files, always validate the scene loads without errors before reporting success.

## 2D Platformer-Specific Rules
This is a precision platformer (Hollow Knight / Celeste / Dead Cells style). These mechanics are already implemented or planned. Follow these patterns:

### Player Controller (CharacterBody2D)
- All movement logic goes in `_physics_process(delta)`, never `_process(delta)`.
- Use `move_and_slide()` with NO arguments (Godot 4). Set `velocity` property directly before calling it.
- Use `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()` AFTER `move_and_slide()` — they update only after that call.
- Gravity must apply every frame including when grounded (prevents floating-off-slopes bug). Standard pattern: `velocity.y += gravity * delta`
- Falling gravity should be higher than rising gravity (descending_gravity_multiplier ~1.5-2.0) for snappy, non-floaty jumps.

### Movement Mechanics (implemented)
- **Coyote time:** ~0.1s window to jump after leaving a ledge. Use a Timer node, NOT frame counting. Start the timer when `was_on_floor` and `!is_on_floor()`.
- **Jump buffering:** ~0.1s window to press jump before landing. If jump pressed in air close to ground, execute jump on landing.
- **Wall jump:** Player must be `is_on_wall()` AND pressing toward wall OR have recently left wall. Apply velocity.x AWAY from wall + velocity.y upward.
- **Wall slide:** Reduce gravity when sliding down a wall (divide by 3-4). Only trigger when falling (velocity.y > 0) AND holding toward wall.
- **Dash:** Fixed duration (~0.15s), fixed speed, ignores gravity during dash. MUST reset velocity after dash ends — otherwise dash velocity combines with other forces and sends player flying.
- **Double jump:** Track jump count. Reset to 0 on `is_on_floor()`. Falling off a ledge should NOT count as a jump (coyote time handles this). Common AI bug: walking off a ledge gives the player an extra jump — always check for this.

### Sprite & Animation Rules
- Flip the sprite with `animated_sprite.flip_h = true/false` based on movement direction. Do NOT flip the entire CharacterBody2D node — this breaks collision shape offsets.
- If the CollisionShape2D is not centered, you MUST offset it when flipping. Common bug: collision shape doesn't flip with sprite, causing wall detection to be offset.
- Animation state machine priority: death > hit > dash > wall_slide > jump/fall > run > idle. Higher priority states override lower ones.
- Animations must call `animated_sprite.play("name")` — do NOT call play() every frame. Check if the animation is already playing first, or it will restart from frame 0 every physics tick.
- Use separate animation files per action (idle.png, run.png, jump.png, etc.), NOT one giant sprite sheet with all animations. We learned this the hard way — multi-row sheets cause flip/clipping bugs.

### Collision Shape
- Use CapsuleShape2D or RectangleShape2D — NOT CircleShape2D (causes sliding on flat ground).
- The collision shape should be slightly narrower than the sprite for forgiving platforming ("tight pants" principle).
- Keep the collision shape CENTERED on the CharacterBody2D. If it's offset, flipping the sprite will misalign the collision.

### Common 2D Platformer Bugs (AI frequently introduces these)
- **Infinite jump glitch:** If coyote time timer isn't properly stopped after jumping, the player can jump repeatedly in mid-air by spamming jump. Always stop the coyote timer immediately when a jump is executed.
- **Dash + wall jump velocity explosion:** Dash velocity and wall jump velocity combine, sending the player flying. Always zero out velocity before applying a new movement ability.
- **Stuck on ceiling:** When dashing horizontally into a wall beneath a ceiling, the player gets stuck. Ensure `move_and_slide()` handles ceiling collisions and stops upward velocity.
- **Floaty jumps:** AI tends to set gravity too low. For a snappy Celeste-like feel, use high gravity (2000-4000) with high jump speed (800-1800). The numbers feel wrong but play right.
- **Wall slide on wrong side:** Wall slide particles or animations play on the wrong side because `is_on_wall()` doesn't tell you WHICH wall. Use `get_wall_normal()` to determine wall direction.
- **Animation fighting:** Two states try to play different animations on the same frame, causing flickering. Use a strict state machine with clear priority.

## Common Gotchas (learned from past failures + community knowledge)
1. **Godot 3 vs 4 syntax:** LLMs frequently generate Godot 3 code. Watch for: `KinematicBody2D` (wrong, use `CharacterBody2D`), `export` (wrong, use `@export`), `onready` (wrong, use `@onready`), `move_and_slide(velocity)` (wrong, Godot 4 uses `velocity` property + `move_and_slide()` with no args).
2. **Sprite sheet cropping:** Single multi-row sprite sheets cause flip/clipping bugs. Always use separate PNG files per animation (exported from Aseprite with --split-tags).
3. **z_index inheritance:** In Godot, z_index is relative to parent by default (`z_as_relative = true`). If a node's parent has z_index 2, and the child has z_index 1, the child renders at effective z_index 3. Be aware of this when nesting nodes.
4. **Parallax gap:** If there is a visible gap between the ground and the parallax background, the fix is adjusting the ground or prop positions — NOT changing the ParallaxBackground layers.
5. **Props floating above ground:** When placing props, always calculate bottom edge: `position.y + (texture_height * scale.y / 2)` should equal ~640 (ground level).
6. **Camera revealing edges:** The camera can scroll to reveal areas where backgrounds don't extend far enough. Always extend backgrounds/ground beyond the expected camera bounds.
7. **TileMap experiments:** Previous TileMap attempts failed badly. If tileset work is needed, discuss the approach first before implementing.
8. **Node access before ready:** Accessing `$ChildNode` or `get_node()` in `_init()` or at class level causes null errors. Always use `@onready var` or access nodes inside `_ready()`.
9. **Texture filtering:** Pixel art MUST use `NEAREST` filter. If sprites look blurry or have subpixel artifacts, check `Project Settings > Rendering > Textures > Canvas Textures > Default Texture Filter` is set to `Nearest`.
10. **Over-engineering by AI:** LLMs tend to write complex GDScript solutions when a simple scene tree change or .tscn edit would suffice. Always prefer the simplest approach: scene tree reorganization > .tscn property edit > simple script > complex script.

## Working With This Project
- **Plan before executing.** For any task involving more than 1 file, describe your plan FIRST. Do not start coding until the plan is confirmed or the task is clearly simple.
- **Before any visual change:** Print the affected node's name, position, z_index, scale, and texture path.
- **After any change:** Describe exactly what changed so the developer can verify visually.
- **If a change doesn't work after 2 attempts:** STOP. Report what you tried and what happened. Do NOT keep trying different approaches — you will make things worse. Let the developer decide the next step.
- **Prefer .tscn edits over code for static changes.** Changing a node's z_index, position, or scale should be done by editing the .tscn file directly, not by writing GDScript that runs at startup.
- **Git:** The developer manages commits manually. Never run git commands unless explicitly asked.
- **Context management:** If the conversation is getting long, suggest a `/clear` before starting a new unrelated task.

## Build & Run
```bash
# Run the game from terminal
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dark-platformer
```

## Asset Pipeline
- Source art: The DARK Series bundle by Penusbmic (76 packs), 32×32 base resolution
- Character animations: Exported from Aseprite using --split-tags (separate PNG per animation)
- Static props: Extracted from sprite sheets using Aseprite's "New Sprite From Selection" → Export As
- All assets must match the dark, muted pixel art aesthetic. Nothing bright or saturated.