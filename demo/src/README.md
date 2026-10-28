# Inventory Planning Demo Data

Object IDs 60000-69999 (test/demo range 50000-99999).

- `GSO Demo Data` (codeunit 60000) creates seven items, `GSODEMO-SMOOTH`, `-ERRATIC`, `-INTERMIT`,
  `-LUMPY`, `-PERISH`, `-RAMP` and `-NEW`, and posts a year of history for each with the item
  journal: one purchase for opening stock, then one sale per demand day. The numbers are the same on
  every run. Posting groups come from the first inventory item in the company, so use CRONUS or another
  demo company.
- `GSO Demo Setup Ext` adds **Create Demo Data** to the Inventory Planning Setup page.
- `GSO Demo` permission set runs the action.
