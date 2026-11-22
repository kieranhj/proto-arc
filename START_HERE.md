# proto-arc: start here

Acorn Archimedes effect prototypes in ARM assembler (vasm): textured tunnel, cubes, rotate and
scale, lighting experiments, each on its own branch. A scratch/prototype repo.

| | |
|---|---|
| GitHub | https://github.com/kieranhj/proto-arc (public) |
| Local path | D:\archie\mine\proto-arc (moved from OneDrive\Archie\Repos\proto-arc on 2026-11-22) |
| Branch | wip/png-uv-maps; others: master, fixed-point-maths, stacked-plot, textured-tunnel, wip/compress-exe-fail, wip/cube-plus-rasterman, wip/dither-lighting, wip/rasterman-lighting, wip/rotate-and-scale, wip/unrolled-tunnel |
| Last commit | 2024-12-18: Add option to use RGB pngs as UV maps. |

## What's in here
- `proto-arc.asm`: top-level source; `lib\`: effect code; `data\`: tables, textures, music.
- `folder\`: files copied into the `!Proto` app; `make.bat`: the build.
- `bin\`: vasm, lz4, and Python 2 helpers (`tunnel_texture.py`, `png2arc.py`, `xor2arc.py`).
- `bin\vasmarm_std_win32.exe` is also the vasm that Nemesis's build.py uses.

## Build and run
- `make`: runs `make.bat` (works, 2026-11-22): assembles `build\proto-arc.bin`, builds `!Proto` and
  copies it to `..\arculator\hostfs\!Proto` (D:\archie\mine\arculator\hostfs).
- The first step, `C:\dev\Python27\python.exe bin\tunnel_texture.py ... -o data\tun2.bin`, fails
  ("path not found": no Python 2 on this machine) and is skipped; the committed `data\tun2.bin` is used.
- Run: in Arculator, double-click `!Proto` in the HostFS filer.

## Local changes
- Working tree clean; no stashes. Every branch tracks an origin branch, but two have one
  **unpushed** commit each: stacked-plot (4cacbb0, 2022-08-15 "Update Arculator version.") and
  wip/cube-plus-rasterman (53ad7d0, 2022-12-27 "Move camera back and increase cube scale.").

## Status and next steps
- Most recent line of work (2024-12): unrolled tunnel, rotate and scale (U:V packing), then
  RGB PNGs as UV maps on wip/png-uv-maps. 2022-12 branches: cube plus RasterMan, dither and
  RasterMan lighting, a failed exe-compression attempt. No TODO or plan notes found.

## See also
- README.md (one line), D:\archie\mine\rasterman-vasm.
