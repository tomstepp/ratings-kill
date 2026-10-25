# Super Rex Live!

A Duke Nukem (1991)-style run-and-gun platformer. Rex Halloway, a former mattress-commercial star, fights his way down
the Tower Below while the Galactic Content Syndicate broadcasts it live. Stylish play fills the ratings meter, a full
meter buys sponsor drops and multiplies every dollar you earn, and a bored audience makes the Showrunner "spice
things up".

Design doc: [design/GAME_DESIGN.txt](design/GAME_DESIGN.txt). The game was called *Ratings Kill* until launch prep; the doc and this repo's folder still use
that name.

## Status

Season 1 is playable start to finish: 4 floors, each 3 levels and a boss (16 episodes), with a title card before every
episode.

| Floor | Set | Levels | New on this floor | Boss |
|---|---|---|---|---|
| 1 | Abandoned subway | Platform Zero, Maintenance Shaft, The Depot | Rat drones, spark-bot turrets, live rails, lifts | Mister Cheddar, the Mascot |
| 2 | Mall after hours | Fountain Plaza, Department Store, Parking Garage | Security bots, mannequins that move when you look away, conveyor belts | The Floor Manager |
| 3 | Studio backlot | Soundstage 9, Western Town Set, Sci-Fi Set | Boom-mic drones, camera-crane platforms, spotlight cues | The Director |
| 4 | Network HQ | Lobby and Security, Server Farm, The Executive Floor | Exec drones that aim, laser gates | The Season Finale |

- **Feel**: momentum running, variable jump height, coyote time, jump buffering, stacking blaster shots (holding fire gives a 3-shot burst; hits on
  enemies refill it, so tap again to keep spraying), and corner
  correction (clip a ledge's corner with your head and you slide past it instead of losing the jump)
- **Levels**: keycards and locked doors, levers and bridges, lifts (they stop level with the ledge beside them),
  sliders, cranes, belts, live rails, laser gates, crates, TV blocks, secrets behind fake walls
- **Ratings**: the meter sets a cash multiplier (x1 to x4) on everything earned on air; each level ends with a ratings
  report (average, peak, grade S to D, network bonus); a full meter brings a sponsor drop; a low one brings boredom
  penalties; and from Floor 3 on, an empty meter for 6 seconds gets the episode canceled
- **Difficulty**: grunts take more hits floor by floor (+35% health per floor), rats lunge when Rex gets close,
  firepower upgrades fan out instead of stacking on one target, enemies get faster and shoot more often, the meter drains faster, shop prices rise, and
  Network HQ hits harder
- **Saving**: progress saves after every level; Continue on the title screen resumes in the break room
- **Tanya Voss**: the rival contestant drops in to race Rex to sponsor crates (and steals them if she gets there
  first; Boom's flash stuns her), and is waiting at the exit on one level per floor
- **How ratings work**: a cheat sheet in the pause menu; a "BORING!" nudge when the meter is low, and a red alarm
  with a countdown before a cancellation
- **Settings** (title screen and pause menu): music, sound and voice volume, narration, fullscreen, touch buttons
- **Touch controls**: on-screen d-pad, jump, shoot, flash and pause on phones and tablets (Settings can force them on
  or off); the web page asks phones to turn sideways
- **Show layer**: Showrunner and B0-0M dialogue (narrated), 20 achievements, the break-room shop, Boom's flash-stun,
  Rex's quips with QUIP COMBO bonuses
- Title screen, pause menu, end-of-floor and end-of-season cards, music per floor and per boss

Cut levels (*Rush Hour Ruins*, and the original *Express Line* and *Last Stop*, now
reworked for Floor 2) are kept in `levels/cut/`.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | Arrows / WASD | D-pad / left stick |
| Jump (hold for height) | Space / Z / K | A |
| Shoot | X / J | X |
| Doors, levers, exit | Up / W / E | D-pad up / B |
| Drop through grate | Down (or Down + Jump) | D-pad down |
| Boom's flash-stun | C / L | Y |
| Pause menu (resume, settings, how ratings work, controls, quit) | Esc / P | Start |
| Fullscreen | F | |
| Music on/off | M | |
| Narration on/off | N | |

## Running it

Requires [Godot 4.7](https://godotengine.org) (free). Installed here via `brew install --cask godot`.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Or open the folder in the Godot editor and press Play.

Dev shortcuts (arguments after `--`):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --level=7        # jump to an episode (0-15; every 4th is a boss)
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --room=test_room  # movement sandbox
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --screen=break   # break room with $2500
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --level=11 --firepower=4  # start with maxed firepower
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --level=1 --touch --tanya # touch buttons, Tanya race
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --test # automated mechanics checks
```

## Builds

Export templates for Godot 4.7.2 are needed once (Editor → Manage Export Templates, or the official `.tpz`).

```bash
sh tools/build_web.sh   # web build + website extras + itch.io zip
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" build/mac/SuperRexLive.zip
node tools/serve_web.mjs 8060   # then open http://localhost:8060
```

`build_web.sh` also copies the finished site into `docs/`, which GitHub Pages publishes at
[rex.tomstepp.com](https://rex.tomstepp.com) (Settings → Pages → branch `main`, folder `/docs`). Commit and push
`docs/` to update the live site.

The web page is `web/shell.html`: a start screen with a Play button (nothing downloads until it's pressed), a notice for
phones and tablets, link-preview tags for rex.tomstepp.com, and a link to `licenses.txt` (the Godot license and its
third-party notices, also shown in the in-game Credits). `web/title.png` and `web/og.png` come from
`tools/make_web_images.py`.

The web build is single-threaded, so it runs on any static host (itch.io, Netlify, GitHub Pages) without special
headers. For itch.io, upload `build/super-rex-live-web.zip` as an HTML game.

## How it's made

Everything is original and generated by code, so there's nothing to license:

- `tools/gen_art.py` draws every sprite, tile and the pixel font from one fixed 16-color palette
- `tools/gen_audio.py` synthesizes the sound effects and composes the chiptune tracks (per floor and per boss, about a
  minute each)
- Dialogue is read aloud by the system's built-in text-to-speech voices (`scripts/autoload/narrator.gd`)
- Levels are ASCII maps in `levels/` (see [levels/README.md](levels/README.md)); `tools/check_levels.py` proves each one
  can be finished

After changing art or audio, re-run the generator and then `Godot --headless --path . --import`.

```
scripts/
  autoload/   art, sfx, game_state, ratings, narrator, showrunner, touch (on-screen buttons)
  player/     rex (movement, quips), boom (drone), bolt
  enemies/    enemy base, rat_drone, spark_bot, security_bot, mannequin, mic_drone, exec_drone, enemy_bolt,
              boss base, mascot, floor_manager, director, finale, shockwave, confetti_bomb, clipboard
  pickups/    pickup, crate, tv_block, sponsor_crate
  world/      level (map loader + show events), door, exit_door, lever, mover (lifts, sliders, cranes), rail,
              laser_gate, trigger_zone (hints, secrets, spotlight cues), stage_light, tanya (the rival)
  ui/         hud (and pause menu), title_screen, level_card, break_room, end_card, credits, settings_menu
  dev/        dev_tools (screenshots, input bot), playtest (automated checks)
```
