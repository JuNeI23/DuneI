"""Fragment machine — config/hypr/modules/machine.lua exécuté par Lua dans un dossier imitant ~/.config/hypr."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class MachineTest(unittest.TestCase):
    """Lecture du nom d'hôte et chargement du fragment machine."""

    def lua(self, code: str, hostname: str | None = None, machines: dict | None = None) -> subprocess.CompletedProcess:
        """Exécute code après require("modules.machine").

        Entrées : code — Lua à exécuter, qui voit M (le module) et HOST (le fichier du nom d'hôte) ;
                  hostname — contenu du fichier HOST, absent si None ; machines — nom → contenu des fragments.
        Sortie : le processus terminé, sans vérification du code de retour.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            (hypr / "machines").mkdir()
            for name, body in (machines or {}).items():
                (hypr / "machines" / f"{name}.lua").write_text(body, encoding="utf-8")
            host = hypr / "hostname"
            if hostname is not None:
                host.write_text(hostname, encoding="utf-8")
            script = (f'package.path = "{hypr}/?.lua;{hypr}/?/init.lua"\n'
                      f'HOST = "{host}"\nM = require("modules.machine")\n' + code)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True)

    def out(self, code: str, **kw) -> str:
        """Exécute code, exige un succès et rend la sortie standard sans espaces de fin."""
        res = self.lua(code, **kw)
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout.strip()

    def test_default_file(self):
        self.assertEqual(self.out("print(M.file)"), "/etc/hostname")

    def test_hostname(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="caladan\n"), "caladan")

    def test_hostname_trims(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="  caladan \n"), "caladan")

    def test_hostname_absent(self):
        self.assertEqual(self.out("print(M.hostname(HOST))"), "nil")

    def test_hostname_empty(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname=""), "nil")

    def test_hostname_rejects_dot(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="caladan.local\n"), "nil")

    def test_hostname_rejects_path(self):
        self.assertEqual(self.out("print(M.hostname(HOST))", hostname="../x\n"), "nil")

    def test_load_without_fragment(self):
        self.assertEqual(self.out("print(M.load(HOST))", hostname="arrakis\n", machines={"caladan": "error('lu')"}), "nil")

    def test_load_fragment(self):
        self.assertEqual(self.out("print(M.load(HOST), LOADED)", hostname="caladan\n",
                                  machines={"caladan": "LOADED = true"}), "caladan\ttrue")

    def test_load_hyphenated_name(self):
        self.assertEqual(self.out("print(M.load(HOST), LOADED)", hostname="mon-pc\n",
                                  machines={"mon-pc": "LOADED = true"}), "mon-pc\ttrue")

    def test_load_propagates_error(self):
        res = self.lua("M.load(HOST)", hostname="caladan\n", machines={"caladan": "error('panne du fragment')"})
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("panne du fragment", res.stderr)


if __name__ == "__main__":
    unittest.main()
