# Notes for validation

Paste into **Partner Center → Supplemental content → Notes for certification**.
Written for a reviewer who has never seen the app and has ten minutes.

---

## What this app does

Reads posted Item Ledger Entries and calculates safety stock, reorder point,
EOQ and a recommended reordering policy, then writes them to the standard item
planning fields. No parallel data model, no external service calls.

## Before you start — important on demo data

**On CRONUS the shipped defaults will produce no results, and that is correct
behaviour, not a fault.**

The app requires 20 distinct days with posted demand inside a 365-day window
before it will produce a number. Demo companies contain far fewer posting days
than that, so every item reports **Insufficient Demand Data** and every value
stays zero.

To see the app work, open **Inventory Planning Setup** and change two fields
first:

| Field | Change to |
|---|---|
| Demand History Window (Days) | **1095** |
| Min Demand Observations | **3** |

Also confirm the **work date** falls inside the range where the demo company has
posted item ledger entries. History windows anchor to the work date, not the
system date.

## Permissions

Two permission sets ship with the app. Assign **GSO** (administrator) to the
account you test with.

- `GSO` — Inventory Planning, administrator
- `GSO - User` — Inventory Planning - User, for planners

## Test script

**1. Setup** — search for *Inventory Planning Setup*. It is also listed under
Manual Setup. Apply the two changes above.

**2. One item** — open item **1896-S**, then
**Item Card → Actions → Inventory Planning → Calculate All Planning Values**.

Expected: a message reporting the calculated safety stock and the reasoning,
for example *"Safety stock 6. Buffer covers demand variability over a stable
lead time at 98% service level… Z=2.0537; LT=7 d; D=0.11/d; n=19 ob"*. The item's
Safety Stock Quantity, Reorder Point and Reorder Quantity are updated.

**3. Evidence** — **Item Card → Inventory Planning → Calculation Log**.

Each entry records the demand statistics, the lead time and where it came from,
the service level and Z-score, the previous value, and the outcome. This is the
audit trail behind every number the app writes.

**4. A set of items** —
**Item List → Inventory Planning → Planning Worksheet → Load Items**, filtered by
item category.

Expected: current and proposed values side by side. Nothing is written at this
point. Tick some lines and choose **Apply Selected** to write them.

**5. Scheduling (optional)** — **Inventory Planning Setup → Create Job Queue
Entry** creates a recurring entry, deliberately **on hold** so it cannot run
unattended without a decision.

## Behaviour that may look like a defect but is not

**Rows reporting Insufficient Demand Data.** Observations count *days with
demand*, not transaction lines. An item with 200 sales lines across 12 days has
12 observations. The app reports this rather than producing a number from data
that cannot support one.

**A calculated value appearing to have no effect on planning.** If an item has
Stockkeeping Units, standard planning reads the SKU values at a location, not
the item card. The app calculates at item level by design and says so in the
calculation note whenever SKUs exist.

**Reordering policy unchanged after an advice run.** *Auto-Update Item
Reordering Policy* is off by default. Recommendations are logged either way.

**Zero Result reported instead of written.** A calculation that produces zero is
reported rather than written, so an existing real value is never replaced with
nothing.

## Data handling

Reads item ledger entries, posted purchase receipt lines and item master data.
Writes to standard item planning fields plus its own setup and calculation log
tables. **Nothing leaves the tenant.**

Diagnostic telemetry (events GSO0001–GSO0003) goes to the publisher's
Application Insights resource over the standard Business Central channel. Those
events carry counts and codes only — no item numbers, quantities, costs or
customer data. Disclosed in the linked privacy statement.

**Supply Values at Planning Time (Dynamic)** is off by default. It is the only
feature that interacts with the planning engine at runtime, and it does not need
to be enabled to validate the app.

## Support

support@gmsoft.co.uk · +44 7771 313713 · Monday to Friday, 09:00–18:00 UK time

Documentation: https://gmsoftdynamics.com/apps/inventory-planning/docs/
Source: https://github.com/GmsoftLtd/bc-inventory-planning (MIT)
