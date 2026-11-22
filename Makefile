# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# NOTE: make_assets.bat needs Python 2.7 at C:\Dev\Python27\python.exe, which
# is not on this machine, so the build currently stops at the assets step.
.PHONY: all build help
all: build

build:
	cmd /c .\make.bat

help:
	@echo make        - build !Tipsy (runs make.bat; also copies !Tipsy to ..\arculator\hostfs)
	@echo make help   - this list
	@echo Blocked: make_assets.bat needs Python 2.7 (C:\Dev\Python27), not installed. See START_HERE.md
