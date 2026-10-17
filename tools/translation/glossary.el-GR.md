# Glossary English -> Greek (el-GR), Inventory Planning

One Greek term per English concept. The app's Greek UI (`app/Translations/Inventory Planning.el-GR.xlf`,
303 units, missing=0 broken=0 on 2026-10-17) uses exactly these terms. Style: formal, sentence case
(as the sibling replenishment apps); field ToolTips start with "Καθορίζει ..."; action ToolTips use the
formal imperative ("Ανοίξτε ...", "Υπολογίστε ..."). Placeholders (%1, %2%%), the AL progress-dialog
text (`\#1#########`), codes in capitals (EOQ, ROP, SS, RQ, ADI, SKU, OK) and names (Wilson,
Syntetos-Boylan, GMSoft, Planning-Get Parameters) stay unchanged.

Sources: [CA] verified glossary of Cost Accounting Production Costing
(`20-In-Development/Cost Accounting Production Costing/source/tools/translation/glossary.el-GR.md`);
[SL] Shelf-Life Aware Replenishment el-GR XLF and glossary; [DFR] Demand Forecast Replenishment el-GR XLF
(same planning domain, already translated); [ABC] ABC Inventory Analysis el-GR XLF; [IP] decision made
for this app (no Greek Microsoft Learn page exists for these BC planning terms: the el-gr URL of
"Design details: Planning parameters" serves the English text, checked 2026-10-17).

## Business Central standard terms

| English | Greek | Evidence |
|---|---|---|
| item / Item No. / Item Card | είδος / Αρ. είδους / Καρτέλα είδους | [CA], [SL], [DFR] |
| inventory item (Type = Inventory) | είδος αποθέματος | [IP] |
| Reordering Policy | πολιτική αναπαραγγελίας | [DFR] Current Reordering Policy |
| Fixed Reorder Qty. / Maximum Qty. / Order / Lot-for-Lot | Σταθερή ποσ. αναπαραγγελίας / Μέγιστη ποσ. / Παραγγελία / Παρτίδα προς παρτίδα | [DFR] |
| Reorder Point | σημείο αναπαραγγελίας | [DFR] |
| Reorder Quantity | ποσότητα αναπαραγγελίας | [DFR] (Reorder Qty.) |
| Safety Stock (Quantity) | απόθεμα ασφαλείας (Ποσότητα αποθέματος ασφαλείας) | [DFR] |
| Maximum Inventory | μέγιστο απόθεμα | [DFR] |
| Order Multiple | Πολλαπλάσιο παραγγελίας | [DFR] (Order Multiple/Batch Size) |
| Minimum / Maximum Order Quantity | ελάχιστη / μέγιστη ποσότητα παραγγελίας | [DFR] Min Order Quantity |
| Lead Time Calculation / lead time | Υπολογισμός χρόνου παράδοσης / χρόνος παράδοσης | [DFR] Lead Time (Days) |
| Manufacturing Policy: Make-to-Order / Make-to-Stock | πολιτική παραγωγής: Παραγωγή κατά παραγγελία / παραγωγή για απόθεμα | [IP] |
| Stockkeeping Unit (SKU) | μονάδα αποθήκευσης (SKU) | [IP]; [ABC] keeps "SKU" |
| Expiration Calculation / shelf life | Υπολογισμός λήξης / διάρκεια ζωής | [SL] |
| Unit Cost / Standard Cost / Last Direct Cost | Κόστος μονάδας / Πρότυπο κόστος / Τελευταίο άμεσο κόστος | [DFR], [CA] |
| consumption (production, assembly) | ανάλωση | [SL] |
| purchase receipt | παραλαβή αγοράς | [SL] receipt = παραλαβή |
| blocked (item) | αποκλεισμένο | [DFR] "Το είδος είναι αποκλεισμένο" |
| Job Queue Entry; On Hold; Ready | εγγραφή ουράς εργασιών; σε αναμονή; Έτοιμο | [SL] Job Queue Entries |
| work date | ημερομηνία εργασίας | [IP] |
| Entry No. / User ID / Primary Key | Αρ. εγγραφής / Αναγνωριστικό χρήστη / Πρωτεύον κλειδί | [DFR] |
| Setup (page, action) | Ρύθμιση | [SL] |
| planning worksheet | φύλλο εργασίας προγραμματισμού | [ABC] Φύλλο Εργασίας, [SL] Φύλλο εργασίας αιτήσεων |
| planning engine | μηχανή προγραμματισμού | [IP] |
| supply (supply order pegged to demand) | εφοδιασμός | [IP]; kept apart from "supply values" (παροχή) |

## App-specific terms

| English | Greek | Evidence |
|---|---|---|
| Inventory Planning (app name, used as a feature name) | Προγραμματισμός αποθέματος | [IP]; the German file also translates it (Bestandsplanung) |
| Inventory Planning - Admin / - User | Προγραμματισμός αποθέματος - Διαχειριστής / - Χρήστης | [IP] |
| calculator / calculation | υπολογισμός | [IP] |
| calculation log | αρχείο καταγραφής υπολογισμών | [DFR] Calculation Log |
| log (verb) | καταγράφω | [IP] |
| demand / demand pattern | ζήτηση / μοτίβο ζήτησης | [DFR] |
| Smooth / Erratic / Intermittent / Lumpy | Ομαλή / Ακανόνιστη / Διαλείπουσα / Σποραδική | [DFR] |
| demand observations | παρατηρήσεις ζήτησης | [DFR] |
| Average Demand Interval (ADI) | μέσο διάστημα ζήτησης (ADI) | [DFR] |
| CV² / coefficient of variation | CV² / συντελεστής μεταβλητότητας | [DFR] |
| standard deviation | τυπική απόκλιση | [DFR] |
| Z-score | βαθμός Z | [DFR] |
| service level (cycle service level) | επίπεδο εξυπηρέτησης (κύκλου) | [DFR] |
| history window | παράθυρο ιστορικού | [DFR] Demand History Window |
| trailing / full-window average | τελευταίες N ημέρες / μέσος όρος όλου του παραθύρου | [IP] |
| trend (warning) | τάση (προειδοποίηση τάσης) | [DFR] Demand Trend |
| phase-out | σταδιακή απόσυρση | [IP] |
| EOQ / economic order quantity | EOQ (feminine: η EOQ) / οικονομική ποσότητα παραγγελίας | [DFR] Προτεινόμενη EOQ |
| raw (result, EOQ) | αρχικό / αρχική | [IP] |
| cap / capped | ανώτατο όριο / περιορίστηκε | [IP] |
| ordering cost (S) | κόστος παραγγελίας (S) | [DFR] |
| holding cost / holding rate | κόστος διατήρησης / συντελεστής κόστους διατήρησης | [DFR] |
| order-up-to level | επίπεδο αναπλήρωσης | [IP] |
| fallback (lead time, setup fallback) | εφεδρικός / εφεδρική τιμή της ρύθμισης | [IP] |
| proposal / proposed | πρόταση / προτεινόμενος | [DFR] |
| apply / applied / Apply Selected | εφαρμογή / εφαρμόστηκε / Εφαρμογή επιλεγμένων | [IP] |
| write (a value to an item field) | μεταφορά / μεταφέρω (Write EOQ to Item = Μεταφορά EOQ στο είδος) | [IP]; avoids "εγγραφή" (entry) and "καταχώριση" (posting) |
| EOQ Write Target | πεδίο-στόχος μεταφοράς EOQ | [IP] |
| auto-update | αυτόματη ενημέρωση | [DFR] |
| policy advisor / advise / advice | σύμβουλος πολιτικής / συμβουλή | [DFR] Policy Advisor; [IP] advice kept apart from recommendation |
| recommend / recommendation / recommended | σύσταση / συνιστώμενος | [DFR] Recommended Policy, Policy Recommendation |
| Run All / Calculate All | Υπολογισμός όλων | [IP] |
| supply values at planning time / dynamic supply | παροχή τιμών κατά τον προγραμματισμό / δυναμική παροχή | [IP] |
| excluded / skipped | εξαιρείται / παραλείπεται, παράλειψη | [IP] |
| result code / outcome | κωδικός αποτελέσματος / έκβαση | [IP] |
| standing stock | μόνιμο απόθεμα | [IP] |
| stockout | εξάντληση αποθέματος | [DFR] |
| exception workbench / manufacturing suite | πάγκος εργασίας εξαιρέσεων / σουίτα παραγωγής | [IP] |
| Planning Engine Integration | Ενοποίηση με τη μηχανή προγραμματισμού | [IP] |

## Open points

- "%1 item(s)" is rendered "%1 είδος(-η)", "line(s)" "γραμμή(-ές)", "day(s)" "ημέρα(-ες)".
- "Make-to-Order" and "Make-to-Stock" are [IP] decisions; check them against a Greek BC client if one becomes available.
