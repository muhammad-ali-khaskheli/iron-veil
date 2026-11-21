class_name Missions
## Story and scripted set-pieces for each mission. Read by main.gd's beat engine.
## Beat types: talk, goto, kill, zone (hold position), event.

const COUNT := 3


static func sp(p: Vector3, n: int = 1, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"p": p, "n": n}
	d.merge(extra)
	return d


static func get_mission(lvl: int) -> Dictionary:
	match lvl:
		2:
			return _port()
		3:
			return _relay()
		_:
			return _breach()


# ---------------------------------------------------------------- shared stealth + gate beats

static func _stealth_beats(guards: Array, hint: String) -> Array:
	return [
		{"type": "goto", "pos": Vector3(0, 0, 48.5), "r": 3.0, "obj": "Creep toward the compound wall",
		 "lines": [["Raven", hint, 5.5]]},
		{"type": "kill", "obj": "Take out the gate guards quietly", "spawns": guards,
		 "lines": [["Col. Hale", "Switch to the suppressed P9 pistol, Specter. Crouch, stay low, and take them one at a time. A rifle shot will wake the whole compound.", 6.5]]},
		{"type": "zone", "pos": Vector3(0, 0, 35.5), "r": 3.5, "secs": 5.0, "label": "PLANTING BREACH CHARGE",
		 "obj": "Plant the breach charge on the gate", "device": "charge", "explode": true, "remove": "Gate",
		 "boom": Vector3(0, 0, 33),
		 "lines": [["Raven", "Charge goes on the gate. Stay clear of the blast, then get ready for company.", 4.5]]},
	]


# ---------------------------------------------------------------- mission 1

static func _breach() -> Dictionary:
	var guards: Array = [
		sp(Vector3(-14, 1, 40), 1, {"unaware": true, "patrol": [Vector3(-19, 0, 40), Vector3(-9, 0, 40)]}),
		sp(Vector3(14, 1, 38), 1, {"unaware": true, "patrol": [Vector3(19, 0, 38), Vector3(9, 0, 38)]}),
	]
	var beats: Array = _stealth_beats(guards,
		"Two sentries patrol outside the wall. They haven't seen us. Crouch and keep to the shadows, they'll spot you at half the range.")
	beats.append_array([
		{"type": "kill", "obj": "Clear the courtyard", "spawns": [
			sp(Vector3(-17, 1, 26), 2), sp(Vector3(16, 1, 24), 2), sp(Vector3(0, 1, 12), 2),
			sp(Vector3(-25, 9.2, 22), 1, {"hold": true}), sp(Vector3(26, 8.2, 18), 1, {"hold": true})],
		 "lines": [["Raven", "Gate's down and the yard just lit up! Two shooters on the rooftops. Use the crates, duck behind cover and pop up to shoot.", 6.0]]},
		{"type": "goto", "pos": Vector3(0, 0, -12), "r": 5.0, "obj": "Push north to the depot",
		 "lines": [["Raven", "Yard's clear. Move up to the depot. Keep to cover.", 3.5]],
		 "ambush": {"dist": 30.0, "spawns": [sp(Vector3(-18, 1, -4), 2), sp(Vector3(18, 1, -6), 2)],
		 "line": ["Raven", "Movement on both flanks! They're coming out of the buildings!", 3.5]}},
		{"type": "zone", "pos": Vector3(0, 0, -17), "r": 3.5, "secs": 12.0, "label": "DOWNLOADING TRANSFER LOG",
		 "obj": "Hold the terminal while the log downloads", "device": "terminal",
		 "lines": [["Col. Hale", "That terminal holds the Veil-7 transfer log. Plug in and hold the position, Specter. Don't let them cut you off.", 5.5]],
		 "waves": [
			{"t": 3.0, "spawns": [sp(Vector3(-14, 1, -28), 2), sp(Vector3(14, 1, -30), 2)],
			 "line": ["Raven", "Reinforcements from the north! Stay on the terminal!", 3.0]},
			{"t": 8.0, "spawns": [sp(Vector3(-16, 1, 4), 2), sp(Vector3(16, 1, 2), 2)],
			 "line": ["Raven", "More behind you! Almost there, Specter!", 3.0]}],
		 "clear": true},
		{"type": "talk", "lines": [["Col. Hale", "Log's secured. Excellent work. Extraction is inbound. Get to the pad.", 4.5]]},
		{"type": "event", "name": "heli"},
		{"type": "goto", "pos": Vector3(0, 0, -46), "r": 4.5, "obj": "Reach the extraction pad",
		 "ambush": {"dist": 32.0, "spawns": [sp(Vector3(-12, 1, -40), 2), sp(Vector3(12, 1, -42), 2)],
		 "line": ["Raven", "Last guards at the pad! Break through!", 3.0]}},
	])
	return {
		"title": "NIGHT BREACH", "sub": "Black Meridian compound  |  02:14 local",
		"intro": [
			["Col. Hale", "Specter, this is Hale. Black Meridian is moving a prototype weapon through that compound. Codename Veil-7. It ships at dawn.", 5.5],
			["Raven", "I'm on the ridge with eyes on the courtyard. A dozen hostiles, maybe more. Lights are on and they're jumpy.", 5.0],
			["Col. Hale", "Breach the gate, take the transfer log from the depot, and reach the pad. Nobody can know we were ever there.", 5.0],
		],
		"beats": beats,
		"outro": [
			["Raven", "Specter... don't get on that bird. Do you hear me? Don't board.", 4.5],
			["Col. Hale", "Well done, Specter. The transfer log names the man who bought Veil-7. A pity it names me.", 5.5],
			["Raven", "Hale sold it. All of it. Stay in the shadows, I'm coming down for you.", 5.0],
		],
		"end_title": "MISSION COMPLETE", "end_text": "The log is in your hands. Hale has turned on you.\nNext: Port Sarnak.",
	}


# ---------------------------------------------------------------- mission 2

static func _port() -> Dictionary:
	var guards: Array = [
		sp(Vector3(-14, 1, 40), 1, {"unaware": true, "patrol": [Vector3(-19, 0, 40), Vector3(-9, 0, 40)]}),
		sp(Vector3(14, 1, 38), 1, {"unaware": true, "patrol": [Vector3(19, 0, 38), Vector3(9, 0, 38)]}),
		sp(Vector3(25, 1, 43), 1, {"unaware": true, "patrol": [Vector3(20, 0, 43), Vector3(30, 0, 43)]}),
	]
	var beats: Array = _stealth_beats(guards,
		"Volk's dock guards are on the fence line. Stay low, use the suppressed pistol and keep out of their sight.")
	beats.append_array([
		{"type": "kill", "obj": "Fight through the container yard", "spawns": [
			sp(Vector3(-12, 1, 22), 2), sp(Vector3(8, 1, 24), 2), sp(Vector3(0, 1, 10), 2), sp(Vector3(12, 1, 6), 1)],
		 "lines": [["Raven", "Volk's crew is dug in between the containers. Use the cover, Specter. Duck, then pop up and fire.", 5.0]]},
		{"type": "zone", "pos": Vector3(16, 0, 26), "r": 3.5, "secs": 9.0, "label": "ARMING FUEL CHARGES",
		 "obj": "Arm the charges on Volk's fuel stock", "device": "charge",
		 "lines": [["Raven", "Volk's fuel stock is stacked right there. Set the charges and I'll cover your back.", 4.5]],
		 "waves": [
			{"t": 2.0, "spawns": [sp(Vector3(-10, 1, 14), 2), sp(Vector3(6, 1, 6), 2)],
			 "line": ["Volk", "Kill him! Nobody burns my port!", 3.0]},
			{"t": 6.0, "spawns": [sp(Vector3(-14, 1, 4), 2), sp(Vector3(10, 1, -2), 2)],
			 "line": ["Raven", "They're flooding in! Hold on!", 3.0]}],
		 "clear": true, "explode": false},
		{"type": "talk", "lines": [["Raven", "Charges armed! You've got ninety seconds, Specter. Get to the far pier before it all goes up!", 5.0]]},
		{"type": "goto", "pos": Vector3(0, 0, -14), "r": 5.0, "time": 45.0, "obj": "RUN! Reach the mid-yard before the fuel blows",
		 "ambush": {"dist": 30.0, "spawns": [sp(Vector3(-12, 1, 6), 2), sp(Vector3(10, 1, -4), 2)],
		 "line": ["Raven", "Guards in your way! Push through, don't stop!", 3.0]}},
		{"type": "event", "name": "explode", "pos": Vector3(16, 0, 26)},
		{"type": "goto", "pos": Vector3(0, 0, -46), "r": 4.5, "time": 40.0, "obj": "RUN! Reach the far pier",
		 "ambush": {"dist": 28.0, "spawns": [sp(Vector3(-12, 1, -30), 2), sp(Vector3(12, 1, -34), 2), sp(Vector3(0, 1, -40), 1)],
		 "line": ["Volk", "He's heading for the pier! Cut him off!", 3.0]}},
	])
	return {
		"title": "PORT SARNAK", "sub": "Container yard  |  05:40 local",
		"intro": [
			["Raven", "Hale has gone dark, but his money hasn't. Everything moved through Port Sarnak. The yard belongs to his fixer, Dmitri Volk.", 6.0],
			["Raven", "No more orders from command, Specter. Just you and me. Burn his fuel stock and take the manifest to the far pier.", 5.5],
		],
		"beats": beats,
		"outro": [
			["Raven", "The manifest shows Veil-7 going to the Frozen Relay, up in the mountains. Hale is arming it there.", 5.5],
			["Raven", "Tomorrow he sells it to the highest bidder. We hit him at first light.", 4.5],
		],
		"end_title": "MISSION COMPLETE", "end_text": "Volk's network is burning.\nNext: Frozen Relay.",
	}


# ---------------------------------------------------------------- mission 3

static func _relay() -> Dictionary:
	var guards: Array = [
		sp(Vector3(-14, 1, 40), 1, {"unaware": true, "patrol": [Vector3(-19, 0, 40), Vector3(-9, 0, 40)]}),
		sp(Vector3(14, 1, 38), 1, {"unaware": true, "patrol": [Vector3(19, 0, 38), Vector3(9, 0, 38)]}),
		sp(Vector3(25, 1, 43), 1, {"unaware": true, "patrol": [Vector3(20, 0, 43), Vector3(30, 0, 43)]}),
	]
	var beats: Array = _stealth_beats(guards,
		"Hale's private guard holds the gate. Snow carries sound, so use the suppressed pistol and stay low.")
	beats.append_array([
		{"type": "kill", "obj": "Secure the lower perimeter", "spawns": [
			sp(Vector3(-17, 1, 26), 2), sp(Vector3(16, 1, 22), 2), sp(Vector3(0, 1, 10), 1),
			sp(Vector3(-28, 5.6, 14), 1, {"hold": true}), sp(Vector3(28, 5.6, 8), 1, {"hold": true})],
		 "lines": [["Raven", "Guards in the treeline and snipers on the bunkers. Move between cover and keep your head down.", 5.0]]},
		{"type": "goto", "pos": Vector3(0, 0, -12), "r": 5.0, "obj": "Advance to the signal jammer",
		 "lines": [["Raven", "That jammer is blocking my link to you. Take it out and I can see the whole station.", 4.5]],
		 "ambush": {"dist": 30.0, "spawns": [sp(Vector3(-18, 1, -6), 2), sp(Vector3(18, 1, -8), 2)],
		 "line": ["Raven", "Flankers in the snow! Left and right!", 3.0]}},
		{"type": "zone", "pos": Vector3(0, 0, -24), "r": 3.5, "secs": 12.0, "label": "DISABLING JAMMER",
		 "obj": "Hold position and disable the jammer", "device": "terminal",
		 "waves": [
			{"t": 3.0, "spawns": [sp(Vector3(-16, 1, -34), 2), sp(Vector3(16, 1, -36), 2)],
			 "line": ["Raven", "Hale's elite team! Don't let them past you!", 3.0]},
			{"t": 8.0, "spawns": [sp(Vector3(-14, 1, 0), 2), sp(Vector3(14, 1, -2), 2)],
			 "line": ["Raven", "Another group behind you!", 3.0]}],
		 "clear": true},
		{"type": "talk", "lines": [["Raven", "Jammer's dead, I've got you. Hale is in the relay building at the end of the road. Be careful, Specter.", 5.0]]},
		{"type": "goto", "pos": Vector3(0, 0, -38), "r": 5.0, "obj": "Approach the relay core",
		 "ambush": {"dist": 18.0, "spawns": [sp(Vector3(-12, 1, -44), 2), sp(Vector3(12, 1, -44), 2)],
		 "line": ["Col. Hale", "Specter. I told you not to come looking. Kill him!", 4.0]}},
		{"type": "kill", "obj": "Take down Colonel Hale", "boss": Vector3(0, 1, -50), "spawns": [
			sp(Vector3(-14, 1, -34), 2), sp(Vector3(14, 1, -34), 2)],
		 "lines": [["Col. Hale", "You should have stayed dead, Specter. I built you. I can end you.", 5.0]]},
	])
	return {
		"title": "FROZEN RELAY", "sub": "Mountain station  |  06:50 local",
		"intro": [
			["Raven", "The relay station is the only place Veil-7 can be broadcast from. Hale's private guard holds the whole mountain.", 5.5],
			["Raven", "Whatever happens up there, finish it, Specter. For everyone Veil-7 would have hurt.", 4.5],
		],
		"beats": beats,
		"outro": [
			["Col. Hale", "Veil-7... was always going to... outlive us all.", 4.0],
			["Raven", "It's over. Veil-7 is destroyed, and so is Hale's network. Come home, Specter.", 5.0],
		],
		"end_title": "CAMPAIGN COMPLETE", "end_text": "Hale is down and Veil-7 is gone.\nThanks for playing Iron Veil.",
	}
