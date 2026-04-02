# AGENTS

This repository hosts `BWG Monitor`, a native iOS SwiftUI app for monitoring and operating KiwiVM / BandwagonHost servers.

## Product Identity

- Product name: `BWG Monitor.app`
- Scheme: `BWG Monitor`
- Bundle identifier: `dev.govo.bwgmonitor.ios`
- Version baseline: `0.1.0`

## Scope

- Add, edit, refresh, and delete KiwiVM servers
- View current transfer, CPU, memory, swap, disk, and status data
- View metric history from local SQLite storage
- Send `Start`, `Restart`, and `Stop` power actions
- Use a single `Servers` home screen; open `Settings` from the top-right button

## Structure

- `App/`: iOS UI and app state
- `Shared/`: models, API client, and mapping
- `Support/`: scripts
- `project.yml`: XcodeGen source of truth
- `.version`: version source of truth

## Platform Target

- iPhone-focused build target (`TARGETED_DEVICE_FAMILY = 1`)
- Keep iPhone simulator validation as the default workflow
- Current runtime plist generation includes scene manifest and launch screen keys from `project.yml`

## Storage

- App data lives in the iOS app sandbox under `Library/Application Support/BWGMonitor/`
- API keys are stored in `servers.json`
- Per-server history lives in `Servers/<serverID>/history.sqlite`

## Build

- Run `./Support/generate_project.sh` after changing `.version` or `project.yml`
- Preferred validation command:
  - `xcodebuild -project BWGMonitor.xcodeproj -scheme "BWG Monitor" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`

## Rules

- Keep KiwiVM API logic in `Shared/`
- Use `apply_patch` for source edits
- Keep identifiers consistent across `project.yml`, runtime defaults, and docs
- Keep docs aligned with the current single-screen navigation and iPhone-only target
