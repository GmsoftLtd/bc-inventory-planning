# Glossary es-ES - Inventory Planning

Spanish (Spain) terminology used in `app/Translations/Inventory Planning.es-ES.xlf`.
One Spanish term per English concept. Spain usage: "coste(s)", never "costo(s)". ToolTips start with "Especifica ...".

Sources:
- **BC-ES**: Microsoft Learn, Spanish (Spain) Business Central pages under `https://learn.microsoft.com/es-es/dynamics365/business-central/`
  (checked 2026-10-17): `design-details-planning-parameters`, `setup-best-practices-reordering-policies`,
  `setup-best-practices-planning-parameters`, `inventory-how-register-new-items`. These pages are partly machine-translated
  and mix variants; the UI caption quoted in bold on the page wins.
- **CAPC**: verified glossary of the Cost Accounting Production Costing app (`20-In-Development/Cost Accounting Production Costing/source/tools/translation/glossary.es-ES.md`).
- **INV-ES**: standard Spanish inventory-management vocabulary (gestión de stocks / modelo de Wilson).
- **App**: app-specific concept; term chosen here and used everywhere.

## Business Central standard terms

| English | Spanish (Spain) | Evidence |
|---|---|---|
| Item / Item Card / Item No. | producto / ficha de producto / Nº producto | BC-ES register-new-items (**Ficha producto**); CAPC |
| inventory item | producto de inventario | BC-ES register-new-items (Tipo **Inventario**) |
| Reordering Policy | directiva de reaprovisionamiento (caption "Directiva reaprov.") | BC-ES reordering-policies (**Directiva reaprov.**) |
| Fixed Reorder Qty. | Cdad. fija reaprov. | BC-ES reordering-policies (**Cdad. fija reaprov.**) |
| Maximum Qty. | Cdad. máxima | BC-ES reordering-policies (**Cdad. máxima**) |
| Order (policy) | Pedido | BC-ES reordering-policies (**Pedido**) |
| Lot-for-Lot | Lote a lote | BC-ES reordering-policies (**Lote a lote**) |
| Reorder Point | punto de pedido (field "Punto pedido") | BC-ES planning-parameters (field **Punto pedido**) |
| Reorder Quantity | cantidad de reaprovisionamiento | BC-ES UI caption "Cantidad reaprov." (not quoted in bold on the Learn pages read; see unsure list) |
| Safety Stock Quantity / safety stock | Cantidad de stock de seguridad / stock de seguridad | BC-ES planning-parameters ("Cantidad de stock de seguridad") |
| Maximum Inventory | inventario máximo | BC-ES reordering-policies ("nivel de inventario máximo") |
| Order Multiple | Múltiplos de pedido | BC-ES planning-parameters ("Múltiplos de pedido") |
| Minimum / Maximum Order Quantity | cantidad mínima / máxima de pedido | BC-ES planning-parameters ("Cantidad mínima pedido", "Cantidad máxima pedido") |
| Make-to-Order / Make-to-Stock | fabricación contra pedido (option "Fab. contra pedido") / fabricación contra stock | BC-ES planning-parameters ("Fab-contra-pedido", "Fab-contra-stock") |
| Manufacturing Policy | directiva de fabricación | BC-ES planning-parameters ("Directiva fabricación") |
| Lead Time Calculation (field) | Plazo entrega | BC-ES UI caption (not shown in bold on the Learn pages read; see unsure list) |
| lead time | plazo de entrega | BC-ES planning-parameters ("plazo de entrega") |
| Expiration Calculation | Cálculo de caducidad | BC-ES UI caption (unverified on Learn) |
| Stockkeeping Unit (SKU) | unidad de almacenamiento | BC-ES planning-parameters ("fichas de UA", "SKU") |
| Planning Worksheet | hoja de planificación | BC-ES register-new-items / planning-parameters ("hoja de trabajo de planificación"; UI "Hoja planificación") |
| Last Direct Cost / Standard Cost / Unit Cost | Último coste directo / Coste estándar / Coste unitario | BC-ES UI captions; CAPC (Coste unitario) |
| Job Queue Entry | movimiento de cola de proyectos | CAPC (Job Queue = cola de proyectos) |
| Ready (job queue status) | Preparado | BC-ES UI status |
| Setup | configuración | CAPC |
| Entry No. / User ID | Nº mov. / Id. usuario | BC-ES UI captions |
| work date | fecha de trabajo | BC-ES UI |
| local currency | divisa local | BC-ES UI ("DL") |
| Blocked | bloqueado | CAPC |
| Permission set captions Admin / User | Administrador / Usuario | App |

## Inventory-planning / statistics terms

| English | Spanish (Spain) | Evidence |
|---|---|---|
| Inventory Planning (app name / module) | Planificación de inventario | App |
| EOQ / economic order quantity | EOQ / cantidad económica de pedido | INV-ES; acronym kept as in English (feminine: "la EOQ") |
| Wilson formula | fórmula de Wilson | INV-ES |
| holding cost / holding rate | coste de posesión / tasa de posesión | INV-ES |
| ordering cost | coste de pedido | INV-ES |
| service level / cycle service level | nivel de servicio / nivel de servicio de ciclo | INV-ES |
| stockout | rotura de stock | INV-ES |
| Z-score | puntuación Z | INV-ES (statistics) |
| standard deviation | desviación estándar (Desv. estándar) | INV-ES |
| CV² / coefficient of variation squared | CV² / coeficiente de variación al cuadrado | INV-ES |
| ADI / Average Demand Interval | ADI / intervalo medio entre demandas | INV-ES; acronym kept |
| demand pattern | patrón de demanda | INV-ES (Syntetos-Boylan) |
| Smooth / Erratic / Intermittent / Lumpy | Suave / Errática / Intermitente / Abultada | INV-ES (Syntetos-Boylan classification); feminine, agrees with "demanda" |
| Unknown (pattern) | Desconocida | App |
| demand observations | observaciones de demanda | App |
| history window | ventana de historial | App |
| trailing / recent demand | demanda de los últimos N días / demanda reciente | App |
| trend warning | aviso de tendencia | App |
| phase-out / ramp | retirada del producto / aumento | App |
| fallback (lead time / setup value) | alternativo (plazo de entrega alternativo, valor alternativo de la configuración) | App |
| buffer (safety stock) | margen | App |
| standing stock | stock permanente | App |
| order-up-to level | nivel de reposición | App |
| cap / capped | límite / limitado | App |
| raw (EOQ / result) | sin ajustar | App |
| calculation log | registro de cálculos ("log" verb = anotar en el registro; never "registrar", reserved for posting) | App; BC-ES uses "Registro de cambios" for Change Log |
| calculator | cálculo | App |
| Policy Advisor / policy advice / advise | asesor de directivas / asesoramiento sobre directivas / asesorar sobre | App; kept distinct from "recomendación" |
| recommendation / recommended policy | recomendación / directiva recomendada | App |
| proposal | propuesta | App |
| apply / applied / Apply Selected | aplicar / aplicado / Aplicar seleccionados | App |
| write (value to item) | escribir (en el producto) | App |
| Run All (all calculators) | cálculo completo | App |
| Dynamic Supply / at planning time | suministro dinámico / en el momento de la planificación | App |
| planning engine | motor de planificación | App |
| Result Code / OK / Error | Código de resultado / OK / Error | App |
| exception workbench | área de trabajo de excepciones | App |
| GMSoft manufacturing suite | conjunto de fabricación de GMSoft | App |

## Names kept unchanged

Business Central, GMSoft, EOQ, ADI, CV², OK, Syntetos-Boylan, Planning-Get Parameters (BC codeunit name), the
formula abbreviations ROP, SS, RQ, LT, D, Z, s, n, obs., and the progress-dialog placeholders `#1#########` / `#2#########`.
