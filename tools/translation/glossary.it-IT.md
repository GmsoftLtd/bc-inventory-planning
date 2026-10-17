# Glossary it-IT - Inventory Planning

Italian (Italy) terminology used in `app/Translations/Inventory Planning.it-IT.xlf`.
One Italian term per English concept. Formal register; ToolTips start with "Specifica ...", action ToolTips in the
third person ("Calcola ...", "Apre ..."), confirmations and instructions impersonal ("Impostare ...", "vedere ...").

Sources:
- **BC-IT**: Microsoft Learn, Italian Business Central pages under `https://learn.microsoft.com/it-it/dynamics365/business-central/`
  (checked 2026-10-17): `setup-best-practices-reordering-policies`, `design-details-planning-parameters`. Partly
  machine-translated and inconsistent (e.g. "Metodo/Politica/Criterio di riordino"); the bold UI caption wins.
- **CAPC**: verified Italian glossary of the Cost Accounting Production Costing app
  (`20-In-Development/Cost Accounting Production Costing/source/tools/translation/glossary.it-IT.md`).
- **INV-IT**: standard Italian inventory-management vocabulary (gestione delle scorte, formula di Wilson).
- **App**: app-specific choice, used everywhere.

## Business Central standard terms

| English | Italian | Evidence |
|---|---|---|
| Item / Item Card / Item No. | articolo / scheda articolo / Nr. articolo | BC-IT (**Scheda articolo**); CAPC |
| inventory item | articolo di magazzino | BC Item Type "Magazzino" |
| Reordering Policy | Metodo di riordino | BC-IT reordering-policies (**Metodo di riordino**) |
| Fixed Reorder Qty. | Qtà riordino fissa | BC-IT (**Qtà riordino fissa**) |
| Maximum Qty. | Qtà massima | BC-IT (**Qtà massima**) |
| Order (policy) | Ordine | BC-IT (**Ordine**) |
| Lot-for-Lot | Lotto-per-lotto | BC-IT (**Lotto-per-Lotto**; sentence case used) |
| Reorder Point | Punto di riordino | BC-IT planning-parameters ("Punto riordino", "punto di riordino") |
| Reorder Quantity | Quantità di riordino | BC-IT ("Qtà Riordino", "quantità di riordino") |
| Safety Stock Quantity / safety stock | Quantità scorta di sicurezza / scorta di sicurezza | BC-IT ("Quantità di scorta di sicurezza", "scorta di sicurezza") |
| Maximum Inventory | Giacenza massima | BC-IT ("Qtà Massima più Giacenza massima") |
| Order Multiple | Molteplicità ordine | BC-IT ("Molteplicità ordine") |
| Minimum / Maximum Order Quantity | Quantità minima ordine / Quantità massima ordine | BC-IT |
| Make-to-Order / Make-to-Stock | produzione su ordine (option **Prod. su ordine**) / produzione per magazzino | BC-IT planning-parameters (**Prod. su ordine**, **Prod. per magazzino**) |
| Manufacturing Policy | Criterio di produzione | BC-IT (**Criteri di produzione**) - singular used |
| lead time / Lead Time Calculation | lead time / Calcolo lead time | BC-IT ("lead time"); field caption not shown on Learn (see doubts) |
| Expiration Calculation | Calcolo scadenza | BC UI caption (not verified on Learn) |
| Stockkeeping Unit | SKU | BC-IT (page **SKU**) |
| Planning Worksheet | Prospetto pianificazione | BC-IT ("prospetto di pianificazione") |
| supply / demand | approvvigionamento / domanda | BC-IT |
| Last Direct Cost / Standard Cost / Unit Cost | Ultimo costo diretto / Costo standard / Costo unitario | BC UI; CAPC |
| purchase receipt | carico acquisto (storico carichi) | BC UI (Carichi acquisti registrati) |
| consumption | consumo | BC UI |
| Job Queue Entry / Ready / On Hold | movimento coda processi / Pronto / In attesa | CAPC; BC UI status |
| Setup | Setup | CAPC |
| Entry No. / User ID | Nr. movimento / ID utente | BC UI |
| work date / local currency | data di lavoro / valuta locale | BC UI |
| Blocked | bloccato | BC UI |
| shelf life | durata di conservazione | INV-IT |
| Permission set captions Admin / User | Amministratore / Utente | App |

## Inventory-planning / statistics terms

| English | Italian | Evidence |
|---|---|---|
| Inventory Planning (app name / module) | Pianificazione scorte | App |
| EOQ / economic order quantity | EOQ / quantità economica di ordine (feminine: "la EOQ") | INV-IT; acronym kept |
| Wilson formula | formula di Wilson | INV-IT |
| holding cost / holding rate | costo di mantenimento / tasso di mantenimento | INV-IT; BC-IT ("costi di mantenimento") |
| ordering cost | costo di ordinazione | INV-IT |
| service level / cycle service level | livello di servizio / livello di servizio di ciclo | INV-IT |
| stockout | rottura di stock | INV-IT |
| Z-score | punteggio Z | INV-IT |
| standard deviation | deviazione standard | INV-IT |
| CV² / squared coefficient of variation | CV² / quadrato del coefficiente di variazione | INV-IT |
| ADI / Average Demand Interval | ADI / intervallo medio tra domande | INV-IT; acronym kept |
| demand pattern | profilo di domanda | App |
| Smooth / Erratic / Intermittent / Lumpy | Regolare / Erratica / Intermittente / Irregolare | App (Syntetos-Boylan); feminine, agrees with "domanda". "Irregolare" = lumpy only, never erratic |
| Unknown (pattern) | Sconosciuto | App |
| demand observations | osservazioni di domanda | App |
| history window | finestra storica | App |
| trailing N-day demand | domanda degli ultimi N giorni | App |
| trend warning | avviso di tendenza | App |
| phase-out / ramp | dismissione / aumento | App |
| fallback (lead time / setup value) | di riserva (lead time di riserva, valore di riserva del setup) | App |
| buffer (safety stock) | margine | App |
| standing stock | scorte permanenti | App |
| order-up-to level | livello di ripristino | App |
| cap / capped | limite / limitato | App |
| raw (EOQ / result) | non rettificato | App |
| skip / skipped | ignorare / ignorato | App |
| calculation log | registro calcoli; "log" (verb) = annotare nel registro. Never "registrare" (reserved for posting) | App |
| calculator | calcolo | App |
| Policy Advisor / policy advice / advise | consulente metodi di riordino / consiglio sul metodo / consigliare | App; kept distinct from "raccomandazione" |
| recommend / recommendation / recommended policy | raccomandare / raccomandazione / metodo raccomandato | App |
| proposal | proposta | App |
| apply / applied / Apply Selected | applicare / applicato / Applica selezionati | App |
| write (value to item) | scrivere (nell'articolo) | App |
| Run All (all calculators) | calcolo completo; action "Calcola tutto" | App |
| Dynamic Supply / at planning time | fornitura dinamica / al momento della pianificazione | App ("supply" here = providing values, not BC approvvigionamento) |
| planning engine | motore di pianificazione | App |
| Result Code / OK / Error | Codice risultato / OK / Errore | App |
| exception workbench | banco di lavoro eccezioni | App |
| GMSoft manufacturing suite | suite di produzione GMSoft | App |

## Names kept unchanged

Business Central, GMSoft, EOQ, ADI, CV², OK, SKU, ABC, Syntetos-Boylan, Planning-Get Parameters (BC codeunit name), the
formula abbreviations ROP, SS, RQ, LT, D, Z, s, n, and the progress-dialog placeholders `#1#########` / `#2#########`.
Abbreviations translated: d (days) = g, obs. = oss.

## Doubts

- "Calcolo lead time", "Calcolo scadenza" and "Molteplicità ordine" are BC captions as remembered/seen on Learn prose; not confirmed in the Italian UI.
- "Irregolare" for Lumpy and "Regolare" for Smooth: no Microsoft source; Italian literature often keeps the English terms.
