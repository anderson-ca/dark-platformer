class_name RoomData

static var ROOMS: Array[Dictionary] = [
	# Room 1 — Forest Edge
	{
		"name": "Forest Edge",
		"width": 5600, "height": 720,
		"spawn": Vector2(100, 631),
		"fall_respawn_y": 2000,
		"solids": [
			# === MAIN GROUND — flat combat zone ===
			{"x": 0, "y": 640, "w": 2000, "h": 80},
			# === SECTION A: Small ground elevation changes ===
			{"x": 2080, "y": 600, "w": 320, "h": 40},    # A1: 40px step up, 5 tiles wide
			# Ground continues at normal level
			{"x": 2480, "y": 640, "w": 384, "h": 80},
			# === SECTION B: Floating platforms above ground ===
			{"x": 2560, "y": 530, "w": 256, "h": 16},    # B1: 110px above ground
			{"x": 2880, "y": 460, "w": 256, "h": 16},    # B2: 70px above B1
			# === SECTION C: Stepped ascending platforms ===
			{"x": 2944, "y": 640, "w": 640, "h": 80},    # Ground continues
			{"x": 3200, "y": 580, "w": 256, "h": 16},    # C1: 60px above ground
			{"x": 3360, "y": 510, "w": 256, "h": 16},    # C2: 70px above C1
			{"x": 3520, "y": 440, "w": 320, "h": 16},    # C3: 70px above C2, highest
			# === SECTION D: Valley pit ===
			{"x": 3648, "y": 720, "w": 512, "h": 80},    # Valley floor: 80px below ground
			# Ramp out of valley
			{"x": 4160, "y": 680, "w": 128, "h": 16},    # Step 1: 40px up from valley
			{"x": 4224, "y": 640, "w": 128, "h": 16},    # Step 2: back to ground level
			# === Ground continues after valley ===
			{"x": 4352, "y": 640, "w": 1200, "h": 80},
			# === SECTION E: Final floating platforms ===
			{"x": 4600, "y": 540, "w": 256, "h": 16},    # E1: 100px above ground
			{"x": 4800, "y": 450, "w": 192, "h": 16},    # E2: 90px above E1
			{"x": 5000, "y": 540, "w": 256, "h": 16},    # E3: back down, peak pattern
		],
		"moving_platforms": [],
		"hazards": [],
		"crumbling_platforms": [],
		"goal": {"x": 5500, "y": 518, "w": 26, "h": 124},
		"hints": ["A/D: Move | Space: Jump"],
		"torches": [],
	},
	# Room 2 — Looking Up
	{
		"name": "Looking Up",
		"width": 1200, "height": 1000,
		"spawn": Vector2(100, 860),
		"fall_respawn_y": 1100,
		"solids": [
			{"x": 0, "y": 920, "w": 1200, "h": 80},
			{"x": 80, "y": 850, "w": 180, "h": 16},
			{"x": 350, "y": 785, "w": 160, "h": 16},
			{"x": 150, "y": 720, "w": 160, "h": 16},
			{"x": 400, "y": 655, "w": 140, "h": 16},
			{"x": 160, "y": 595, "w": 200, "h": 16},
			{"x": 160, "y": 560, "w": 200, "h": 16},
			{"x": 450, "y": 520, "w": 140, "h": 16},
			{"x": 200, "y": 455, "w": 160, "h": 16},
			{"x": 480, "y": 390, "w": 140, "h": 16},
			{"x": 200, "y": 325, "w": 300, "h": 16},
		],
		"moving_platforms": [],
		"hazards": [],
		"crumbling_platforms": [
			{"x": 450, "y": 520, "w": 140, "h": 16, "shake": 0.5, "respawn": 3.0},
		],
		"goal": {"x": 440, "y": 201, "w": 26, "h": 124},
		"hints": ["Climb up! Tap jump briefly for short hops.", "Some ledges crumble — don't linger!"],
		"torches": [Vector2(200, 920), Vector2(480, 655)],
	},
	# Room 3 — Second Wind
	{
		"name": "Second Wind",
		"width": 2200, "height": 720,
		"spawn": Vector2(100, 580),
		"fall_respawn_y": 820,
		"solids": [
			{"x": 0, "y": 640, "w": 300, "h": 80},
			{"x": 500, "y": 640, "w": 200, "h": 80},
			{"x": 910, "y": 640, "w": 180, "h": 80},
			{"x": 1230, "y": 540, "w": 160, "h": 16},
			{"x": 1550, "y": 640, "w": 200, "h": 80},
			{"x": 1900, "y": 640, "w": 300, "h": 80},
		],
		"moving_platforms": [
			{"start": Vector2(1420, 640), "end": Vector2(1420, 540), "width": 80, "height": 16, "speed": 50.0, "pause": 0.6},
		],
		"hazards": [],
		"crumbling_platforms": [],
		"goal": {"x": 2120, "y": 518, "w": 26, "h": 124},
		"hints": ["Some gaps are too wide for a single jump...", "Press jump again in the air! (Double Jump)"],
		"torches": [],
	},
	# Room 4 — Grip
	{
		"name": "Grip",
		"width": 800, "height": 1200,
		"spawn": Vector2(150, 1060),
		"fall_respawn_y": 1300,
		"solids": [
			{"x": 0, "y": 1120, "w": 800, "h": 80},
			{"x": 335, "y": 380, "w": 30, "h": 740},
			{"x": 495, "y": 380, "w": 30, "h": 740},
			{"x": 525, "y": 440, "w": 200, "h": 16},
		],
		"moving_platforms": [],
		"hazards": [
			{"x": 365, "y": 1100, "w": 130, "h": 16},
		],
		"crumbling_platforms": [],
		"goal": {"x": 612, "y": 316, "w": 26, "h": 124},
		"hints": ["Press into a wall while airborne to cling.", "Jump off walls to ascend! Thorns below."],
		"torches": [Vector2(250, 1120), Vector2(620, 440)],
	},
	# Room 5 — Bolt
	{
		"name": "Bolt",
		"width": 2600, "height": 720,
		"spawn": Vector2(100, 580),
		"fall_respawn_y": 820,
		"solids": [
			{"x": 0, "y": 640, "w": 350, "h": 80},
			{"x": 350, "y": 640, "w": 200, "h": 80},
			{"x": 750, "y": 640, "w": 250, "h": 80},
			{"x": 1000, "y": 640, "w": 250, "h": 80},
			{"x": 1000, "y": 590, "w": 250, "h": 16},
			{"x": 1250, "y": 640, "w": 200, "h": 80},
			{"x": 1650, "y": 640, "w": 250, "h": 80},
			{"x": 2050, "y": 640, "w": 520, "h": 80},
		],
		"moving_platforms": [
			{"start": Vector2(1250, 600), "end": Vector2(1410, 600), "width": 40, "height": 40, "speed": 80.0, "pause": 0.0},
		],
		"hazards": [],
		"crumbling_platforms": [],
		"goal": {"x": 2500, "y": 518, "w": 26, "h": 124},
		"hints": ["Press SHIFT to dash!", "Dash across wide gaps and through tight corridors."],
		"torches": [Vector2(150, 640), Vector2(1350, 640), Vector2(2400, 640)],
	},
	# Room 6 — Precision
	{
		"name": "Precision",
		"width": 2400, "height": 720,
		"spawn": Vector2(100, 580),
		"fall_respawn_y": 820,
		"solids": [
			{"x": 0, "y": 640, "w": 250, "h": 80},
			{"x": 450, "y": 640, "w": 80, "h": 16},
			{"x": 730, "y": 625, "w": 60, "h": 16},
			{"x": 990, "y": 640, "w": 50, "h": 16},
			{"x": 1200, "y": 640, "w": 200, "h": 80},
			{"x": 1850, "y": 640, "w": 520, "h": 80},
		],
		"moving_platforms": [],
		"hazards": [
			{"x": 1400, "y": 700, "w": 500, "h": 16},
		],
		"crumbling_platforms": [
			{"x": 1450, "y": 640, "w": 60, "h": 16, "shake": 0.4, "respawn": 3.5},
			{"x": 1580, "y": 625, "w": 50, "h": 16, "shake": 0.35, "respawn": 3.5},
			{"x": 1720, "y": 640, "w": 50, "h": 16, "shake": 0.3, "respawn": 3.5},
		],
		"goal": {"x": 2300, "y": 518, "w": 26, "h": 124},
		"hints": ["Land precisely — platforms get smaller.", "The crumbling ones won't wait. Keep moving!"],
		"torches": [],
	},
	# Room 7 — The Chimney
	{
		"name": "The Chimney",
		"width": 800, "height": 1400,
		"spawn": Vector2(400, 1260),
		"fall_respawn_y": 1500,
		"solids": [
			{"x": 0, "y": 1320, "w": 800, "h": 80},
			{"x": 335, "y": 920, "w": 30, "h": 400},
			{"x": 335, "y": 620, "w": 30, "h": 200},
			{"x": 335, "y": 320, "w": 30, "h": 200},
			{"x": 495, "y": 280, "w": 30, "h": 1040},
			{"x": 525, "y": 340, "w": 200, "h": 16},
		],
		"moving_platforms": [],
		"hazards": [
			{"x": 300, "y": 818, "w": 35, "h": 100},
			{"x": 300, "y": 518, "w": 35, "h": 100},
		],
		"crumbling_platforms": [],
		"goal": {"x": 612, "y": 216, "w": 26, "h": 124},
		"hints": ["Wall jump up — but the left wall has gaps!", "Double jump across gaps. Watch for thorns!"],
		"torches": [Vector2(250, 1320)],
	},
	# Room 8 — The Gauntlet
	{
		"name": "The Gauntlet",
		"width": 800, "height": 1400,
		"spawn": Vector2(150, 1260),
		"fall_respawn_y": 1500,
		"solids": [
			{"x": 0, "y": 1320, "w": 800, "h": 80},
			{"x": 370, "y": 1220, "w": 120, "h": 16},
			{"x": 300, "y": 280, "w": 30, "h": 940},
			{"x": 530, "y": 280, "w": 30, "h": 940},
			{"x": 560, "y": 340, "w": 200, "h": 16},
		],
		"moving_platforms": [
			{"start": Vector2(380, 1000), "end": Vector2(470, 1000), "width": 60, "height": 16, "speed": 30.0, "pause": 1.0},
			{"start": Vector2(380, 700), "end": Vector2(470, 700), "width": 60, "height": 16, "speed": 35.0, "pause": 0.8},
			{"start": Vector2(380, 450), "end": Vector2(470, 450), "width": 60, "height": 16, "speed": 40.0, "pause": 0.6},
		],
		"hazards": [
			{"x": 330, "y": 1300, "w": 200, "h": 16},
		],
		"crumbling_platforms": [],
		"goal": {"x": 650, "y": 216, "w": 26, "h": 124},
		"hints": ["Walls are too far apart for a normal wall jump.", "Wall jump → DASH → cling! Moving ledges offer brief rest."],
		"torches": [],
	},
	# Room 9 — Cascade
	{
		"name": "Cascade",
		"width": 2400, "height": 1200,
		"spawn": Vector2(100, 160),
		"fall_respawn_y": 1400,
		"checkpoint": Vector2(960, 750),
		"solids": [
			{"x": 0, "y": 220, "w": 200, "h": 16},
			{"x": 380, "y": 320, "w": 120, "h": 16},
			{"x": 150, "y": 460, "w": 120, "h": 16},
			{"x": 370, "y": 460, "w": 30, "h": 200},
			{"x": 530, "y": 500, "w": 30, "h": 200},
			{"x": 580, "y": 700, "w": 140, "h": 16},
			{"x": 920, "y": 750, "w": 120, "h": 16},
			{"x": 1100, "y": 750, "w": 30, "h": 200},
			{"x": 1260, "y": 800, "w": 30, "h": 200},
			{"x": 1350, "y": 1000, "w": 160, "h": 16},
			{"x": 1750, "y": 1050, "w": 620, "h": 80},
		],
		"moving_platforms": [
			{"start": Vector2(1520, 1000), "end": Vector2(1650, 1050), "width": 80, "height": 16, "speed": 45.0, "pause": 0.4},
		],
		"hazards": [],
		"crumbling_platforms": [],
		"goal": {"x": 2300, "y": 928, "w": 26, "h": 124},
		"hints": ["Flow downward — use everything you know.", "A checkpoint awaits mid-descent. Keep moving!"],
		"torches": [Vector2(60, 220), Vector2(660, 700), Vector2(1850, 1050)],
	},
	# Room 10 — Switchback
	{
		"name": "Switchback",
		"width": 1200, "height": 1000,
		"spawn": Vector2(100, 860),
		"fall_respawn_y": 1100,
		"solids": [
			{"x": 0, "y": 920, "w": 200, "h": 80},
			{"x": 350, "y": 860, "w": 120, "h": 16},
			{"x": 580, "y": 700, "w": 30, "h": 200},
			{"x": 640, "y": 660, "w": 100, "h": 16},
			{"x": 860, "y": 500, "w": 30, "h": 200},
			{"x": 900, "y": 440, "w": 120, "h": 16},
			{"x": 1150, "y": 280, "w": 30, "h": 200},
			{"x": 700, "y": 320, "w": 400, "h": 80},
		],
		"moving_platforms": [],
		"hazards": [
			{"x": 300, "y": 910, "w": 400, "h": 16},
		],
		"crumbling_platforms": [
			{"x": 420, "y": 730, "w": 120, "h": 16, "shake": 0.5, "respawn": 4.0},
			{"x": 700, "y": 530, "w": 120, "h": 16, "shake": 0.45, "respawn": 4.0},
		],
		"goal": {"x": 900, "y": 198, "w": 26, "h": 124},
		"hints": ["Keep changing direction! Ledges crumble behind you.", "Jump right → wall jump left → dash right → commit!"],
		"torches": [Vector2(80, 920), Vector2(850, 320)],
	},
	# Room 11 — No Floor
	{
		"name": "No Floor",
		"width": 3200, "height": 1000,
		"spawn": Vector2(100, 610),
		"fall_respawn_y": 1100,
		"checkpoint": Vector2(1700, 480),
		"solids": [
			{"x": 0, "y": 670, "w": 200, "h": 16},
			{"x": 400, "y": 450, "w": 30, "h": 250},
			{"x": 600, "y": 520, "w": 80, "h": 16},
			{"x": 850, "y": 370, "w": 30, "h": 250},
			{"x": 1050, "y": 440, "w": 60, "h": 16},
			{"x": 1300, "y": 320, "w": 30, "h": 300},
			{"x": 1500, "y": 500, "w": 180, "h": 16},
			{"x": 1900, "y": 350, "w": 30, "h": 250},
			{"x": 2150, "y": 450, "w": 60, "h": 16},
			{"x": 2400, "y": 300, "w": 30, "h": 300},
			{"x": 2650, "y": 500, "w": 320, "h": 80},
		],
		"moving_platforms": [
			{"start": Vector2(1700, 480), "end": Vector2(1870, 400), "width": 70, "height": 16, "speed": 55.0, "pause": 0.5},
			{"start": Vector2(2200, 420), "end": Vector2(2350, 350), "width": 60, "height": 16, "speed": 60.0, "pause": 0.4},
			{"start": Vector2(2500, 350), "end": Vector2(2500, 500), "width": 80, "height": 16, "speed": 40.0, "pause": 0.6},
		],
		"hazards": [
			{"x": 200, "y": 900, "w": 2400, "h": 16},
			{"x": 1680, "y": 600, "w": 200, "h": 16},
		],
		"crumbling_platforms": [],
		"goal": {"x": 2900, "y": 378, "w": 26, "h": 124},
		"hints": ["Everything you've learned — in one run.", "No ground. Chain wall jumps, double jumps, dashes."],
		"torches": [Vector2(80, 670), Vector2(1580, 500), Vector2(2750, 500)],
	},
]
