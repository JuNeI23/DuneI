# DuneI — chaîne de construction.
#   make tokens   tokens.toml → generated/
#   make motion   motion.toml → generated/
#   make energie  energie.toml → generated/hypridle.conf, generated/energie.lua
#   make test     tests unitaires et de non-régression
#   make check    refuse si un fichier de generated/ a été modifié à la main
#   make golden   régénère les instantanés de référence (changement de sortie VOULU)
#   make install  generated/ et config/ → ~/.config/hypr et ~/.config/fontconfig ; active les services de session.toml et masque l'autostart XDG ; systeme/ → /etc (sudo, seulement si un fichier diffère) ; greetd remplace le gestionnaire de connexion au démarrage suivant ; bascule depuis la configuration générique au premier passage

PY := python3
GOLDEN_HUES := 0 55 200 265

.PHONY: tokens motion energie test check golden install

tokens:
	$(PY) generate_tokens.py --out generated

motion:
	$(PY) generate_motion.py --out generated

energie:
	$(PY) generate_energie.py --out generated

test:
	$(PY) -m unittest discover -s tests -t .

check: tokens motion energie test
	git diff --exit-code generated/

golden:
	$(foreach h,$(GOLDEN_HUES),$(PY) generate_tokens.py --out tests/golden/hue-$(h) --hue $(h) >/dev/null;)
	$(PY) generate_motion.py --out tests/golden/motion >/dev/null
	$(PY) generate_energie.py --out tests/golden/energie >/dev/null

install: tokens motion energie
	$(PY) deploy.py
