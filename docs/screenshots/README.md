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
| 02 | `02-setup.png` | **re-shoot** — General group scrolled off the top | One setup page for all four calculators — service level, costs, thresholds and write targets. |
| 03 | `03-calculation-log.png` | **re-shoot** — every row reads Insufficient with zero statistics | Every calculation records the statistics, lead time, costs and previous value behind it. |
| 04 | `04-item-card.png` | **ready** | Every calculator, per item, from the Item Card. |
| 05 | `05-result-message.png` | **ready** | The app flags when a result deserves review — here, demand too intermittent for the method to be reliable. |

### 02 — what to change

Maximise the page (⤢ top right) so it does not open over the Role Center, press
Ctrl+- until all six group headers fit, and scroll to the very top. General is
the group that matters most to an evaluator and it is currently above the fold.
The crop already removes the Role Center bleed and the Windows taskbar.

### 03 — what to change

Filter the log to `Result Code = OK`, or to a single item that produced values
such as 1896-S. The current capture shows WRB-1001…1007, which have no demand at
all, so every statistic column is zero and the notes read "Found 0 observations".
The caption promises the opposite of what the image shows.

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
