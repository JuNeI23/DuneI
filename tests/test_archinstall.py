"""Phase 1 — setup/archinstall.json suit le format d'archinstall 4.5 et ne contient ni disque ni secret."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class ArchinstallTest(unittest.TestCase):
    """Valeurs de la section 3.2 de la spec, clés relevées dans archinstall 4.5."""

    def setUp(self):
        self.c = json.loads((ROOT / "setup/archinstall.json").read_text())

    def test_contenu(self):
        c = self.c
        self.assertEqual(c["bootloader_config"]["bootloader"], "Systemd-boot")
        self.assertTrue(c["bootloader_config"]["uki"])
        self.assertEqual(set(c["kernels"]), {"linux", "linux-lts"})
        self.assertEqual(c["timezone"], "Europe/Paris")
        self.assertTrue({"git", "make", "python"} <= set(c["packages"]))
        self.assertTrue(c["ntp"])
        self.assertEqual(c["swap"], {"enabled": True, "algorithm": "zstd"})
        self.assertEqual(c["locale_config"], {"kb_layout": "uk", "sys_lang": "en_US", "sys_enc": "UTF-8"})
        self.assertEqual(set(c["mirror_config"]["mirror_regions"]), {"France", "Germany", "Switzerland"})
        self.assertEqual(c["network_config"], {"type": "nm"})
        self.assertEqual(c["audio_config"], {"audio": "pipewire"})
        self.assertNotIn("profile_config", c)

    def test_ni_disque_ni_secret(self):
        for cle in ("disk_config", "disk_encryption", "hostname", "users", "root_enc_password", "!users"):
            self.assertNotIn(cle, self.c)


if __name__ == "__main__":
    unittest.main()
