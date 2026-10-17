# Inventory Planning — User Test Manual

A manual acceptance-test script for the **Inventory Planning** app
(GMSOFT Limited, prefix `GSO`, object range 73030575–73031574).

Use it for pre-release regression, AppSource validation rehearsal, and customer
UAT. Every case is written to be run by a functional consultant in the UI — no
AL knowledge required.

- **Applies to:** Inventory Planning v1.0.0.0
- **Requires:** Business Central 2026 wave 1 (v28) or later
- **Companion:** [User Guide](user-guide.md) — behaviour reference for anything a case leaves implicit
- **Automated suite:** codeunits 50600 / 50601 (see [section 8](#8-what-the-automated-tests-already-cover))

---

## Contents

1. [How to use this manual](#1-how-to-use-this-manual)
2. [Environment and prerequisites](#2-environment-and-prerequisites)
3. [Building the test data](#3-building-the-test-data)
4. [Test cases](#4-test-cases)
5. [Result-code matrix](#5-result-code-matrix)
6. [Regression checklist (short run)](#6-regression-checklist-short-run)
7. [Defect reporting](#7-defect-reporting)
8. [What the automated tests already cover](#8-what-the-automated-tests-already-cover)

---

## 1. How to use this manual

Each case has an **ID**, a **precondition**, **steps**, and an **expected
result**. Record Pass / Fail / Blocked with the build number and date.

| Column | Meaning |
|---|---|
| **ID** | Stable reference — quote it in defect reports |
| **Priority** | **P1** must pass to ship · **P2** should pass · **P3** nice to have |
| **Type** | *Functional*, *Guard rail* (a deliberate refusal), *Integration*, *Non-functional* |

A **guard rail** case passes when the app **declines** to act and says why.
A guard-rail case that silently succeeds is a failure, not a bonus.

> **Golden rule for this app:** a calculation that cannot produce a trustworthy
> number must leave the item's existing value alone and log a result code. Any
> case where a planning field is overwritten with a wrong or empty value is P1.

---

## 2. Environment and prerequisites

| # | Item | Detail |
|---|---|---|
| E1 | Environment | A **sandbox** with the CRONUS demo company, or an empty company you can post into |
| E2 | Build | The signed `.app` under test, installed via Extension Management |
| E3 | Licence | Any BC licence permitting item journal posting |
| E4 | Permissions | Assign **GSO** (admin) to yourself; keep a second user with **GSO - User** for TC-40 |
| E5 | Work date | Note the work date — **all windows are anchored to it**, not to today |
| E6 | Clean log | Before a full run, clear the *Inventory Planning Calculation Log* so counts are readable |

**About the work date.** In CRONUS the work date usually sits in the demo data's
period, not today. Demand is only counted inside *History Window (Days)* counted
back from the **work date**. If you post history relative to today but the work
date is two years back, every item returns *Zero Demand* and every case looks
broken. Set the work date deliberately and post relative to it.

### Default setup values (after a clean install)

| Field | Default |
|---|---|
| History Window (Days) | 365 |
| Min Demand Observations | 20 |
| Default Lead Time (Days) | 7 |
| Default Service Level % | 95 |
| Trend Warning Threshold % | 30 |
| Ordering Cost (S) | 50 |
| Holding Rate | 0.25 |
| Maximum EOQ (Months of Demand) | 6 |
| Intermittent ADI Threshold | 1.32 |
| Erratic CV² Threshold | 0.49 |
| Count Consumption as Demand | No |
| Auto-Update Item Reordering Policy | **No** |
| Supply Values at Planning Time (Dynamic) | **No** |

---

## 3. Building the test data

> **There is no test-data generator in the app.** The automated suite builds its
> own items in code, but nothing in the shipped product creates demo items,
> demand history or BOMs for manual testing. The steps below are the manual
> equivalent. See [section 8](#8-what-the-automated-tests-already-cover) for what
> the automated tests do instead, and the note there on BOM coverage.

### 3.1 The pattern

For each test item: create the item, seed stock with a **Positive Adjmt.**, then
post one **Sale** item journal line per day of history. The demand engine reads
**Item Ledger Entries** with entry type *Sale* (plus *Consumption* and *Assembly
Consumption* when the setup flag is on) — so sales orders, sales invoices and
item journal sales all work equally. Item journal lines are fastest.

**Steps for one item:**

1. **Items → New.** Set *Base Unit of Measure*, *Last Direct Cost*, and
   *Replenishment System = Purchase*. Leave *Reordering Policy* blank.
2. **Item Journals → default batch.** One line, *Entry Type = Positive Adjmt.*,
   quantity ≥ total demand you are about to post. Post it.
3. Post one line per demand day: *Entry Type = Sale*, *Posting Date* = work date
   minus *n* days, quantity per the profile below. Post the batch.

> Post the Positive Adjmt. **before** the earliest sale date, or the sales fail
> on negative inventory.

### 3.2 The item set

Build these twelve items once and reuse them across the whole manual. Quantities
assume a 365-day window and the 20-observation minimum.

| Item | Profile | How to build it | Used by |
|---|---|---|---|
| **T-SMOOTH** | Steady: 10/day for 120 consecutive days | 120 Sale lines, qty 10 | TC-10, TC-11, TC-20 |
| **T-VARIABLE** | Same total, lumpy sizes: alternate 2 / 18 across 120 days | 120 Sale lines, alternating qty | TC-12, TC-31 |
| **T-INTERMITTENT** | Demand every 5th day only, qty 40, for 150 days (30 events) | 30 Sale lines, 5 days apart | TC-30, TC-32 |
| **T-SPARSE** | Only 8 demand days in the window | 8 Sale lines | TC-21 (Insufficient Demand Data) |
| **T-ZERO** | Item exists, no postings at all | Create item only | TC-22 (Zero Demand) |
| **T-BLOCKED** | Steady history, then tick *Blocked* | Copy T-SMOOTH pattern, then block | TC-23 |
| **T-EXCLUDED** | Steady history, then tick *Exclude from Inventory Planning* | Copy T-SMOOTH pattern, then exclude | TC-24, TC-41 |
| **T-SERVICE** | *Type = Service*, no postings | Create item only | TC-25 |
| **T-NOCOST** | Steady history, **zero** Last Direct Cost | Copy T-SMOOTH, clear cost | TC-26 |
| **T-MTO** | Steady history, *Manufacturing Policy = Make-to-Order* | Copy T-SMOOTH, set policy | TC-27 |
| **T-MAXINV** | Steady history, *Maximum Inventory = 50* (deliberately low) | Copy T-SMOOTH, set max | TC-13 (cap) |
| **T-PERISH** | Steady history, *Expiration Calculation = 30D* | Copy T-SMOOTH, set expiry | TC-33 |

### 3.3 Optional — manufacturing / consumption data

Only needed for TC-34 and TC-35. These are the **only** cases in this manual
that require a BOM, and the app itself has no automated coverage for them.

1. Create component **T-COMP** (*Replenishment System = Purchase*) and parent
   **T-PARENT** (*Replenishment System = Prod. Order*).
2. Create a **Production BOM** for T-PARENT with T-COMP, quantity per = 2.
   Certify it and set it on T-PARENT's *Production BOM No.*
3. Release and finish several production orders across the window so
   **Consumption** entries land on T-COMP at known dates and quantities.
   *(For assembly instead: an Assembly BOM and posted assembly orders produce
   Assembly Consumption entries — the engine treats both the same.)*
4. Set T-COMP's *Lead Time Calculation*, or leave it blank to test the fallback.

> If you only need to prove the consumption **flag** works and not the
> manufacturing chain, you can post *Consumption* item journal lines directly
> against T-COMP. That is much faster and exercises the same engine filter,
> but it does **not** test that a real BOM explosion produces those entries.

---

## 4. Test cases

### 4.1 Installation and setup

| ID | Pri | Type | Precondition | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-01** | P1 | Functional | App not installed | Install the extension | Installs with no errors. No permission or dependency warnings. |
| **TC-02** | P1 | Functional | TC-01 done | Search **Inventory Planning Setup** | Page opens. The setup record already exists with the defaults in section 2 — no "record does not exist" error. |
| **TC-03** | P1 | Integration | TC-01 done | **Manual Setup** → search *Inventory Planning* | The entry is listed and opens the setup page. |
| **TC-04** | P2 | Functional | Setup open | Change *History Window* to 0, then to 4000 | Both rejected with a clear message. Value stays valid. |
| **TC-05** | P2 | Functional | Setup open | Set *Default Service Level %* to 50, then 99.9 | 50 accepted (Z = 0); 99.9 accepted. No error, no rounding to a bucket. |
| **TC-06** | P2 | Functional | Setup open | Set *Holding Rate* to 1.5 | Rejected — the field is a 0–1 fraction, not a percentage. |
| **TC-07** | P1 | Integration | Setup open | **Create Job Queue Entry** | A recurring entry for codeunit **GSO Job Queue** is created, daily at 03:00, **Status = On Hold**. |
| **TC-08** | P3 | Functional | TC-07 done | Run the action again | Does not create a silent duplicate, or clearly tells you one exists. |

### 4.2 Single-item calculation

| ID | Pri | Type | Precondition | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-10** | P1 | Functional | T-SMOOTH built | Item Card → **Calculate All Planning Values** | *Safety Stock Qty.*, *Reorder Point* and *Reorder Quantity* are all populated. Log shows four entries, result **OK**. |
| **TC-11** | P1 | Functional | TC-10 done | Recalculate immediately | Same values. Repeat runs are stable — no drift from a cache or a rounding path. |
| **TC-12** | P1 | Functional | T-VARIABLE built | **Calculate Safety Stock** | Safety stock is **higher** than T-SMOOTH's, for the same average demand. Variability drives the number. |
| **TC-13** | P1 | Guard rail | T-MAXINV built (Max Inventory 50) | **Calculate Reorder Point** | Reorder point is capped at 50 and the log records **Cap Applied**, not OK. |
| **TC-14** | P1 | Functional | T-SMOOTH built | **Calculate EOQ** | *Reorder Quantity* populated. Cross-check by hand: `sqrt(2 × D × 50 ÷ (unit cost × 0.25))`, D = annual demand. |
| **TC-15** | P2 | Functional | Setup: *EOQ Write Target = Order Multiple* | **Calculate EOQ** on T-SMOOTH | The result lands in *Order Multiple*, and *Reorder Quantity* is untouched. |
| **TC-16** | P2 | Functional | Setup: *Write EOQ to Item = No* | **Calculate EOQ** on T-SMOOTH | Nothing is written to the item. The log still records the computed value. |
| **TC-17** | P2 | Functional | T-SMOOTH, *Minimum Order Quantity = 9999* | **Calculate EOQ** | Written quantity is raised to 9999 — order modifiers are respected. |
| **TC-18** | P1 | Functional | T-SMOOTH built | **Advise Reordering Policy** | A recommendation is logged. With *Auto-Update = No*, the item's *Reordering Policy* is **unchanged**. |
| **TC-19** | P1 | Functional | Setup: *Auto-Update Policy = Yes* | **Advise Reordering Policy** on T-SMOOTH | Now the item's *Reordering Policy* **is** updated to the recommendation. |
| **TC-20** | P2 | Functional | T-SMOOTH, ends on Maximum Qty. policy | **Calculate All** | *Maximum Inventory* is set to reorder point + EOQ, completing the min/max pair. |

### 4.3 Guard rails — the refusals

Each of these must **decline and explain**. Confirm the item's existing planning
values are still there afterwards.

| ID | Pri | Type | Item | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-21** | P1 | Guard rail | T-SPARSE | Calculate All | **Insufficient Demand Data**. Nothing written. |
| **TC-22** | P1 | Guard rail | T-ZERO | Calculate All | **Zero Demand**. Nothing written. |
| **TC-23** | P1 | Guard rail | T-BLOCKED | Calculate All | **Item Blocked**. Nothing written. |
| **TC-24** | P1 | Guard rail | T-EXCLUDED | Calculate All | **Excluded**. Existing values survive untouched — this is the setting's whole purpose. |
| **TC-25** | P1 | Guard rail | T-SERVICE | Calculate All | **Not an Inventory Item**. Nothing written. |
| **TC-26** | P1 | Guard rail | T-NOCOST | Calculate EOQ | **Zero Unit Cost**. Safety stock and reorder point still succeed — one failure must not poison the others. |
| **TC-27** | P1 | Guard rail | T-MTO | Calculate All | **Make-to-Order Skipped** (default setting). Turning *Skip Make-to-Order* off makes it calculate. |
| **TC-28** | P2 | Guard rail | Setup: *Ordering Cost = 0* | Calculate EOQ on T-SMOOTH | **Zero Ordering Cost**. Nothing written. |
| **TC-29** | P1 | Guard rail | Any item whose formula yields 0 | Calculate All | **Zero Result** — reported, never written. A real value is never replaced by nothing. |

### 4.4 Demand classification and policy advice

| ID | Pri | Type | Precondition | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-30** | P1 | Functional | T-INTERMITTENT | Advise Reordering Policy | Classified **Intermittent** or **Lumpy** (ADI > 1.32); recommendation is **Lot-for-Lot**. |
| **TC-31** | P2 | Functional | T-VARIABLE | Advise Reordering Policy | CV² above 0.49 → classified **Erratic** or **Lumpy**. |
| **TC-32** | P2 | Functional | T-SMOOTH | Advise Reordering Policy | Classified **Smooth**; recommendation **Fixed Reorder Qty.** |
| **TC-33** | P2 | Functional | T-PERISH, *Perishable Means Max Qty. = Yes* | Advise Reordering Policy | Recommendation is **Maximum Qty.** because of the expiration calculation. |
| **TC-34** | P2 | Integration | T-COMP with consumption history; *Count Consumption as Demand* = **No** | Calculate All on T-COMP | **Zero Demand** — consumption is correctly ignored while the flag is off. |
| **TC-35** | P1 | Integration | Same item; flag switched to **Yes** | Calculate All on T-COMP | Now calculates from consumption. This is the manufacturing-component path — see the BOM note in section 3.3. |

### 4.5 Bulk runs and the Planning Worksheet

| ID | Pri | Type | Precondition | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-36** | P1 | Functional | All T- items exist | Item List → filter to `T-*` → **Calculate All (Selected/Filtered Items)** | Every item processed. Successes written, guard-railed items skipped with codes. A run summary is shown. |
| **TC-37** | P1 | Functional | Item List | Select exactly 3 rows → same action | Only those 3 are processed — selection wins over the filter. |
| **TC-38** | P1 | Functional | Item List, filter `T-*`, nothing selected | Same action | The **filter** is honoured. This and TC-37 together prove the caption's promise. |
| **TC-39** | P1 | Functional | — | Item List → **Planning Worksheet** → **Load Items** | Lines load showing *Current* vs *Proposed* side by side. **No item is modified yet** — verify on an item card. |
| **TC-40** | P1 | Functional | Worksheet loaded | Tick 2 lines → **Apply Selected** | Only those 2 items change. The applied lines refresh their *Current* values in place. |
| **TC-41** | P1 | Guard rail | Worksheet loaded | Find T-EXCLUDED | It is skipped or shows its result code — never silently overwritten. |
| **TC-42** | P2 | Functional | Worksheet loaded | **Select All**, then **Clear Selection** | Selection toggles correctly across all loaded lines. |
| **TC-43** | P2 | Functional | Worksheet | Review the *Note* and result-code columns | Skips and caps are explained per line and per calculator (SS / ROP / EOQ codes). |
| **TC-44** | P2 | Non-functional | ~500 items with history | Load Items, then Apply All | Completes in a reasonable time without timeout. Note the duration. |

### 4.6 Scheduling, planning integration, log

| ID | Pri | Type | Precondition | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-45** | P1 | Integration | TC-07 done | Set the entry to **Ready**, let it run | Runs to completion. Log fills. Item values update. Entry returns to its schedule, not to Error. |
| **TC-46** | P2 | Integration | Job queue entry | Set *Parameter String* = `SAFETYSTOCK`, run | **Only** safety stock is calculated. Repeat for `REORDERPOINT`, `EOQ`, `ADVISOR`. |
| **TC-47** | P2 | Integration | Job queue entry | Clear the *Parameter String*, run | Behaves as `ALL` — empty is the documented default. |
| **TC-48** | P1 | Integration | *Supply Values at Planning Time* = **No** | Run **Calculate Regenerative Plan** on T-SMOOTH | Planning uses the **stored** item values. Baseline for TC-49. |
| **TC-49** | P1 | Integration | Flag switched to **Yes**; clear the item's stored values | Run the plan again | Planning still produces sensible lines — values are supplied live. Log shows **Dynamic Supply** entries. |
| **TC-50** | P1 | Guard rail | Dynamic on; a **real SKU** exists for the item/location | Run the plan | The SKU's own parameters are respected and **not** overwritten. |
| **TC-51** | P1 | Guard rail | Dynamic on; T-EXCLUDED in the plan | Run the plan | Fails open — the stored values are used, planning does not error. |
| **TC-52** | P2 | Functional | Log has entries | Open **Inventory Planning Calculation Log** | Read-only. Shows item, type, result code, values, date/time and user. |
| **TC-53** | P2 | Functional | Setup: *Log History = No* | Calculate All on T-SMOOTH | The calculation runs; no new log rows are written. |
| **TC-54** | P2 | Integration | — | **Retention Policies** → new policy | The *Inventory Planning Calculation Log* table is selectable, and a policy deletes aged entries. |

### 4.7 Permissions, per-item controls, upgrade

| ID | Pri | Type | Precondition | Steps | Expected result |
|---|---|---|---|---|---|
| **TC-55** | P1 | Functional | User with **GSO - User** only | Run Calculate All from the Item Card | Succeeds. Item and log writes go through the calculators' own elevation. |
| **TC-56** | P1 | Guard rail | Same user | Open Inventory Planning Setup and try to edit | Can **read** setup; cannot modify it. |
| **TC-57** | P1 | Functional | User with **GSO** (admin) | Edit setup, delete log entries | Both permitted. |
| **TC-58** | P2 | Functional | Item Card → Planning tab | Set *Service Level %* = 99 on one item | That item alone uses 99%; others keep the 95% default. Its safety stock is visibly higher. |
| **TC-59** | P2 | Functional | Item Card | Set per-item *Service Level %* back to 0 | Falls back to the setup default — 0 means "use default", not "zero service". |
| **TC-60** | P2 | Functional | Previous version installed with data | Upgrade to the build under test | Existing setup and log survive. New setup fields have sensible defaults, not blanks or zeros. |
| **TC-61** | P3 | Non-functional | App installed | Uninstall, then reinstall | Uninstalls cleanly. Reinstall finds the setup record intact. |
| **TC-62** | P2 | Non-functional | Telemetry configured | Run a scheduled and a bulk run | Events **GSO0001** / **GSO0002** appear in App Insights, carrying counts and codes only — **no item numbers or customer data**. |

---

## 5. Result-code matrix

Every code below should be reachable from this manual. Tick each one off — a
code you cannot produce is either dead or a gap in this script.

| Result code | Produced by | Value written? |
|---|---|---|
| OK | TC-10 | Yes |
| Cap Applied | TC-13 | Yes (capped) |
| Insufficient Demand Data | TC-21 | No |
| Zero Demand | TC-22, TC-34 | No |
| No Lead Time Data | Clear the item's lead time **and** the setup fallback | No |
| Item Blocked | TC-23 | No |
| Make-to-Order Skipped | TC-27 | No |
| Not an Inventory Item | TC-25 | No |
| Excluded | TC-24 | No |
| Zero Unit Cost | TC-26 | No |
| Zero Ordering Cost | TC-28 | No |
| Zero Result | TC-29 | No |
| Error | Not reachable by design — investigate any occurrence | No |

---

## 6. Regression checklist (short run)

When there is no time for the full script, run these fourteen. They touch every
calculator, both write paths, the guard rails and both integrations.

TC-01 · TC-02 · TC-07 · TC-10 · TC-13 · TC-18 · TC-21 · TC-24 · TC-27 ·
TC-36 · TC-39 · TC-40 · TC-45 · TC-49

---

## 7. Defect reporting

Include all of the following — the first three are the ones most often missing,
and without them a demand-calculation defect cannot be reproduced:

1. **Work date** and **History Window** at the time of the run
2. The **item's** replenishment system, reordering policy, costs and lead time
3. The **item ledger entries** in the window (entry type, date, quantity)
4. Test case ID, build number, expected vs actual
5. The **calculation log row**, including its result code and note
6. Screenshot of the item's planning fields before and after

---

## 8. What the automated tests already cover

Two test codeunits ship in the `test` app (range
50600–50649). Do not spend manual time re-testing what they already assert.

| Codeunit | ID | Tests | Covers |
|---|---|---|---|
| GSO Math Tests | 50600 | 7 | Square root and the service-level → Z-score conversion, including boundaries |
| GSO Calculator Tests | 50601 | 24 | Demand statistics, all four calculators, most guard rails, and the dynamic provider |

**Their test data**, built in code via `Library - Inventory`: an item, a Positive
Adjmt. to seed stock, then one **Sale** item journal line per demand day. That is
exactly the pattern in [section 3.1](#31-the-pattern).

### Gaps this manual exists to fill

The automated suite does **not** touch any of the following, so these cases carry
the full weight of coverage:

| Area | Cases |
|---|---|
| **BOMs, production and assembly consumption** — no BOM is ever created in code, and `Include Consumption Demand` is forced **off** in the test setup | TC-34, TC-35 |
| Manufacturing / assembly **lead-time resolution** paths | TC-35 |
| Job Queue codeunit and its parameter strings | TC-45–TC-47 |
| Install, upgrade and telemetry codeunits | TC-03, TC-60, TC-62 |
| Planning Worksheet page — load, select, apply | TC-39–TC-44 |
| Permission sets | TC-55–TC-57 |
| Every UI action, page and field validation | TC-04–TC-08 |

---

## Support

- **User Guide:** [user-guide.md](user-guide.md)
- **Online docs:** <https://gmsoftdynamics.com/apps/inventory-planning/docs/>
- **Issues:** <https://github.com/GmsoftLtd/bc-inventory-planning>
