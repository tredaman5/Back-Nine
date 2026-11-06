# Back Nine: Project Rules for Claude

3D arcade golf game with boss matches and a story. CSCE 552 (USC). Solo developer: Tre' Smith (Smith Games).
The approved GDD (`Back_Nine_GDD_Smith_Games.docx`, v1.0, Oct 30 2026) is the source of truth. **Ask before going against it.**

## Hard rules
1. **NEVER run `git commit`, `git push`, or anything else that changes git history or a remote** (no rebase, merge, reset, tag, amend, `git lfs push`, etc.). When work is ready, give Tre' the exact commands to run with a suggested commit message. Read-only git (`status`, `diff`, `log`) is fine.
2. **Engine: Godot 4.x, GDScript only.** No C#, no plugins unless approved. Installed: Godot 4.7.2 at `/Users/tredaman5/Downloads/Godot.app` (binary: `Contents/MacOS/Godot`). Re-check with `--version` before assuming.
3. Tre' is on a Mac.
4. **Work in small steps testable in the editor.** After each step, say exactly what to open and what to press to test it.
5. **GDScript style:** static typing everywhere, signals for cross-object communication, and the node/component/signal names below so code matches the GDD.

## Game summary
- Story: Dez Carter (19, caddie) plays three boss matches to save Pine Hollow from the Ashworth Club. Bo (best friend, caddie) is comic relief.
- 3 matches x 3 holes:
  - Rex at Pine Hollow: `TauntRule` (taunts add +15 Pressure)
  - Marigold at Thornbrook: `HedgeGrowthRule` (hedges grow where buds appeared one shot earlier)
  - Sterling at Ashworth Links: `WindControlRule` (wind changes, mid-flight gusts)
- Boss rules affect only Dez; every rule is telegraphed one shot ahead.
- Scoring: holes 1-2 = 1 point, hole 3 = 2. Farther from hole hits next. Tie -> closest-to-the-pin playoff from hole 3's tee.
- Controls: mouse/left stick aims a dashed aim line. Q/E clubs: Driver 250 yd, 7 Iron 160 yd, Wedge 90 yd, Putter. 1-4 shot shape: Straight/Draw/Fade, High Lob (after Match01), Stinger (half wind, after Match02). Shift = green read (3/hole). F = Clutch Shot at 100 Focus (wide window, slow-mo). C = Caddie Call (1/hole, Bo right ~80%). Esc = pause.
- Swing: drag back to set power (0-100%), release inside the green accuracy window. A miss adds hook/slice on top of the shape.
- Pressure (0-100): +20 lost hole, +15 taunt, -10 good shot. Above 70, accuracy window shrinks 40%.
- Focus (0-100, cap 100): +25 fairway hit, +25 green in regulation, +50 putt holed from >15 ft. Clutch Shot spends all. Carries between holes, resets each match.
- Lies: rough -20% power, sand -40%. OOB/water = +1 stroke and replace ball. 8 strokes concedes the hole.

## Architecture (GDD names)
- Prefabs (.tscn): player, ball, opponent, hole_*, hedge, wind_system, match_manager, hud, camera_rig
- Autoloads: `GameState`, `AudioManager`
- Components:
  - Player: `PlayerInput`, `ShotAim`, `SwingController`, `GreenReader`, `CaddieCall`
  - Ball: `BallPhysics`, `SurfaceDetector`
  - Hole: `CupDetector`, `OOBDetector`
  - Match: `MatchManager`, `MatchScorer`, `PressureFocus`
  - Opponent: `OpponentAI`, `BossRule` (base) -> `TauntRule` / `HedgeGrowthRule` / `WindControlRule`
  - Other: `HedgeGrowth`, `WindSystem`, `HUDController`, `PauseGame`, `CameraRig`, `DialogueRunner`
- Ball: `RigidBody3D`, continuous collision detection ON; `BallPhysics` adds drag, spin, wind.
- Hedge: `AnimatableBody3D` (not StaticBody3D).
- Signals: `turn_started`, `ball_landed(surface)`, `ball_holed`, `out_of_bounds`, `score_changed`, `shot_taken`, `hole_finished`, `match_finished`, `rule_telegraphed`, `wind_changed`, `pressure_changed`, `focus_changed`, `caddie_call_used`, `chapter_finished`
- Assets: Kenney/Quaternius CC0 models, Freesound SFX. Use primitive placeholder meshes until real art exists.

## Folder layout
`scenes/`, `scripts/`, `assets/`, `docs/`

## Licensing
Code: MIT (c) Tre' Smith. Art, audio, story, characters: (c) Tre' Smith, all rights reserved.

## Schedule
Week01 (Nov 2-6): Ball prefab, PlayerInput, ShotAim, SwingController, CameraRig, graybox Hole 1. Week02: Hole prefab, MatchManager, MatchScorer, OpponentAI, HUD, GreenReader. Week03 (Nov 20): proof of concept. Final release Dec 11.
