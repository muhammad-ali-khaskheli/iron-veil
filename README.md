# IRON VEIL — Operation: Night Breach

A story-driven mobile first-person shooter built with **Godot 4.3** (Mobile renderer).

## Get the APK

1. Push this project to a GitHub repo (branch `main`).
2. Open the repo's **Actions** tab and wait for **Build Android APK** to finish (about 5-10 minutes).
3. Download the APK from the **Releases** page (or the `IronVeil-apk` artifact on the workflow run).
4. Copy it to your phone and install it (allow "install unknown apps" when asked).

You can also trigger a build manually: Actions -> Build Android APK -> Run workflow.

## What's in the game

- Three story missions, each a chain of set-pieces: sneak past guards, breach the gate, firefights, hold a terminal while it downloads, timed runs, a boss fight
- Checkpoints after every objective
- Cover system: crouch behind low cover to hide from enemy fire, then hold fire or aim to pop up and shoot
- Stealth: crouch to halve how far guards can spot you; the suppressed P9 pistol silently kills unaware guards
- Real CC0 gun models and prop models (trucks, containers, barrels, pines, rocks), plus explosions, dust and blood effects with camera shake
- 3 weapons: M4-X rifle, VX-12 shotgun, P9 suppressed pistol (aim, reload, swap)
- Pick any mission from the main menu
- Beginner-friendly enemies: slow to react, modest accuracy, regenerating health
- Procedural gunshots and ambient score

## Controls

Touch: left side = move, right side = look, buttons bottom-right (CROUCH is the bottom-left of the button cluster).
Desktop (for testing in the Godot editor): WASD, mouse, left click fire, right click aim, R reload, Q swap, C crouch, Space jump, Esc release mouse.

## Run locally

Open the folder in Godot 4.3+, press F5.

## Next steps (ideas)

- More enemy types, grenades, killstreaks, difficulty setting
- Real art: import CC0 character/weapon models and PBR textures
- Voice acting and a licensed music track
- Settings menu (sensitivity, graphics quality)

## Credits

Gun models by Quaternius, environment models by Kenney and Quaternius (all CC0). The build runs an automated self-test of all three missions in GitHub Actions on every push.
