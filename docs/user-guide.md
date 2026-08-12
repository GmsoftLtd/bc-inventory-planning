# Inventory Planning — User Guide

Safety stock, reorder point, EOQ and reordering policy advice, calculated from
your actual demand history and written to the standard Business Central
planning fields.

- **Publisher:** GMSOFT Limited
- **License:** MIT (free, open source)
- **Requires:** Business Central 2026 wave 1 (v28) or later, cloud

---

## Contents

1. [What the app does](#1-what-the-app-does)
2. [Installation](#2-installation)
3. [First-time setup](#3-first-time-setup)
4. [Setup reference](#4-setup-reference)
5. [How demand and lead time are measured](#5-how-demand-and-lead-time-are-measured)
6. [Calculating for a single item](#6-calculating-for-a-single-item)
7. [Calculating for many items](#7-calculating-for-many-items)
8. [The Planning Worksheet](#8-the-planning-worksheet)
9. [Scheduling a nightly run](#9-scheduling-a-nightly-run)
10. [Reading the results](#10-reading-the-results)
11. [Per-item controls](#11-per-item-controls)
12. [Planning-time values (dynamic provider)](#12-planning-time-values-dynamic-provider)
13. [The calculation log and retention](#13-the-calculation-log-and-retention)
14. [Formula reference](#14-formula-reference)
15. [Troubleshooting](#15-troubleshooting)
16. [Data, privacy and telemetry](#16-data-privacy-and-telemetry)

---

## 1. What the app does

Most Business Central implementations leave **Safety Stock Quantity**, **Reorder
Point** and **Reorder Quantity** either empty or filled with a number somebody
guessed years ago. The planning engine faithfully executes those guesses.

This app calculates them from posted Item Ledger Entries and writes them to the
standard item fields, so standard planning, requisition worksheets and MRP pick
them up with no further configuration.

| Calculator | Produces | Writes to |
|---|---|---|
| Safety Stock | Buffer covering demand and lead-time variability at your service level | Item **Safety Stock Quantity** |
| Reorder Point | Demand during lead time, plus safety stock | Item **Reorder Point** |
| EOQ | Wilson economic order quantity, capped and order-modifier aware | Item **Reorder Quantity** (or **Order Multiple**) |
| Maximum Inventory | Order-up-to level (reorder point + EOQ) for Maximum Qty. items | Item **Maximum Inventory** |
| Policy Advisor | Demand classification and a recommended reordering policy | Item **Reordering Policy** (opt-in) |

There is no parallel data model. The app reads history, computes, and writes
standard fields — everything downstream of the item card keeps working exactly
as it did.

---

## 2. Installation

Install from AppSource. On installation the app:

- Creates the **Inventory Planning Setup** record with working defaults
- Registers itself under **Manual Setup** (search: *Manual Setup* → *Inventory
  Planning*)
- Registers the calculation log with the standard **Retention Policy** module

No data is calculated and no item is touched until you ask for it.

---

## 3. First-time setup

### Step 1 — Assign permissions

| Permission set | Give it to | Grants |
|---|---|---|
| **GSO - User** (`Inventory Planning - User`) | Planners, buyers | Run the calculators, use the worksheet, read the log and setup |
| **GSO** (`Inventory Planning`) | Administrators | The above, plus editing setup and maintaining the log |

Anyone who runs standard planning while the dynamic provider is enabled needs at
least **GSO - User**.

### Step 2 — Review the setup

Search for **Inventory Planning Setup**. The defaults are sensible for a
distributor with a year of clean history:

- Demand History Window: **365 days**
- Min Demand Observations: **20**
- Default Service Level: **95%**
- Ordering Cost: **50**
- Holding Rate: **0.25**

**If you manufacture or assemble**, turn on **Count Consumption as Demand**.
Without it, a component consumed by production shows no "demand" at all, because
it is never sold — and every purchased component will report *Zero Demand*.

### Step 3 — Try one item first

Open an item you know well: **Item Card → Inventory Planning → Calculate All
Planning Values**. Read the note in the message and the resulting entries in the
calculation log before you run anything in bulk.

### Step 4 — Roll out

Use the **Planning Worksheet** to review a whole category before applying
anything. See [section 8](#8-the-planning-worksheet).

---

## 4. Setup reference

All fields live on the **Inventory Planning Setup** page.

### General

| Field | Default | What it does |
|---|---|---|
| Demand History Window (Days) | 365 | Calendar days of history to analyse, ending on the work date. Range 30–1095. |
| Min Demand Observations | 20 | Minimum number of **days with demand** required before a result is produced. Below this, the item is reported as *Insufficient Demand Data*. Minimum 3. |
| Round Up Results to Whole Units | Yes | Round results up to whole units. Turn off for items measured in kg, litres or metres. |
| Log Calculation History | Yes | Write an entry to the calculation log for every calculation. |
| Skip Make-to-Order Items | Yes | Skip items whose replenishment is make-to-order — their supply is driven by the order, not by a reorder point. |
| Fallback Lead Time (Days) | 7 | Used when neither receipt history nor the item's Lead Time Calculation yields a lead time. |
| Count Consumption as Demand | No | Count production and assembly consumption as demand alongside sales. **Turn this on in manufacturing companies.** |
| Trend Warning Threshold % (0 = off) | 30 | Warn in the note when recent demand deviates from the window average by more than this. |

### Safety Stock

| Field | Default | What it does |
|---|---|---|
| Default Service Level % | 95 | Probability of not stocking out during a replenishment cycle. Range 70–99.99. Overridable per item. |
| Write Safety Stock to Item | Yes | Turn off to calculate and log without writing to items. |

### Reorder Point

| Field | Default | What it does |
|---|---|---|
| Add Safety Stock to Reorder Point | Yes | Include the freshly calculated safety stock in the reorder point. |
| Write Reorder Point to Item | Yes | Turn off to preview only. |
| Set Policy to Fixed Reorder Qty. when None | Yes | Give items with no reordering policy one, so the reorder point actually does something. Suppressed for an item when the advisor recommends a different policy. |
| Write Maximum Inventory (ROP + EOQ) for Maximum Qty. Items | Yes | Set the order-up-to level for items on the Maximum Qty. policy. |

### EOQ

| Field | Default | What it does |
|---|---|---|
| Ordering Cost (S) | 50 | Cost of placing one order — administration, receiving, inspection. In your local currency. |
| Holding Rate | 0.25 | Annual cost of holding one unit, as a fraction of unit cost. 0.25 means 25% per year. Range 0–1. |
| Maximum EOQ (Months of Demand) | 6 | Cap on the result. Prevents a low-cost, high-volume item ordering two years of stock. Minimum 0.5. |
| EOQ Write Target | Reorder Quantity | Or **Order Multiple**, if you prefer the engine to round order sizes rather than fix them. |
| Unit Cost Source | Last Direct Cost | Or **Standard Cost** or **Unit Cost**. |
| Write EOQ to Item | Yes | Turn off to preview only. |

### Policy Advisor

| Field | Default | What it does |
|---|---|---|
| Intermittent ADI Threshold | 1.32 | Average Demand Interval above which demand counts as intermittent. The Syntetos–Boylan value. |
| Erratic CV-Squared Threshold | 0.49 | Squared coefficient of variation above which demand size counts as erratic. Also Syntetos–Boylan. |
| Treat Shelf Life as Maximum Qty. | Yes | Items with an Expiration Calculation are steered to Maximum Qty. so standing stock is capped. |
| Auto-Update Item Reordering Policy | **No** | Off by default. Recommendations are logged either way; turn this on only once you trust the advice. |

### Planning Engine Integration

| Field | Default | What it does |
|---|---|---|
| Supply Values at Planning Time (Dynamic) | No | See [section 12](#12-planning-time-values-dynamic-provider). |

---

## 5. How demand and lead time are measured

Every calculator draws on one shared statistics engine, so all four agree on
what "demand" and "lead time" mean for a given item.

### Demand

- **Sales, netted against same-day returns.** A day whose net demand is zero or
  negative counts as a zero-demand day.
- **Consumption too**, when *Count Consumption as Demand* is on — production and
  assembly consumption join sales, so purchased components are planned from
  real usage.
- The mean and standard deviation are computed over **all calendar days** in the
  window, including days with no demand, so the daily rate lines up with a
  lead time expressed in calendar days.
- **Observations** counts days that had demand — not transaction lines. An item
  with 200 sales lines across 12 busy days has 12 observations, and with the
  default minimum of 20 it will report *Insufficient Demand Data*.

### Lead time

Resolved in this order, and the source is recorded in the log:

1. **Purchase receipt history** — mean and standard deviation of order-to-receipt
   days over posted purchase receipts from the trailing two years (purchased
   items only). This is the only source that yields lead-time *variability*.
2. **The item's Lead Time Calculation** field — also used for produced and
   assembled items.
3. **Fallback Lead Time (Days)** from setup.

Safety stock and reorder point use the same resolution, so the two can never
disagree about an item's lead time.

### The work date

History windows are anchored to the **work date**, not the system date. In
production these are the same. In a demo or evaluation company, where the work
date follows the demo data, this is what makes a trial produce real results
instead of empty ones.

---

## 6. Calculating for a single item

**Item Card → Inventory Planning**:

| Action | What it does |
|---|---|
| **Calculate All Planning Values** | Runs everything in dependency order: policy advice → safety stock → reorder point → EOQ → maximum inventory |
| **Calculate Safety Stock** | Safety stock only |
| **Calculate Reorder Point** | Reorder point only |
| **Calculate EOQ** | EOQ only |
| **Advise Reordering Policy** | Classifies demand and recommends a policy |
| **Calculation Log** | Opens the log filtered to this item |

Each action reports its result and its reasoning in a message. Whether the value
is written to the item depends on the corresponding *Write … to Item* switch in
setup.

**Why the order matters:** the reorder point is fed the *freshly calculated*
safety stock, not whatever was stored on the item. Running the calculators
individually and out of order can produce a reorder point built on a stale
safety stock.

---

## 7. Calculating for many items

**Item List → Inventory Planning**:

| Action | What it does |
|---|---|
| **Planning Worksheet** | Opens the preview worksheet |
| **Calculate All (Selected/Filtered Items)** | Runs everything and applies, after a confirmation showing the item count |
| **Advise Policy (Selected/Filtered Items)** | Classifies demand and logs recommendations |

**Scope:** if you have selected more than one row, the selected rows win.
Otherwise the current filter on the list defines the scope. Non-inventory,
blocked and excluded items are skipped automatically.

Bulk runs commit every 100 items, so a long run that is interrupted keeps the
work already done.

---

## 8. The Planning Worksheet

The safest way to roll out. **Item List → Inventory Planning → Planning
Worksheet**, or search for *Inventory Planning Worksheet*.

1. **Load Items** — choose a filter (item number, item category, vendor). Every
   matching inventory item is calculated as a **preview**. Nothing is written.
2. Review the columns: current versus proposed for safety stock, reorder point,
   reorder quantity and maximum inventory, alongside the demand pattern, the
   current and recommended policy, a result code per calculator, and the
   advisor's note.
3. After loading, a message reports how many lines change the reorder point by
   **more than 25%** — triage those first rather than reading every line.
4. Tick the lines you want. **Select All** / **Clear Selection** help.
5. **Apply Selected** — confirms the count, then applies.

**Applies are not a copy of the preview.** The calculators re-run through their
validated, logged path, so an apply is exactly equivalent to running the item
individually. Applied lines refresh their "current" columns in place and are
deselected, so you can see the effect without reloading.

---

## 9. Scheduling a nightly run

**Inventory Planning Setup → Create Job Queue Entry** creates a recurring entry
for codeunit **GSO Job Queue**, every day at 03:00, **on hold** so you can
review it first. Set it to **Ready** when you are satisfied.

The **Parameter String** selects what runs:

| Value | Runs |
|---|---|
| `ALL` *(default, also used when empty)* | Everything, in dependency order |
| `SAFETYSTOCK` | Safety stock only |
| `REORDERPOINT` | Reorder point only |
| `EOQ` | EOQ only |
| `ADVISOR` | Policy advice only |

Create several entries with different parameters and schedules if you want, for
example policy advice weekly and safety stock nightly.

---

## 10. Reading the results

### Result codes

| Code | Meaning | What to do |
|---|---|---|
| **OK** | Calculated and usable | — |
| **Cap Applied** | Usable, but a configured cap limited it | Check *Maximum EOQ (Months of Demand)* or the item's Maximum Inventory |
| **Insufficient Demand Data** | Fewer days with demand than *Min Demand Observations* | Lengthen the window, lower the minimum, or accept that the item is too sporadic to model |
| **Zero Demand** | No demand at all in the window | New item, dead item — or a manufacturing component with *Count Consumption as Demand* off |
| **No Lead Time Data** | No lead time from any source | Set the item's Lead Time Calculation or a fallback in setup |
| **Item Blocked** | The item is blocked | — |
| **Make-to-Order Skipped** | Make-to-order item, and skipping is on | Expected; turn the setting off to include them |
| **Not an Inventory Item** | Type is Service or Non-Inventory | Expected |
| **Excluded by Item Setting** | *Exclude from Inventory Planning* is ticked on the item | Expected |
| **Zero Unit Cost** | EOQ needs a unit cost | Populate the chosen cost source, or switch Unit Cost Source |
| **Zero Ordering Cost** | EOQ needs an ordering cost | Set *Ordering Cost (S)* in setup |
| **Zero Result** | The formula produced zero | Reported rather than written, so a real value is never overwritten with nothing |
| **Error** | Unexpected failure | See the note on the log entry |

### Demand patterns

Classified from ADI (how *often* demand occurs) and CV² (how *variable* the
quantities are):

| Pattern | ADI | CV² | Recommended policy |
|---|---|---|---|
| **Smooth** | < 1.32 | < 0.49 | Fixed Reorder Qty. |
| **Erratic** | < 1.32 | ≥ 0.49 | Fixed Reorder Qty. |
| **Intermittent** | ≥ 1.32 | < 0.49 | Lot-for-Lot |
| **Lumpy** | ≥ 1.32 | ≥ 0.49 | Lot-for-Lot |

Two overrides come first: an item with an **Expiration Calculation** (and *Treat
Shelf Life as Maximum Qty.* on) or an item that already has a **Maximum
Inventory** is steered to **Maximum Qty.** instead. Make-to-order items are
recommended **Order**.

Auto-update, when enabled, only ever writes Fixed Reorder Qty., Maximum Qty. or
Lot-for-Lot. It never flips an item to **Order** automatically — that is a
sourcing decision, not a statistical one.

### Notes and warnings

The note on every calculation is where the app tells you when to doubt it:

- **Trend warning** — recent demand (the last quarter of the window, minimum 30
  days) deviates from the full-window average by more than the threshold.
  History-based values lag a ramp-up and overstate a phase-out.
- **SKU notice** — Stockkeeping Units exist for this item, so standard planning
  reads the SKU values at those locations rather than the item card. This app
  calculates at item level by design; the note prevents the "why isn't my
  calculated value working" conversation.
- **Intermittent / lumpy warning** — safety stock for this demand shape rests on
  a normal approximation that does not really hold. The number is still the best
  available estimate, but it deserves review rather than trust.

---

## 11. Per-item controls

On the **Item Card → Planning** tab:

| Field | Effect |
|---|---|
| **Exclude from Inventory Planning** | The item is skipped by every calculator, bulk run, scheduled job and the dynamic provider. Use it to protect values a planner maintains by hand. |
| **Planning Service Level % (0 = default)** | Per-item service level for safety stock. 0 means use the setup default. Raise it for critical A items, lower it for cheap C items. |

---

## 12. Planning-time values (dynamic provider)

**Off by default. Opt in deliberately.**

Normally the calculators write values to items, and planning reads them later —
so a plan uses whatever the last batch run produced. With **Supply Values at
Planning Time (Dynamic)** enabled, the app instead supplies calculated values to
the planning engine *during the planning run*, computed from live history at
that moment.

Behaviour:

- Real Stockkeeping Units are **never** modified.
- An item that cannot be calculated falls back to its stored values.
- Every fresh computation is written to the calculation log as a **Dynamic
  Supply** entry, so planning-time values are as auditable as batch ones.
- Order modifiers are never touched — Minimum/Maximum Order Quantity and Order
  Multiple stay under the planning engine's control.

**Verify on a sandbox before enabling in production:** run a regenerative plan
for one item, confirm the requisition line reflects the calculated values, and
check that a Dynamic Supply entry appears in the log.

---

## 13. The calculation log and retention

Search for **Inventory Planning Calculation Log**, or open it from the setup
page, the worksheet, or an item card.

Every entry records the full basis of a calculation, not just its answer:

- **Identity** — calculation type, item, date/time, user
- **Demand** — average daily demand, standard deviation, observations, ADI, CV²,
  demand pattern
- **Lead time** — days, standard deviation, and the source it came from
- **Safety stock inputs** — service level and the Z-score used
- **EOQ inputs** — annual demand, unit cost, holding cost, ordering cost
- **Outcome** — raw result, final result, previous value, whether it was
  applied, result code, recommended policy, and the note

This makes any number defensible months later: you can see exactly which history
produced it and what the item's value was before.

### Set a retention policy

The log grows by one row per item per calculator per run. It is registered with
the standard **Retention Policy** module, so:

1. Search for **Retention Policies**
2. New → table **GSO Calculation Log**
3. Set a period — **90 days** is a sensible starting point

Without a policy, nothing is deleted.

---

## 14. Formula reference

**Safety stock** — covers variability in both demand and lead time:

```
SS = Z × √( LT × σD² + D² × σLT² )
```

where `Z` is the inverse normal at your service level, `LT` the lead time in
days, `σD` the standard deviation of daily demand, `D` the average daily demand,
and `σLT` the standard deviation of lead time.

Z-scores come from a continuous inverse-normal approximation (Acklam), so a
94.9% service level gets a 94.9% buffer. There is no lookup table rounding you
down to the nearest bucket.

**Reorder point:**

```
ROP = (average daily demand × lead time) + safety stock
```

Capped at the item's Maximum Inventory when one is set.

**EOQ** — the Wilson formula:

```
EOQ = √( 2 × D × S / H )
```

where `D` is annual demand, `S` the ordering cost, and `H` the annual holding
cost per unit (unit cost × holding rate). The result is capped at *Maximum EOQ
(Months of Demand)* and reconciled with the item's Minimum Order Quantity,
Maximum Order Quantity and Order Multiple.

**Maximum inventory** — the order-up-to level for Maximum Qty. items:

```
Maximum Inventory = reorder point + EOQ
```

---

## 15. Troubleshooting

**Every item reports Zero Demand.**
You manufacture, and *Count Consumption as Demand* is off. Components are
consumed, never sold. Turn it on.

**Every item reports Insufficient Demand Data.**
Observations count *days with demand*, not transaction lines. Sporadic items
genuinely fail this test. Lengthen the history window, or lower *Min Demand
Observations* — but understand that a statistic from 5 days of demand is a
statistic from 5 days of demand.

**The calculated values are ignored by planning.**
Check for Stockkeeping Units on the item. Standard planning reads SKU values at
a location, not the item card. The note on the calculation says so when SKUs
exist. Per-location planning is out of scope for this free app.

**The reorder point looks too low for a growing product.**
Read the note — a trend warning will be there. History-based planning lags
growth by design. Consider a shorter window for fast-moving ranges.

**EOQ says Zero Unit Cost.**
The chosen *Unit Cost Source* is empty on that item. Populate it, or switch the
source in setup.

**Values changed and I do not know why.**
Open the calculation log for the item. Every run records the previous value, the
new value, and every input that produced it.

**I do not want an item touched again.**
Tick **Exclude from Inventory Planning** on the item card.

---

## 16. Data, privacy and telemetry

**Your data stays in your tenant.** The app reads Item Ledger Entries, purchase
receipt lines and item master data, and writes to standard item planning fields
plus its own setup and log tables. Nothing is sent anywhere.

**Diagnostic telemetry** is emitted to the publisher's Application Insights
resource using the standard Business Central telemetry channel:

| Event ID | Raised when | Data |
|---|---|---|
| `GSO0001` | A scheduled run completes | Mode, item count |
| `GSO0002` | An interactive bulk run completes | Calculation type, item count |
| `GSO0003` | The dynamic provider computes values | Event count only |

These carry **counts and codes only** — never item numbers, quantities, costs,
customer names or any other business data. Telemetry also flows to your own
environment's Application Insights resource if you have configured one.

---

## Support

- **Source and issues:** https://github.com/GmsoftLtd/bc-inventory-planning
- **Methodology write-ups:** https://insidebusinesscentral.com/
- **Licence:** MIT

This app calculates at item level. Per-location (SKU) planning, ABC-driven
service levels and an exception workbench are outside its scope.
