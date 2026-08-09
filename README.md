# Inventory Planning for Business Central

One free app consolidating the four standalone GMSoft planning calculators —
[Safety Stock](https://github.com/GmsoftLtd/Lexon-SafetyStockCalculator),
[Reorder Point](https://github.com/GmsoftLtd/bc-reorder-point),
[EOQ](https://github.com/GmsoftLtd/bc-eoq-calculator) and
[Replenishment Policy Advisor](https://github.com/GmsoftLtd/bc-replenishment-policy) —
into a single extension with a shared statistics engine, one setup, one log,
a planning worksheet, and optional **dynamic integration with the standard
planning engine**.

Methodology write-ups: [insidebusinesscentral.com](https://insidebusinesscentral.com/)

## What it calculates

| Calculator | Formula | Writes to |
|---|---|---|
| Safety Stock | `Z × √(LT×σD² + D²×σLT²)` | Item **Safety Stock Quantity** |
| Reorder Point | `(avg daily demand × lead time) + safety stock` | Item **Reorder Point** |
| EOQ | Wilson: `√(2DS/H)`, capped, order-multiple aware | Item **Reorder Quantity** (or Order Multiple) |
| Policy Advisor | Syntetos-Boylan ADI/CV² classification | Item **Reordering Policy** (opt-in) |

All demand statistics come from one engine (`IPL Demand Statistics`) reading
Item Ledger Entries of type Sale — one definition of "demand" across all four,
computed in a single pass (mean, σ, observations, ADI, CV²).

## What's new versus the four standalone apps

- **One setup, one log, one prefix (`IPL`)**, IDs 50500–50599 — the old apps'
  duplicated statistics code (3 slightly different copies) is gone.
- **Planning Worksheet** — current vs proposed values side by side for a
  filtered item set, selective apply. Applies re-run the calculators through
  the validated, logged path; nothing is blind-copied from the preview.
- **Run All** — the four calculators in dependency order: policy advice →
  safety stock → reorder point (fed the *fresh* safety stock, not the stored
  one) → EOQ.
- **Dynamic planning provider** (`IPL Planning Provider`) — opt-in. Subscribes
  to `OnAtSKUOnAfterCopyFromItem` on codeunit **99000855 "Planning-Get
  Parameters"** and supplies calculated values to the planning engine *at
  planning time*, so a regenerative plan consumes numbers computed from live
  history instead of whatever a batch job last wrote. Fails open (stored
  values stand when an item can't be calculated), caches per run, and never
  touches order modifiers — the engine stays authoritative on Min/Max Order
  Qty and Order Multiple.

## Requirements

- Business Central 2026 wave 1 (v28) or later, cloud.
  (The `Planning-Get Parameters` integration events are verified against
  BC 28 symbols; for older versions, disable the dynamic provider and check
  event availability.)

## Setup

1. Install; the setup record is created automatically with the same defaults
   as the standalone apps.
2. **Inventory Planning Setup**: review history window (365 d), minimum
   observations (20), service level (95%), ordering cost (50), holding rate
   (0.25).
3. Per item: **Item Card → Inventory Planning → Calculate All Planning Values**.
4. Per set: **Item List → Inventory Planning → Planning Worksheet** → Load
   Items → review → Apply Selected.
5. Scheduled: create a **Job Queue Entry** for codeunit **50518 "IPL Job
   Queue"**; Parameter String `ALL` (default), `SAFETYSTOCK`, `REORDERPOINT`,
   `EOQ` or `ADVISOR`.
6. Optional: enable **Supply Values at Planning Time (Dynamic)** in setup.
   Verify on a sandbox first: run a regenerative plan for one item and confirm
   the requisition line reflects the calculated values.

## Migrating from the four standalone apps

The apps coexist safely: different object IDs (50500+ vs 50100–50499) and
different object names. Recommended path:

1. Install Inventory Planning alongside the old apps.
2. Copy your setup values into Inventory Planning Setup (one page now).
3. Retire the old apps' Job Queue entries; create one for `IPL Job Queue`.
4. Uninstall the four standalone apps when comfortable. Their logs live in
   their own tables — export before uninstall if you delete the apps' data.

Calculation behaviour is a faithful port, with one deliberate change: the EOQ
calculator's minimum-observations test now counts **days with demand** (like
the other three calculators) instead of ILE rows. If you relied on the old
row-count behaviour, lower `Min Demand Observations` accordingly.

## Repository layout

```
InventoryPlanning/            the app
  src/{Tables,Pages,Codeunits,PageExtensions,PermissionSets,Enums}
InventoryPlanning.Tests/      test app (Library Assert + Library - Inventory)
```

## Building

```bash
altool downloadsymbols --project ./InventoryPlanning
altool build --project ./InventoryPlanning
altool build --project ./InventoryPlanning.Tests
```

Note: the test app's dependency GUIDs for Microsoft test libraries follow the
standard published IDs; if `al_downloadsymbols` reports a mismatch for your
localization, correct them from your environment's extension list.

## License

MIT — same as the four standalone apps.
