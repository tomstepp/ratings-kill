# Level files

Each level is a plain text file: a header, a `---` line, then the map. One character is one 16×16 tile.
Rex is 2 tiles tall, jumps about 3 tiles high and 4 tiles across.

## Header

```
name: Platform Zero            # shown in the break room and the wrap-up line
music: music_level2            # optional; a track in assets/audio (default music_level)
intro: showrunner|Hello!       # dialogue at level start (speaker: showrunner, boom or rex)
hint: boom|Psst.               # one per T in the map, in reading order (left-to-right, top-to-bottom)
; comment lines start with a semicolon
```

## Legend

| Char | Meaning |
|---|---|
| `#` | Brick wall (solid) |
| `=` | Concrete floor (solid; the top row gets the yellow safety stripe) |
| `-` | Grate: one-way platform (jump up through it, DOWN+JUMP to drop) |
| `F` | Fake wall: looks solid, walk straight through (hide secrets behind it) |
| `m` | Bridge tile, appears when a lever is pulled |
| `z` | Electrified rail (put it on top of a floor; cycles on and off) |
| `P` | Rex's start (exactly one) |
| `R` | Rat drone (patrols, stomp or shoot) |
| `r` | Fast red rat (quicker, 2 hits) |
| `L` | Lift, 2 tiles wide (rides up from here to just below the ceiling, then back) |
| `H` | Slider, 2 tiles wide (rides right from here until a wall, then back) |
| `M` | The Mascot (Floor 1 boss) |
| `e` | Where the exit appears once the boss is beaten |
| `S` | Spark bot (turret, 3 hits, don't stomp unless stunned) |
| `a` `b` `c` | Red, blue, yellow keycard |
| `A` `B` `C` | Red, blue, yellow door (bottom tile; leave the tile above empty) |
| `h` | Fizzo soda (+1 health) |
| `f` | Food (+2 health) |
| `u` | Firepower upgrade |
| `o` | Token ($50) |
| `x` | Breakable crate (random contents) |
| `?` | TV block with a token (bonk from below) |
| `*` | TV block with a firepower upgrade |
| `w` | Lever (UP to pull; extends every `m` bridge) |
| `$` | Secret zone (bonus money and ratings) |
| `T` | Showrunner hint trigger (uses the next `hint:` line) |
| `E` | Exit door (bottom tile) |
| `.` | Empty |

After editing, run `python3 tools/check_levels.py` to confirm every keycard, lever, secret and the exit can be reached.
Add new levels to `LEVELS` in `scripts/autoload/game_state.gd`.
