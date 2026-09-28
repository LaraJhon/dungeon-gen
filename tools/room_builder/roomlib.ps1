# Constructor de salas PSX para dungeon-gen (genera .tscn de Godot 4).
$ErrorActionPreference = "Stop"
$script:inv = [Globalization.CultureInfo]::InvariantCulture
$script:MODELS = "res://Dungeon_gen/assets/PSX_Dungeon/Models/"

function F([double]$v) { if ([math]::Abs($v) -lt 1e-9) { $v = 0 }; return $v.ToString("0.####", $script:inv) }

# Base (por filas, formato Transform3D de Godot) = RotY(deg) * Escala(sx, sy, sz)
function Basis([double]$deg = 0, [double]$sx = 1, [double]$sy = 1, [double]$sz = 1) {
  $r = $deg * [math]::PI / 180
  $c = [math]::Round([math]::Cos($r), 6); $s = [math]::Round([math]::Sin($r), 6)
  return "$(F ($c*$sx)), 0, $(F ($s*$sz)), 0, $(F $sy), 0, $(F (-$s*$sx)), 0, $(F ($c*$sz))"
}
$script:RX180 = "1, 0, 0, 0, -1, 0, 0, 0, -1"

function New-Room($rootName, [int]$nx, [int]$ny, [int]$nz, [int]$maxPer = 0, [double]$weight = 1.0) {
  $script:R = @{
    nx = $nx; ny = $ny; nz = $nz; root = $rootName; maxPer = $maxPer; weight = $weight
    ext = [ordered]@{}; subs = New-Object Text.StringBuilder; nodes = New-Object Text.StringBuilder
    names = @{}; mask = { param($i, $j) $true }
  }
  Res "script" 'type="Script" uid="uid://ofasgoxwj34" path="res://Dungeon_gen/DungeonRoom.gd"'
}
function Res($key, $decl) { if (-not $script:R.ext.Contains($key)) { $script:R.ext[$key] = $decl } }
function Model($file) {
  $key = $file
  Res $key "type=`"PackedScene`" path=`"$($script:MODELS)$file.fbx`""
  return $key
}
function CX([int]$i) { return -$script:R.nx * 2 + 2 + 4 * $i }
function CZ([int]$j) { return -$script:R.nz * 2 + 2 + 4 * $j }
function InMask([int]$i, [int]$j) {
  if ($i -lt 0 -or $j -lt 0 -or $i -ge $script:R.nx -or $j -ge $script:R.nz) { return $false }
  return [bool](& $script:R.mask $i $j)
}
function UniqueName($parent, $name) {
  $k = "$parent/$name"; $n = $name; $c = 1
  while ($script:R.names.ContainsKey("$parent/$n")) { $c++; $n = "$name$c" }
  $script:R.names["$parent/$n"] = $true
  return $n
}
function AddGroup($name, $parent = ".") {
  [void]$script:R.nodes.AppendLine("[node name=`"$name`" type=`"Node3D`" parent=`"$parent`"]`n")
}
function Put($model, $parent, $name, $basis, $x, $y, $z) {
  $key = Model $model
  $n = UniqueName $parent $name
  [void]$script:R.nodes.AppendLine("[node name=`"$n`" parent=`"$parent`" instance=ExtResource(`"$key`")]")
  [void]$script:R.nodes.AppendLine("transform = Transform3D($basis, $(F $x), $(F $y), $(F $z))`n")
}
function Pillar($parent, $x, $y, $z, [double]$height = 6) {
  Put "Pillar" $parent "Pilar" (Basis 0 1 ($height / 6) 1) $x $y $z
}
function Light($parent, $name, $x, $y, $z, $color = "1, 0.62, 0.3", [double]$energy = 1.6, [double]$range = 10) {
  $n = UniqueName $parent $name
  [void]$script:R.nodes.AppendLine("[node name=`"$n`" type=`"OmniLight3D`" parent=`"$parent`"]")
  [void]$script:R.nodes.AppendLine("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, $(F $x), $(F $y), $(F $z))")
  [void]$script:R.nodes.AppendLine("light_color = Color($color, 1)`nlight_energy = $(F $energy)`nomni_range = $(F $range)`n")
}
# Luz cálida + vela apoyada en (x, y, z)
function Candle($parent, $x, $y, $z, [double]$energy = 1.4, [double]$range = 8) {
  Put "Candle_02" $parent "Vela" (Basis 0) $x $y $z
  Light $parent "LuzVela" $x ($y + 1.2) $z "1, 0.62, 0.3" $energy $range
}

# Baldosas en todas las celdas de la máscara (o las que pase $filter)
function Floor($parent, [double]$y, $filter = $null, [switch]$Ceiling) {
  $basis = if ($Ceiling) { $script:RX180 } else { Basis 0 }
  for ($i = 0; $i -lt $script:R.nx; $i++) { for ($j = 0; $j -lt $script:R.nz; $j++) {
    if (-not (InMask $i $j)) { continue }
    if ($filter -and -not (& $filter $i $j)) { continue }
    Put "Floor_Tiles" $parent "Baldosa" $basis (CX $i) $y (CZ $j)
  } }
}

# Agua semitransparente (un solo plano)
function Water($parent, [double]$y, [double]$w, [double]$d, [double]$tiling = 9) {
  Res "water_tex" 'type="Texture2D" path="res://Dungeon_gen/assets/PSX_Dungeon/Textures/TEX_Water_01.png"'
  [void]$script:R.subs.AppendLine(@"
[sub_resource type="StandardMaterial3D" id="mat_agua"]
transparency = 1
albedo_color = Color(0.45, 0.75, 1, 0.8)
albedo_texture = ExtResource("water_tex")
specular_mode = 2
uv1_scale = Vector3($(F $tiling), $(F ($tiling * $d / $w)), 1)
texture_filter = 0

[sub_resource type="PlaneMesh" id="mesh_agua"]
material = SubResource("mat_agua")
size = Vector2($(F $w), $(F $d))

"@)
  [void]$script:R.nodes.AppendLine("[node name=`"Agua`" type=`"MeshInstance3D`" parent=`"$parent`"]")
  [void]$script:R.nodes.AppendLine("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, $(F $y), 0)`nmesh = SubResource(`"mesh_agua`")`ncast_shadow = 0`n")
}

# Paredes en todo el borde de la máscara, filas $rows (índices de piso).
# $doors: lista de @{side="N|S|E|W"; cell=<índice a lo largo del lado>; row=<piso>; name="DOOR_x"}
# $pick: scriptblock (row, side, k) -> nombre de modelo de pared (variedad)
function Walls($rows, $doors, $pick = $null) {
  AddGroup "Paredes"
  $sides = @(
    @{ s = "N"; di = 0; dj = -1; basis = (Basis 0) },
    @{ s = "S"; di = 0; dj = 1; basis = (Basis 180) },
    @{ s = "W"; di = -1; dj = 0; basis = (Basis 90) },
    @{ s = "E"; di = 1; dj = 0; basis = (Basis 90) }
  )
  $k = 0
  foreach ($row in $rows) {
    $y = 4 * $row
    for ($i = 0; $i -lt $script:R.nx; $i++) { for ($j = 0; $j -lt $script:R.nz; $j++) {
      if (-not (InMask $i $j)) { continue }
      foreach ($sd in $sides) {
        if (InMask ($i + $sd.di) ($j + $sd.dj)) { continue }
        $cx = CX $i; $cz = CZ $j
        $px = $cx + $sd.di * 1.5; $pz = $cz + $sd.dj * 1.5
        $along = if ($sd.s -in "N", "S") { $i } else { $j }
        # Portal grande: 3 celdas de ancho x 2 pisos de alto (como el pasillo)
        $door = $doors | Where-Object { $_.side -eq $sd.s -and $_.cell -eq $along -and $_.row -eq $row } | Select-Object -First 1
        $inGate = $doors | Where-Object { $_.side -eq $sd.s -and [math]::Abs($_.cell - $along) -le 1 -and $row -ge $_.row -and $row -le $_.row + 1 } | Select-Object -First 1
        $k++
        if ($door) {
          $rotDeg = @{ N = 0; S = 180; W = 90; E = 90 }[$sd.s]
          $gx = $cx + $sd.di * 1.26; $gz = $cz + $sd.dj * 1.26   # Door_Frame_02 tiene 1.48 de grosor
          Put "Door_Frame_02" "Paredes" "Portal_$($sd.s)" (Basis $rotDeg 3 2 1) $gx $y $gz
        } elseif ($inGate) {
          continue
        } else {
          $m = if ($pick) { & $pick $row $sd.s $k } else { "Wall_01" }
          Put $m "Paredes" "Pared_$($sd.s)" $sd.basis $px $y $pz
        }
      }
    } }
  }
  # Marcadores lógicos, justo en el borde exterior de la celda de la puerta
  AddGroup "Puertas"
  foreach ($d in $doors) {
    $rot = @{ N = 0; S = 180; E = 90; W = 270 }[$d.side]
    switch ($d.side) {
      "N" { $x = CX $d.cell; $z = -$script:R.nz * 2 }
      "S" { $x = CX $d.cell; $z = $script:R.nz * 2 }
      "W" { $x = -$script:R.nx * 2; $z = CZ $d.cell }
      "E" { $x = $script:R.nx * 2; $z = CZ $d.cell }
    }
    # Puerta obligatoria en el centro + dos opcionales a los costados (el portal
    # mide 3 celdas; el pasillo ancho siempre las cubre a las tres).
    $along = if ($d.side -in "N", "S") { @(1, 0) } else { @(0, 1) }
    $side = $d.name -replace '^DOOR_', 'DOOR?_'
    foreach ($o in @(@(0, $d.name), @(-1, "${side}_a"), @(1, "${side}_b"))) {
      $ox = $x + 4 * $o[0] * $along[0]; $oz = $z + 4 * $o[0] * $along[1]
      [void]$script:R.nodes.AppendLine("[node name=`"$($o[1])`" type=`"Node3D`" parent=`"Puertas`"]")
      [void]$script:R.nodes.AppendLine("transform = Transform3D($(Basis $rot), $(F $ox), $(F (4 * $d.row)), $(F $oz))`n")
    }
  }
}

function Save-Room($path) {
  $sb = New-Object Text.StringBuilder
  $uid = ""
  if (Test-Path $path) {
    $m = [regex]::Match([IO.File]::ReadAllText($path), '^\[gd_scene[^\]]*uid="([^"]+)"')
    if ($m.Success) { $uid = " uid=`"$($m.Groups[1].Value)`"" }
  }
  [void]$sb.AppendLine("[gd_scene format=3$uid]`n")
  foreach ($k in $script:R.ext.Keys) { [void]$sb.AppendLine("[ext_resource $($script:R.ext[$k]) id=`"$k`"]") }
  [void]$sb.AppendLine()
  [void]$sb.Append($script:R.subs.ToString())
  [void]$sb.AppendLine("[node name=`"$($script:R.root)`" type=`"Node3D`"]")
  [void]$sb.AppendLine("script = ExtResource(`"script`")")
  [void]$sb.AppendLine("size_in_voxels = Vector3i($($script:R.nx), $($script:R.ny), $($script:R.nz))")
  if ($script:R.weight -ne 1.0) { [void]$sb.AppendLine("spawn_weight = $(F $script:R.weight)") }
  if ($script:R.maxPer -gt 0) { [void]$sb.AppendLine("max_per_dungeon = $($script:R.maxPer)") }
  [void]$sb.AppendLine("tall_doors = true")
  [void]$sb.AppendLine()
  [void]$sb.Append($script:R.nodes.ToString())
  [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
  "$path : " + ([regex]::Matches($sb.ToString(), '(?m)^\[node ')).Count + " nodos"
}
