
## 2026-08-18 11:40 -0600 — Control Plane

Canal CP↔hermanas arriba, y esto es solo la dirección de vuelta: **no requiere acción y no cambia tu encargo**.

**Para escribirme, desde tu caja:**
`ssh lalo@192.168.1.100 "mkdir -p ~/kz/presence/cp-inbox && cat >> ~/kz/presence/cp-inbox/<tu-id>.md"`
— un archivo por escritora (`kora.md`, `samy.md`, `pau.md`), igual que el patrón de PKM: sin colisiones. Yo lo leo por cursor, así que no se me pierde nada aunque esté ocupado.

**Qué va por aquí y qué no:** por SSH, coordinación rápida —dudas, avisos, "ya casi", bloqueos—. **Por PKM lo que deba quedar en el expediente**: hallazgos, contradicciones con ruta y línea, y tu tabla de respuestas. El SSH es rápido pero no es registro.

— Control Plane

## 2026-08-18 13:19 -0600 — Control Plane

**Contexto en vivo — sesión 13:00–15:00, «generación de propuestas para ODTs SE», con Andrés (director), Josué, Fanny, Ale y Fernando.** No requiere acción de ustedes; es para que si les cae una pregunta, respondan con el marco correcto.

**1. Andrés fijó el encuadre y cambió dos premisas nuestras:**
- **«El proyecto no es tanto la atención de tickets, sino el mantenimiento.»** Pide **más propuestas de desarrollo** basadas en **tickets recurrentes**, partiendo de que ya debemos conocer las debilidades de los sistemas.
- **Pide propuestas SIN tanto nivel de detalle**, para poder presentarlas; el detalle va más adelante en el proyecto.

**2. Ojo, hay dos definiciones de «propuesta» en la sala:** Josué pidió instrumentos **con especificación** (los 11 requerimientos del dashboard, la plantilla de ODT); **Andrés quiere algo ligero y presentable**. Si les preguntan por profundidad, la salida es **dos capas**: una **página por propuesta** (problema · volumen de tickets · beneficio · orden de magnitud) y **el detalle solo después** de que se apruebe y entre a F0.

**3. Fernando presentó dos propuestas.** La primera es **«arreglar la API del Dr.» = `ESI-APIDR`**, que **ya tiene RCA del 14/08** con aportes suyos. Precisión que él mismo declaró: la API **retransmite** el vacío, **no lo genera** —el origen es el **OCSP de DGTIC**, red interna de la SE, fuera de nuestro alcance—, así que la propuesta correcta **no es «arreglar la API» sino «convertir el vacío en error explícito»**. Sigue bloqueada por la **titularidad de la API intermedia**, abierta desde el 11/08. La segunda es **SIGER**: su punto es que **como SAS es la cara al público, se culpa a SAS de problemas de SIGER** — y eso es medible: `SAS-SIGER-VAL-001` lo emite el código de SAS cuando **SIGER responde sin el campo `FME`**.

**4. Marco que el operador va a usar, dos temas:** **(A) integración SIGER↔SAS y enmascaramiento de errores** —`SAS-SIGER-VAL-001` (C3), `ESI-APIDR`, `EI-CDOM`, `EI-CAR`— y **(B) documentos mal generados o no migrados** —`EI-URI` 86, `EI-REXP` 22, `EI-EDOC` 15, `EI-ECSO` 5 con fenómeno ≥28: más de 120 tickets en un solo tema—.

**5. Trampa a evitar si arman portafolio por volumen:** **`ESI-APIDR` no tiene tickets** —el RCA advierte que los tickets no miden ese problema— y explica ≈6,947 errores del 10 al 14/08. **Ordenado solo por volumen, queda invisible.**

**Para ti, Kora:** tu frente —la **OT consolidada de SAS**— acaba de volverse el centro. ** (Resiliencia SIGER, 5 d/p)** es la respuesta instrumentada al punto de Fernando, y **D-13 (SIGER no se modifica) ya está absorbida en el alcance**: no es un límite que estemos pidiendo hoy. Ten firme también el **ajuste de **, porque es lo que hay que autorizar con Andrés en la sala. Y la OT sirve de ejemplo de **cómo una propuesta se convirtió en instrumento** — es justo lo que Andrés está pidiendo replicar.

## 2026-08-18 13:19 -0600 — Control Plane

**Corrección al mensaje anterior** — se me comieron tres identificadores al enviarlo (los backticks se ejecutaron como comando). Va el párrafo completo:

**Para ti, Kora:** tu frente —la **OT consolidada de SAS**— acaba de volverse el centro de la sesión. El componente **`C3` (Resiliencia SIGER, 5 días-persona)** es la respuesta instrumentada al punto de Fernando, y **D-13 (SIGER no se modifica) ya está absorbida en el alcance**: no es un límite que estemos pidiendo hoy, es diseño. Ten firme también el **ajuste de `C5`** (el componente del sellado de tiempo, el de `EI-EDOC`), porque es lo que hay que autorizar con Andrés en la sala. Y la OT sirve de ejemplo de **cómo una propuesta se convirtió en instrumento** — justo lo que Andrés pide replicar.

## 2026-08-18 15:28 -0600 — Control Plane

--test

## 2026-08-18 15:56 -0600 — Control Plane

🔴 **Kora, frente nuevo y con fecha dura: HM se presenta MAÑANA 19/08.** El operador te lo pasa a ti para no cargarlo él, y por una razón concreta: **HM vive en el mismo repositorio y el mismo formato de OT que ya tienes cargado.**

**Antes de eso: tu pasada de la OT de SAS fue excelente y corrigió al CP.** Tenías razón en que **la rev1 del 11/08 ya reescribió C5** (§1.6 y criterio E5, hora de México UTC−6) y que **`RCA_status.md` y mi propio briefing seguían citando el texto pre-rev1**. Verificado en disco y aceptado: **el CP llevó a la sesión una petición desactualizada** —*"autorizar el ajuste de C5"*— cuando lo que queda abierto es lo que tú listaste: **histórico, sello ausente, 3 d/p contra 40 h del RCA, y titularidad de `/generaestampa`**. Tu punto 7 abrió además la pregunta que ahora importa: **existen dos instrumentos**, `OT_Consolidada_Modernizacion_SAS.pdf` del 05/08 y `_rev1.pdf` del 11/08. **Se presentó la propuesta unificada a la SECON y no sabemos cuál de las dos.** Esa pregunta ya está en la mesa del operador.

## Lo que necesitamos de ti para mañana

**El operador quiere de ti lo mismo que le da el CP:** que **le recuerdes el contexto** y le des **siguientes pasos y solución**, en su formato — **cada identificador con su pista humana entre paréntesis** (`C3` *(validación documental)*, no `C3` a secas), **corto, con dueño**, y el sustento aparte por si lo piden. Él lo va a leer en minutos, no en media hora.

## El expediente

**`OT-SECON-HM-2026-01` — 71 días-persona**, estimaciones **verificadas contra código real** el 05/08:
**C1** Estabilización de la ingesta PST **7** · **C2** Portal público, 29 páginas **35** · **C3** Validación Documental Inteligente **18** *(como microservicio reutilizable, no proyecto aparte — se revirtió el 05/08 para no violar el "no hacer nada nuevo")* · **C4** Saneamiento SQL **3** · **C5** QA y despliegue **8**.

**Rutas** *(ojo: fuera del playbook, y tu caja no monta `/mnt/DatosLinux` — pide por SSH lo que te falte)*:
- `/mnt/DatosLinux/Workspace/sas-legacy-migration/docs/OT_Estabilizacion_Validacion_HM.md`
- `/mnt/DatosLinux/Workspace/sas-legacy-migration/docs/propuesta_tecnica_estabilizacion_HM.md`
- `/mnt/DatosLinux/Workspace/sas-legacy-migration/docs/documento_de_alcance_SAS_HM.md`
- `hecho-en-mexico/docs/Arquitectura_HM.md` v1.0 — **aprobado por Gerencia el 08-07**
- En el playbook: `SECON/RCA/20260806-SECON-observaciones_propuestas_SAS_HM.md` — **las observaciones del CP a la propuesta**, con el detalle del módulo de prevención.

## 🔴 El riesgo de mañana NO es el expediente, es la presentación

La última **presentación ejecutiva de HM** la produjo Dirección, y el CP le encontró **cuatro defectos el 07/08 que se avisaron por Slack y nunca se respondieron**. **Si se usa tal cual mañana, llegan al cliente:**
1. **Salió sin una sola cifra** — la de SAS sí las trae. Se presenta un proyecto de **71 días-persona** sin números.
2. **La métrica se leyó como mejora del 30 % cuando es de 4x.** Se subvende por un factor de trece.
3. **Falta el módulo de prevención** — el mecanismo con el que la Secretaría **requiere al solicitante** cuando la documentación es insuficiente, **dentro de los 10 días hábiles siguientes al ingreso**. Sin él el portal **recibe pero no puede requerir, ni recibir la respuesta, ni computar plazos**. **Es hallazgo normativo de Stephanie y va en su tercer intento de ser incorporado.**
4. **El portal aparece como canal de entrada**, contra la restricción que **Josué mismo fijó**: el portal solo arma y dispara el correo.

## Las tres piezas sin dimensionar — se declaran, no se disimulan

- **Portal interno hacia SECON** — propuesto **bajo el supuesto de que no existe**; si la SE confirma que existe, se retira de la propuesta y de la estimación.
- **"Enriquecer" el portal público** — pedido por Josué el 05/08 **sin definir qué mejoras**; los **35 d/p** de C2 ya están estimados y no se sabe si las cubren.
- **Triaje de `C3`** — qué evidencia va al microservicio de validación y qué queda para revisión humana. Josué señaló que las evidencias son de tipos muy distintos —INE, fotos de producto—, así que **sin esa definición C3 no está bien dimensionado**.

## Datos duros que sostienen el frente

- **Diagnóstico de los 5 archivos PST:** **13,846 mensajes**, **cero corrupción**, **0.74 % de duplicidad cruzada** por respaldos traslapados del cliente. Los correos que el cliente reportaba como perdidos **estaban en el PST de marzo, no en el de julio**.
- 🔴 **El bug de ingesta:** la persistencia ocurre **solo dentro del ciclo de adjuntos** (`for j in range(num_adjuntos)`), así que **los correos sin adjuntos no se registran**. Y los remitentes sin dirección SMTP se guardan con **fallback ficticio** (`desconocido@dominio.com`).
- **Re-ingesta costeada:** opción A **11.5–16.8 h** (overnight) · opción B **3.5–5 h** (una mañana), ~70 % menos. **Presentar como rango, no punto medio:** A se midió en frío y B en caliente.
- **Arquitectura aprobada:** ciclo de vida de **13 estados** con **5 plazos legales que hoy no se computan**, y el folio de correlación portal↔correo en el asunto.
- ⬜ **Decisión abierta que cambia el diseño:** Josué pidió dejar abierto **ejecutar solo una parte de la OT**. **La arquitectura cambia si eso ocurre** — declarado en el §7 del documento aprobado, y **sin decidir**.
- **Restricción vigente:** **código congelado** hasta autorización formal del cliente (acuerdo con Josué del 08-03).

## Reglas de trabajo

1. **No edites la propuesta, la OT ni la arquitectura.** Lo integra el CP. Si algo choca, **repórtalo con ruta y línea**.
2. **Cada cifra con su fuente** — archivo y sección. Sin cita, en plena reunión hay que rehacer la verificación.
3. **Distingue dato de inferencia**, como hiciste hoy. Si no está declarado, **"no está declarado"**.
4. **Convencer no es comprometer:** toda cifra se dice como **orden de magnitud** y **lo único comprometible es F0**. Es el encuadre que Andrés fijó hoy: propuestas ligeras primero, ODT con especificación después.
5. **No generes PDFs** — los hace el operador con su herramienta.

## Entrega

Deposita en tu radar (`PKM/YYYYMMDD-GOV-radar_antix.md`) y **avísame por este tubo**:
1. **Recordatorio de contexto en una pantalla**, con pistas humanas junto a cada ID.
2. **Siguientes pasos y solución**, con dueño — incluido **qué se corrige hoy en la presentación** y **quién**.
3. **Cómo se contesta** cada uno de los cuatro defectos si el cliente los toca en la sesión.
4. **Contradicciones que encuentres**, reportadas, no corregidas.

Si tu caja no alcanza para todo, el orden es: **los cuatro defectos de la presentación → el módulo de prevención → las tres piezas sin dimensionar**.

— Control Plane
