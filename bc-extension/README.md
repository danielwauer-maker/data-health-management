## BC extension build profiles

This repository now uses a release-safe default manifest for cloud packaging:

- `app.json`
  - default cloud manifest
  - intended for production/release packaging
  - `resourceExposurePolicy` is hardened for release:
    - `allowDebugging=false`
    - `allowDownloadingSource=false`
    - `includeSourceInSymbolFile=false`

Additional manifests are kept for explicit non-default scenarios:

- `app.cloud.json`
  - cloud development companion manifest
  - keeps source/debug exposure enabled for intentional DEV builds only
- `app.onprem.bc19.json`
  - legacy on-prem BC19 companion manifest
  - hardened, not the default cloud release path

## Build path

### DEV cloud

- Use `.vscode/launch.json` (`Microsoft cloud sandbox (DEV)`) for local debugging.
- If a cloud sandbox build with debug/source exposure is explicitly needed, use `app.cloud.json` intentionally as the manifest source for that build.
- The repository default `app.json` is no longer the DEV profile.
- To prepare an isolated DEV build workspace without mutating the repo manifest, run:
  - `powershell -ExecutionPolicy Bypass -File .\bc-extension\scripts\New-BCBuildWorkspace.ps1 -Profile DevCloud`
- Use the generated workspace at `bc-extension\.build\DevCloud\`.

### PROD / release cloud

- Use `app.json` as the only default packaging manifest for customer-facing cloud releases.
- Do not replace it with `app.cloud.json` during release packaging.
- To prepare an isolated release build workspace, run:
  - `powershell -ExecutionPolicy Bypass -File .\bc-extension\scripts\New-BCBuildWorkspace.ps1 -Profile ReleaseCloud`
- Use the generated workspace at `bc-extension\.build\ReleaseCloud\`.

### OnPrem BC19

- Use `app.onprem.bc19.json` only for explicit BC19 on-prem builds.
- To prepare an isolated BC19 OnPrem workspace, run:
  - `powershell -ExecutionPolicy Bypass -File .\bc-extension\scripts\New-BCBuildWorkspace.ps1 -Profile OnPremBc19`
- Use the generated workspace at `bc-extension\.build\OnPremBc19\`.

## What The Script Does

- copies `app/` into a generated build workspace
- copies the selected manifest into that workspace as `app.json`
- copies `.alpackages/` when present
- copies `.vscode/launch.json` for the DEV cloud profile

This keeps `bc-extension/app.json` as the release-safe default in the repo while making DEV and PROD packaging paths explicit.

## Release hygiene

The repo still contains dev/build artifacts that should not be treated as release sources:

- `.alpackages/`
- `.snapshots/`
- packaged `.app` files in the repo root

They are already ignored in the root `.gitignore`, but existing tracked artifacts should be cleaned up separately to reduce the risk of shipping the wrong output.
