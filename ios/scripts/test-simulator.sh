#!/usr/bin/env bash
set -euo pipefail
ios_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ios_dir"
build_dir="${1:-$ios_dir/build/simulator}"
mkdir -p "$build_dir"
# Use a device from an installed iOS runtime rather than hard-coding an iPhone model or OS minor version.
device_id="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in devices if ".iOS-" in r), key=lambda r: tuple(map(int, re.findall(r"\d+", r.split(".iOS-")[-1]))), reverse=True)
for runtime in runtimes:
    phone = next((d for d in devices[runtime] if d["name"].startswith("iPhone") and d.get("isAvailable", True)), None)
    if phone:
        print(phone["udid"]); break
else:
    sys.exit("No iPhone simulator is installed for the selected Xcode. Install an iOS simulator runtime.")
')"
xcodebuild test -project ClashTimers.xcodeproj -scheme ClashTimers -configuration Debug \
    -destination "id=$device_id" -derivedDataPath "$build_dir/DerivedData" \
    -resultBundlePath "$build_dir/Tests-$(date +%s).xcresult" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
