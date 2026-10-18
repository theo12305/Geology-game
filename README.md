# Deep Strata (Geology-game)

An 8-bit 2D mining game for Android that teaches mineralogy and petrology. Dig down through the crust,
chip samples off mineral veins, test them like a field geologist (streak, hardness, acid, magnet, hand
lens, heft), name them, and craft better tools from what you identify.

![Mining a vein](docs/screenshot-mining.png)
![Field kit](docs/screenshot-field-kit.png)

## What is in this first build

- A procedural layered crust: soil, shale and limestone beds with caves, a hard quartz sandstone band,
  then a deeper dolostone basin.
- Mining by holding a finger (or the mouse) on a tile. Your pick's Mohs hardness decides what it can break.
- Mineral veins give unknown samples. The **Field Kit** runs real tests from `data/minerals.json` and
  keeps a notebook per sample. Pick the right name out of four to identify it.
- Wrong answers spend the sample, and that mineral turns up more often until you get it right.
- **Codex** with the full data for each mineral you have identified (30 minerals so far).
- **Craft**: a furnace (calcite flux and kaolinite fireclay), then a steel pick (iron oxides) that cuts the
  sandstone band and opens tier 2.
- Auto-save.

## Play it on your Android phone

### Option A: straight on the phone, no computer

1. Install **Godot Engine 4** (the editor) from the
   [Google Play Store](https://play.google.com/store/apps/details?id=org.godotengine.editor.v4).
2. On this GitHub page tap **Code > Download ZIP**, then unzip it in your phone's file manager.
3. Open the Godot app, choose **Import**, and select the `project.godot` file in the unzipped folder.
4. Press the **Play** button at the top right.

### Option B: build an installable app on a computer

1. Install [Godot 4.3 or newer](https://godotengine.org/download) and open this folder with it.
2. Follow [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
   once: install OpenJDK 17 and the Android SDK, then download export templates
   (**Editor > Manage Export Templates**).
3. Turn on USB debugging on the phone, plug it in, and click the Android icon at the top right of the
   editor. Godot installs and starts the game. **Project > Export** makes an APK file instead.

## Controls

| Phone | Computer | Action |
| --- | --- | --- |
| Left and right buttons | A / D or arrows | Walk |
| Up button | W, Space or Up | Jump |
| Hold on a tile | Hold left mouse button | Mine or collect a sample |

## Project layout

| Path | What it holds |
| --- | --- |
| `data/minerals.json`, `data/rocks.json` | All mineral and rock facts. Add a mineral here and the game picks it up. |
| `scripts/game_data.gd` | Loads the data and produces field test results. |
| `scripts/game_state.gd` | Samples, identification, spaced repetition, crafting, saving. |
| `scripts/world.gd` | World generation and tiles (painted in code for now). |
| `scripts/main.gd`, `player.gd`, `hud.gd` | Game loop, mining, the geologist, on-screen controls. |
| `scripts/field_kit.gd`, `codex.gd`, `craft.gd` | The three menus. |
| `tests/smoke_test.gd` | Automated check of data, world, identification, crafting and saving. |

Run the test with `godot --headless --path . res://tests/smoke_test.tscn` (exit code 0 means it passed).

## Roadmap

The full design and step-by-step plan is in the project's design document. Next up: rock samples and
textures, more minerals, the tier 2 boss, real pixel art, and the polarizing microscope.
