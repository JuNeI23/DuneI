# DuneI — chaîne de construction.
#   make tokens   tokens.toml → generated/
#   make motion   motion.toml → generated/
#   make energie  energie.toml → generated/hypridle.conf, generated/energie.lua
#   make shaders  coque/Theme/materiau.frag → generated/materiau.frag.qsb (qsb de qt6-shadertools) et son empreinte
#                 generated/materiau.frag.sha256 ; ne recompile que si la source ne répond plus à l'empreinte, car les
#                 octets du .qsb changent avec la version de qsb (D85)
#   make icones   icones/correspondances.toml + SVG Phosphor versionnés → generated/icons/DuneI (index.theme et variantes
#                 symbolic, normale et pleine) ; jamais de réseau
#   make phosphor icones/correspondances.toml → icones/phosphor/ : télécharge l'archive Phosphor épinglée (sha256), seule
#                 cible qui touche au réseau, et n'en extrait que les SVG de la table
#   make paquets  paquets.toml → système : installe le manquant, marque, propose de retirer l'excédent
#   make chiffrement  racine LUKS2 → puce + phrase et clé de secours, une étape par passage (python3 chiffrement.py --etat : l'état seul)
#   make phrase   change la phrase de la puce, une fois le chiffrement terminé
#   make test     tests unitaires et de non-régression
#   make generes  refuse si generated/ diffère d'une génération fraîche (le .qsb, par son empreinte) ou contient un
#                 fichier hors de git
#   make check    generes, puis les tests
#   make golden   régénère les instantanés de référence (changement de sortie VOULU)
#   make install  generated/ et config/ → ~/.config/hypr, ~/.config/fontconfig, ~/.config/dunei (tokens et shader de la coque) et ~/.config/kitty ; thème d'icônes DuneI lié sous ~/.local/share/icons/DuneI et déclaré à GTK (settings.ini, gsettings) ; active les services de session.toml et masque l'autostart XDG ; systeme/ → /etc (sudo, seulement si un fichier diffère) ; greetd remplace le gestionnaire de connexion au démarrage suivant ; bascule depuis la configuration générique au premier passage ; pose rtk (version épinglée dans atelier.toml) ; clone dunei-atelier, installe ses plugins Claude Code et en lie les fichiers ; pose core.hooksPath (crochets du dépôt)

PY := python3
GOLDEN_HUES := 0 55 200 265
# qsb est hors du PATH : appelé par son chemin.
QSB := /usr/lib/qt6/bin/qsb

.PHONY: tokens motion energie icones shaders phosphor paquets chiffrement phrase test generes check golden install

tokens:
	$(PY) generate_tokens.py --out generated

motion:
	$(PY) generate_motion.py --out generated

energie:
	$(PY) generate_energie.py --out generated

icones:
	$(PY) generate_icones.py --out generated

shaders:
	@[ -f generated/materiau.frag.qsb ] && sha256sum --status -c generated/materiau.frag.sha256 2>/dev/null || { \
	$(QSB) --qt6 -o generated/materiau.frag.qsb coque/Theme/materiau.frag && \
	sha256sum coque/Theme/materiau.frag > generated/materiau.frag.sha256; }

phosphor:
	$(PY) phosphor.py

paquets:
	$(PY) paquets.py

chiffrement:
	$(PY) chiffrement.py

phrase:
	$(PY) chiffrement.py --phrase

test:
	$(PY) -m unittest discover -s tests -t .

generes: tokens motion energie icones shaders
	git diff --exit-code generated/
	@! git ls-files --others --exclude-standard generated/ | grep . || { echo "fichiers de generated/ hors de git : git add generated/" >&2; false; }

check: generes test

golden:
	$(foreach h,$(GOLDEN_HUES),$(PY) generate_tokens.py --out tests/golden/hue-$(h) --hue $(h) >/dev/null;)
	$(PY) generate_motion.py --out tests/golden/motion >/dev/null
	$(PY) generate_energie.py --out tests/golden/energie >/dev/null

install: tokens motion energie icones
	$(PY) deploy.py
