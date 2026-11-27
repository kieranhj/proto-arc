# tipsy-cube: start here

Tipsy Cube, an Acorn Archimedes intro (ARM, vasm) by Bitshifters & Slipstream, released for the FieldFX 2022 New Year's demostream. Finished demo; needs 2 MB and an ARM250.

| | |
|---|---|
| GitHub | https://github.com/bitshifters/tipsy-cube (public; GitHub fork of kieranhj/proto-arc) |
| Upstream | `upstream` remote = https://github.com/kieranhj/proto-arc (the framework it grew from) |
| Local path | D:\bitshifters\tipsy-cube (moved from OneDrive\Archie\Repos\tipsy-cube in the 2026-11 tidy) |
| Branch | master (only local branch) |
| Last commit | 2023-01-01: Update readmes. |

## What's in here
- `tipsy-cube.asm`: the demo; `lib\loader.asm`: the !RunImage loader; `link_script.txt`: vlink script.
- `bin\`: the tools, checked in (vasmarm_std_win32, vlink, Shrinkler, lz4, plus Python asset scripts png2arc*.py, sine_table.py, ported from Python 2 to Python 3 on 2026-11-22).
- `data\`: graphics and music source; `folder\`: the !Tipsy app's static files.
- `build\` and `!Tipsy\` are build output (gitignored).

## Build and run
- `make`: runs `make.bat` (Makefile added 2026-11-22). Works (2026-11-22): `make.bat` first empties `build\`, then `make_assets.bat` runs the asset scripts with `py -3` (`set PYTHON=py -3`). The scripts were ported to Python 3 on 2026-11-22. A clean build reproduces the 2023 `build\` byte for byte, including `tipsy-cube.shri`.
- Rest of the chain: vasm -> `build\tipsy-cube.o`, vlink -> `build\tipsy-cube.bin`, Shrinkler -> `build\tipsy-cube.shri`, then `!Tipsy\` is assembled and copied to `..\arculator\hostfs\Builds\!Tipsy` (= D:\archie\mine\arculator\hostfs\Builds).
- Run: Arculator v2.1+, emulate an A3010, sound filter "more reduced" (README). Real hardware: RISC OS 2 or 3.1.
- `make help` lists the targets.

## Local changes
- Working tree clean.
- Remote snapshot branches on `upstream` (kieranhj/proto-arc), seen locally as `upstream/wip/*`: compress-exe-fail (2022-12-30), cube-plus-rasterman (2022-12-23), dither-lighting (2022-12-21), rasterman-lighting (2022-12-30), png-uv-maps (2024-12-18), rotate-and-scale (2024-12-17), unrolled-tunnel (2024-12-11). The 2024 ones are later experiments on the proto-arc framework, not this intro.

## Status and next steps
- Released; no TODO/plan notes found.
- Builds again since the Python 3 port (2026-11-22).

## See also
- README.md; https://bitshifters.github.io for the release.
- Related: D:\archie\mine\arculator (hostfs target), kieranhj/arc-shrinkler (Shrinkler port).
