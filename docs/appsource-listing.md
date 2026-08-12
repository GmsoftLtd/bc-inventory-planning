# AppSource Listing — Inventory Planning

Marketing copy and asset plan for the Partner Center offer listing.
Copy blocks below are written to fit Partner Center's field limits and are
ready to paste.

> Field limits are those current at the time of writing. Partner Center adjusts
> them occasionally — check the character counters as you paste.

---

## Positioning

**The one-line pitch**

> Your planning engine is only as good as the numbers you feed it. This fills in
> the numbers.

**The problem.** Business Central's planning engine is capable and correct. It
also does exactly what the item card tells it to — and on most implementations
Safety Stock Quantity is empty, Reorder Point was typed in during go-live by
somebody estimating, and Reorder Quantity is a round number nobody has revisited
since. The engine executes those guesses faithfully, and the business absorbs
the result as stockouts on the items that matter and dead stock on the ones that
do not.

**The answer.** Calculate the parameters from history that is already posted in
the system, write them to the standard fields, and show your working.

**Who it is for**

- SMB manufacturers, distributors and wholesalers running BC planning
- Inventory managers and buyers who maintain planning parameters by hand
- BC partners who need defensible planning numbers at go-live rather than
  placeholders

**Why anyone would choose it**

1. **No parallel data model.** It writes standard fields. Standard planning,
   requisition worksheets and MRP consume the results with zero further
   configuration, and uninstalling leaves the values behind.
2. **It shows its working.** Every calculation logs the demand statistics, the
   lead time and its source, the Z-score, the costs, the previous value and the
   reasoning. Any number is defensible months later.
3. **It tells you when to doubt it.** Trend warnings when recent demand diverges
   from the window, notices when Stockkeeping Units mean the item card is not
   what planning reads, and explicit warnings when demand is too lumpy for the
   statistics to be trustworthy.
4. **Preview before commit.** The Planning Worksheet shows current versus
   proposed for a filtered set, flags the material changes, and applies only
   what you tick.
5. **Free and open source.** MIT licensed, source on GitHub.

---

## Listing copy

### Offer name — 50 char limit

```
Inventory Planning: Safety Stock, ROP, EOQ
```
*42 characters*

### Search results summary — 100 char limit

```
Calculate safety stock, reorder point and EOQ from your real Business Central demand history.
```
*93 characters*

### Short description — 256 char limit

```
Stop guessing your planning parameters. Inventory Planning reads posted item ledger history and calculates safety stock, reorder point, EOQ and a recommended reordering policy, then writes them to the standard fields. Free and open source.
```
*239 characters*

### Description — 3000 char limit

Partner Center accepts a subset of HTML (`<p>`, `<h2>`, `<h3>`, `<ul>`, `<li>`,
`<b>`, `<i>`, `<br>`). Plain text below; wrap when pasting.

---

**Planning parameters calculated from history you already have**

Business Central's planning engine does exactly what your item cards tell it to.
On most systems that means an empty Safety Stock Quantity, a Reorder Point
somebody estimated at go-live, and a Reorder Quantity nobody has revisited since.
Inventory Planning replaces the guesswork with arithmetic.

It reads your posted Item Ledger Entries and calculates:

- **Safety stock** covering demand and lead-time variability at the service level
  you choose, per item if you want
- **Reorder point** — demand during lead time, plus safety stock
- **Economic order quantity** using the Wilson formula, capped and aware of your
  order modifiers
- **Maximum inventory** — the order-up-to level for Maximum Qty. items
- **A recommended reordering policy**, from a Syntetos–Boylan classification of
  each item's demand pattern

Results are written to the standard item fields, so standard planning,
requisition worksheets and MRP pick them up immediately. There is no parallel
data model and nothing to reconfigure.

**Review before you commit**

The Planning Worksheet shows current versus proposed values side by side for any
filtered set of items, tells you how many lines change the reorder point
materially, and applies only the lines you select.

**Numbers you can defend**

Every calculation is logged with the demand statistics behind it, the lead time
and where it came from, the service level and Z-score, the costs, the previous
value and the reasoning. When someone asks why an item's reorder point is what
it is, the answer is one click away.

**Honest about its own limits**

The app warns you when recent demand has diverged from the historical window,
when Stockkeeping Units mean the planning engine reads a different value than
the item card, and when an item's demand is too intermittent for the underlying
statistics to be trusted.

**Optional planning-time values**

Instead of relying on whatever the last batch run wrote, the app can supply
freshly calculated values to the planning engine during a planning run, fully
logged. Off by default.

**Run it your way**

Per item from the Item Card, in bulk from the Item List, from the Planning
Worksheet, or on a nightly Job Queue schedule.

**Free and open source.** MIT licensed. Source at
github.com/GmsoftLtd/bc-inventory-planning

---

### Key benefits — 3 items, title ~50 / description ~300 chars

**1. Planning numbers from real history**
Safety stock, reorder point, EOQ and reordering policy calculated from posted
item ledger entries and written to the standard Business Central fields — no
parallel data model, no reconfiguration, results your existing planning runs
consume immediately.

**2. Preview the whole range before you apply**
The Planning Worksheet puts current and proposed values side by side for any
filtered item set, highlights how many lines change the reorder point by more
than 25%, and applies only the lines you tick.

**3. Every number is defensible**
Each calculation logs its demand statistics, lead time and source, service
level, costs and previous value, plus explicit warnings when a trend, a
Stockkeeping Unit or a lumpy demand pattern means the result deserves review.

### Search keywords — 3 maximum

```
safety stock
reorder point
economic order quantity
```

### Getting started instructions

```
1. Assign permission sets: "Inventory Planning - User" to planners, "Inventory
   Planning" to administrators.
2. Search for "Inventory Planning Setup" and review the defaults: 365-day
   history window, 95% service level, ordering cost and holding rate.
   Manufacturing companies should enable "Count Consumption as Demand".
3. Try one item: Item Card > Inventory Planning > Calculate All Planning Values,
   and read the calculation log entry it produces.
4. Roll out with Item List > Inventory Planning > Planning Worksheet: load a
   filtered set, review current vs proposed, apply what you select.
5. Optional: Inventory Planning Setup > Create Job Queue Entry for a nightly
   recalculation, and set a Retention Policy on the calculation log.

Full guide: <user guide URL>
```

### Categories and industries

| Field | Value |
|---|---|
| Primary category | Operations & Supply Chain |
| Secondary category | Analytics *(optional)* |
| Industries | Manufacturing; Distribution / Wholesale; Retail |
| Products it works with | Dynamics 365 Business Central |
| App type | Free |

---

## Visual assets

### Logos

| Asset | Size | Status |
|---|---|---|
| Large logo | 216×216 PNG | Derive from `InventoryPlanning/logo/icon.png` |
| Small / medium / wide | 48×48, 90×90, 255×115 | Partner Center generates from the large logo, but supply your own if the crop is poor |

### Screenshots — up to 5, 1280×720 PNG

Shoot these in a demo company with real-looking data. Order matters; the first
is the one most people see.

1. **Planning Worksheet, loaded** — current versus proposed columns visible
   across several items, with a mix of demand patterns and result codes. This is
   the single most persuasive image the app has: it shows the product doing its
   job and being cautious about it.
   *Caption: Review current versus proposed values for a filtered item set, then
   apply only what you select.*

2. **Inventory Planning Setup** — the whole page, showing the four calculator
   groups.
   *Caption: One setup page for all four calculators — service level, costs,
   thresholds and write targets.*

3. **Calculation log entry** — an entry with demand statistics, lead time
   source, Z-score and note populated.
   *Caption: Every calculation records the statistics, lead time, costs and
   previous value behind it.*

4. **Item Card, Inventory Planning action group open** — with the Planning tab
   showing the two per-item fields.
   *Caption: Calculate per item, and exclude planner-maintained items from bulk
   runs.*

5. **A calculation result message showing a trend or SKU warning.**
   *Caption: The app flags when a result deserves review — trends, Stockkeeping
   Units and lumpy demand.*

### Video — optional, up to 4

A 60–90 second screen capture converts well for a free app:

- 0:00–0:10 — the problem: an item card with empty planning fields
- 0:10–0:30 — Calculate All Planning Values on that item, show the result and
  the log entry behind it
- 0:30–0:60 — Planning Worksheet: load a category, point at the variance
  message, apply a selection
- 0:60–0:75 — the setup page and the nightly Job Queue entry
- 0:75–0:90 — free, MIT, source on GitHub

---

## Links

Point these at the ISV site rather than the consultancy or the blog. See the
mapping discussion in the repo before filling them in.

| Partner Center field | Value |
|---|---|
| Landing / product page | `https://www.gmsoftdynamics.com/apps/inventory-planning/` |
| Help / documentation | `https://www.gmsoftdynamics.com/apps/inventory-planning/docs/` |
| Support | `https://www.gmsoftdynamics.com/apps/inventory-planning/support/` |
| Privacy policy | GMSoft Dynamics privacy statement |
| Licence terms | `https://github.com/GmsoftLtd/bc-inventory-planning/blob/main/LICENSE` (MIT) |

These must match `app.json` (`url`, `help`, `privacyStatement`, `EULA`,
`contextSensitiveHelpUrl`). All must be HTTPS, publicly reachable without a
login, and actually resolve.

Microsoft defines these fields distinctly, so do not point two of them at the
same generic page:

- **`help`** — "an online description of the extension focusing on the help and
  troubleshooting content". May be identical to `contextSensitiveHelpUrl`. The
  readiness checklist requires a landing page carrying documentation, FAQs,
  step-by-step guides and getting-started instructions.
- **`url`** — the app's advertising or feature page, explicitly "other than
  troubleshooting and help". Shown in Business Central on the Extension
  Management page as **Website**.
- **`contextSensitiveHelpUrl`** — required for Marketplace submission, with a
  trailing slash. Every **Learn more** link in the app's tooltips and Help pane
  resolves against it, falling back to a default page for any object without a
  `ContextSensitiveHelpPage`. It must not 404.
- **Support link** must be a *separate page* from the help link, offering **more
  than two** contact options, reachable without sign-in, and stating a response
  time frame.

Ready-made pages for all of these are in [`website/`](website/).

**Privacy statement must cover the extension, not just the website.** The app
emits diagnostic telemetry (events GSO0001–GSO0003: counts and codes only, never
business data) to the publisher's Application Insights resource. Disclose what
is collected, that it is diagnostic rather than business data, and where it is
stored.

---

## Pre-submission checklist

**Done**

- [x] Objects in GMSOFT's assigned AppSource range 73030575–73031574
- [x] `AppSourceCop.json` configured with the `GSO` affix; compiles clean under
      CodeCop, UICop and AppSourceCop
- [x] `applicationInsightsConnectionString` set in `app.json`
- [x] Final app icon in place
- [x] Namespaces on every object
- [x] Permission sets shipped: `GSO` (admin) and `GSO - User` (planner)

**Outstanding**

- [ ] Register the `GSO` affix with Microsoft via the AppSourceISVs process
- [ ] Publish the pages in [`website/`](website/) and update the URLs in
      `app.json` — the current `contextSensitiveHelpUrl` returns 404, which
      breaks every **Learn more** link in the app
- [ ] Publish a separate support page with 3+ contact options and a stated
      response time (`website/support.html`)
- [ ] Extend the privacy statement to cover extension telemetry
      (`website/privacy-telemetry-section.md`)
- [ ] Capture the five screenshots and add them to the Partner Center listing
- [ ] Confirm which legal entity publishes the offer, and make `publisher` in
      `app.json`, the listing and the linked privacy statement agree
- [ ] Optional: add `ContextSensitiveHelpPage` to the five UI objects to
      deep-link tooltips to specific articles instead of the docs hub

---

## Copy notes

Things to keep saying, because they are true and unusual:

- *"Writes to the standard fields"* — the strongest technical differentiator.
  Buyers have been burned by apps that build a shadow planning model.
- *"Shows its working"* — the log is a genuine feature, not plumbing.
- *"Tells you when to doubt it"* — trend, SKU and lumpy-demand warnings. Very
  few planning tools admit their own limits, and it builds trust fast.
- *"Free and open source"* — removes the evaluation barrier entirely.

Things to avoid claiming:

- Anything about forecasting or AI. This is descriptive statistics over posted
  history, and saying so plainly is more credible than dressing it up.
- Per-location or SKU-level planning. Explicitly out of scope — say so, and say
  what the app does instead.
- Guaranteed savings or service-level outcomes. The app calculates parameters;
  results depend on data quality and how the business uses them.
