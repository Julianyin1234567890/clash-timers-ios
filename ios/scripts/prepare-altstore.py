"""Embed the App Group request that AltStore reads before it provisions the app and widget."""
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path


def prepare(app):
    widget = app / 'PlugIns/ClashTimersWidget.appex'
    bundles = [widget, app]  # Sign embedded code first, then seal it into its parent.
    groups = [plistlib.loads((bundle / 'Info.plist').read_bytes())['AppGroupIdentifier'] for bundle in bundles]
    if groups[0] != groups[1] or not groups[0].startswith('group.') or '$(' in groups[0]:
        sys.exit('The built app and widget must declare one matching, expanded App Group.')
    requested = {'com.apple.security.application-groups': [groups[0]]}
    with tempfile.TemporaryDirectory() as temp:
        entitlements = Path(temp) / 'groups.plist'
        entitlements.write_bytes(plistlib.dumps(requested))
        for bundle in bundles:
            subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none', '--generate-entitlement-der',
                            '--entitlements', entitlements, bundle], check=True)
            embedded = subprocess.check_output(['codesign', '--display', '--entitlements', '-', '--xml', bundle])
            if plistlib.loads(embedded) != requested:
                sys.exit(f'Incorrect signing entitlements in {bundle.name}')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', app], check=True)


if __name__ == '__main__':
    prepare(Path(sys.argv[1]))
