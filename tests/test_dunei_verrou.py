"""Lanceur du verrou — dunei-verrou exécuté avec une coque simulée et de faux hyprlock, stdbuf, hyprctl, qs, busctl,
systemd-run, systemctl, notify-send et logger dans le PATH ; aucun verrou réel, aucune notification réelle (L2-22).

Le PATH des essais ne contient que deux dossiers du dossier temporaire : les faux outils, et des liens vers les seuls
utilitaires système nécessaires (OUTILS). Aucun dossier système n'y figure, si bien qu'un processus qui survivrait à la
suppression du dossier ne trouverait plus aucune commande, et jamais les vrais outils de la session. Chaque lancement
ouvre sa propre session ; tout processus de cette session, ou portant le dossier dans son environnement, est tué avant
la suppression du dossier (GNU timeout change de groupe de processus, mais pas de session). Aucun essai ne doit voir
hyprlock recevoir SIGUSR1, qui déverrouillerait toute la session : tearDown le vérifie pour chacun."""

import json
import re
import os
import shutil
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
# « false »), lu par le faux hyprctl, basculé par le faux hyprlock et par la coque simulée.
FAKES = {
    # Coque simulée, lue (.) par les faux qs et hyprctl : son état vit sous $FAKE_DIR/coque (couvre : heure de la pose ;
    # ordre ; pris : heure du verrou pris ; mort : heure de sa disparition ; tombe : disparue après tomber ; revenu :
    # relancée une fois). evoluer() fait passer le temps : FAKE_PRISE ms après la pose (100 par défaut, 2,5 s pour
    # « lente », jamais pour « fige »), la coque tient le verrou (locked = true) ; FAKE_TENUE ms plus tard (500 par défaut), la session est
    # rendue comme par un succès PAM (locked = false). Une coque morte garde le verrou du compositeur et ne rend rien ;
    # « revient » reparaît FAKE_RETOUR ms après (1000 par défaut), sous l'ordre 0, et repose son bloc si la session est
    # tenue, comme demarrer().
    "fake-coque": 'D="$FAKE_DIR/coque"; mkdir -p "$D"\nnow=$(date +%s%3N)\nmode=${FAKE_COQUE:-tient}\n'
                  '[ -e "$D/debut" ] || echo "$now" > "$D/debut"\n'
                  'prise=${FAKE_PRISE:-100}; [ "$mode" = lente ] && prise=2500; [ "$mode" = fige ] && prise=99999999\n'
                  'evoluer() {\n'
                  '    if [ -e "$D/mort" ]; then\n'
                  '        [ "$mode" = revient ] && [ $((now - $(cat "$D/mort"))) -ge "${FAKE_RETOUR:-1000}" ] || return 0\n'
                  '        rm -f "$D/mort" "$D/pris" "$D/couvre"; echo 0 > "$D/ordre"; : > "$D/revenu"\n'
                  '        [ "$(cat "$FAKE_DIR/locked" 2>/dev/null)" = true ] && echo "$now" > "$D/couvre"\n'
                  '    fi\n'
                  '    if [ -e "$D/couvre" ] && [ ! -e "$D/pris" ] && [ $((now - $(cat "$D/couvre"))) -ge "$prise" ]; then\n'
                  '        echo "$now" > "$D/pris"; echo true > "$FAKE_DIR/locked"\n'
                  '    fi\n'
                  '    if [ -e "$D/pris" ] && [ $((now - $(cat "$D/pris"))) -ge "${FAKE_TENUE:-500}" ]; then\n'
                  '        rm -f "$D/pris" "$D/couvre"; echo false > "$FAKE_DIR/locked"\n'
                  '    fi\n'
                  '}\n',
    # hyprctl -j locked : rend l'état du fichier, faux par défaut, après avoir fait évoluer la coque ; muet tant que le
    # compteur $FAKE_DIR/muet est positif.
    "hyprctl": 'if [ -e "$FAKE_DIR/muet" ]; then\n'
               '    n=$(cat "$FAKE_DIR/muet"); [ "$n" -gt 0 ] && { echo $((n - 1)) > "$FAKE_DIR/muet"; exec sleep 1; }\n'
               '    rm -f "$FAKE_DIR/muet"\nfi\n'
               '. "$FAKE_DIR/bin/fake-coque"; evoluer\n'
               'printf \'{"locked": %s}\\n\' "$(cat "$FAKE_DIR/locked" 2>/dev/null || echo false)"\n',
    # qs ipc -c dunei call verrou <méthode> [ordre], selon FAKE_COQUE : « tient » (défaut), « absente » (code 255 de qs
    # sans instance), « muette » (dort 1 s), « fige » (répond à tout sauf à etat, où elle dort 1 s), « lente » (tient après 2,5 s), « tard » (255 pendant FAKE_TARD ms, 500 par
    # défaut, puis tient), « tombe » (répond à tomber, puis 255 pour de bon), « meurt » (255 dès que tient a été rendu
    # une fois, pour de bon), « revient » (comme meurt, puis tient de nouveau). tomber et poserSec posent le bloc sous
    # un ordre qui n'est pas périmé ; remonter est ignoré sous le verrou ; etat rend {pose, ordre, tient, couvre,
    # remonte} et, si FAKE_VEILLE=1, annonce la veille en touchant verrou-sec. qs -p (rideau) est consigné, se dit posé
    # sur sa sortie, consigne « rideau posé <DUNEI_RIDEAU_COULEUR> », puis vit jusqu'à un TERM, consigné
    # « rideau TERM ».
    "qs": LOG.format(name="qs") + '. "$FAKE_DIR/bin/fake-coque"\n'
          '[ "$1" = -p ] && { trap \'echo "rideau TERM" >> "$FAKE_LOG"; exit 0\' TERM; echo "rideau : posé"\n'
          '    echo "rideau posé $DUNEI_RIDEAU_COULEUR" >> "$FAKE_LOG"; while :; do sleep 0.02; done; }\n'
          'case $mode in absente) exit 255 ;; muette) exec sleep 1 ;; esac\n'
          '[ "$mode" = fige ] && [ "$6" = etat ] && exec sleep 1\n'
          '[ "$mode" = tard ] && [ $((now - $(cat "$D/debut"))) -lt "${FAKE_TARD:-500}" ] && exit 255\n'
          '[ -e "$D/tombe" ] && exit 255\n'
          'evoluer\n[ -e "$D/mort" ] && exit 255\n'
          'o=$(cat "$D/ordre" 2>/dev/null || echo 0)\n'
          'case $6 in\n'
          '    tomber|poserSec) [ "$7" -ge "$o" ] && { echo "$7" > "$D/ordre"; [ -e "$D/couvre" ] || echo "$now" > "$D/couvre"; }\n'
          '                     [ "$mode" = tombe ] && : > "$D/tombe" ;;\n'
          '    remonter) [ -e "$D/pris" ] || rm -f "$D/couvre" ;;\n'
          '    etat) c=false t=false; [ -e "$D/couvre" ] && c=true; [ -e "$D/pris" ] && t=true\n'
          '          [ "${FAKE_VEILLE:-}" = 1 ] && : > "$XDG_RUNTIME_DIR/dunei/verrou-sec"\n'
          '          printf \'{"pose": %s, "ordre": %s, "tient": %s, "couvre": %s, "remonte": false}\\n\' '
          '"$c" "$(cat "$D/ordre" 2>/dev/null || echo 0)" "$t" "$c"\n'
          '          [ "$t" = true ] && case $mode in meurt|revient) [ -e "$D/revenu" ] || echo "$now" > "$D/mort" ;; esac ;;\n'
          'esac\nexit 0\n',
    # stdbuf -oL <commande> : exécute sa commande, options retirées.
    "stdbuf": LOG.format(name="stdbuf") + 'while case "$1" in -*) true;; *) false;; esac; do shift; done\nexec "$@"\n',
    "busctl": LOG.format(name="busctl") + 'echo "${FAKE_BUSCTL:-b false}"\n',
    # systemd-run : échoue si l'unité existe ($FAKE_DIR/unite) ou si FAKE_SYSTEMD_RUN=panne, sinon exécute sa commande.
    "systemd-run": LOG.format(name="systemd-run") + '[ -e "$FAKE_DIR/unite" ] && exit 1\n'
                   '[ "${FAKE_SYSTEMD_RUN:-}" = panne ] && exit 1\n'
                   'while case "$1" in --*) true;; *) false;; esac; do shift; done\nexec "$@"\n',
    "systemctl": LOG.format(name="systemctl") + '[ "$2" != is-active ] || [ -e "$FAKE_DIR/unite" ]\n',
    "notify-send": LOG.format(name="notify-send"),
    # pgrep : FAKE_PGREP_REND=1 simule l'autre hyprlock qui rend la session juste après avoir été trouvé ;
    # FAKE_PGREP_MUET=1, le compositeur qui devient muet pour de bon juste après.
    "pgrep": LOG.format(name="pgrep") + '[ -n "${FAKE_PGREP_REND:-}" ] && echo false > "$FAKE_DIR/locked"\n'
             '[ -n "${FAKE_PGREP_MUET:-}" ] && echo 100000 > "$FAKE_DIR/muet"\n'
             'exit "${FAKE_PGREP:-1}"\n',
    "logger": LOG.format(name="logger"),
    # hyprlock : le n-ième lancement suit le n-ième mot de $FAKE_HYPRLOCK (le dernier ensuite). « tient » : verrou tenu
    # FAKE_HYPRLOCK_TENUE ms (800 par défaut) puis rendu ; « garde » : sort au bout de 15 pas de 20 ms en laissant le
    # verrou ; « vite » : sort aussitôt en laissant le verrou ; « fige » : comme « garde », mais rend le compositeur muet
    # 5 appels ; « dort » : vit 10 s sans prendre le verrou ; « jamais » : sort sans verrou ; « muet » : sort sans
    # verrou en rendant le compositeur muet 12 appels (plus de 2 s). À la prise du verrou, il écrit onLockLocked sur sa
    # sortie ; il consigne son lancement, son heure, et chaque TERM ou USR1 reçu (USR1 rendrait la session). Avec
    # FAKE_HYPRLOCK_SOURD=1, il consigne TERM sans en mourir.
    "hyprlock": 'echo "hyprlock $*" >> "$FAKE_LOG"\n'
                'date +%s%3N >> "$FAKE_DIR/lancements"\n'
                'n=$(wc -l < "$FAKE_DIR/lancements"); set -- ${FAKE_HYPRLOCK:-tient}\n'
                '[ "$n" -gt $# ] && n=$#; eval "mode=\\${$n}"\n'
                'trap \'echo "hyprlock TERM" >> "$FAKE_LOG"; [ -n "${FAKE_HYPRLOCK_SOURD:-}" ] || exit 143\' TERM\n'
                'trap \'echo "hyprlock USR1" >> "$FAKE_LOG"; echo false > "$FAKE_DIR/locked"; exit 0\' USR1\n'
                'prendre() { echo true > "$FAKE_DIR/locked"; echo onLockLocked; }\n'
                'case "$mode" in\n'
                '    jamais) sleep 0.05; exit 1 ;;\n'
                '    muet) sleep 0.05; echo 12 > "$FAKE_DIR/muet"; exit 1 ;;\n'
                '    dort) i=500 ;;\n'
                '    vite) prendre; exit 1 ;;\n'
                '    garde|fige) prendre; i=15 ;;\n'
                '    *) prendre; i=$((${FAKE_HYPRLOCK_TENUE:-800} / 20)) ;;\n'
                'esac\n'
                'while [ "$i" -gt 0 ]; do sleep 0.02; i=$((i - 1)); done\n'
                '[ "$mode" = fige ] && { echo 5 > "$FAKE_DIR/muet"; exit 1; }\n'
                '[ "$mode" = garde ] && exit 1\n[ "$mode" = dort ] && exit 1\necho false > "$FAKE_DIR/locked"\n',
}
# Utilitaires système appelés par le lanceur et par les faux outils, liés un à un dans le dossier temporaire.
OUTILS = ("cat", "date", "id", "jq", "mkdir", "rm", "sed", "sleep", "timeout", "wc")
# Délais du verrou, sous la forme de generated/motion.json.
DELAIS = {"verrouAttente": 1500}


def etape(ligne: str) -> str:
    """Nom court d'un appel consigné : méthode IPC, « rideau » pour qs -p, « rideau posé » et « rideau TERM » pour le
    rideau prêt puis retiré, « kill -TERM » ou « kill -USR1 » pour un signal reçu par hyprlock, sinon le nom de
    l'outil."""
    mots = ligne.split()
    if mots[0] == "rideau":
        return " ".join(mots[:2])
    if mots[0] == "qs":
        return "rideau" if mots[1] == "-p" else mots[6]
    if mots[0] == "hyprlock" and mots[1:2] in (["TERM"], ["USR1"]):
        return "kill -" + mots[1]
    return mots[0]


class DuneiVerrouTest(unittest.TestCase):
    """Entrée par la coque, échéance et secours de hyprlock, relais vers la coque, verrou sec, veille, relances,
    second appel et placement."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.t = t = Path(self.tmp.name)
        for d in ("bin", "sys", "run", "config/dunei", "config/hypr"):
            (t / d).mkdir(parents=True)
        for name, body in FAKES.items():
            (t / "bin" / name).write_text("#!/bin/sh\n" + body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        for outil in OUTILS:
            (t / "sys" / outil).symlink_to(shutil.which(outil))
        (t / "config/dunei/motion.json").write_text(json.dumps({"delays": DELAIS}), encoding="utf-8")
        self.sessions = []
        self.repli = t / "config/hypr/hyprlock.conf"
        self.log, self.run_dir = t / "log", t / "run" / "dunei"
        env = {k: v for k, v in os.environ.items() if k != "DUNEI_VERROU_PORTEE"}
        self.env = {**env, "PATH": f"{t / 'bin'}:{t / 'sys'}", "FAKE_LOG": str(self.log), "FAKE_DIR": str(t),
                    "XDG_RUNTIME_DIR": str(t / "run"), "XDG_CONFIG_HOME": str(t / "config"),
                    "XDG_STATE_HOME": str(t / "state")}

    def tearDown(self):
        # Aucun processus d'un essai ne survit à son dossier : privé de ses faux outils, il atteindrait les vrais. Aucun
        # essai n'envoie SIGUSR1 à hyprlock : ce signal rendrait toute la session, verrou de la coque compris.
        self.tuer_sessions()
        appels = self.calls()
        self.tmp.cleanup()
        self.assertNotIn("hyprlock USR1", appels)

    def restants(self) -> list[int]:
        """Processus vivants des essais : membres d'une session ouverte par lancer(), ou portant FAKE_DIR=<dossier>.

        Entrées : self.sessions (PID des lancements, chefs de leur session) et self.tmp.
        Sortie : liste des PID trouvés dans /proc, zombies exclus (ils n'exécutent plus rien).
        Erreurs : un processus disparu ou illisible pendant la lecture est ignoré. Dépendances : /proc (Linux)."""
        marque = f"FAKE_DIR={self.tmp.name}".encode() + b"\0"
        trouves = []
        for entree in os.listdir("/proc"):
            if not entree.isdigit() or int(entree) == os.getpid():
                continue
            try:
                champs = Path(f"/proc/{entree}/stat").read_text().rsplit(")", 1)[1].split()
                if champs[0] in "ZX":
                    continue
                if int(champs[3]) in self.sessions or marque in Path(f"/proc/{entree}/environ").read_bytes():
                    trouves.append(int(entree))
            except (OSError, IndexError, ValueError):
                continue
        return trouves

    def tuer_sessions(self):
        """Tue (SIGKILL) tous les processus des essais, jusqu'à n'en plus trouver aucun.

        Entrées : aucune, voir restants(). Sortie : aucune ; les sessions tuées sont retirées de la liste.
        Erreurs : échec de l'essai si des processus survivent encore au bout de 5 s. Dépendances : restants()."""
        for _ in range(250):
            pids = self.restants()
            if not pids:
                self.sessions.clear()
                return
            for pid in pids:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            time.sleep(0.02)
        self.fail(f"processus d'essai toujours vivants : {self.restants()}")

    def lancer(self, *args: str, **env: str) -> subprocess.Popen:
        """Lance le lanceur dans sa propre session, retenue pour être tuée en fin d'essai."""
        proc = subprocess.Popen([str(SCRIPT), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                env={**self.env, **env}, start_new_session=True)
        self.sessions.append(proc.pid)
        return proc

    def run_script(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        """Lance le lanceur avec les faux outils et les variables FAKE_* données ; borné à 20 s, session tuée ensuite."""
        proc = self.lancer(*args, **env)
        try:
            out, err = proc.communicate(timeout=20)
        finally:
            proc.kill()
            proc.wait()
            self.tuer_sessions()
        return subprocess.CompletedProcess(proc.args, proc.returncode, out, err)

    def calls(self) -> list[str]:
        """Appels consignés, dans l'ordre."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def etapes(self) -> list[str]:
        """Noms courts des appels consignés, dans l'ordre."""
        return [etape(c) for c in self.calls()]

    def lancements(self) -> list[str]:
        """Lignes consignées par chaque lancement de hyprlock."""
        return [c for c in self.calls() if c.startswith("hyprlock -")]

    def jetons(self, choix: dict | None):
        """Installe des jetons de coque réduits (deux familles, deux moments) et, si choix est donné, theme.json.

        Entrées : choix — {famille, moment}, ou None pour ne pas écrire theme.json.
        Sortie : aucune ; fichiers écrits sous config/dunei. Erreurs : aucune. Dépendances : json."""
        theme = lambda c: {"color": {"surfaceBase": c}}
        tokens = {"defaut": {"famille": "thematisee", "moment": "nuit"}, "familles": ["thematisee", "dominante"],
                  "moments": ["nuit", "jour"],
                  "themes": {"thematisee": {"nuit": theme("#0f0703"), "jour": theme("#e6e6e6")},
                             "dominante": {"nuit": theme("#040404")}}}
        (self.t / "config/dunei/coque-tokens.json").write_text(json.dumps(tokens), encoding="utf-8")
        if choix is not None:
            (self.t / "config/dunei/theme.json").write_text(json.dumps(choix), encoding="utf-8")

    def lancement(self) -> int:
        """Heure (ms) du premier lancement de hyprlock."""
        return int((self.t / "lancements").read_text().split()[0])

    def assertSousSuite(self, attendu: list[str], reel: list[str]):
        """Vérifie que les étapes attendues figurent dans cet ordre parmi les étapes réelles."""
        it = iter(reel)
        self.assertTrue(all(e in it for e in attendu), f"{attendu} hors d'ordre dans {reel}")

    # Entrée par la coque.

    def test_chute_tenue_par_la_coque(self):
        # La coque tombe et prend le verrou elle-même : aucun hyprlock ; le bloc remonte au déverrouillage.
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["tomber", "etat", "remonter"], self.etapes())
        self.assertEqual(self.lancements(), [])
        self.assertNotIn("poserSec", self.etapes())

    def test_coque_absente(self):
        # Sans coque, hyprlock part aussitôt sur la configuration de secours, sous stdbuf, sortie au journal.
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="absente")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.lancements(), [f"hyprlock --no-fade-in -c {self.repli}"])
        self.assertIn(f"stdbuf -oL hyprlock --no-fade-in -c {self.repli}", self.calls())
        self.assertLess(self.lancement() - debut, 300)
        self.assertIn("onLockLocked", (self.run_dir / "verrou-hyprlock.log").read_text())
        self.assertSousSuite(["tomber", "hyprlock", "remonter"], self.etapes())

    def test_coque_muette(self):
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="muette")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.lancements(), [f"hyprlock --no-fade-in -c {self.repli}"])
        self.assertLess(self.lancement() - debut, 500)
        # Coque muette 2 s à la remontée : relancée par le lanceur.
        self.assertIn("systemctl --user restart dunei-coque.service", self.calls())

    def test_coque_lente_echeance(self):
        # La coque ne tient qu'après 2,5 s : hyprlock part à l'échéance (1,5 s), puis lui cède le verrou par SIGTERM.
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="lente", FAKE_HYPRLOCK_TENUE="5000")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 1)
        self.assertGreaterEqual(self.lancement() - debut, 1400)
        self.assertLess(self.lancement() - debut, 1800)
        self.assertSousSuite(["tomber", "etat", "hyprlock", "etat", "kill -TERM", "remonter"], self.etapes())

    def test_hyprlock_sourd_a_term(self):
        # Un hyprlock qui survit au SIGTERM du relais est tué au bout de la borne ; le lanceur finit, code 0.
        res = self.run_script(FAKE_COQUE="lente", FAKE_HYPRLOCK_TENUE="8000", FAKE_HYPRLOCK_SOURD="1")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["kill -TERM", "logger", "remonter"], self.etapes())
        self.assertTrue(any(c.startswith("logger") and "sourd" in c for c in self.calls()))

    def test_coque_figee_echeance(self):
        # La coque répond à tomber puis se fige sur etat (borne de 0,2 s à chaque tour) : hyprlock part à l'échéance.
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="fige")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertLess(self.lancement() - debut, DELAIS["verrouAttente"] + 100)

    def test_coque_disparue_en_chute(self):
        # La coque répond à tomber puis disparaît : plus de bloc, hyprlock part sans attendre l'échéance.
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="tombe")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertSousSuite(["tomber", "etat", "hyprlock", "remonter"], etapes)
        self.assertEqual(etapes[:etapes.index("hyprlock")].count("etat"), 1)
        self.assertLess(self.lancement() - debut, DELAIS["verrouAttente"] / 2)

    def test_ouverture_de_session(self):
        # --sec : hyprlock tout de suite ; la coque, arrivée plus tard, reçoit poserSec, tient, et hyprlock reçoit TERM.
        res = self.run_script("--sec", FAKE_COQUE="tard", FAKE_TARD="400", FAKE_HYPRLOCK_TENUE="5000")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertEqual(len(self.lancements()), 1)
        self.assertLess(etapes.index("hyprlock"), etapes.index("etat"))
        self.assertSousSuite(["hyprlock", "etat", "poserSec", "etat", "kill -TERM", "remonter"], etapes)
        self.assertNotIn("tomber", etapes)
        self.assertNotIn("busctl", etapes)

    def test_coque_posee_d_elle_meme(self):
        # --sec : la coque, démarrée seule sur une session tenue, a posé son bloc sous son propre ordre (0) avant de
        # répondre. Elle reçoit poserSec sous l'ordre du lanceur, puis tient sous lui, et hyprlock reçoit TERM.
        (self.t / "coque").mkdir()
        (self.t / "coque" / "couvre").write_text(f"{int(time.time() * 1000)}\n")
        (self.t / "coque" / "ordre").write_text("0\n")
        res = self.run_script("--sec", FAKE_COQUE="tard", FAKE_TARD="400", FAKE_HYPRLOCK_TENUE="5000")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["hyprlock", "etat", "poserSec", "etat", "kill -TERM", "remonter"], self.etapes())

    def test_veille_annoncee(self):
        res = self.run_script(FAKE_BUSCTL="b true")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertNotIn("tomber", etapes)
        self.assertSousSuite(["busctl", "poserSec", "etat", "remonter"], etapes)
        self.assertEqual(self.lancements(), [])

    def test_veille_en_cours_de_chute(self):
        # Une veille annoncée pendant la chute (verrou-sec, posé par un second appel) l'abrège une seule fois.
        res = self.run_script(FAKE_VEILLE="1", FAKE_PRISE="600")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertSousSuite(["tomber", "etat", "abreger", "remonter"], etapes)
        self.assertEqual(etapes.count("abreger"), 1)
        self.assertGreater(etapes.count("etat"), 2)
        self.assertEqual(self.lancements(), [])
        self.assertFalse((self.run_dir / "verrou-sec").exists())

    def test_delai_non_entier(self):
        # Une valeur non entière de motion.json ne fait pas mourir le shell dans son arithmétique : la valeur par
        # défaut (1500) la remplace, et l'échéance tombe à son heure.
        (self.t / "config/dunei/motion.json").write_text(json.dumps({"delays": {**DELAIS, "verrouAttente": 1000.5}}),
                                                         encoding="utf-8")
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="lente", FAKE_HYPRLOCK_TENUE="5000")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertGreaterEqual(self.lancement() - debut, 1400)
        self.assertLess(self.lancement() - debut, 1800)

    def test_ordre_corrompu(self):
        self.run_dir.mkdir()
        (self.run_dir / "verrou-ordre").write_text("abc\n")
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("qs ipc -c dunei call verrou tomber 1", self.calls())

    def test_repli_de_secours(self):
        # Configuration de secours : date française rafraîchie chaque minute, champ qui s'efface vide, aucune image.
        texte = (ROOT / "config" / "hypr" / "hyprlock.conf").read_text(encoding="utf-8")
        self.assertIn("secours de la voie B", texte.splitlines()[0])
        self.assertIn("cmd[update:60000] date '+%w %-d %-m' | awk", texte)
        self.assertIn("fade_on_empty = true", texte)
        self.assertIsNone(re.search(r"^\s*(image|path)\b", texte, re.M))

    # Relances de hyprlock, coque absente.

    def test_jamais_tenu_relance(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="jamais jamais tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.lancements(), [f"hyprlock --no-fade-in -c {self.repli}"] * 3)
        self.assertNotIn("notify-send", self.etapes())

    def test_trois_echecs_notifie(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="jamais")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(len(self.lancements()), 3)
        notes = [c for c in self.calls() if c.startswith("notify-send")]
        self.assertEqual(len(notes), 1)
        self.assertIn("-u critical", notes[0])
        self.assertIn("Verrouillage impossible", notes[0])
        self.assertSousSuite(["notify-send", "remonter"], self.etapes())

    def test_trois_echecs_a_l_ouverture(self):
        # À l'ouverture de session, dunei-verrou-initial ferme la session : le bloc reste posé, rien ne s'annonce.
        res = self.run_script("--sec", FAKE_COQUE="absente", FAKE_HYPRLOCK="jamais")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(len(self.lancements()), 3)
        self.assertNotIn("notify-send", self.etapes())
        self.assertNotIn("remonter", self.etapes())

    def test_relance_si_tenu(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="garde tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 2)
        self.assertNotIn("notify-send", self.etapes())

    def test_echeance_sans_verrou(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="dort dort tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 3)
        self.assertEqual(len([c for c in self.calls() if "non pris" in c]), 2)

    def test_sorties_rapides_pause(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="vite vite vite tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 4)
        heures = [int(h) for h in (self.t / "lancements").read_text().split()]
        self.assertTrue(all(b - a >= 450 for a, b in zip(heures, heures[1:])), heures)

    def test_compositeur_muet(self):
        # Compositeur muet à la sortie de hyprlock, session encore tenue : jamais prise pour rendue.
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="fige tient")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 2)
        # Une seule fin : la remontée, sans coque, se termine par une seule relance de la coque.
        self.assertEqual(self.calls().count("systemctl --user restart dunei-coque.service"), 1)

    def test_muet_jamais_presume_tenu_sec(self):
        # Compositeur muet plus de 2 s après un lancement manqué : relance, mais jamais « verrou vu » ; code non nul.
        res = self.run_script("--sec", FAKE_COQUE="absente", FAKE_HYPRLOCK="muet jamais")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(len(self.lancements()), 4)
        self.assertNotIn("remonter", self.etapes())

    def test_muet_jamais_presume_tenu_notifie(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="muet jamais")
        self.assertEqual(res.returncode, 1)
        self.assertSousSuite(["notify-send", "remonter"], self.etapes())

    def test_muet_permanent_sec(self):
        # Compositeur muet trois fois de suite : échec du verrou, jamais 0.
        res = self.run_script("--sec", FAKE_COQUE="absente", FAKE_HYPRLOCK="muet")
        self.assertEqual(res.returncode, 1)
        self.assertEqual(len(self.lancements()), 3)
        self.assertNotIn("remonter", self.etapes())

    def test_muet_permanent_notifie(self):
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="muet")
        self.assertEqual(res.returncode, 1)
        self.assertSousSuite(["notify-send", "remonter"], self.etapes())

    def test_autre_hyprlock_suivi(self):
        # Un autre hyprlock vivant garde la session à la sortie du nôtre : on le suit au lieu de relancer.
        def deverrouiller():
            """Rend la session 1 s après le départ."""
            time.sleep(1)
            (self.t / "locked").write_text("false\n")

        fil = threading.Thread(target=deverrouiller)
        fil.start()
        res = self.run_script(FAKE_COQUE="absente", FAKE_HYPRLOCK="garde", FAKE_PGREP="0")
        fil.join()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 1)
        self.assertSousSuite(["pgrep", "remonter"], self.etapes())

    def test_deja_tenu_sans_verrouilleur(self):
        # Session tenue sans verrouilleur vivant ni coque : rideau d'abord, à la couleur surface-base du thème choisi
        # par theme.json, puis hyprlock ; le rideau est retiré à onLockLocked.
        (self.t / "locked").write_text("true\n")
        self.jetons({"famille": "thematisee", "moment": "jour"})
        res = self.run_script(FAKE_COQUE="absente")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertNotIn("tomber", etapes)
        self.assertNotIn("poserSec", etapes)
        self.assertSousSuite(["rideau", "rideau posé", "hyprlock", "rideau TERM", "remonter"], etapes)
        self.assertIn(f"qs -p {self.t / 'config/quickshell/dunei/Rideau/shell.qml'}", self.calls())
        self.assertIn("rideau posé #e6e6e6", self.calls())
        self.assertEqual(len(self.lancements()), 1)

    def test_couleur_du_rideau_par_defaut(self):
        # theme.json absent : thème par défaut des jetons ; jetons illisibles : noir.
        (self.t / "locked").write_text("true\n")
        self.jetons(None)
        self.run_script(FAKE_COQUE="absente")
        self.assertIn("rideau posé #0f0703", self.calls())
        self.log.unlink()
        (self.t / "locked").write_text("true\n")
        (self.t / "config/dunei/coque-tokens.json").write_text("{", encoding="utf-8")
        self.run_script(FAKE_COQUE="absente")
        self.assertIn("rideau posé black", self.calls())

    def test_deja_tenu_par_la_coque(self):
        # La coque tient déjà le verrou (relancée sur une session tenue, sous son propre ordre) : on la suit, sans
        # hyprlock ni rideau, puis le bloc remonte.
        (self.t / "locked").write_text("true\n")
        (self.t / "coque").mkdir()
        maintenant = f"{int(time.time() * 1000)}\n"
        for nom in ("couvre", "pris"):
            (self.t / "coque" / nom).write_text(maintenant)
        (self.t / "coque" / "ordre").write_text("0\n")
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertEqual(self.lancements(), [])
        self.assertNotIn("rideau", etapes)
        self.assertNotIn("tomber", etapes)
        self.assertSousSuite(["etat", "remonter"], etapes)

    def test_deja_tenu_coque_vivante(self):
        # Session tenue sans verrouilleur, coque vivante sans bloc : elle reçoit poserSec et reprend le verrou.
        (self.t / "locked").write_text("true\n")
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.lancements(), [])
        self.assertNotIn("tomber", self.etapes())
        self.assertSousSuite(["etat", "poserSec", "etat", "remonter"], self.etapes())

    # Garde : coque disparue pendant le verrou.

    def test_coque_revient_a_temps(self):
        # La coque meurt verrou tenu et revient 1 s plus tard, sous l'ordre 0 : poserSec lui rend l'ordre courant,
        # elle tient de nouveau ; ni rideau ni hyprlock.
        res = self.run_script(FAKE_COQUE="revient", FAKE_TENUE="2000")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertEqual(self.lancements(), [])
        self.assertNotIn("rideau", etapes)
        self.assertSousSuite(["tomber", "etat", "poserSec", "etat", "remonter"], etapes)

    def test_coque_ne_revient_pas(self):
        # La coque meurt verrou tenu : vers verrouReprise (3 s), rideau posé, puis hyprlock, puis rideau retiré ;
        # hyprlock rend la session, le bloc est remonté, code 0. Sans jetons installés, le rideau est noir.
        debut = time.time() * 1000
        res = self.run_script(FAKE_COQUE="meurt")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertSousSuite(["tomber", "rideau", "rideau posé", "hyprlock", "rideau TERM", "remonter"], etapes)
        self.assertEqual(len(self.lancements()), 1)
        self.assertGreaterEqual(self.lancement() - debut, 3000)
        self.assertLess(self.lancement() - debut, 4000)
        self.assertIn("rideau posé black", self.calls())

    def test_hyprlock_tombe_coque_reprend(self):
        # --sec : hyprlock garde la session, la coque couvre sans encore tenir ; hyprlock sort en laissant le verrou :
        # la coque, vivante, reçoit poserSec et reprend la garde, sans second hyprlock.
        res = self.run_script("--sec", FAKE_HYPRLOCK="garde", FAKE_PRISE="1000")
        self.assertEqual(res.returncode, 0, res.stderr)
        etapes = self.etapes()
        self.assertEqual(len(self.lancements()), 1)
        self.assertEqual(etapes.count("poserSec"), 2)
        self.assertSousSuite(["hyprlock", "poserSec", "poserSec", "remonter"], etapes)

    def test_unite_restart_always(self):
        # Une coque qui quitte pendant le verrou, même proprement, est relancée par systemd.
        unite = (ROOT / "config/systemd/user/dunei-coque.service").read_text(encoding="utf-8")
        self.assertIn("Restart=always", unite.splitlines())
        self.assertNotIn("Restart=on-failure", unite)

    # Second appel et placement.

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
        self.assertNotIn("tomber", self.etapes())

    def test_second_appel_pendant_la_fin(self):
        # L'unité finit sans que le verrou ait été vu tenu : le placement est retenté une fois, en verrou sec pour
        # tenir la borne depuis l'appel réel, et la coque prend le verrou.
        (self.t / "unite").touch()

        def retirer():
            """Retire l'unité 0,3 s après le départ, sans que le verrou ait été tenu."""
            time.sleep(0.3)
            (self.t / "unite").unlink()

        fil = threading.Thread(target=retirer)
        fil.start()
        res = self.run_script()
        fil.join()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.lancements(), [])
        self.assertNotIn("tomber", self.etapes())
        self.assertSousSuite(["poserSec", "etat", "remonter"], self.etapes())

    def test_trace_nettoyee(self):
        proc = self.lancer()
        for _ in range(200):
            if list(self.run_dir.glob("verrou-place-*")):
                break
            time.sleep(0.01)
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=20)
        self.assertEqual(list(self.run_dir.glob("verrou-place-*")), [])

    def test_suivi_course_au_depart(self):
        # L'autre hyprlock rend la session entre le « oui » lu et le suivi : le lanceur placé rend 0, sans boucler
        # sur sa propre unité (toujours active).
        (self.t / "unite").touch()
        (self.t / "locked").write_text("true\n")
        res = self.run_script(DUNEI_VERROU_PORTEE="-", FAKE_PGREP="0", FAKE_PGREP_REND="1")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.lancements(), [])

    def test_suivi_course_a_la_relance(self):
        (self.t / "unite").touch()
        res = self.run_script(DUNEI_VERROU_PORTEE="-", FAKE_COQUE="absente", FAKE_HYPRLOCK="garde", FAKE_PGREP="0",
                              FAKE_PGREP_REND="1")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 1)
        self.assertSousSuite(["pgrep", "remonter"], self.etapes())

    def test_suivi_muet_appel_exterieur(self):
        # Un autre lanceur mène le verrou et le compositeur meurt : le second appel renonce, code 1, sans boucler.
        (self.t / "unite").touch()
        (self.t / "muet").write_text("100000\n")
        debut = time.time()
        res = self.run_script()
        self.assertEqual(res.returncode, 1, res.stderr)
        self.assertLess(time.time() - debut, 10)
        self.assertEqual(self.lancements(), [])
        self.assertTrue(any(c.startswith("logger") and "suivi" in c for c in self.calls()))

    def test_suivi_muet_lanceur_place(self):
        # Le lanceur placé suit un autre hyprlock et le compositeur meurt : il renonce, code 1, sans remonter le bloc,
        # et son unité se termine avec lui.
        (self.t / "locked").write_text("true\n")
        debut = time.time()
        res = self.run_script(DUNEI_VERROU_PORTEE="-", FAKE_PGREP="0", FAKE_PGREP_MUET="1")
        self.assertEqual(res.returncode, 1, res.stderr)
        self.assertLess(time.time() - debut, 10)
        self.assertEqual(self.lancements(), [])
        self.assertNotIn("remonter", self.etapes())

    def test_debut_herite_ignore(self):
        # Une heure d'appel héritée par l'appel extérieur est ignorée : la chute garde son échéance, la coque tient.
        res = self.run_script(DUNEI_VERROU_DEBUT="1")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["tomber", "etat", "remonter"], self.etapes())
        self.assertEqual(self.lancements(), [])

    def test_debut_plafonne(self):
        # Une heure d'appel future, côté placé, est ramenée à maintenant : hyprlock part à l'échéance.
        debut = time.time() * 1000
        res = self.run_script(DUNEI_VERROU_PORTEE="-", DUNEI_VERROU_DEBUT=str(int(debut) + 60000), FAKE_COQUE="lente",
                              FAKE_HYPRLOCK_TENUE="5000")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertLess(self.lancement() - debut, DELAIS["verrouAttente"] + 300)

    def test_systemd_run_en_panne(self):
        res = self.run_script(FAKE_SYSTEMD_RUN="panne")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["tomber", "etat", "remonter"], self.etapes())
        self.assertTrue(any(c.startswith("logger") and "systemd-run" in c for c in self.calls()))

    def test_sec_garde_dans_le_lanceur_place(self):
        # Le lanceur placé n'efface pas le verrou-sec qu'un second appel a pu poser : la chute est abrégée.
        self.run_dir.mkdir()
        (self.run_dir / "verrou-sec").touch()
        res = self.run_script(DUNEI_VERROU_PORTEE="-")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertSousSuite(["tomber", "abreger", "remonter"], self.etapes())

    def test_unite_qui_finit_bornee(self):
        # Appel juste après un déverrouillage : l'unité du verrou précédent reste active 2 s (remontée, coque muette),
        # la session franchement rendue. L'appel ne l'attend que jusqu'à l'échéance, puis pose un verrou sec hors
        # unité : sans coque, hyprlock part aussitôt.
        (self.t / "unite").touch()

        def retirer():
            """Retire l'unité 2 s après le départ, sans que le verrou ait été tenu."""
            time.sleep(2.0)
            (self.t / "unite").unlink()

        fil = threading.Thread(target=retirer)
        debut = time.time() * 1000
        fil.start()
        res = self.run_script(FAKE_COQUE="absente")
        fil.join()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len(self.lancements()), 1)
        self.assertLess(self.lancement() - debut, DELAIS["verrouAttente"] + 300)
        self.assertNotIn("tomber", self.etapes())
        self.assertSousSuite(["poserSec", "hyprlock", "remonter"], self.etapes())
        self.assertTrue(any(c.startswith("logger") and "hors unité" in c for c in self.calls()))

    def test_usage(self):
        self.assertEqual(self.run_script("--vite").returncode, 2)
        self.assertEqual(self.run_script("--sec", "--sec").returncode, 2)


if __name__ == "__main__":
    unittest.main()
