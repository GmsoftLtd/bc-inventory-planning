# Signing

Business Central `.app` packages are signed with **Azure Artifact Signing**
(formerly Trusted Signing) rather than a certificate file. There is no `.pfx`
anywhere: the key lives in Microsoft's FIPS 140-3 Level 3 HSMs, certificates are
issued and renewed automatically, and only a digest of the package ever leaves
this machine.

## The Azure resources

| | |
|---|---|
| Signing account | `gmsoftsigning` |
| Certificate profile | `gmsoft-public-trust` (Public Trust) |
| Endpoint | `https://neu.codesigning.azure.net/` |
| Subscription | MCPP Subscription · `gmsoft-signing-rg` · North Europe |
| Identity validation | GMSOFT LIMITED, company 12275621 |

Certificate subject: `CN=GMSOFT LIMITED, O=GMSOFT LIMITED, L=Bolton, C=GB`.

## One-off setup

### 1. Register NavSip.dll — needs an elevated PowerShell

```powershell
.\install-navsip.ps1
```

`signtool` has no idea what an `.app` file is until this Subject Interface
Package is registered. Without it you get *"The form specified for the subject
is not one supported or known by the specified trust provider"* — the same error
`Get-AuthenticodeSignature` gives on an already-signed `.app`.

It ships with Business Central Server, not the Windows SDK, so the script pulls
the BC artifacts to extract it. No Docker needed. The download is a few hundred
MB and is cached.

### 2. Sign in to Azure

```powershell
az login
```

Or, for unattended use, set `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` and
`AZURE_CLIENT_SECRET` for a service principal.

Whichever identity signs needs the **Artifact Signing Certificate Profile
Signer** role on `gmsoftsigning`. A user account's assignment does not help a
pipeline — a service principal or managed identity needs its own.

## Signing

Build and sign in one go:

```powershell
.\sign.ps1 -Build
```

Sign packages that already exist:

```powershell
.\sign.ps1 -Path "C:\path\GMSOFT Limited_Vendor Dispute_1.2.5.0.app"
```

Both accept multiple paths, and `-SkipVerify` if you want to skip the
post-signing check.

On first run the script downloads two NuGet packages into `.tools\`
(gitignored): `microsoft.windows.sdk.buildtools` for `signtool.exe`, and
`microsoft.trusted.signing.client` for the dlib that signtool calls out to.

## What it runs

```
signtool sign /v /debug /fd SHA256
              /tr http://timestamp.acs.microsoft.com /td SHA256
              /dlib Azure.CodeSigning.Dlib.dll /dmdf metadata.json
              <file.app>
```

The timestamp matters: it keeps signatures valid after the signing certificate
expires. Artifact Signing certificates are short-lived by design, so signing
without `/tr` would produce signatures that stop validating within days.

## Quota

The Basic tier allows **5,000 signatures a month**, which is far more than four
apps a year needs. Check the timestamp service is healthy with:

```powershell
curl http://timestamp.acs.microsoft.com   # 200 = fine
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| "form specified for the subject is not supported" | NavSip not registered — run `install-navsip.ps1` elevated |
| `403` | Signing identity lacks **Certificate Profile Signer**, or the account/profile name in `metadata.json` is wrong |
| `401` | Not signed in — `az login` |
| "No certificates were found that met all the given criteria" | signtool is looking locally instead of at the service — check the `/dlib` path is correct |
| Silent failure, no error | Missing .NET runtime, or the C++ redistributable |
