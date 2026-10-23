# DESIGN · FantasyNotch (provisional)

> **Estado: propuesta sin validar en pantalla.** Los números son puntos de partida para FN-009 y FN-011; ajustar al probar en un Mac con notch.
> Contrato de datos: `docs/specs/001-mvp/plan.md` §Contracts. Comportamiento de la librería: `docs/spikes/004-dynamicnotchkit.md`.

## Vista compacta (junto al notch)

Solo existe en pantallas con notch: sin notch `compact()` no muestra nada (spike FN-004).

- Dos zonas, a la izquierda y a la derecha del notch: **mis puntos** a la izquierda, **los del rival** a la derecha.
- Alto: el del notch (la librería lo ajusta; no se fija a mano). Ancho propuesto por zona: **56 pt**, margen interior **8 pt**.
- Un solo número por zona, sin etiquetas. Tamaño `caption` (≈ 12 pt) en semibold.
- Si no hay rival (bye), la zona derecha muestra `—` y la izquierda mis puntos.

## Vista expandida (al hacer clic o al pasar el cursor)

- Ancho propuesto: **360 pt**. Alto: lo que pida el contenido, con máximo **260 pt** (7–9 titulares por equipo caben en dos columnas).
- Cabecera: nombre de cada equipo y su total, el del líder en peso `semibold`.
- Cuerpo: dos columnas, una por equipo, con una fila por titular: posición, nombre, puntos y un indicador de `PlayStatus`.
- Pie: texto `Actualizado hace N s`. Si `isStale == true`, el pie cambia a `Sin conexión · datos de hace N min`.

## Colores

Semánticos, con variante clara y oscura. Los hex son propuestas; verificar contraste mínimo 4.5:1 sobre el negro del notch.

| Estado | Uso | Oscuro | Claro |
|---|---|---|---|
| Ganando | mi total mayor que el rival | `#34C759` | `#248A3D` |
| Perdiendo | mi total menor que el rival | `#FF453A` | `#D70015` |
| Empate | totales iguales | `#FFD60A` | `#B25000` |
| Desactualizado | `isStale == true` | `#8E8E93` | `#6C6C70` |

El color nunca es la única señal: el indicador de `PlayStatus` y el texto del pie siguen presentes.

## Indicador de `PlayStatus`

| Caso | Indicador |
|---|---|
| `.pending` | círculo vacío, gris |
| `.playing` | punto relleno con pulso lento (se desactiva con "Reducir movimiento") |
| `.done` | marca de verificación, gris |
| `.unknown` | guion `–`, gris |

## Tipografía

- **Todos los números de puntos** usan `.monospacedDigit()` para que no salten al cambiar de valor.
- Puntos con **un decimal** (`112.4`); `0` se muestra como `0.0`.
- Nombres con `lineLimit(1)` y truncado al final; tamaño `callout` en la vista expandida.

## Accesibilidad

- Respetar "Reducir movimiento": sin pulso ni animación de expandir.
- Cada zona compacta lleva una etiqueta de VoiceOver: "Tú 112.4, rival 98.7".
- Soporte de modo claro y oscuro con los colores semánticos de arriba.
