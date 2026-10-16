#!/usr/bin/env python3
"""Validate release refs and version metadata before any signing secrets are used."""
import os
from pathlib import Path
import re
import subprocess


def project_version(text):
    versions = re.findall(r'\bMARKETING_VERSION\s*=\s*("[^"]*"|[^;\s]+)\s*;', text)
    builds = re.findall(r'\bCURRENT_PROJECT_VERSION\s*=\s*("[^"]*"|[^;\s]+)\s*;', text)
    if not versions or len(versions) != len(builds):
        raise ValueError('Missing or incomplete target version metadata')
    versions = {value.strip().strip('"') for value in versions}
    builds = {value.strip().strip('"') for value in builds}
    if len(versions) != 1 or len(builds) != 1:
        raise ValueError('All target configurations must use the same version and build')
    version, build = next(iter(versions)), next(iter(builds))
    if not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', version):
        raise ValueError('Marketing version must have three numeric components')
    if not re.fullmatch(r'[1-9]\d*', build):
        raise ValueError('Build number must be a positive integer')
    return version, build


def validate_ref(event, ref, version, build, platform):
    if platform not in ('both', 'ios', 'macos'):
        raise ValueError('Unsupported platform')
    expected = f'refs/tags/testflight/v{version}-{build}'
    if event == 'push' and ref == expected:
        return
    if event == 'workflow_dispatch' and ref in ('refs/heads/main', expected):
        return
    raise ValueError('Use main for a manual run or a matching testflight/vVERSION-BUILD tag')


def main():
    version, build = project_version(Path('ThruFlow.xcodeproj/project.pbxproj').read_text())
    platform = os.environ.get('RELEASE_PLATFORM') or 'both'
    validate_ref(os.environ['GITHUB_EVENT_NAME'], os.environ['GITHUB_REF'], version, build, platform)
    # Tags must point to reviewed main history, not arbitrary feature commits.
    subprocess.run(['git', 'merge-base', '--is-ancestor', 'HEAD', 'origin/main'], check=True)
    subprocess.run(['git', 'diff', '--exit-code', 'HEAD'], check=True)
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    matrix = '["ios","macos"]' if platform == 'both' else f'["{platform}"]'
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'version={version}\nbuild={build}\nsha={sha}\nplatforms={matrix}\n')
    print(f'Validated {version} ({build}), {sha}, platforms: {platform}')


if __name__ == '__main__':
    main()
