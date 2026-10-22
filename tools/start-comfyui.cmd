@echo off
REM ComfyUI を起動してブラウザで開く
set COMFY=C:\AI\ComfyUI
if not exist "%COMFY%\.venv\Scripts\python.exe" (
  echo [ERROR] ComfyUI が見つかりません: %COMFY%
  pause
  exit /b 1
)
cd /d "%COMFY%"
start "" "http://127.0.0.1:8188"
".venv\Scripts\python.exe" main.py --listen 127.0.0.1 --port 8188
