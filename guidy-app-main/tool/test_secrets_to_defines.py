import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "secrets_to_defines.py")


class SecretsToDefinesTest(unittest.TestCase):
    def run_tool(self, text, env_extra=None):
        d = tempfile.mkdtemp()
        self.addCleanup(__import__("shutil").rmtree, d, True)
        src = os.path.join(d, "secrets.properties")
        with open(src, "w", encoding="utf-8") as f:
            f.write(text)
        env = {k: v for k, v in os.environ.items()
               if k not in ("API_BASE_URL", "ANDROID_CERT_SHA1")}
        env.update(env_extra or {})
        r = subprocess.run([sys.executable, SCRIPT, src, os.path.join(d, "d.json"),
                            os.path.join(d, "S.xcconfig")],
                           capture_output=True, text=True, env=env)
        out = {"rc": r.returncode, "stdout": r.stdout, "stderr": r.stderr}
        if r.returncode == 0:
            out["defines"] = json.load(open(os.path.join(d, "d.json")))
            out["xc"] = open(os.path.join(d, "S.xcconfig")).read()
        return out

    def test_known_keys_become_defines_and_comments_are_skipped(self):
        r = self.run_tool("# API_BASE_URL=http://commented/api\nMAPS_API_KEY_IOS=AIzaIOS\n\nAPI_BASE_URL = http://h:8000/api\n"
                          "FACEBOOK_CLIENT_TOKEN=tok\nADMOB_BANNER_AD_UNIT_ID_IOS=\n")
        self.assertEqual(r["defines"], {"MAPS_API_KEY_IOS": "AIzaIOS",
                                        "API_BASE_URL": "http://h:8000/api"})

    def test_ios_maps_key_goes_to_xcconfig(self):
        r = self.run_tool("MAPS_API_KEY_IOS=AIzaIOS\n")
        self.assertIn("MAPS_API_KEY_IOS = AIzaIOS\n", r["xc"])

    def test_missing_ios_key_leaves_setting_undefined(self):
        r = self.run_tool("MAPS_API_KEY_ANDROID=a\n")
        self.assertNotIn("MAPS_API_KEY_IOS", r["xc"])
        self.assertIn("MISSING", r["stdout"])

    def test_env_overrides_backend_url(self):
        r = self.run_tool("API_BASE_URL=http://old/api\n", {"API_BASE_URL": "http://mac:8000/api"})
        self.assertEqual(r["defines"]["API_BASE_URL"], "http://mac:8000/api")

    def test_env_overrides_android_cert_sha1(self):
        r = self.run_tool("ANDROID_CERT_SHA1=WINDOWSSHA\n", {"ANDROID_CERT_SHA1": "MACSHA"})
        self.assertEqual(r["defines"]["ANDROID_CERT_SHA1"], "MACSHA")

    def test_secret_values_are_not_printed(self):
        r = self.run_tool("MAPS_API_KEY_IOS=AIzaSECRET\nMAPS_API_KEY_ANDROID=AIzaOTHER\n")
        self.assertNotIn("AIza", r["stdout"] + r["stderr"])

    def test_quoted_values_and_bom(self):
        r = self.run_tool("﻿MAPS_API_KEY_IOS=\"AIzaQ\"\n")
        self.assertEqual(r["defines"]["MAPS_API_KEY_IOS"], "AIzaQ")

    def test_rejects_key_that_would_break_xcconfig(self):
        r = self.run_tool("MAPS_API_KEY_IOS=abc;def\n")
        self.assertNotEqual(r["rc"], 0)


if __name__ == "__main__":
    unittest.main()
