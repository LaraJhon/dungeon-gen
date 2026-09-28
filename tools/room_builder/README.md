# Constructor de salas PSX

Scripts de PowerShell que generan las salas grandes de `rooms/` a partir de una
descripción en código (tamaño, puertas, piezas, decoración). Sirven para hacer
cambios en muchas piezas a la vez (alturas, luces, portales) sin moverlas a mano
en el editor.

| Archivo | Qué es |
|---|---|
| `roomlib.ps1` | Funciones comunes: paredes según una máscara de celdas, portales de 3x2 con sus marcadores `DOOR`, piso, techo, agua, luces. |
| `build_rooms.ps1` | La descripción de cada sala: sala_principal, sala_columnas, cruz_piedra, sala_inundada, gran_sala_abandonada y cruce_elevado. |

## Cómo usarlo

Desde PowerShell, en la carpeta del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File tools\room_builder\build_rooms.ps1
```

Después, en Godot: **Recargar desde el disco**.

## Importante

- **Reescribe los 6 archivos `.tscn` completos.** Si editaste alguna de esas
  salas a mano en Godot, esos cambios se pierden al volver a correr el script.
  Para retocar una sala a mano de forma permanente, sacala de `build_rooms.ps1`.
- Conserva el `uid` de cada escena, así `main.tscn` las sigue encontrando.
- `room_a_psx.tscn`, `room_stair.tscn` y `corridor_piece.tscn` no se generan
  con estos scripts: se editan directamente en Godot.
- La carpeta `tools/` tiene un `.gdignore` para que Godot no la importe.

## Convenciones que usa (y que usa el generador)

- Celda = 4 m. Sala centrada en X/Z, con la base en Y = 0.
- Paredes metidas 0.5 m hacia adentro del borde de la sala.
- Rotación de las puertas: norte = 0, este = 90, sur = 180, oeste = 270.
- Cada portal: `DOOR_x` en el centro (obligatoria) + `DOOR?_x_a` / `DOOR?_x_b` a los costados.
- Las salas generadas tienen `tall_doors = true` (el portal mide 2 pisos de alto).
