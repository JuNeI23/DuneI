"""Lanceur du verrou — dunei-verrou exécuté avec de faux hyprlock, hyprctl, qs, busctl, systemd-run, systemctl,
notify-send et logger dans le PATH ; aucun verrou réel, aucune notification réelle (L2-22)."""

import json
import os
import signal
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "hypr" / "scripts" / "dunei-verrou"
LOG = 'echo "{name} $*" >> "$FAKE_LOG"\n'
# Chaque faux outil consigne son appel dans $FAKE_LOG. L'état du verrou vit dans $FAKE_DIR/locked (« true » ou
# « false »), lu par le faux hyprctl et basculé par le faux hyprlock.
FAKES = {
    # hyprctl -j locked : rend l'état du fichier, faux par défaut ; muet tant que le compteur $FAKE_DIR/muet est positif.
    "hyprctl": 'if [ -e "$FAKE_DIR/muet" ]; then\n'
               '    n=$(cat "$FAKE_DIR/muet"); [ "$n" -gt 0 ] && { echo $((n - 1)) > "$FAKE_DIR/muet"; exec sleep 1; }\n'
               '    rm -f "$FAKE_DIR/muet"\nfi\n'
               'printf \'{"locked": %s}\\n\' "$(cat "$FAKE_DIR/locked" 2>/dev/null || echo false)"\n',
    # qs ipc -c dunei call verrou <méthode> [ordre] : $FAKE_QS=muet ne répond jamais, =fige ne répond pas à etat ; etat rend le bloc posé sous
    # l'ordre courant (FAKE_POSE=non : jamais posé) et, si FAKE_VEILLE=1, annonce la veille en touchant verrou-sec.
    "qs": LOG.format(name="qs") + '[ "${FAKE_QS:-}" = muet ] && exec sleep 1\n'
          '[ "${FAKE_QS:-}" = fige ] && [ "$6" = etat ] && exec sleep 1\n'
          'if [ "$6" = etat ]; then\n'
          '    [ "${FAKE_VEILLE:-}" = 1 ] && : > "$XDG_RUNTIME_DIR/dunei/verrou-sec"\n'
          '    p=true; [ "${FAKE_POSE:-}" = non ] && p=false\n'
          '    printf \'{"pose": %s, "ordre": %s}\\n\' "$p" "$(cat "$XDG_RUNTIME_DIR/dunei/verrou-ordre")"\n'
          'fi\n',
    "busctl": LOG.format(name="busctl") + 'echo "${FAKE_BUSCTL:-b false}"\n',
    # systemd-run : échoue si l'unité existe ($FAKE_DIR/unite) ou si FAKE_SYSTEMD_RUN=panne, sinon exécute sa commande.
    "systemd-run": LOG.format(name="systemd-run") + '[ -e "$FAKE_DIR/unite" ] && exit 1\n'
                   '[ "${FAKE_SYSTEMD_RUN:-}" = panne ] && exit 1\n'
                   'while case "$1" in --*) true;; *) false;; esac; do shift; done\nexec "$@"\n',
    "systemctl": LOG.format(name="systemctl") + '[ "$2" != is-active ] || [ -e "$FAKE_DIR/unite" ]\n',
    "notify-send": LOG.format(name="notify-send"),
    "pgrep": LOG.format(name="pgrep") + 'exit "${FAKE_PGREP:-1}"\n',
    "logger": LOG.format(name="logger"),
    # hyprlock : le n-ième lancement suit le n-ième mot de $FAKE_HYPRLOCK (le dernier ensuite). « tient » : verrou tenu
    # $FAKE_TENUE pas de 20 ms puis rendu ; « garde » : sort au bout de 15 pas en laissant le verrou ; « vite » : sort
    # aussitôt en laissant le verrou ; « fige » : comme « garde », mais rend le compositeur muet 5 appels ; « dort » :
    # vit 10 s sans prendre le verrou ; « jamais » : sort sans verrou. Il écrit son masque SigCgt ($FAKE_SIGCGT) sous la fausse racine de /proc et consigne la
    # présence du marqueur, l'heure de son lancement et chaque SIGUSR2 reçu.
    "hyprlock": 'm=non; [ -e "$XDG_RUNTIME_DIR/dunei/verrou-apparition" ] && m=oui\n'
                'echo "hyprlock $* marqueur=$m" >> "$FAKE_LOG"\n'
                'date +%s%3N >> "$FAKE_DIR/lancements"\n'
                'n=$(wc -l < "$FAKE_DIR/lancements"); set -- ${FAKE_HYPRLOCK:-tient}\n'
                '[ "$n" -gt $# ] && n=$#; eval "mode=\\${$n}"\n'
                'mkdir -p "$DUNEI_VERROU_PROC/$$"\n'
                'printf \'SigBlk:\\t0000000000000000\\nSigCgt:\\t%s\\n\' "${FAKE_SIGCGT:-0000000000004a03}" '
                '> "$DUNEI_VERROU_PROC/$$/status"\n'
                'trap \'echo "hyprlock USR2" >> "$FAKE_LOG"\' USR2\n'
                'case "$mode" in\n'
                '    jamais) sleep 0.05; exit 1 ;;\n'
                '    dort) i=500 ;;\n'
                '    vite) echo true > "$FAKE_DIR/locked"; exit 1 ;;\n'
                '    garde|fige) echo true > "$FAKE_DIR/locked"; i=15 ;;\n'
                '    *) echo true > "$FAKE_DIR/locked"; i=${FAKE_TENUE:-40} ;;\n'
                'esac\n'
                'while [ "$i" -gt 0 ]; do sleep 0.02; i=$((i - 1)); done\n'
                '[ "$mode" = fige ] && { echo 5 > "$FAKE_DIR/muet"; exit 1; }\n'
                '[ "$mode" = garde ] && exit 1\n[ "$mode" = dort ] && exit 1\necho false > "$FAKE_DIR/locked"\n',
}
# Délais raccourcis pour les essais, sous la forme de generated/motion.json.
DELAIS = {"verrouAttente": 1000, "verrouApparition": 150, "verrouCession": 50, "verrouRetrait": 20, "verrouSecours": 300}


def etape(ligne: str) -> str:
    """Nom court d'un appel consigné : méthode IPC, « kill -USR2 » pour un signal reçu, sinon le nom de l'outil."""
    mots = ligne.split()
    if mots[0] == "qs":
        return mots[6]
    if mots[:2] == ["hyprlock", "USR2"]:
        return "kill -USR2"
    return mots[0]


class DuneiVerrouTest(unittest.TestCase):
    """Chute, verrou sec, veille, replis, relances, second appel et garde du SIGUSR2."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.t = t = Path(self.tmp.name)
        for d in ("bin", "run", "config/dunei", "state/dunei/verrou", "proc"):
            (t / d).mkdir(parents=True)
        for name, body in FAKES.items():
            (t / "bin" / name).write_text("#!/bin/sh\n" + body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        (t / "config/dunei/motion.json").write_text(json.dumps({"delays": DELAIS}), encoding="utf-8")
        self.conf = t / "state/dunei/verrou/hyprlock.conf"
        self.conf.write_text("# produite\n", encoding="utf-8")
        self.repli = t / "config/hypr/hyprlock.conf"
        self.log, self.run_dir = t / "log", t / "run" / "dunei"
        env = {k: v for k, v in os.environ.items() if k != "DUNEI_VERROU_PORTEE"}
        self.env = {**env, "PATH": f"{t / 'bin'}:{env['PATH']}", "FAKE_LOG": str(self.log), "FAKE_DIR": str(t),
                    "XDG_RUNTIME_DIR": str(t / "run"), "XDG_CONFIG_HOME": str(t / "config"),
                    "XDG_STATE_HOME": str(t / "state"), "DUNEI_VERROU_PROC": str(t / "proc")}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        """Lance le lanceur avec les faux outils et les variables FAKE_* données ; borné à 20 s."""
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env={**self.env, **env}, timeout=20)

    def calls(self) -> list[str]:
        """Appels consignés, dans l'ordre."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def etapes(self) -> list[str]:
        """Noms courts des appels consignés, dans l'ordre."""
        return [etape(c) for c in self.calls()]

    def lancements(self) -> list[str]:
        """Lignes consignées par chaque lancement de hyprlock."""
        return [c for c in self.calls() if c.startswith("hyprlock -")]

    def assertSousSuite(self, attendu: list[str], reel: list[str]):
        """Vérifie que les étapes attendues figurent dans cet ordre parmi les étapes réelles."""
        it = iter(reel)
        self.assertTrue(all(e in it for e in attendu), f"{attendu} hors d'ordre dans {reel}")

    def test_chute_complete(self):
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["tomber", "etat", "hyprlock", "apparaitre", "kill -USR2", "ceder", "remonter"],
                             self.etapes())
        self.assertEqual(self.lancements(), [f"hyprlock --no-fade-in -c {self.conf} marqueur=oui"])
        self.assertFalse((self.run_dir / "verrou-apparition").exists())
        self.assertNotIn("poserSec", self.etapes())

    def test_coque_muette_sec(self):
        debut = time.time() * 1000
        res = self.run_script(FAKE_QS="muet")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertIn("poserSec", etapes)
        for absent in ("etat", "apparaitre", "ceder"):
            self.assertNotIn(absent, etapes)
        lance = int((self.t / "lancements").read_text().split()[0])
        self.assertLess(lance - debut, 500)
        self.assertIn("hyprlock", etapes)
        # Coque muette 2 s à la remontée : relancée par le lanceur.
        self.assertIn("systemctl --user restart dunei-coque.service", self.calls())

    def test_sec(self):
        res = self.run_script("--sec")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertNotIn("tomber", etapes)
        self.assertNotIn("busctl", etapes)
        self.assertSousSuite(["poserSec", "hyprlock", "remonter"], etapes)
        self.assertEqual(self.lancements(), [f"hyprlock --no-fade-in -c {self.conf} marqueur=non"])

    def test_veille_annoncee(self):
        res = self.run_script(FAKE_BUSCTL="b true")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertNotIn("tomber", etapes)
        self.assertSousSuite(["busctl", "poserSec", "hyprlock", "remonter"], etapes)

    def test_veille_en_cours_de_chute(self):
        debut = time.time() * 1000
        res = self.run_script(FAKE_POSE="non", FAKE_VEILLE="1")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertSousSuite(["tomber", "etat", "abreger", "hyprlock", "remonter"], etapes)
        self.assertEqual(etapes.count("etat"), 1)
        self.assertNotIn("apparaitre", etapes)
        self.assertEqual(self.lancements(), [f"hyprlock --no-fade-in -c {self.conf} marqueur=non"])
        lance = int((self.t / "lancements").read_text().split()[0])
        self.assertLess(lance - debut, DELAIS["verrouAttente"])
        self.assertFalse((self.run_dir / "verrou-sec").exists())

    def test_jamais_tenu_repli(self):
        res = self.run_script(FAKE_HYPRLOCK="jamais jamais tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        confs = [c.split(" -c ")[1].split()[0] for c in self.lancements()]
        self.assertEqual(confs, [str(self.conf), str(self.conf), str(self.repli)])
        self.assertNotIn("notify-send", self.etapes())

    def test_trois_echecs_notifie(self):
        res = self.run_script(FAKE_HYPRLOCK="jamais")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(len(self.lancements()), 3)
        notes = [c for c in self.calls() if c.startswith("notify-send")]
        self.assertEqual(len(notes), 1)
        self.assertIn("-u critical", notes[0])
        self.assertIn("Verrouillage impossible", notes[0])
        self.assertSousSuite(["notify-send", "remonter"], self.etapes())

    def test_trois_echecs_a_l_ouverture(self):
        # À l'ouverture de session, dunei-verrou-initial ferme la session : le bloc reste posé, rien ne s'annonce.
        res = self.run_script("--sec", FAKE_HYPRLOCK="jamais")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(len(self.lancements()), 3)
        self.assertNotIn("notify-send", self.etapes())
        self.assertNotIn("remonter", self.etapes())

    def test_relance_si_tenu(self):
        res = self.run_script(FAKE_HYPRLOCK="garde tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 2)
        self.assertEqual(self.etapes().count("apparaitre"), 1)
        self.assertNotIn("notify-send", self.etapes())

    def test_second_appel_attend(self):
        (self.t / "unite").touch()
        (self.t / "locked").write_text("true\n")

        def deverrouiller():
            """Rend la session 0,5 s après le départ, puis retire l'unité."""
            time.sleep(0.5)
            (self.t / "locked").write_text("false\n")
            time.sleep(0.1)
            (self.t / "unite").unlink()

        fil = threading.Thread(target=deverrouiller)
        debut = time.time()
        fil.start()
        res = self.run_script()
        fil.join()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertGreaterEqual(time.time() - debut, 0.5)
        self.assertEqual(self.lancements(), [])

    def test_second_appel_pendant_la_fin(self):
        # L'unité finit sans que le verrou ait été vu tenu : le placement est retenté une fois et le verrou posé.
        (self.t / "unite").touch()

        def retirer():
            """Retire l'unité 0,3 s après le départ, sans que le verrou ait été tenu."""
            time.sleep(0.3)
            (self.t / "unite").unlink()

        fil = threading.Thread(target=retirer)
        fil.start()
        res = self.run_script(FAKE_BUSCTL="b true")
        fil.join()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 1)
        self.assertSousSuite(["poserSec", "hyprlock", "remonter"], self.etapes())

    def test_echeance_sans_verrou(self):
        res = self.run_script(FAKE_HYPRLOCK="dort dort tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        confs = [c.split(" -c ")[1].split()[0] for c in self.lancements()]
        self.assertEqual(confs, [str(self.conf), str(self.conf), str(self.repli)])
        self.assertEqual(len([c for c in self.calls() if "non pris" in c]), 2)

    def test_sorties_rapides_repli(self):
        res = self.run_script(FAKE_HYPRLOCK="vite vite vite tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        confs = [c.split(" -c ")[1].split()[0] for c in self.lancements()]
        self.assertEqual(confs, [str(self.conf), str(self.conf), str(self.repli), str(self.repli)])
        heures = [int(h) for h in (self.t / "lancements").read_text().split()]
        self.assertTrue(all(b - a >= 450 for a, b in zip(heures, heures[1:])), heures)

    def test_compositeur_muet(self):
        # Compositeur muet à la sortie de hyprlock, session encore tenue : jamais prise pour rendue.
        res = self.run_script(FAKE_HYPRLOCK="fige tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 2)
        self.assertEqual(self.etapes().count("remonter"), 1)

    def test_systemd_run_en_panne(self):
        res = self.run_script(FAKE_SYSTEMD_RUN="panne")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 1)
        self.assertTrue(any(c.startswith("logger") and "systemd-run" in c for c in self.calls()))

    def test_coque_figee_delai(self):
        # La coque répond à tomber puis se fige : hyprlock part au plus tard à l'échéance de verrouAttente.
        debut = time.time() * 1000
        res = self.run_script(FAKE_QS="fige")
        self.assertEqual(res.returncode, 0, res.stderr)
        lance = int((self.t / "lancements").read_text().split()[0])
        self.assertLess(lance - debut, DELAIS["verrouAttente"] + 100)

    def test_verrou_orphelin(self):
        # Session tenue sans verrouilleur vivant : hyprlock la reprend en verrou sec.
        (self.t / "locked").write_text("true\n")
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertNotIn("tomber", etapes)
        self.assertSousSuite(["pgrep", "poserSec", "hyprlock", "remonter"], etapes)

    def test_ordre_corrompu(self):
        self.run_dir.mkdir()
        (self.run_dir / "verrou-ordre").write_text("abc\n")
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("qs ipc -c dunei call verrou tomber 1", self.calls())

    def test_sec_garde_dans_le_lanceur_place(self):
        # Le lanceur placé n'efface pas le verrou-sec qu'un second appel a pu poser : la chute est abrégée.
        self.run_dir.mkdir()
        (self.run_dir / "verrou-sec").touch()
        res = self.run_script(DUNEI_VERROU_PORTEE="-")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["tomber", "abreger", "hyprlock"], self.etapes())
        self.assertNotIn("apparaitre", self.etapes())

    def test_hup_retire_le_marqueur(self):
        marqueur = self.run_dir / "verrou-apparition"
        proc = subprocess.Popen([str(SCRIPT)], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env={**self.env, "FAKE_POSE": "non"})
        for _ in range(200):
            if marqueur.exists() and marqueur.read_text().strip():
                break
            time.sleep(0.01)
        os.kill(int(marqueur.read_text()), signal.SIGHUP)
        proc.communicate(timeout=20)
        self.assertEqual(proc.returncode, 1)
        self.assertFalse(marqueur.exists())

    def test_sigusr2_garde(self):
        res = self.run_script(FAKE_SIGCGT="0000000000004203")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertNotIn("kill -USR2", self.etapes())
        self.assertFalse((self.run_dir / "verrou-apparition").exists())
        self.assertEqual([c.rsplit(" ", 1)[1] for c in self.lancements()], ["marqueur=oui", "marqueur=non"])
        self.assertSousSuite(["apparaitre", "hyprlock", "ceder", "remonter"], self.etapes())

    def test_usage(self):
        self.assertEqual(self.run_script("--vite").returncode, 2)
        self.assertEqual(self.run_script("--sec", "--sec").returncode, 2)


if __name__ == "__main__":
    unittest.main()
