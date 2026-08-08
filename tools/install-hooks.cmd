@echo off
REM Installs Valuate's git hooks. Double-click this file, or run it from a terminal.
REM
REM .git/hooks is not version-controlled, so the hook lives in tools/hooks/ and is
REM copied into place. That means it has to be installed once per clone - which is
REM what this is for.

setlocal
cd /d "%~dp0.."

if not exist ".git\hooks" (
    echo Not a git repository ^(no .git\hooks folder here^).
    echo Run this from inside the Valuate working copy.
    pause
    exit /b 1
)

copy /y "tools\hooks\pre-commit" ".git\hooks\pre-commit" >nul
if errorlevel 1 (
    echo Failed to copy the hook.
    pause
    exit /b 1
)

echo Installed: .git\hooks\pre-commit
echo.
echo Every commit will now run the gates first ^(about 1.3 seconds^).
echo Bypass in an emergency with: git commit --no-verify
echo.

REM Prove it works now rather than at the next commit, when it would be a surprise.
where node >nul 2>&1
if errorlevel 1 (
    echo WARNING: node is not on PATH, so the hook will BLOCK commits until it is.
) else (
    echo Running the gates once to check:
    echo.
    node tools\gates.js
)

echo.
pause
