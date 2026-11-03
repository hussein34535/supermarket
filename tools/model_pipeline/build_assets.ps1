# Clean The Supermarket — asset pipeline
#
# Rebuilds every 3D asset in the project from the sources in Downloads and
# rewrites the files under assets/models/. Run from the repo root:
#
#   pwsh -File tools/model_pipeline/build_assets.ps1
#
# Requirements: node + pnpm available through $env:DSH_NODE / DSH_PNPM (the
# harness sets these), or edit $node / $pnpm below. The gltf-transform CLI must
# already be installed:
#
#   node $pnpm add --dir tools/model_pipeline --config.node-linker=hoisted @gltf-transform/cli
#
# Pipeline per asset: weld -> simplify (meshoptimizer) -> resize textures to a
# power-of-two budget -> WebP -> prune unused data. Draco/meshopt are NOT used
# because Godot 4 cannot import them.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $root

$node = "C:\Users\husso\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe"
$cli = "tools\model_pipeline\node_modules\@gltf-transform\cli\bin\cli.js"
$out = "tools\model_pipeline\out"
$src = "$env:USERPROFILE\Downloads"
New-Item -ItemType Directory -Force -Path $out, "assets\models\props" | Out-Null

function Step($name, $argsList) {
	Write-Host "  $name" -ForegroundColor DarkGray
	& $node $cli @argsList | Select-Object -Last 1
}

function Optimize($input, $output, $ratio, $tex, $label) {
	Write-Host "== $label" -ForegroundColor Cyan
	$w = "$out\w.glb"; $s = "$out\s.glb"; $r = "$out\r.glb"
	Step "weld" @("weld", $input, $w)
	Step "simplify $ratio" @("simplify", $w, $s, "--ratio", "$ratio", "--error", "1")
	Step "resize $tex" @("resize", $s, $r, "--width", "$tex", "--height", "$tex")
	Step "webp" @("webp", $r, $output)
	$mb = [math]::Round((Get-Item $output).Length / 1MB, 2)
	Write-Host "   -> $output ($mb MB)" -ForegroundColor Green
}

# --- first person arms (viewmodel, keeps the rig: 1.5M -> 150k tris) ----------
Optimize "assets\models\arms_src.glb" "$out\arms.glb" 0.1 1024 "arms"

# --- third person body --------------------------------------------------------
Optimize "assets\models\character_src.glb" "assets\models\character.glb" 0.02 1024 "character"

# --- grabber tool -------------------------------------------------------------
Optimize "assets\models\grabber_src.glb" "assets\models\grabber.glb" 0.05 512 "grabber"

# --- sculpted shelf props from the AI model drops ------------------------------
Optimize "$src\20261024214959_ded8bd4a.glb" "assets\models\props\cleaner_bottle.glb" 0.02 512 "cleaner bottle"
Optimize "$src\20261025003526_dc3d2260.glb" "assets\models\props\tomato_tray.glb" 0.02 512 "tomato tray"

Write-Host ""
Write-Host "Now re-import and rebuild the split arm meshes:" -ForegroundColor Yellow
Write-Host "  godot --headless --path . --import"
Write-Host "  godot --headless --path . --script res://tools/model_pipeline/mesh_tool.gd -- split res://assets/models/arms_rigged.glb res://assets/models/arm_left_mesh.res res://assets/models/arm_right_mesh.res 0"
