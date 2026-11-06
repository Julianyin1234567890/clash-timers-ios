"""Build the full device app on an ephemeral macOS runner with the owner's provisioning profiles."""
import base64
import datetime
import hashlib
import os
import plistlib
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(args, *, capture=False, quiet=False, cwd=None):
    # Never include the command line in an error: security import takes a password argument.
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE if capture else (subprocess.DEVNULL if quiet else None))
    if result.returncode:
        sys.exit(f"{Path(args[0]).name} failed (exit {result.returncode}).")
    return result.stdout


def profile(folder, name):
    source = folder / (name + '.mobileprovision')
    source.write_bytes(base64.b64decode(''.join(os.environ[name].split()), validate=True))
    data = plistlib.loads(run(['security', 'cms', '-D', '-i', source], capture=True))
    if data['ExpirationDate'] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        sys.exit(f'{name} has expired.')
    if not data.get('ProvisionedDevices'):
        sys.exit(f'{name} must be a development or ad hoc profile for a registered device.')
    return source, data


def main():
    if sys.platform != 'darwin' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        sys.exit('Use the private-repository workflow: this script configures a disposable macOS runner.')
    os.umask(0o077)
    for name in ['IOS_CERTIFICATE_P12', 'IOS_APP_PROFILE', 'IOS_WIDGET_PROFILE', 'IOS_CERTIFICATE_PASSWORD']:
        if name not in os.environ or (name != 'IOS_CERTIFICATE_PASSWORD' and not os.environ[name]):
            sys.exit(f'Missing repository secret: {name}')
    ios_dir = Path(__file__).resolve().parents[1]
    output = Path(sys.argv[1]).resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        work = Path(temp)
        app_file, app = profile(work, 'IOS_APP_PROFILE')
        widget_file, widget = profile(work, 'IOS_WIDGET_PROFILE')
        app_ent, widget_ent = app['Entitlements'], widget['Entitlements']
        bundle_id = app_ent['application-identifier'].split('.', 1)[1]
        if '*' in bundle_id or widget_ent['application-identifier'] != app_ent['application-identifier'] + '.widget':
            sys.exit('Use explicit App IDs: the widget ID must be the app ID followed by .widget.')
        if app['TeamIdentifier'] != widget['TeamIdentifier'] or not set(app['ProvisionedDevices']) & set(widget['ProvisionedDevices']):
            sys.exit('The profiles must share a team and at least one registered device.')
        groups = set(app_ent.get('com.apple.security.application-groups', [])) & set(widget_ent.get('com.apple.security.application-groups', []))
        if len(groups) != 1 or not next(iter(groups)).startswith('group.') or '*' in next(iter(groups)):
            sys.exit('Enable one explicit, matching App Group in both profiles.')
        p12 = work / 'signing.p12'
        p12.write_bytes(base64.b64decode(''.join(os.environ['IOS_CERTIFICATE_P12'].split()), validate=True))
        keychain = str(work / 'build.keychain-db')
        password = secrets.token_urlsafe(32)
        run(['security', 'create-keychain', '-p', password, keychain], quiet=True)
        run(['security', 'unlock-keychain', '-p', password, keychain], quiet=True)
        run(['security', 'set-keychain-settings', '-lut', '3600', keychain], quiet=True)
        run(['security', 'import', p12, '-k', keychain, '-P', os.environ['IOS_CERTIFICATE_PASSWORD'], '-T', '/usr/bin/codesign'], quiet=True)
        run(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, keychain], quiet=True)
        existing = [line.strip().strip('"') for line in run(['security', 'list-keychains', '-d', 'user'], capture=True).decode().splitlines()]
        run(['security', 'list-keychains', '-d', 'user', '-s', keychain, *existing])
        valid = set(re.findall(r'\b[0-9A-F]{40}\b', run(['security', 'find-identity', '-v', '-p', 'codesigning', keychain], capture=True).decode()))
        for item in (app, widget):
            valid &= {hashlib.sha1(cert).hexdigest().upper() for cert in item['DeveloperCertificates']}
        if not valid:
            sys.exit('The imported signing identity is not valid for both profiles.')
        for source, data in [(app_file, app), (widget_file, widget)]:
            for relative in ['Library/Developer/Xcode/UserData/Provisioning Profiles', 'Library/MobileDevice/Provisioning Profiles']:
                target = Path.home() / relative
                target.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target / (data['UUID'] + '.mobileprovision'))
        derived = work / 'DerivedData'
        run(['xcodebuild', 'build', '-project', 'ClashTimers.xcodeproj', '-scheme', 'ClashTimers',
             '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-derivedDataPath', derived,
             'CODE_SIGN_STYLE=Manual', 'CODE_SIGN_IDENTITY=' + sorted(valid)[0], 'DEVELOPMENT_TEAM=' + app['TeamIdentifier'][0],
             'APP_BUNDLE_IDENTIFIER=' + bundle_id, 'APP_GROUP_IDENTIFIER=' + next(iter(groups)),
             'APP_PROFILE_NAME=' + app['UUID'], 'WIDGET_PROFILE_NAME=' + widget['UUID']], cwd=ios_dir)
        built = derived / 'Build/Products/Release-iphoneos/ClashTimers.app'
        assert (built / 'embedded.mobileprovision').is_file() and (built / 'PlugIns/ClashTimersWidget.appex/embedded.mobileprovision').is_file()
        run(['codesign', '--verify', '--deep', '--strict', built])
        stage = work / 'Payload'
        stage.mkdir()
        run(['ditto', built, stage / built.name])
        run(['/usr/bin/zip', '-yqr', work / 'signed.ipa', 'Payload'], cwd=work)
        shutil.move(work / 'signed.ipa', output / 'ClashTimers-provisioned.ipa')
        run(['security', 'list-keychains', '-d', 'user', '-s', *existing])
        run(['security', 'delete-keychain', keychain])


if __name__ == '__main__':
    main()
