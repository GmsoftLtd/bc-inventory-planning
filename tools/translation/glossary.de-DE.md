# Glossary English -> German (de-DE), Inventory Planning

One German term per English concept; used everywhere in `app/Translations/Inventory Planning.de-DE.xlf`.
Style: formal "Sie"; field ToolTips "Gibt ... an."; action ToolTips as "Sie" imperatives
("Öffnen Sie ...", "Berechnen Sie ..."); confirmations as questions; "must / cannot" kept strict
("muss", "kann nicht", "nicht anwendbar").

Sources: [L] Microsoft Learn de-de, Business Central, checked 2026-10-17:
design-details-planning-parameters (Planungsparameter), inventory-how-to-set-up-stockkeeping-units;
[G] shared glossary `20-In-Development/Cost Accounting Production Costing/source/tools/translation/glossary.de-DE.md`;
[NAV] long-standing German NAV/BC UI captions; [LIT] standard German inventory-management literature
(Syntetos-Boylan demand classification, Wilson/Andler EOQ formula).

## Business Central standard terms

| English | German | Evidence |
|---|---|---|
| Item / Item No. / Description | Artikel / Artikelnr. / Beschreibung | [G] [L] |
| Inventory item / Not an inventory item | Lagerartikel / Kein Lagerartikel | [NAV] Item Type "Lager" |
| Blocked | Gesperrt | [G] |
| Entry No. / User ID / Primary Key | Lfd. Nr. / Benutzer-ID / Primärschlüssel | [G] [NAV] |
| Unit Cost / Standard Cost / Last Direct Cost | Einstandspreis / Einstandspreis (fest) / Letzter EK-Preis | [G] [NAV] item card |
| Reordering Policy | Wiederbeschaffungsverfahren | [L] planning parameters |
| Fixed Reorder Qty. / Maximum Qty. / Order / Lot-for-Lot | Feste Bestellmenge / Auffüllen auf Maximalbestand / Auftrag / Los-für-Los | [L] planning parameters |
| Reorder Point | Meldebestand | [L] planning parameters |
| Reorder Quantity | Bestellmenge | [L] |
| Safety Stock (Quantity) | Sicherheitsbestand (Sicherheitsbestandsmenge) | [L] |
| Maximum Inventory | Maximalbestand | [L] |
| Minimum / Maximum Order Quantity | Minimale Losgröße / Maximale Losgröße | [L] |
| Order Multiple | Losgrößenrundungsfaktor | [L] |
| Manufacturing Policy: Make-to-Stock / Make-to-Order | Produktionsart: Lagerfertigung / Auftragsfertigung | [L] |
| Lead time / Lead Time Calculation | Beschaffungszeit (field "Beschaffungszeit") | [NAV] item card |
| Expiration Calculation | Ablaufdatumsformel | [NAV] item card |
| Stockkeeping Unit (SKU) | Lagerhaltungsdaten | [L] SKU page ("Lagerhaltungsdaten vorhanden") |
| Planning Worksheet (BC page) | Planungsvorschlag - not used for this app's own page (see below) | [L] |
| Supply / demand | Vorrat / Bedarf | [L] |
| Consumption | Verbrauch | [NAV] |
| Item Card | Artikelkarte | [L] |
| Work date | Arbeitsdatum | [G] |
| Job Queue Entry; On Hold / Ready | Aufgabenwarteschlangenposten; Wartend / Bereit | [G] [NAV] |
| Setup / General | Einrichtung / Allgemein | [G] |
| local currency | Mandantenwährung | [NAV] |
| Planning-Get Parameters (codeunit name) | kept unchanged | object name |

## App-specific concepts

| English | German | Evidence / note |
|---|---|---|
| Inventory Planning (feature, action group, captions) | Bestandsplanung | app name in AppSource listing stays English |
| Inventory Planning Setup | Bestandsplanung einrichten | pattern "X einrichten" [G] |
| Calculation Log | Berechnungsprotokoll | |
| Inventory Planning Proposal | Bestandsplanungsvorschlag | |
| Inventory Planning Worksheet / Planning Worksheet (app page) | Bestandsplanungs-Arbeitsblatt / Planungsarbeitsblatt | kept apart from BC "Planungsvorschlag" |
| calculator(s) | Berechnung(en) | |
| apply / applied (write result to item) | übernehmen / übernommen | |
| Apply Selected | Ausgewählte übernehmen | |
| Write ... to Item | ... in Artikel schreiben | |
| cap / capped / Cap Applied | Obergrenze, begrenzen / begrenzt / Begrenzung angewendet | kept apart from "apply to item" |
| demand / demand pattern | Bedarf / Bedarfsmuster | |
| Smooth / Erratic / Intermittent / Lumpy | Gleichmäßig / Erratisch / Intermittierend / Klumpig | [LIT] Syntetos-Boylan; Intermittent and Lumpy kept apart |
| Avg. Demand Interval (ADI) | Durchschn. Bedarfsintervall (ADI) | [LIT] |
| CV² / CV-Squared / squared coefficient of variation | CV² / CV-Quadrat / quadrierter Variationskoeffizient | [LIT] |
| Demand observations / obs. | Bedarfsbeobachtungen / Beob. | |
| Standard deviation / Std. Deviation | Standardabweichung | |
| Service level / cycle service level | Servicegrad / Zyklus-Servicegrad | [LIT] |
| Z-Score | Z-Wert | [LIT] |
| stockout | Fehlbestand | [LIT] |
| EOQ / economic order quantity | EOQ / wirtschaftliche Bestellmenge | acronym kept as code |
| Wilson formula | Wilson-Formel | [LIT] |
| Ordering cost (S) | Bestellkosten (S) | [LIT] |
| Holding cost / holding rate | Lagerhaltungskosten / Lagerhaltungskostensatz | [LIT] |
| Unit Cost Source / Cost Source | Herkunft Einstandspreis / Kostenherkunft | |
| EOQ Write Target | EOQ-Zielfeld | |
| order-up-to level | Auffüllniveau | |
| standing stock | Dauerbestand | |
| buffer | Puffer | |
| shelf life / perishable | Haltbarkeit | |
| History window / demand history | Zeitraum des Verlaufs / Bedarfsverlauf | |
| receipt history / purchase receipt history | Eingangsverlauf / Verlauf der Einkaufslieferungen | |
| Fallback lead time / setup fallback | Ersatz-Beschaffungszeit / Ersatzwert aus Einrichtung | |
| Trend warning / phase-out / ramp | Trendwarnung / Auslauf / Anstieg | |
| Policy Advisor | Verfahrensberater | |
| Policy Advice (calculation type) | Verfahrensempfehlung | |
| Recommended Policy / Policy Recommendation (enum) | Empfohlenes Verfahren | |
| Advise (Reordering) Policy | (Wiederbeschaffungs-)Verfahren empfehlen | |
| Dynamic Supply / supplied at planning time | Dynamische Bereitstellung / zum Planungszeitpunkt bereitgestellt | |
| planning engine | Planungsmodul | |
| Run All / Calculate All | Alle berechnen | |
| Result / Raw Result / Result Code | Ergebnis / Rohergebnis / Ergebniscode | |
| Insufficient (Demand) Data | Unzureichende (Bedarfs-)Daten | |
| Zero Demand / Ordering Cost / Result / Unit Cost | Bedarf / Bestellkosten / Ergebnis / Einstandspreis null | |
| Permission sets Admin / User | Bestandsplanung - Admin / Bestandsplanung - Benutzer | |
| exception workbench / manufacturing suite | Ausnahme-Workbench / Fertigungssuite | |

Kept unchanged: GMSoft, EOQ, ROP, SS, RQ, LT, D, ADI, CV², OK, ABC, Syntetos-Boylan, Planning-Get Parameters,
formula symbols (Z, s, n, x), placeholders and progress-dialog fields (#1#########).
Day abbreviation "d" in formula notes -> "T" (Tag).
