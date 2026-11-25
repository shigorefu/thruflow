import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).parents[1] / "verify_apple_sdk.sh"


class VerifyAppleSDKTests(unittest.TestCase):
    def run_verification(self, *, xcode="27.2", macosx="27.2", iphoneos="27.2", watchos="27.2", status=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "xcodebuild").write_text("#!/bin/bash\nprintf 'Xcode %s\\nBuild version 27B52\\n' \"$XCODE_TEST_VERSION\"\n")
            (root / "xcrun").write_text("""#!/bin/bash
[[ "$1" == --sdk && "$3" == --show-sdk-version ]] || exit 90
[[ "$SDK_TEST_STATUS" == 0 ]] || exit "$SDK_TEST_STATUS"
case "$2" in
  macosx) printf '%s\\n' "$SDK_TEST_MACOSX" ;;
  iphoneos) printf '%s\\n' "$SDK_TEST_IPHONEOS" ;;
  watchos) printf '%s\\n' "$SDK_TEST_WATCHOS" ;;
  *) exit 91 ;;
esac
""")
            for name in ("xcodebuild", "xcrun"):
                (root / name).chmod(0o755)
            environment = dict(os.environ, PATH=str(root), XCODE_TEST_VERSION=xcode,
                               SDK_TEST_MACOSX=macosx, SDK_TEST_IPHONEOS=iphoneos,
                               SDK_TEST_WATCHOS=watchos, SDK_TEST_STATUS=str(status))
            return subprocess.run(["/bin/bash", str(SCRIPT)], env=environment,
                                  capture_output=True, text=True, check=False)

    def test_xcode_and_all_device_sdks_27_are_accepted(self):
        self.assertEqual(self.run_verification().returncode, 0)

    def test_old_or_malformed_xcode_is_rejected(self):
        for value in ("26.6", "270", "27beta", ""):
            with self.subTest(value=value):
                self.assertNotEqual(self.run_verification(xcode=value).returncode, 0)

    def test_every_device_sdk_must_be_27(self):
        for sdk in ("macosx", "iphoneos", "watchos"):
            for value in ("26.5", "270", "27beta", ""):
                with self.subTest(sdk=sdk, value=value):
                    self.assertNotEqual(self.run_verification(**{sdk: value}).returncode, 0)

    def test_sdk_probe_failure_is_propagated(self):
        self.assertEqual(self.run_verification(status=23).returncode, 23)
