# Privacy statement — extension telemetry section

**Add this to <https://gmsoft.co.uk/privacy-statement-uk/>** — the page
`privacyStatement` in the manifest now points at, and the one that names GMSOFT
Limited (company 12275621) as data controller.

That statement is currently a website policy: cookies, visitors, analytics.
AppSource links it from the app manifest, so it also has to describe what **the
extension** does with data once it is installed in a customer's Business Central
environment. Nothing below applies to the website.

Paste it as a new section, or publish it as a sub-page and link to it
prominently from the statement.

> Have your usual legal reviewer check the wording against the entity that
> publishes the offer. This is drafted to be accurate about what the app actually
> does — it is not legal advice.

---

## Business Central extensions — data processing

This section applies to the Business Central apps published by
**GMSOFT Limited**, including **Inventory Planning**.

### Data the app processes inside your environment

Inventory Planning runs entirely inside your own Microsoft Dynamics 365 Business
Central environment. It reads:

- Item ledger entries
- Posted purchase receipt lines
- Item master data, including cost, planning and unit-of-measure fields

It writes to:

- Standard item planning fields — Safety Stock Quantity, Reorder Point, Reorder
  Quantity, Order Multiple, Maximum Inventory and, where you have enabled it,
  Reordering Policy
- Its own setup table and calculation log within your environment

**None of this data is transmitted outside your Business Central environment.**
GMSOFT Limited has no access to it. We are not a data processor for this
content; it never reaches our systems.

### Diagnostic telemetry

The app emits diagnostic telemetry over the standard Business Central telemetry
channel to an Azure Application Insights resource operated by
GMSOFT Limited. This is limited to the following events:

| Event ID | Raised when | Data included |
|---|---|---|
| `GSO0001` | A scheduled calculation run completes | Run mode, number of items processed |
| `GSO0002` | An interactive bulk calculation completes | Calculation type, number of items processed |
| `GSO0003` | Values are computed during a planning run | Event occurrence only |

These events contain **counts and codes only**. They do not include item numbers,
item descriptions, quantities, costs, prices, customer or vendor names, or any
other business data.

Microsoft's telemetry platform attaches standard environment context to these
events, such as an anonymised environment identifier, Business Central version,
country and the extension version. We use this solely to:

- Understand which features are used, so we know what to improve
- Detect errors and performance problems across installations
- Confirm compatibility with new Business Central releases

We do not use telemetry for marketing, we do not sell or share it, and we do not
attempt to re-identify individual users or organisations from it.

Telemetry is retained for **90 days** and is stored in
**UK South**.

If you have configured your own Application Insights resource on your Business
Central environment, the same events are also sent there, under your control.

### Legal basis and your rights

Where this processing involves personal data, we rely on our legitimate interest
in maintaining, securing and improving software we publish. Because the telemetry
described above contains no directly identifying information, we are generally
unable to link it to an individual.

For questions about this section, or to exercise any right you have under
applicable data protection law, contact
**info@gmsoft.co.uk**.

### Support communications

When you contact support we process the contact details and any information you
choose to send us — screenshots, log entries, configuration details — for the
purpose of answering you. We retain support correspondence for
**24 months**.

---

## Values used, and the ones worth checking

| Value | Source | Check it |
|---|---|---|
| GMSOFT Limited | `publisher` in app.json, and the data controller named at gmsoft.co.uk/privacy-statement-uk/ | Confirmed |
| info@gmsoft.co.uk | The contact address on your imprint and UK privacy statement | Confirmed |
| UK South | The region in your Application Insights connection string | Confirmed |
| **90 days** | **Assumed** — the Application Insights default | Check the retention setting on the resource and correct if it differs |
| **24 months** | **Assumed** — matches the retention period your existing statement already declares | Adjust if support mail is kept for a different period |
