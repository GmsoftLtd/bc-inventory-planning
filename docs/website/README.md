# Website files — Inventory Planning

Everything you need to publish on gmsoftdynamics.com to satisfy the AppSource
help, support and marketing link requirements, and to stop the current 404 on
`contextSensitiveHelpUrl`.

These are plain HTML pages with one shared stylesheet. Deploy them as-is on
static hosting, or paste the content inside `<main>` into your CMS and let your
own theme style it.

---

## Fastest route: the WordPress import file

`inventory-planning-wordpress-import.xml` contains all 11 pages, already
converted to theme-native markup — no stylesheet, no page shell, callouts as
blockquotes, and every internal link absolute so it resolves wherever the pages
end up.

1. WordPress admin → **Tools → Import → WordPress** (install the importer if
   prompted)
2. Upload the XML, assign the posts to your own user, **Submit**
3. **Pages** → open **Inventory Planning** → set **Page Attributes → Parent** to
   your existing **Apps** page

Step 3 is the only manual bit. Setting the parent once moves the whole tree, so
the URLs become:

```
/apps/inventory-planning/
/apps/inventory-planning/support/
/apps/inventory-planning/docs/
/apps/inventory-planning/docs/getting-started/
/apps/inventory-planning/docs/inventory-planning-setup/
…and the other five articles
```

Then verify `…/docs/` returns 200 — that is the URL `contextSensitiveHelpUrl`
points at.

The import creates pages with IDs 1001–1011 in the file; WordPress assigns real
IDs on import and remaps the parent relationships automatically.

---

## What goes where

| File | Publish at | Referenced by |
|---|---|---|
| `inventory-planning.html` | `/apps/inventory-planning/` | `app.json` → `url`, Partner Center landing page |
| `docs/index.html` | `/apps/inventory-planning/docs/` | `app.json` → `help` **and** `contextSensitiveHelpUrl`, Partner Center help link |
| `docs/getting-started.html` | `/apps/inventory-planning/docs/getting-started` | linked from docs hub |
| `docs/inventory-planning-setup.html` | `…/docs/inventory-planning-setup` | context help for the Setup page |
| `docs/inventory-planning-worksheet.html` | `…/docs/inventory-planning-worksheet` | context help for the Planning Worksheet |
| `docs/inventory-planning-log.html` | `…/docs/inventory-planning-log` | context help for the Calculation Log |
| `docs/inventory-planning-item-fields.html` | `…/docs/inventory-planning-item-fields` | context help for the Item Card fields |
| `docs/running-the-calculators.html` | `…/docs/running-the-calculators` | context help for the Item List actions |
| `docs/troubleshooting.html` | `…/docs/troubleshooting` | linked from docs hub |
| `docs/faq.html` | `…/docs/faq` | linked from docs hub |
| `support.html` | `/apps/inventory-planning/support/` or a site-wide `/support/` | Partner Center **support link** |
| `privacy-telemetry-section.md` | append to your existing privacy statement | `app.json` → `privacyStatement` |
| `assets/site.css` | `/assets/site.css` | all pages |

The URLs must end without a trailing `.html` if you want them to match the
context-help slugs exactly. Most static hosts do this automatically; on Apache
use `MultiViews`, on nginx `try_files $uri $uri.html $uri/ =404`.

**`contextSensitiveHelpUrl` must keep its trailing slash:**
`https://gmsoftdynamics.com/apps/inventory-planning/docs/`

---

## Values baked into these pages

| Field | Value |
|---|---|
| Support mailbox | `support@gmsoft.co.uk` |
| Support telephone | `+44 7771 313713` |
| Support hours | Monday to Friday, 09:00–18:00 UK time |
| Response time | 2 business days |
| Contact form | `https://gmsoftdynamics.com/contact/` |
| Legal entity | GMSOFT Limited |

Change any of them by editing the HTML, or the page directly in WordPress if it
has already been imported.

**Still outstanding:** the product page has no AppSource button, because the
offer is not live yet. `inventory-planning.html` carries a commented-out marker
showing where it goes once you have the listing URL. The privacy telemetry
section also has three values left to decide — see
`privacy-telemetry-section.md`.

---

## Why the support page is separate

Microsoft's readiness checklist requires the help link and support link to be
**two distinct pages**, unless one page fully covers both sets of requirements.
The support page must offer **more than two** contact options, be reachable
without signing in, and should state a response time frame.

`support.html` provides four contact routes and a stated response time. Fill in
the placeholders and it satisfies the requirement.

---

## After publishing

Update [`InventoryPlanning/app.json`](../../InventoryPlanning/app.json):

```json
"privacyStatement": "https://gmsoftdynamics.com/privacy/",
"EULA": "https://github.com/GmsoftLtd/bc-inventory-planning/blob/main/LICENSE",
"help": "https://gmsoftdynamics.com/apps/inventory-planning/docs/",
"url": "https://gmsoftdynamics.com/apps/inventory-planning/",
"contextSensitiveHelpUrl": "https://gmsoftdynamics.com/apps/inventory-planning/docs/",
```

Then verify every URL returns 200 in a private browser window with no session.

### Optional: deep-link the tooltips

Right now every **Learn more** link in the app lands on the docs hub, which is
correct and sufficient. To send each page to its own article, add
`ContextSensitiveHelpPage` to the AL objects:

| Object | Property value |
|---|---|
| `page "GSO Setup"` | `'inventory-planning-setup'` |
| `page "GSO Planning Worksheet"` | `'inventory-planning-worksheet'` |
| `page "GSO Calculation Log"` | `'inventory-planning-log'` |
| `pageextension "GSO Item Card Ext"` | `'inventory-planning-item-fields'` |
| `pageextension "GSO Item List Ext"` | `'running-the-calculators'` |

The slugs above match the filenames in `docs/`. Not required for submission.
