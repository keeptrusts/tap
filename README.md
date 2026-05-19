# Keeptrusts Tap


```ruby
tap "keeptrusts/tap"
brew "<formula>"
```

For the Keeptrusts CLI specifically:

```bash
brew tap keeptrusts/tap
brew install keeptrusts/tap/kt
```

## What this tap manages

- `kt` — the Keeptrusts CLI and local gateway runtime

The formula installs the prebuilt `kt` binary for macOS or Linux. It does not
require Rust for normal installation.

## Current release model

- Release artifacts are served from `https://dl.keeptrusts.com/releases/latest/`.
- macOS uses `kt-macos-universal.tar.gz`.
- Linux uses `kt-linux-x86_64.tar.gz` or `kt-linux-aarch64.tar.gz`.
- The release manifest is available at
  `https://dl.keeptrusts.com/releases/latest/manifest.json`.