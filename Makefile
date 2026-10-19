# DuneI — chaîne de construction.
#   make tokens   tokens.toml → generated/
#   make motion   motion.toml → generated/
#   make energie  energie.toml → generated/hypridle.conf, generated/energie.lua
#   make paquets  paquets.toml → système : installe le manquant, marque, propose de retirer l'excédent
#   make chiffrement  racine LUKS2 → puce + phrase et clé de secours, une étape par passage (python3 chiffrement.py --etat : l'état seul)
#   make phrase   change la phrase de la puce, une fois le chiffrement terminé
#   make test     tests unitaires et de non-régression
#   make generes  refuse si generated/ diffère d'une génération fraîche ou contient un fichier hors de git (crochet pre-commit)
#   make check    generes, puis les tests
#   make golden   régénère les instantanés de référence (changement de sortie VOULU)
#   make install  generated/ et config/ → ~/.config/hypr, ~/.config/fontconfig et ~/.config/kitty ; active les services de session.toml et masque l'autostart XDG ; systeme/ → /etc (sudo, seulement si un fichier diffère) ; greetd remplace le gestionnaire de connexion au démarrage suivant ; bascule depuis la configuration générique au premier passage ; pose rtk (version épinglée dans atelier.toml) ; clone dunei-atelier, installe ses plugins Claude Code et en lie les fichiers

PY := python3
GOLDEN_HUES := 0 55 200 265

.PHONY: tokens motion energie paquets chiffrement phrase test generes check golden install

tokens:
	$(PY) generate_tokens.py --out generated

motion:
	$(PY) generate_motion.py --out generated

energie:
	$(PY) generate_energie.py --out generated

paquets:
	$(PY) paquets.py

chiffrement:
	$(PY) chiffrement.py

phrase:
	$(PY) chiffrement.py --phrase

test:
	$(PY) -m unittest discover -s tests -t .

generes: tokens motion energie
	git diff --exit-code generated/
	@! git ls-files --others --exclude-standard generated/ | grep . || { echo "fichiers de generated/ hors de git : git add generated/" >&2; false; }

check: generes test

golden:
	$(foreach h,$(GOLDEN_HUES),$(PY) generate_tokens.py --out tests/golden/hue-$(h) --hue $(h) >/dev/null;)
	$(PY) generate_motion.py --out tests/golden/motion >/dev/null
	$(PY) generate_energie.py --out tests/golden/energie >/dev/null

install: tokens motion energie
	$(PY) deploy.py
