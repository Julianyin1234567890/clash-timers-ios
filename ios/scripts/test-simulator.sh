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
result="$build_dir/Tests-$(date +%s).xcresult"
# Report and bound simulator startup separately from test execution.
python3 - "$device_id" <<'PY'
import subprocess, sys
subprocess.run(['xcrun', 'simctl', 'bootstatus', sys.argv[1], '-b'], check=True, timeout=300)
PY
test_args=()
if [[ -n "${UI_TEST_FILTER:-}" ]]; then
    IFS=',' read -r -a selected_tests <<< "$UI_TEST_FILTER"
    for selected_test in "${selected_tests[@]}"; do
        test_args+=("-only-testing:$selected_test")
    done
fi
set +e
xcodebuild test -project ClashTimers.xcodeproj -scheme ClashTimers -configuration Debug \
    -destination "id=$device_id" -derivedDataPath "$build_dir/DerivedData" \
    -resultBundlePath "$result" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 "${test_args[@]}"
test_status=$?
set -e

xcrun xcresulttool export attachments --path "$result" --output-path "$build_dir/screenshots"
exit "$test_status"
