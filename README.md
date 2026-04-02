# BWG Monitor

`BWG Monitor` is a native iOS app for monitoring and operating KiwiVM / BandwagonHost servers.

## Current Scope

- Add servers with `Name`, `VEID`, `API key`, and optional `Note`
- Refresh `getServiceInfo`, `getLiveServiceInfo`, and `getRawUsageStats`
- View transfer, CPU, memory, swap, disk, and basic server status
- Open metric history sheets backed by local SQLite history
- Send `Start`, `Restart`, and `Stop` power actions
- Edit or delete configured servers
- Use a single `Servers` home screen and open `Settings` from the top-right button

## Platform

- Current app target is iPhone-focused (`TARGETED_DEVICE_FAMILY = 1`)
- Recommended validation simulator remains `iPhone 17`

## Project Layout

- `App/`: iOS UI and app state
- `Shared/`: KiwiVM client, models, and mapping logic
- `Support/`: helper scripts
- `project.yml`: XcodeGen source of truth
- `.version`: release label source of truth

## Build

Generate the project:

```bash
./Support/generate_project.sh
```

Validate with Xcode build:

```bash
xcodebuild -project BWGMonitor.xcodeproj -scheme "BWG Monitor" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Storage

- `<App Sandbox>/Library/Application Support/BWGMonitor/servers.json`
- `<App Sandbox>/Library/Application Support/BWGMonitor/settings.json`
- `<App Sandbox>/Library/Application Support/BWGMonitor/current_snapshots.json`
- `<App Sandbox>/Library/Application Support/BWGMonitor/Servers/<serverID>/history.sqlite`

API keys are stored directly in `servers.json`.

## App Identity

- Product name: `BWG Monitor`
- Scheme: `BWG Monitor`
- Bundle identifier: `dev.govo.bwgmonitor.ios`
- Version: `0.1.0`
