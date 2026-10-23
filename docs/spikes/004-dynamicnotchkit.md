# Spike FN-004 · DynamicNotchKit 1.1.0: vista compacta y comportamiento sin notch

- Fecha: 2026-10-23 · Tarea: FN-004 · Relacionadas: FN-009, FN-011 · ADR 0002
- Entorno: macOS 26.7.1, Swift 6.4 (tools-version 5.9), MacBook con notch (pantalla integrada, `screens[0]`) + monitor externo 1080p sin notch.
- Método: paquete SwiftPM temporal **fuera del repo** (`exact: "1.1.0"`, `platforms: [.macOS(.v13)]`) + lectura del código fuente de la versión fijada. Compiló y corrió sin cambios en la API.

## Pregunta que responde
> ¿DynamicNotchKit permite contenido compacto a izquierda y derecha del notch sin expandir, y cómo se comporta sin notch? (spec §Open questions)

**Respuesta corta:** sí al compacto, pero (1) el compacto **solo existe en pantallas con notch**: sin notch `compact()` oculta y no muestra nada; (2) la librería **no expande por hover ni por clic**: eso lo conecta la app llamando a `expand()`/`compact()`.

## API relevante (verificada contra el código de 1.1.0)

```swift
let notch = DynamicNotch(
    hoverBehavior: .all,            // OptionSet: .keepVisible, .hapticFeedback, .increaseShadow
    style: .auto                    // .auto | .notch | .floating (o con radios)
) {
    /* expanded */  ExpandedView()
} compactLeading: {
    /* izquierda del notch */  Text("112.4")
} compactTrailing: {
    /* derecha del notch */    Text("98.7")
}

await notch.compact(on: screen)   // muestra leading/trailing junto al notch
await notch.expand(on: screen)    // despliega el contenido grande debajo del notch
await notch.hide()                // oculta y destruye la ventana
```

- Los tres métodos son `async` y esperan ~0.4 s a que termine la animación. Defecto de `on:` = `NSScreen.screens[0]` (pantalla con la barra de menús), **no** `NSScreen.main`.
- `init` sin `compactLeading`/`compactTrailing` desactiva el compacto (`compact()` equivale a `hide()`).
- `transitionConfiguration` permite sobrescribir animaciones; `skipIntermediateHides` evita el parpadeo hide→show al cambiar de estado.
- Estados internos (`hidden/compact/expanded`) son `internal`: la app no los puede leer. Lo único público de estado es `isHovering`.

## Snippet mínimo que funcionó
Versión reducida del prototipo que sí compiló y corrió (`swift build`, `Spike builtin`; usaba el mismo flujo con logs extra). `compact()` devolvió en 0.45 s con la ventana en pantalla. El snippet reducido en sí no se recompiló por separado.

```swift
import AppKit, SwiftUI, DynamicNotchKit

@MainActor final class Driver: NSObject, NSApplicationDelegate {
    var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    func applicationDidFinishLaunching(_ n: Notification) {
        let screen = NSScreen.screens[0]
        var notch: DynamicNotch<AnyView, AnyView, AnyView>!
        notch = DynamicNotch {
            AnyView(VStack { Text("Matchup"); Button("Cerrar") { Task { await notch.compact(on: screen) } } }.padding())
        } compactLeading: {
            AnyView(Text("112.4").font(.caption.monospacedDigit())
                .onTapGesture { Task { await notch.expand(on: screen) } })
        } compactTrailing: {
            AnyView(Text("98.7").font(.caption.monospacedDigit())
                .onTapGesture { Task { await notch.expand(on: screen) } })
        }
        self.notch = notch                  // retener: si se libera, la ventana desaparece
        Task { await notch.compact(on: screen) }
    }
}
// main: NSApplication.shared.setActivationPolicy(.accessory); delegate = Driver(); run()
```

El tipo genérico es `DynamicNotch<Expanded, CompactLeading, CompactTrailing>`; con `AnyView` se puede guardar en una propiedad sin escribir los tres tipos.

## Observado en la pantalla con notch (integrada)
| Estado | Ventana (`NSPanel`) | Notas |
|---|---|---|
| compact | frame `(367, 478, 735×478)`, `level = 1000` (`.screenSaver`), alpha 1 | `compact()` tardó 0.45 s |
| expanded | mismo frame, alpha 1 | `isHovering == false` sin mouse encima |
| back to compact | mismo frame | transición sin recrear la ventana |
| hide | `windowController == nil` | ventana destruida |

- El panel mide **la mitad de la pantalla** (ancho/2 × alto/2), anclado arriba al centro, y es **el mismo en todos los estados**; lo que cambia es la forma negra que SwiftUI dibuja dentro. `collectionBehavior = [.canJoinAllSpaces, .stationary]`, `styleMask = [.borderless, .nonactivatingPanel]`, `canBecomeKey = true`.
- Geometría del notch: `notchSize = (frame.width − auxTopLeft.width − auxTopRight.width) × safeAreaInsets.top` (aquí alto 32, barra de menús 33).
- El compacto se centra respecto al notch aunque leading y trailing midan distinto (`offset` de `(trailing − leading) / 2`). Cada lado recibe 8 pt de margen exterior; el alto útil es el del notch.
- En compacto, el hover agranda la forma al alto de la barra de menús (`menubarHeight`).

## Expandir por hover / clic / cerrar
- **No hay expansión automática.** `hoverBehavior` solo hace: `keepVisible` (un `hide()` se pospone mientras el puntero esté encima), `hapticFeedback`, `increaseShadow`. Ninguno cambia compact↔expanded.
- Entonces: **hover/clic → la app llama a `expand(on:)`**, con `.onHover` o `.onTapGesture` dentro de `compactLeading/Trailing`; **cerrar → botón o `.onExitCommand`/temporizador que llama a `compact(on:)`** (o `hide()`).
- Para cerrar al sacar el puntero se puede observar `notch.isHovering` (es `@Published`, `public private(set)`) y llamar a `compact()` al pasar a `false`.
- ⚠️ **No verificado empíricamente:** que `.onTapGesture`/`.onHover` reciban eventos dentro del panel compacto. No pude inyectar mouse (requiere permiso de Accesibilidad) ni capturar pantalla. La ruta es la prevista por el código (`NotchView` aplica `.onHover(perform: updateHoverState)` al contenedor), pero **FN-009 debe probarlo con el mouse real** antes de asumirlo.

## Comportamiento sin notch o con monitor externo como principal
Corrida con el externo (sin notch) como objetivo (`style: .auto`):

| Llamada | Resultado observado |
|---|---|
| `compact(on: externo)` | Retorna en ~0 s, **`windowController == nil`: no se muestra nada** |
| `expand(on: externo)` | Panel **flotante** (no forma de notch), frame `(−600, 1496, 960×540)` = mitad de pantalla, arriba al centro; desliza hacia abajo desde la barra de menús con fondo `VisualEffectView(.popover)` y radio 20 |
| `compact()` estando expandido | Se oculta (no hay compacto) → `frame == nil` |
| `hide()` | Ventana destruida |

Por qué (código): `style == .auto` decide por pantalla con `hasNotch = auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil`; si es `.floating`, `_compact` llama a `hide()` (documentado en el header: *"floating style does not support compact mode"*). Forzar `.floating` en la pantalla con notch produce lo mismo.

Datos de entorno de esta máquina que importan:
- `NSScreen.screens[0]` = integrada (con notch, barra de menús 33 pt); `NSScreen.main` = el externo (el que tiene el foco). **Usar `screens[0]` para la barra de menús, nunca `main`.** Si el usuario pone el externo como pantalla principal en Ajustes, `screens[0]` es el externo → sin compacto.
- Alto del notch de reserva en pantallas sin notch: `notchFrameWithMenubarAsBackup` usa 300 pt de ancho × alto de la barra de menús.

### Riesgos detectados leyendo el código (no reproducidos)
1. `observeScreenParameters()` reacciona a `didChangeScreenParametersNotification` y llama `initializeWindow(screen: NSScreen.screens.first)` **sin comprobar el estado**: tras conectar/desconectar un monitor puede recrearse la ventana en `screens[0]` aunque estuviera oculta o en otra pantalla. Probar en FN-011 conectando/desconectando el externo.
2. El panel es de media pantalla y está a nivel `.screenSaver`: hay que confirmar que las zonas transparentes **no bloquean clics** hacia otras apps (esperable para píxeles con alpha 0, pero no probado aquí).
3. Cada `DynamicNotch` escucha cambios de pantalla en una `Task` que nunca se cancela: crear instancias nuevas repetidamente las acumula. Crear **una sola** y reutilizarla.

## Implicaciones para el producto
- **Con notch:** usar `compact(on: screens[0])` con marcador/puntos a izquierda y derecha; expandir por hover o clic; cerrar con `compact()`.
- **Sin notch (o externo principal):** la librería no da compacto. Para el MVP, el fallback debe ser **solo expandido** (`expand()` flotante, abierto con un `NSStatusItem` o atajo) o un indicador propio en la barra de menús. Decisión pendiente de FN-009/FN-011; hay que ponerla en la spec.
- Aislar todo en `App/Notch/` (como dice el ADR 0002): los riesgos 1 y 3 se pueden mitigar ahí o, en el peor caso, sustituir por un `NSPanel` propio.

## Evidencia pendiente / limitaciones del spike
- Sin capturas: `screencapture` falló (`could not create image from display`, sin permiso de grabación de pantalla). La descripción de arriba sale de logs de frames de ventana y del código fuente.
- Hover y clic reales: sin verificar (ver arriba).
- Prototipo en `$CLAUDE_JOB_DIR/tmp/spike` (no versionado); el snippet de este doc es su versión reducida.
