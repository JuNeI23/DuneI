# DuneI — chaîne de construction.
#   make tokens   tokens.toml → generated/
#   make motion   motion.toml → generated/
#   make test     tests unitaires et de non-régression
#   make check    refuse si un fichier de generated/ a été modifié à la main
#   make golden   régénère les instantanés de référence (changement de sortie VOULU)

PY := python3
GOLDEN_HUES := 0 55 200 265

.PHONY: tokens motion test check golden

tokens:
	$(PY) generate_tokens.py --out generated

motion:
	$(PY) generate_motion.py --out generated

test:
	$(PY) -m unittest discover -s tests -t .

check: tokens motion test
	git diff --exit-code generated/

golden:
	$(foreach h,$(GOLDEN_HUES),$(PY) generate_tokens.py --out tests/golden/hue-$(h) --hue $(h) >/dev/null;)
	$(PY) generate_motion.py --out tests/golden/motion >/dev/null
