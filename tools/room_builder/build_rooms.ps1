. "$PSScriptRoot\roomlib.ps1"
$ROOMS = (Resolve-Path "$PSScriptRoot\..\..\rooms").Path
$H8 = 8.0 / 6.0   # escala Y de Pillar (6 m) para llegar a un techo de 8 m
$R0 = Basis 0; $R90 = Basis 90; $R180 = Basis 180; $R270 = Basis 270
$Dais = Basis 0 1 0.125 1   # Hexagon aplastado = tarima/medallón de 20 cm

# =========================================================================
# 1. SALA PRINCIPAL — 7x2x6 (28 x 12 x 24 m)
#    Plataforma elevada al fondo (norte) con escalera central, columnas,
#    tarima central y 3 entradas (sur, oeste, este).
# =========================================================================
New-Room "SalaPrincipal" 7 3 6 1 0.6
AddGroup "Piso"; Floor "Piso" 0
AddGroup "Techo"; Floor "Techo" 12 -Ceiling
Walls @(0, 1, 2) @(
  @{ side = "S"; cell = 3; row = 0; name = "DOOR_sur" },
  @{ side = "W"; cell = 3; row = 0; name = "DOOR_oeste" },
  @{ side = "E"; cell = 3; row = 0; name = "DOOR_este" }
) { param($row, $s, $k) if ($row -eq 0 -and $k % 3 -eq 0) { "Skull_Wall" } else { "Wall_01" } }

AddGroup "Plataforma"
for ($i = 0; $i -lt 7; $i++) { Put "Block_Half" "Plataforma" "Bloque" $R0 (CX $i) 0 -10 }
Put "Stairs" "Plataforma" "Escalera" $R90 0 0 -6          # sube hacia el norte
Pillar "Plataforma" -4 2 -10 10
Pillar "Plataforma" 4 2 -10 10
Put "Chest" "Plataforma" "Cofre" $R0 0 2 -10.8

AddGroup "Columnas"
foreach ($p in @(@(-8, -2), @(8, -2), @(-8, 6), @(8, 6), @(-8, 10), @(8, 10))) { Pillar "Columnas" $p[0] 0 $p[1] 12 }

AddGroup "Decoracion"
Put "Hexagon" "Decoracion" "Tarima" $Dais 0 0 2
foreach ($x in -10, -6, 6, 10) { Candle "Decoracion" $x 2 -10.6 1.0 6 }
Candle "Decoracion" -2 0.2 2 1.4 9
Candle "Decoracion" 2 0.2 2 1.4 9
Put "Barrel" "Decoracion" "Barril" $R0 -12 0 10.5
Put "Barrel" "Decoracion" "Barril" $R90 -10.5 0 10.8
Put "Box" "Decoracion" "Caja" $R0 12 0 10.5
foreach ($p in @(@(-12, -2), @(12, -2), @(-12, 7), @(12, 7), @(0, 7))) { Light "Decoracion" "LuzSala" $p[0] 8.5 $p[1] "1, 0.6, 0.32" 1.5 15 }
Save-Room "$ROOMS\sala_principal.tscn"

# =========================================================================
# 2. SALA DE COLUMNAS — 9x2x7 (36 x 12 x 28 m)
#    Dos columnatas, esquinas macizas, rocas/escombros, 4 entradas.
# =========================================================================
New-Room "SalaColumnas" 9 3 7 1 0.6
AddGroup "Piso"; Floor "Piso" 0
AddGroup "Techo"; Floor "Techo" 12 -Ceiling
Walls @(0, 1, 2) @(
  @{ side = "N"; cell = 4; row = 0; name = "DOOR_norte" },
  @{ side = "S"; cell = 4; row = 0; name = "DOOR_sur" },
  @{ side = "W"; cell = 3; row = 0; name = "DOOR_oeste" },
  @{ side = "E"; cell = 3; row = 0; name = "DOOR_este" }
) { param($row, $s, $k) if ($row -eq 0 -and $k % 4 -eq 0) { "Skull_Wall" } else { "Wall_01" } }

AddGroup "Esquinas"
foreach ($x in -16, 16) { foreach ($z in -12, 12) { foreach ($y in 0, 4) { Put "Block" "Esquinas" "Bloque" $R0 $x $y $z } } }

AddGroup "Columnas"
foreach ($z in -6, 6) { foreach ($x in -14, -10, -6, -2, 2, 6, 10, 14) { Pillar "Columnas" $x 0 $z 12 } }

AddGroup "Decoracion"
Put "Pillar_Collapsed_01" "Decoracion" "PilarRoto" $R0 -10 0 10
Put "Pillar_Collapsed_02" "Decoracion" "PilarCaido" $R90 9 0 -10
Put "Debris" "Decoracion" "Escombros" $R0 -8 0 -11
Put "Debris" "Decoracion" "Escombros" $R90 11 0 11
Put "Debris" "Decoracion" "Escombros" $R0 -13 0 9
Put "Box" "Decoracion" "Caja" $R0 13.5 0 -9
Put "Barrel" "Decoracion" "Barril" $R0 -9 0 11.5
foreach ($p in @(@(-10, 0), @(10, 0), @(0, -10), @(0, 10), @(-8, -10), @(8, 10))) { Light "Decoracion" "LuzSala" $p[0] 8.5 $p[1] "1, 0.6, 0.32" 1.5 15 }
Save-Room "$ROOMS\sala_columnas.tscn"

# =========================================================================
# 4. CRUZ DE PIEDRA — 9x2x9 (36 x 12 x 36 m), máscara en forma de cruz
#    Plaza central con medallón, 4 brazos (salas laterales), 4 entradas.
# =========================================================================
New-Room "CruzPiedra" 9 3 9 1 0.6
$script:R.mask = { param($i, $j) ($i -ge 3 -and $i -le 5) -or ($j -ge 3 -and $j -le 5) }
AddGroup "Piso"; Floor "Piso" 0
AddGroup "Techo"; Floor "Techo" 12 -Ceiling
Walls @(0, 1, 2) @(
  @{ side = "N"; cell = 4; row = 0; name = "DOOR_norte" },
  @{ side = "S"; cell = 4; row = 0; name = "DOOR_sur" },
  @{ side = "W"; cell = 4; row = 0; name = "DOOR_oeste" },
  @{ side = "E"; cell = 4; row = 0; name = "DOOR_este" }
) { param($row, $s, $k) if ($row -eq 0 -and $k % 3 -eq 0) { "Skull_Wall" } else { "Wall_01" } }

AddGroup "Columnas"
foreach ($x in -6, 6) { foreach ($z in -6, 6) { Pillar "Columnas" $x 0 $z 12 } }

AddGroup "Decoracion"
Put "Hexagon" "Decoracion" "Medallon" $Dais 0 0 0
foreach ($p in @(@(-5, -5), @(5, -5), @(-5, 5), @(5, 5))) { Candle "Decoracion" $p[0] 0 $p[1] 1.2 8 }
Put "Chest" "Decoracion" "Cofre" $R0 -4.5 0 -16
Put "Barrel" "Decoracion" "Barril" $R0 -5 0 16.5
Put "Barrel" "Decoracion" "Barril" $R0 -3.3 0 16.8
Put "Box" "Decoracion" "Caja" $R0 16.5 0 -5
Put "Debris" "Decoracion" "Escombros" $R0 -15 0 4
Put "Pillar_Collapsed_01" "Decoracion" "PilarRoto" $R0 15 0 5
Light "Decoracion" "LuzCentro" 0 9 0 "1, 0.62, 0.34" 2.0 18
foreach ($p in @(@(0, -13), @(0, 13), @(-13, 0), @(13, 0))) { Light "Decoracion" "LuzBrazo" $p[0] 7.5 $p[1] "1, 0.58, 0.3" 1.4 12 }
Save-Room "$ROOMS\cruz_piedra.tscn"

# =========================================================================
# 5. SALA INUNDADA — 9x2x7 (36 x 12 x 28 m)
#    Foso con agua (piso 0), pasarelas y cornisa perimetral en y = 4,
#    islotes sueltos con cofres, plataforma hexagonal central.
#    Puertas en el piso de ARRIBA (y = 4).
# =========================================================================
New-Room "SalaInundada" 9 3 7 1 0.6
$solid = { param($i, $j) $i -eq 0 -or $i -eq 8 -or $j -eq 0 -or $j -eq 6 -or $i -eq 4 -or $j -eq 3 }
$island = { param($i, $j) ($i -eq 2 -or $i -eq 6) -and ($j -eq 1 -or $j -eq 5) }
AddGroup "Fondo"; Floor "Fondo" 0 { param($i, $j) -not (& $solid $i $j) -and -not (& $island $i $j) }
Water "Fondo" 3.2 36 28 9
AddGroup "Techo"; Floor "Techo" 12 -Ceiling
Walls @(1, 2) @(
  @{ side = "S"; cell = 4; row = 1; name = "DOOR_sur" },
  @{ side = "W"; cell = 3; row = 1; name = "DOOR_oeste" },
  @{ side = "E"; cell = 3; row = 1; name = "DOOR_este" }
)
AddGroup "Pasarelas"
for ($i = 0; $i -lt 9; $i++) { for ($j = 0; $j -lt 7; $j++) {
  if ((& $solid $i $j) -or (& $island $i $j)) { Put "Block" "Pasarelas" "Bloque" $R0 (CX $i) 0 (CZ $j) }
} }
Put "Hexagon" "Pasarelas" "PlataformaCentral" $Dais 0 4 0

AddGroup "Decoracion"
foreach ($x in -16, 16) { foreach ($z in -12, 12) { Pillar "Decoracion" $x 4 $z 8 } }
foreach ($p in @(@(-2.4, -2.4), @(2.4, -2.4), @(-2.4, 2.4), @(2.4, 2.4))) { Candle "Decoracion" $p[0] 4.2 $p[1] 1.1 7 }
Put "Chest" "Decoracion" "Cofre" $R0 -8 4 -8
Put "Chest" "Decoracion" "Cofre" $R180 8 4 8
Put "Barrel" "Decoracion" "Barril" $R0 8 4 -8
Put "Box" "Decoracion" "Caja" $R0 -8 4 8
foreach ($p in @(@(-8, 0), @(8, 0), @(0, -6), @(0, 6))) { Light "Decoracion" "LuzAgua" $p[0] 2.2 $p[1] "0.3, 0.6, 1" 1.2 10 }
foreach ($p in @(@(-12, 0), @(12, 0), @(0, -10), @(0, 10))) { Light "Decoracion" "LuzSala" $p[0] 9 $p[1] "1, 0.6, 0.32" 1.3 13 }
Save-Room "$ROOMS\sala_inundada.tscn"

# =========================================================================
# 6. GRAN SALA ABANDONADA — 11x2x9 (44 x 12 x 36 m)
#    Plataforma elevada lateral (NE) con escalera, pilares rotos,
#    escombros, paredes derruidas arriba, 3 entradas.
# =========================================================================
New-Room "GranSalaAbandonada" 11 3 9 1 0.5
AddGroup "Piso"; Floor "Piso" 0
AddGroup "Techo"; Floor "Techo" 12 -Ceiling
Walls @(0, 1, 2) @(
  @{ side = "N"; cell = 2; row = 0; name = "DOOR_norte" },
  @{ side = "S"; cell = 7; row = 0; name = "DOOR_sur" },
  @{ side = "W"; cell = 4; row = 0; name = "DOOR_oeste" }
) { param($row, $s, $k) if ($row -eq 2 -and $k % 5 -eq 2) { "Wall_Ruin" } elseif ($row -eq 0 -and $k % 4 -eq 1) { "Skull_Wall" } else { "Wall_01" } }

AddGroup "Plataforma"
foreach ($i in 8, 9, 10) { foreach ($j in 0, 1, 2) { Put "Block_Half" "Plataforma" "Bloque" $R0 (CX $i) 0 (CZ $j) } }
Put "Stairs" "Plataforma" "Escalera" $R0 8 0 -12          # sube hacia el este
Put "Chest" "Plataforma" "Cofre" $R0 18 2 -15
Pillar "Plataforma" 12 2 -16 10
Candle "Plataforma" 14.5 2 -15.5 1.2 8
Candle "Plataforma" 19.5 2 -10 1.2 8

AddGroup "Ruinas"
Pillar "Ruinas" -15 0 -6 12
Pillar "Ruinas" 4 0 8 12
Pillar "Ruinas" -4 0 -12 12
Put "Pillar_Collapsed_01" "Ruinas" "PilarRoto" $R0 -4 0 -2
Put "Pillar_Collapsed_01" "Ruinas" "PilarRoto" $R90 -14 0 10
Put "Pillar_Collapsed_01" "Ruinas" "PilarRoto" $R0 12 0 6
Put "Pillar_Collapsed_02" "Ruinas" "PilarCaido" $R90 0 0 12
Put "Pillar_Collapsed_02" "Ruinas" "PilarCaido" $R0 -9 0 3
foreach ($p in @(@(-16, -12, 0), @(-6, 6, 90), @(8, -2, 0), @(16, 12, 90), @(-18, 14, 0), @(2, -14, 90))) { Put "Debris" "Ruinas" "Escombros" (Basis $p[2]) $p[0] 0 $p[1] }

AddGroup "Decoracion"
Put "Hexagon" "Decoracion" "Medallon" $Dais -2 0 2
Candle "Decoracion" -2 0.2 2 1.4 10
Put "Barrel" "Decoracion" "Barril" $R0 -19.5 0 -15.5
Put "Box" "Decoracion" "Caja" $R0 -20 0 -12
foreach ($p in @(@(-14, 0), @(0, -8), @(0, 10), @(12, 10), @(-14, 12))) { Light "Decoracion" "LuzSala" $p[0] 8.5 $p[1] "1, 0.58, 0.3" 1.4 15 }
Save-Room "$ROOMS\gran_sala_abandonada.tscn"

# =========================================================================
# 3. CRUCE ELEVADO — 9x4x9 (36 x 16 x 36 m)
#    Abismo con agua (fondo y = 0), pasarelas en cruz de 3 celdas de ancho
#    en y = 8, 4 portales en el piso 2, techo a 16 m.
# =========================================================================
New-Room "CruceElevado" 9 4 9 1 1.0
$cross = { param($i, $j) ($i -ge 3 -and $i -le 5) -or ($j -ge 3 -and $j -le 5) }
AddGroup "Fondo"; Floor "Fondo" 0
Water "Fondo" 1 36 36 9
Put "Pillar_Collapsed_02" "Fondo" "PilarCaido" $R90 -12 0 -12
Put "Debris" "Fondo" "Escombros" $R0 12 0 -13
Put "Debris" "Fondo" "Escombros" $R90 -13 0 12
AddGroup "Techo"; Floor "Techo" 16 -Ceiling
Walls @(0, 1, 2, 3) @(
  @{ side = "N"; cell = 4; row = 2; name = "DOOR_norte" },
  @{ side = "S"; cell = 4; row = 2; name = "DOOR_sur" },
  @{ side = "W"; cell = 4; row = 2; name = "DOOR_oeste" },
  @{ side = "E"; cell = 4; row = 2; name = "DOOR_este" }
) { param($row, $s, $k) if ($row -eq 0 -and $k % 2 -eq 0) { "Skull_Wall" } else { "Wall_01" } }

AddGroup "Pasarelas"
for ($i = 0; $i -lt 9; $i++) { for ($j = 0; $j -lt 9; $j++) {
  if (& $cross $i $j) { Put "Block_Half" "Pasarelas" "Bloque" $R0 (CX $i) 6 (CZ $j) }
} }
AddGroup "Pilares"
foreach ($p in @(@(-4, -4), @(4, -4), @(-4, 4), @(4, 4), @(-4, -12), @(4, -12), @(-4, 12), @(4, 12), @(-12, -4), @(-12, 4), @(12, -4), @(12, 4))) {
  Pillar "Pilares" $p[0] 0 $p[1] 6
}
AddGroup "Barandas"
$RailX = Basis 0 1 0.5 0.5; $RailZ = Basis 90 1 0.5 0.5
foreach ($d in 8, 12, 16) { foreach ($s in -5.75, 5.75) {
  Put "Wall_Border_01" "Barandas" "Baranda" $RailZ $s 8 (-$d)
  Put "Wall_Border_01" "Barandas" "Baranda" $RailZ $s 8 $d
  Put "Wall_Border_01" "Barandas" "Baranda" $RailX (-$d) 8 $s
  Put "Wall_Border_01" "Barandas" "Baranda" $RailX $d 8 $s
} }
AddGroup "Decoracion"
foreach ($p in @(@(-5, -5), @(5, -5), @(-5, 5), @(5, 5))) { Candle "Decoracion" $p[0] 8 $p[1] 1.6 10 }
Put "Barrel" "Decoracion" "Barril" $R0 -4.6 8 -2.8
Put "Box" "Decoracion" "Caja" $R0 4.4 8 2.6
foreach ($p in @(@(-12, -12), @(12, -12), @(-12, 12), @(12, 12))) { Light "Decoracion" "LuzAbismo" $p[0] 2.5 $p[1] "0.3, 0.6, 1" 1.3 13 }
foreach ($p in @(@(0, -12), @(0, 12), @(-12, 0), @(12, 0))) { Light "Decoracion" "LuzAlta" $p[0] 13 $p[1] "1, 0.6, 0.32" 1.3 14 }
Save-Room "$ROOMS\cruce_elevado.tscn"
