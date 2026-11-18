# Gambito Arruinado

Roguelike de ajedrez con meta de puntos, reliquias, jefes y demasiadas explosiones. Hecho en Godot 4.7.2.

## Cómo jugar

- Doble clic en `Jugar.bat`, o abre la carpeta en el editor de Godot y presiona F5.
- Clic en tu pieza y luego en su destino. Clic derecho cancela.
- Cada combate: llega a la META de puntos antes de que se acaben las jugadas.
- Golpe = PUNTOS (valor de la pieza capturada) × MULT (racha de capturas seguidas + reliquias).
- Jaque mate al rey enemigo gana al instante. Si te dan mate, te ahogan o te quedas sin jugadas, pierdes la partida.
- 8 actos × 3 combates (Escaramuza, Batalla, Jefe). Entre combates hay tienda.
- Jaque real (no puedes dejar tu rey en jaque). No hay enroque, captura al paso ni salto doble de peón.
- Maldiciones al azar: la Batalla siempre trae una, la Escaramuza a veces desde el acto 3, y desde el acto 3 el jefe suma una extra.
- El enemigo siempre tiene más material que tú. Está hecho para ser muy difícil.

## Contenido

- 20 reliquias, 5 pergaminos, 3 encantamientos (vidrio, oro, explosiva).
- 8 jefes que rompen reglas + el Gran Maestro (jefe final).
- Tableros 6×6 (actos 1–2), 7×7 (3–5) y 8×8 (6–8).
- Coronas: al ganar se desbloquea una dificultad más alta (hasta Corona 3).
- Todo el arte y el sonido se generan en código: no hay archivos de imagen ni audio.

## Estructura

| Archivo | Qué hace |
|---|---|
| `scripts/board.gd` | Tablero y movimientos (incluye reglas de reliquias y hoyos de lava) |
| `scripts/ai.gd` | IA negamax con poda alfa-beta; dificultad = profundidad + metidas de pata |
| `scripts/run.gd` | Estado de la partida, metas, recompensas, tienda, guardado (autoload `Run`) |
| `scripts/data.gd` | Reliquias, pergaminos, encantamientos y jefes |
| `scripts/combat.gd` | Pantalla de combate, puntuación, jefes, pergaminos, efectos |
| `scripts/piece_view.gd` | Piezas dibujadas con caras y animaciones |
| `scripts/fx.gd` | Explosiones, textos de cómic, temblor, congelado de impacto |
| `scripts/sfx.gd` | Sonidos sintetizados (autoload `Sfx`) |
| `scripts/screens/` | Título, mapa, tienda y final |

## Versión web (GitHub Pages)

Juega en: https://pollofreddys.github.io/gambito-arruinado/
Descarga para Windows: https://pollofreddys.github.io/gambito-arruinado/descargar.html

Cada push a `main` corre `.github/workflows/web.yml`: baja Godot 4.7.2 y las plantillas en la nube,
exporta la versión web (sin hilos, para hosting estático) y un `.exe` de Windows, y lo sube todo a la
rama `web`. GitHub Pages publica esa rama.

## Pruebas (sin ventana)

```
godot --headless --path . -s res://tests/sim.gd            # reglas, velocidad de la IA, calibración
godot --headless --path . -- --autoplay --speed=8           # el bot juega una partida completa
godot --headless --path . -- --demo --act=3 --stage=2 --boss=plaga --speed=8   # un jefe concreto
```

Opciones del modo demo: `--relics=a,b`, `--scrolls=a,b`, `--ench=vidrio|oro|explosiva`, `--boss=<id>`, `--boomtest[=R]`.
Los modos de prueba no guardan el progreso.
