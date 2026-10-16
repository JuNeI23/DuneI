#!/usr/bin/env bash
# vm.sh — machine virtuelle de recette de DuneI : QEMU/KVM, UEFI (OVMF) et TPM2 (swtpm).
# Rôle : prouver la procédure d'installation sans toucher à la machine ; réutilisée par la feature de chiffrement.
# Entrées : un argument facultatif, l'ISO Arch à démarrer ; sans argument, la machine redémarre sur son disque.
#   $XDG_CACHE_HOME (sinon ~/.cache) situe le dossier d'état dunei-vm/.
# Sortie : la fenêtre de la machine ; dans le dossier d'état, disque.qcow2 (40 Go, créé au premier lancement),
#   vars.fd (copie des variables OVMF), tpm/ (état de swtpm) et tpm.sock. Rien n'entre dans le dépôt.
# Erreurs : code 1 si l'ISO donnée est introuvable, ou si KVM, QEMU, swtpm ou OVMF manque (message nommant le
#   paquet à installer) ; dans les deux cas avant toute création. Code 1 aussi si l'ancien swtpm
#   ne s'arrête pas ou si la socket du nouveau n'apparaît pas.
# Dépendances : qemu-desktop (qemu-system-x86_64, qemu-img), swtpm, edk2-ovmf, accès à /dev/kvm.
set -euo pipefail

OVMF=/usr/share/edk2/x64
ETAT="${XDG_CACHE_HOME:-$HOME/.cache}/dunei-vm"

# exige — vérifie qu'une condition est vraie, sinon nomme le paquet à installer.
# Entrées : le paquet, puis la commande de test et ses arguments. Sortie : aucune.
# Erreurs : message sur la sortie d'erreur et arrêt avec le code 1. Dépendances : aucune.
exige() {
  local paquet=$1
  shift
  "$@" || { echo "vm.sh : $paquet est requis (pacman -S $paquet)." >&2; exit 1; }
}

[ $# -eq 0 ] || [ -r "$1" ] || { echo "vm.sh : ISO introuvable : $1" >&2; exit 1; }

exige "qemu-desktop" command -v qemu-system-x86_64 >/dev/null
exige "qemu-desktop" command -v qemu-img >/dev/null
exige "swtpm" command -v swtpm >/dev/null
exige "edk2-ovmf" test -r "$OVMF/OVMF_CODE.4m.fd"
exige "edk2-ovmf" test -r "$OVMF/OVMF_VARS.4m.fd"
[ -r /dev/kvm ] && [ -w /dev/kvm ] || { echo "vm.sh : /dev/kvm inaccessible (virtualisation absente ou utilisateur hors du groupe kvm)." >&2; exit 1; }

mkdir -p "$ETAT/tpm"
# Le disque naît sous un nom provisoire : un create interrompu ne laisse pas de disque partiel.
[ -e "$ETAT/disque.qcow2" ] || { qemu-img create -f qcow2 "$ETAT/disque.qcow2.tmp" 40G >/dev/null && mv "$ETAT/disque.qcow2.tmp" "$ETAT/disque.qcow2"; }
[ -e "$ETAT/vars.fd" ] || cp "$OVMF/OVMF_VARS.4m.fd" "$ETAT/vars.fd"

# Un swtpm resté d'une exécution précédente (QEMU tombé au démarrage) est arrêté, puis sa socket périmée retirée.
pid=$(cat "$ETAT/swtpm.pid" 2>/dev/null || true)
if [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = swtpm ]; then
  kill "$pid" 2>/dev/null || true
  # On attend sa mort (5 s au plus) : il tient le verrou de tpm/ et retirerait la socket du nouveau.
  for _ in {1..50}; do [ -e "/proc/$pid" ] || break; sleep 0.1; done
  [ ! -e "/proc/$pid" ] || { echo "vm.sh : l'ancien swtpm (pid $pid) ne s'arrête pas." >&2; exit 1; }
fi
rm -f "$ETAT/tpm.sock"

# swtpm s'arrête de lui-même quand QEMU se déconnecte (--terminate). --daemon ne garantit pas la socket prête
# au retour : attente bornée à 5 s.
swtpm socket --tpm2 --tpmstate dir="$ETAT/tpm" --ctrl type=unixio,path="$ETAT/tpm.sock" --pid file="$ETAT/swtpm.pid" --terminate --daemon
for _ in {1..50}; do [ -S "$ETAT/tpm.sock" ] && break; sleep 0.1; done
[ -S "$ETAT/tpm.sock" ] || { echo "vm.sh : la socket de swtpm n'apparaît pas." >&2; exit 1; }

args=(-enable-kvm -machine q35 -cpu host -smp 4 -m 4G
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF/OVMF_CODE.4m.fd"
  -drive "if=pflash,format=raw,file=$ETAT/vars.fd"
  -drive "file=$ETAT/disque.qcow2,if=virtio"
  -chardev "socket,id=chrtpm,path=$ETAT/tpm.sock" -tpmdev "emulator,id=tpm0,chardev=chrtpm"
  -device "tpm-tis,tpmdev=tpm0"
  -device virtio-vga-gl -display "gtk,gl=on"
  -nic "user,model=virtio-net-pci")
[ $# -eq 0 ] || args+=(-cdrom "$1")
exec qemu-system-x86_64 "${args[@]}"
