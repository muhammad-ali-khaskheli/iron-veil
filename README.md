# IRON VEIL — Operation: Night Breach

A story-driven mobile first-person shooter built with **Godot 4.3** (Mobile renderer).

## Get the APK

1. Push this project to a GitHub repo (branch `main`).
2. Open the repo's **Actions** tab and wait for **Build Android APK** to finish (about 5-10 minutes).
3. Download the APK from the **Releases** page (or the `IronVeil-apk` artifact on the workflow run).
4. Copy it to your phone and install it (allow "install unknown apps" when asked).

You can also trigger a build manually: Actions -> Build Android APK -> Run workflow.

## What's in the game

- Cinematic briefing and debrief with a voiced-in-text story (Specter, Colonel Hale, Raven)
- Night-time compound with fog, bloom, moonlight shadows, lamps and lit windows
- 3 weapons: M4-X rifle, VX-12 shotgun, P9 pistol (aim, reload, swap)
- Enemy soldiers with line of sight, strafing, obstacle sliding and escalating waves
- Two combat waves, then run to extraction
- Touch controls: floating move stick, drag-to-look, fire / aim / jump / reload / swap buttons
- Procedural gunshots and a dark ambient score (no external assets needed)

## Controls

Touch: left side = move, right side = look, buttons bottom-right.
Desktop (for testing in the Godot editor): WASD, mouse, left click fire, right click aim, R reload, Q swap, Space jump, Esc release mouse.

## Run locally

Open the folder in Godot 4.3+, press F5.

## Next steps (ideas)

- Mission 2 (Port Sarnak), more enemy types, grenades, killstreaks
- Real art: import CC0 character/weapon models and PBR textures
- Voice acting and a licensed music track
- Settings menu (sensitivity, graphics quality)
