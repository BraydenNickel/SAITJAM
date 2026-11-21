# Luck Jam setup - run once from this folder in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\setup-jam.ps1
$ErrorActionPreference = "Stop"
Write-Host "== Luck Jam setup ==" -ForegroundColor Cyan

function Need($cmd, $hint) {
  if (Get-Command $cmd -ErrorAction SilentlyContinue) { Write-Host "  [ok] $cmd" -ForegroundColor Green }
  else { Write-Host "  [missing] $cmd - $hint" -ForegroundColor Yellow }
}
Need node   "install Node.js 18+ (godot-mcp and pixelfx need it)"
Need npx    "comes with Node.js"
Need git    "install Git for Windows (also gives Bash for the studio hooks)"
Need python "install Python 3 (studio skills read project.yaml)"
Need claude "install Claude Code"

# uv runs the godot-ai Python server (live-editor MCP)
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Write-Host "  installing uv (needed by godot-ai)..." -ForegroundColor Yellow
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}
Need uv "https://docs.astral.sh/uv/ (godot-ai server)"

# Find Godot
$godot = Get-ChildItem -Path "$env:USERPROFILE","C:\Program Files","C:\Godot","$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop" `
  -Filter "Godot_v4*win64.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notmatch "console" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($godot) { $path = $godot.FullName; Write-Host "  [found] $path" -ForegroundColor Green }
else { $path = Read-Host "Paste the full path to your Godot 4.6 .exe" }

# Register the Godot MCP for THIS machine only (local scope: stored in your user
# config, not in the repo, so teammates never overwrite each other's Godot path).
if (Get-Command claude -ErrorAction SilentlyContinue) {
  cmd /c "claude mcp remove --scope local godot >nul 2>nul"
  claude mcp add --scope local godot -e "GODOT_PATH=$path" -e DEBUG=false -- cmd /c npx -y @coding-solo/godot-mcp
  Write-Host "  [ok] godot MCP registered for this PC (local scope)" -ForegroundColor Green
} else {
  Write-Host "  [!] Claude Code not found - install it, then re-run this script" -ForegroundColor Yellow
}

Write-Host "  warming up godot-mcp (first npx download)..."
cmd /c "npx -y @coding-solo/godot-mcp --help >nul 2>nul"

if (-not (Test-Path .git)) { git init -q; git add -A; git commit -qm "Jam kit baseline" ; Write-Host "  [ok] git baseline commit" -ForegroundColor Green }

Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. claude"
Write-Host "  2. /mcp              (check godot shows connected)"
Write-Host "  3. Open the project in Godot 4.6. Find the Godot AI tab (right-hand dock, next to Inspector/Node) and click Configure on the Claude Code row. Do NOT click Update (v4 needs Godot 4.7)."
Write-Host "  4. Restart claude, approve godot-ai, check /mcp shows godot AND godot-ai"
Write-Host "  5. /setup-engine godot 4.6"
Write-Host "  6. When the theme drops: 'Theme is X. Read design/jam-plan.md, use chance-mechanic-designer, give me 3 pitches.'"
