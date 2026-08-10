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
| Reorder Point | `(avg daily demand × lead time) + safety stock`, capped at Maximum Inventory | Item **Reorder Point** |
| EOQ | Wilson: `√(2DS/H)`, capped, order-modifier aware (Min/Max Order Qty, Order Multiple) | Item **Reorder Quantity** (or Order Multiple) |
| Maximum Inventory | order-up-to: `reorder point + EOQ` (Maximum Qty. items, via Run All) | Item **Maximum Inventory** |
| Policy Advisor | Syntetos-Boylan ADI/CV² classification | Item **Reordering Policy** (opt-in) |

All demand statistics come from one engine (`IPL Demand Statistics`) reading
Item Ledger Entries — one definition of "demand" across all four, computed in
a single cached pass per item (mean, σ, observations, ADI, CV²).

- **Demand definition**: sales, netted against same-day returns. In
  manufacturing companies, enable **Count Consumption as Demand** in setup so
  production and assembly consumption count too — purchased components are
  then planned from their real usage, not just direct sales.
- **Z-scores** come from a continuous inverse-normal approximation (Acklam),
  so a 94.9% service level gets a 94.9% buffer — there is no bucket table.
- **Windows are anchored to the work date**, which equals today in production
  and follows the demo date in evaluation companies, so sandbox trials
  produce real results.
- **Safety stock and reorder point share one lead-time resolution**
  (receipt history → item Lead Time Calculation → setup fallback), so the two
  always agree on the lead time for an item.
- Safety stock results for demand the advisor classifies as intermittent or
  lumpy carry an explicit warning in the log — the normal approximation is
  shaky there and the app says so instead of pretending precision.

## Honest diagnostics

The app tells you when its own numbers deserve suspicion, in the note of
every calculation:

- **Trend warning** — when trailing demand (last quarter of the window, min
  30 days) deviates from the full-window average by more than the setup
  threshold (default 30%), the note says so: history-based values lag
  production ramps and overstate phase-outs. The threshold is configurable;
  0 disables it.
- **SKU notice** — when Stockkeeping Units exist for an item, standard
  planning reads the SKU values at those locations, not the item card. The
  note states this so nobody wonders why a calculated value "isn't working".
  (Per-location calculation is deliberately out of scope for this app.)
- After loading the Planning Worksheet, a summary reports how many lines
  change the reorder point by more than 25%, so a large set can be triaged.

## Per-item controls

Two fields on the Item Card (Planning tab):

- **Exclude from Inventory Planning** — the item is skipped by every
  calculator, bulk run, scheduled job and the dynamic provider. Use it to
  protect planner-maintained values.
- **Planning Service Level %** — per-item override of the default service
  level (0 = use the setup default).

## What's new versus the four standalone apps

- **One setup, one log, one prefix (`IPL`)** — the old apps' duplicated
  statistics code (3 slightly different copies) is gone.
- **Planning Worksheet** — current vs proposed values side by side for a
  filtered item set, selective apply. Applies re-run the calculators through
  the validated, logged path; nothing is blind-copied from the preview, and
  applied lines refresh in place.
- **Run All** — the calculators in dependency order: policy advice →
  safety stock → reorder point (fed the *fresh* safety stock, not the stored
  one) → EOQ → Maximum Inventory (ROP + EOQ, for Maximum Qty. items). When
  the advisor recommends something other than Fixed Reorder Qty., the "Set
  Policy When None" default is suppressed for that item so a single run never
  stamps a policy its own advice contradicts.
- **Dynamic planning provider** (`IPL Planning Provider`) — opt-in. Subscribes
  to `OnAtSKUOnAfterCopyFromItem` on codeunit **99000855 "Planning-Get
  Parameters"** and supplies calculated values to the planning engine *at
  planning time*, so a regenerative plan consumes numbers computed from live
  history instead of whatever a batch job last wrote. Real Stockkeeping Units
  are never touched; items that can't be calculated fall back to their stored
  values; every fresh computation is written to the calculation log (Dynamic
  Supply entries) and emits telemetry, so planning-time values are as
  traceable as batch ones. The provider never touches order modifiers — the
  engine stays authoritative on Min/Max Order Qty and Order Multiple.
- **Log retention** — the calculation log is registered with the standard
  Retention Policy module. Set a retention period under
  *Retention Policies* (90 days is a sensible default); without one the log
  grows by one row per item per calculator per run.

## Requirements

- Business Central 2026 wave 1 (v28) or later, cloud.
  (The `Planning-Get Parameters` integration events are verified against
  BC 28 symbols; for older versions, disable the dynamic provider and check
  event availability.)

## Setup

1. Install; the setup record is created automatically with the same defaults
   as the standalone apps. The setup page is listed under **Manual Setup**.
2. **Inventory Planning Setup**: review history window (365 d), minimum
   observations (20), service level (95%), ordering cost (50), holding rate
   (0.25). Manufacturing companies: enable **Count Consumption as Demand**.
3. Assign permission sets: **IPL - User** for planners, **IPL** (admin) for
   whoever maintains the setup. Users running standard planning runs with the
   dynamic provider enabled need at least IPL - User.
4. Per item: **Item Card → Inventory Planning → Calculate All Planning Values**.
5. Per set: **Item List → Inventory Planning → Planning Worksheet** → Load
   Items → review → Apply Selected. The bulk actions on the Item List honour
   your multi-selection when you make one, otherwise the current filter.
6. Scheduled: **Inventory Planning Setup → Create Job Queue Entry** creates a
   nightly recurring entry (on hold) for codeunit **"IPL Job Queue"**;
   Parameter String `ALL` (default), `SAFETYSTOCK`, `REORDERPOINT`, `EOQ` or
   `ADVISOR`. Review and set it to Ready.
7. Optional: enable **Supply Values at Planning Time (Dynamic)** in setup.
   Verify on a sandbox first: run a regenerative plan for one item and confirm
   the requisition line reflects the calculated values (and the log shows a
   Dynamic Supply entry).

## Migrating from the four standalone apps

The apps coexist safely: different object IDs and different object names.
Recommended path:

1. Install Inventory Planning alongside the old apps.
2. Copy your setup values into Inventory Planning Setup (one page now).
3. Retire the old apps' Job Queue entries; create one for `IPL Job Queue`.
4. Uninstall the four standalone apps when comfortable. Their logs live in
   their own tables — export before uninstall if you delete the apps' data.

Calculation behaviour is a faithful port, with deliberate changes:

- The EOQ calculator's minimum-observations test counts **days with demand**
  (like the other three calculators) instead of ILE rows. If you relied on
  the old row-count behaviour, lower `Min Demand Observations` accordingly.
- Same-day **returns now net against demand** instead of being ignored.
- Z-scores are continuous instead of bucketed; between-bucket service levels
  now get slightly **more** buffer than the old floor-to-lower-bucket table.
- EOQ honours **Round Up Results** and the item's **Minimum/Maximum Order
  Quantity**; a zero result is reported (`Zero Result`) instead of written.
- The reorder point is capped at **Maximum Inventory** when one is set.
- History windows anchor to the **work date** instead of the system date
  (identical in production).

## AppSource submission checklist

The app carries AppSourceCop configuration (`AppSourceCop.json`, affix `IPL`)
and compiles clean under CodeCop, UICop and AppSourceCop. Before submitting:

- [ ] **Object ID range**: objects use the placeholder range
      **70455000–70455099**. Replace it with the range Microsoft assigned to
      your publisher in Partner Center (find/replace `704550` consistently,
      including the two Item field IDs in `IPLItemExt.TableExt.al` and
      `idRanges` in `app.json`).
- [ ] **Register the `IPL` affix** with Microsoft (AppSourceISVs process).
- [ ] **applicationInsightsConnectionString** in `app.json`: create an Azure
      Application Insights resource and paste its connection string —
      without it the IPL0001–IPL0003 telemetry events go nowhere (AS0092).
- [ ] **logo/icon.png** is a generated placeholder — replace with your brand
      asset (240×240).
- [ ] Add **screenshots** to `app.json` and the Partner Center listing.
- [ ] Note: apps in the 70M range cannot be sideloaded as per-tenant
      extensions; cloud sandboxes install via AppSource or as a dev extension.

## Repository layout

```
InventoryPlanning/            the app
  src/{Tables,TableExtensions,Pages,Codeunits,PageExtensions,PermissionSets,Enums}
  logo/icon.png               placeholder logo
  AppSourceCop.json           mandatory affix configuration
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
