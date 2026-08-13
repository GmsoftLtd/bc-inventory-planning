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

| # | File | Shows | Caption |
|---|---|---|---|
| 01 | `01-planning-worksheet.png` | Planning Worksheet loaded, current vs proposed side by side | Review current versus proposed values for a filtered set of items, then apply only the lines you select. |
| 02 | *pending* | Inventory Planning Setup, all five groups | One setup page for all four calculators — service level, costs, thresholds and write targets. |
| 03 | *pending* | A populated calculation log entry | Every calculation records the statistics, lead time, costs and previous value behind it. |
| 04 | *pending* | Item Card with the Inventory Planning actions open | Calculate per item, and exclude planner-maintained items from bulk runs. |
| 05 | *pending* | A result message carrying a trend or SKU warning | The app flags when a result deserves review — trends, Stockkeeping Units and lumpy demand. |

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
