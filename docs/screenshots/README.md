# Listing screenshots

Images for the Partner Center **Offer listing → Marketplace media** section.
Nothing here is packaged into the `.app` — only `logo/icon.png` is, via the
`logo` property in `app.json`. The `screenshots` array in the manifest is a
separate, unused mechanism and stays empty.

## Naming

```
NN-name.png        1280×720, ready to upload
NN-name-raw.png    the original capture, kept so it can be re-cropped
```

The number is the display order. AppSource shows the first image largest, and
most visitors never scroll past it.

## The set

| # | File | Status | Caption |
|---|---|---|---|
| 01 | `01-planning-worksheet.png` | **ready** | Review current versus proposed values for a filtered set of items, then apply only the lines you select. |
| 02 | `02-setup.png` | **ready** | One setup page for all four calculators — history window, service level, costs and write targets. |
| 03 | `03-calculation-log.png` | **ready** | Every calculation records the statistics, lead time and previous value behind it. |
| 04 | `04-item-card.png` | **ready** | Every calculator, per item, from the Item Card. |
| 05 | `05-result-message.png` | **ready** | The app flags when a result deserves review — here, demand too intermittent for the method to be reliable. |

### 02 — note

Policy Advisor and Planning Engine Integration sit below the fold. That is the
right trade: General, Safety Stock, Reorder Point and EOQ are what an evaluator
reads, and squeezing all six in would have made the text too small.

The values shown are the demo settings — 1095-day window, 3 minimum
observations — not the shipped defaults of 365 and 20. That matches the
"evaluating on demo data" note in the Partner Center getting started
instructions, so the two are consistent.

### 03 — optional tidy

Re-captured with a `Avg. Daily Demand <> 0` filter so the statistics columns are
populated. The Views pane is still open on the left, showing that filter. It is
honest and costs about 200px of frame; closing it before a re-shoot would be
slightly cleaner but is not worth another pass on its own.

Captions are also in [`../appsource-listing.md`](../appsource-listing.md). Keep
the two in step.

## Preparing an image

Captures come out wider than 16:9, so scaling straight to 1280×720 distorts
them. Scale to 1280 wide and centre on a white 1280×720 canvas instead — the
Business Central page background is white, so the bars are invisible, and every
column stays readable.

```powershell
Add-Type -AssemblyName System.Drawing
$img    = [System.Drawing.Image]::FromFile($src)
$h      = [int][Math]::Round($img.Height * (1280 / $img.Width))
$canvas = New-Object System.Drawing.Bitmap(1280, 720)
$g      = [System.Drawing.Graphics]::FromImage($canvas)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::White)
$g.DrawImage($img, 0, [int][Math]::Round((720 - $h) / 2), 1280, $h)
$g.Dispose(); $canvas.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
```

## What makes these work

**Show a change.** Current and proposed columns must differ, or the screen reads
as a tool that agrees with itself. Raise the service level and reload without
applying.

**Leave the failures in.** Screenshot 01 keeps three rows reporting
*Insufficient Demand Data*. A screen where everything succeeds looks staged;
honest skips demonstrate the app knows its own limits, which is the pitch.

**Demo data needs loosening first.** On CRONUS, set Min Demand Observations to 3
and the history window to 1095, or every row reports Insufficient Demand Data —
correctly, but uselessly for a screenshot.

**Check before uploading:** no customer or personal data, no browser chrome, no
Copilot or extension icons. These are public permanently.
