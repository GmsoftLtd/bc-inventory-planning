# Glossary - French (France), fr-FR

Inventory Planning by GMSoft. One French term per English concept; use it everywhere.

Sources:
- **MS-BC**: Microsoft Learn, Business Central documentation in French (learn.microsoft.com/fr-fr/dynamics365/business-central/...): design-details-planning-parameters, setup-best-practices-reordering-policies, setup-best-practices-planning-parameters, inventory-how-register-new-items.
- **CAPC**: verified glossary of the Cost Accounting Production Costing app (20-In-Development/Cost Accounting Production Costing/source/tools/translation/glossary.fr-FR.md).
- **BC UI**: standard Business Central fr-FR field/option captions.
- **SCM**: usual French supply-chain / inventory-management vocabulary; app-specific choice.

## Business Central standard terms

| English | French | Evidence |
|---|---|---|
| Reordering Policy | Méthode de réapprovisionnement | MS-BC setup-best-practices-reordering-policies (**Méthode réapprovisionnement**) |
| Policy (short for reordering policy) | Méthode | follows the above |
| Reorder Point | Point de commande | MS-BC setup-best-practices-planning-parameters (**Point de commande**) |
| Reorder Quantity | Quantité de réapprovisionnement | MS-BC design-details-planning-parameters ("Quantité de réappro.") |
| Safety Stock / Safety Stock Quantity | Stock de sécurité / Quantité de stock de sécurité | MS-BC setup-best-practices-planning-parameters |
| Maximum Inventory | Stock maximum | MS-BC design-details-planning-parameters |
| Fixed Reorder Qty. | Qté fixe de commande | MS-BC setup-best-practices-reordering-policies |
| Maximum Qty. | Qté maximale | MS-BC setup-best-practices-reordering-policies |
| Order (policy) | Commande | MS-BC same page |
| Lot-for-Lot | Lot pour lot | MS-BC same page |
| Minimum / Maximum Order Quantity | Qté minimum commande / Qté maximum commande (running text: quantité minimum/maximum commande) | MS-BC same page |
| Order Multiple | Commandé par | MS-BC same page |
| Make-to-Order / Make-to-Stock | Fabrication à la commande / Fabrication sur stock | MS-BC design-details-planning-parameters |
| Manufacturing Policy | Méthode de fabrication | BC UI |
| Stockkeeping Unit (SKU) | Point de stock | MS-BC setup-best-practices-planning-parameters ("fiches point de stock") |
| Location | Magasin | MS-BC (**Code magasin**) |
| Lead Time Calculation | Délai de réapprovisionnement | BC UI (Item field) |
| Lead time (generic) | Délai | MS-BC ("délai de sécurité") |
| Expiration Calculation | Calcul d'expiration | BC UI |
| Unit Cost / Last Direct Cost / Standard Cost | Coût unitaire / Dernier coût direct / Coût standard | CAPC; BC UI |
| Item / inventory item | Article / article stocké | CAPC; MS-BC |
| Item No. / Description / User ID / Entry No. | N° article / Désignation / Code utilisateur / N° séquence | BC UI |
| Setup | Paramètres | CAPC |
| Job Queue Entry | Écriture file d'attente des travaux | CAPC |
| Ready / On hold | Prêt / en attente | BC UI |
| Work date | Date de travail | BC UI |
| Local currency (LCY) | Devise société | BC UI |
| Holding cost | Coût de possession | MS-BC setup-best-practices-supply-planning ("coûts de possession") |
| Stockout | Rupture de stock | MS-BC setup-best-practices-supply-planning |
| Primary Key | Clé primaire | BC UI |

## App-specific terms

| English | French | Evidence |
|---|---|---|
| Inventory Planning (app/module name) | Planification des stocks | SCM, app choice |
| Inventory Planning Worksheet / Planning Worksheet (app page) | Feuille de planification des stocks / Feuille de planification | App choice; kept apart from BC's own "Feuille planning" |
| Calculation Log | Journal des calculs | App choice |
| Log entry | Écriture (du journal) | BC style |
| Calculator | Module de calcul | App choice |
| Policy Advisor / advise / policy advice | Conseiller en méthode / conseiller / conseil de méthode | App choice |
| Apply / applied | Appliquer / appliqué | App choice |
| Write (a value) to the item | Reporter (sur l'article / dans le champ) | App choice |
| Write target (EOQ) | Champ cible | App choice |
| Run All (calculate all values) | Calcul complet / Calculer toutes les valeurs de planification | App choice |
| Demand / demand pattern | Demande / profil de demande | SCM |
| Smooth / Erratic / Intermittent / Lumpy | Régulière / Erratique / Intermittente / Sporadique (Unknown = Inconnue) | SCM (Syntetos-Boylan classification); feminine, agrees with "demande" |
| Average Demand Interval (ADI) | Intervalle moyen entre demandes (ADI) | SCM |
| Coefficient of variation (CV²) | Coefficient de variation (CV²) | SCM |
| Standard deviation | Écart type | SCM |
| Observations | Observations | SCM |
| History window | Fenêtre d'historique | App choice |
| Fallback (lead time / setup fallback) | Délai de secours / valeur de secours des paramètres | App choice |
| Ordering cost | Coût de passation de commande | SCM |
| Holding rate | Taux de possession | SCM |
| Service level / cycle service level | Niveau de service / niveau de service par cycle | SCM |
| Z-score | Score Z | SCM |
| Order-up-to level | Niveau de recomplètement | SCM |
| Cap / capped | Plafond / plafonné | App choice |
| Shelf life | Durée de conservation | SCM |
| Standing stock | Stock permanent | App choice |
| Planning engine / at planning time | Moteur de planification / au moment de la planification | App choice |
| Dynamic Supply (calculation type) | Valeur dynamique fournie | App choice |
| Skip / skipped | Ignorer / ignoré | App choice |
| Trend warning / ramp / phase-out | Avertissement de tendance / montée en charge / arrêt progressif | App choice |
| Exception workbench | Poste de traitement des exceptions | App choice |
| Purchase receipt history | Historique des réceptions achat | BC style |
| Wilson formula | Formule de Wilson | SCM |

## Kept unchanged

EOQ, ROP, SS, RQ, LT, D, Z, ADI, CV², S (Wilson symbol), OK, ABC, GMSoft, Syntetos-Boylan, the event name "Planning-Get Parameters", progress-dialog tokens (#1, #2). EOQ is expanded once as "quantité économique de commande (EOQ)" in ToolTips; it is treated as feminine (l'EOQ calculée, EOQ proposée).
