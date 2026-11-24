import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / "prepare_apple_toolchain.sh"


class PrepareAppleToolchainTests(unittest.TestCase):
    def run_preparation(self, *, present=False, install_status=0, installed_works=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "xcrun").write_text("""#!/bin/bash
set -eu
printf 'probe:%s\\n' "$*" >> "$TOOLCHAIN_TEST_LOG"
[[ "$*" == 'metal --version' ]] || exit 90
if [[ "$TOOLCHAIN_PRESENT" == 1 || -f "$TOOLCHAIN_TEST_STATE" && "$TOOLCHAIN_INSTALLED_WORKS" == 1 ]]; then
  exit 0
fi
exit 1
""")
            (root / "xcodebuild").write_text("""#!/bin/bash
set -eu
printf 'install:%s\\n' "$*" >> "$TOOLCHAIN_TEST_LOG"
[[ "$*" == '-downloadComponent MetalToolchain' ]] || exit 91
[[ "$TOOLCHAIN_INSTALL_STATUS" == 0 ]] || exit "$TOOLCHAIN_INSTALL_STATUS"
: > "$TOOLCHAIN_TEST_STATE"
""")
            for name in ("xcrun", "xcodebuild"):
                (root / name).chmod(0o755)
            log = root / "calls"
            environment = dict(os.environ, PATH=str(root), TOOLCHAIN_TEST_LOG=str(log),
                               TOOLCHAIN_TEST_STATE=str(root / "installed"),
                               TOOLCHAIN_PRESENT=str(int(present)),
                               TOOLCHAIN_INSTALL_STATUS=str(install_status),
                               TOOLCHAIN_INSTALLED_WORKS=str(int(installed_works)))
            result = subprocess.run(["/bin/bash", str(SCRIPT)], env=environment,
                                    capture_output=True, text=True, check=False)
            return result.returncode, log.read_text().splitlines()

    def test_present_toolchain_does_not_download(self):
        status, calls = self.run_preparation(present=True)
        self.assertEqual(status, 0)
        self.assertEqual(calls, ["probe:metal --version"])

    def test_missing_toolchain_downloads_and_verifies(self):
        status, calls = self.run_preparation()
        self.assertEqual(status, 0)
        self.assertEqual(calls, ["probe:metal --version", "install:-downloadComponent MetalToolchain",
                                 "probe:metal --version"])

    def test_download_failure_is_propagated_without_final_probe(self):
        status, calls = self.run_preparation(install_status=23)
        self.assertEqual(status, 23)
        self.assertEqual(calls, ["probe:metal --version", "install:-downloadComponent MetalToolchain"])

    def test_download_success_with_unusable_toolchain_fails(self):
        status, calls = self.run_preparation(installed_works=False)
        self.assertNotEqual(status, 0)
        self.assertEqual(calls[-1], "probe:metal --version")
