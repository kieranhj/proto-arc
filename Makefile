# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# make_assets.bat runs the asset scripts with Python 3 (py -3; ported 2026-11-22).
.PHONY: all build help
all: build

build:
	cmd /c .\make.bat

help:
	@echo make        - build !Tipsy (runs make.bat; also copies !Tipsy to ..\arculator\hostfs)
	@echo make help   - this list
	@echo See START_HERE.md
