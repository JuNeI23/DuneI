#!/usr/bin/env bash
# vm.sh — machine virtuelle de recette de DuneI : QEMU/KVM, UEFI (OVMF) et TPM2 (swtpm).
# Rôle : prouver la procédure d'installation sans toucher à la machine ; réutilisée par la feature de chiffrement.
# Entrées : un argument facultatif, l'ISO Arch à démarrer ; sans argument, la machine redémarre sur son disque.
#   $XDG_CACHE_HOME (sinon ~/.cache) situe le dossier d'état dunei-vm/.
# Sortie : la fenêtre de la machine ; dans le dossier d'état, disque.qcow2 (40 Go, créé au premier lancement),
#   vars.fd (copie des variables OVMF), tpm/ (état de swtpm) et tpm.sock. Rien n'entre dans le dépôt.
# Erreurs : code 1 et message nommant le paquet à installer si KVM, QEMU, swtpm ou OVMF manque, avant toute création.
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

exige "qemu-desktop" command -v qemu-system-x86_64 >/dev/null
exige "qemu-desktop" command -v qemu-img >/dev/null
exige "swtpm" command -v swtpm >/dev/null
exige "edk2-ovmf" test -r "$OVMF/OVMF_CODE.4m.fd" -a -r "$OVMF/OVMF_VARS.4m.fd"
[ -r /dev/kvm ] && [ -w /dev/kvm ] || { echo "vm.sh : /dev/kvm inaccessible (virtualisation absente ou utilisateur hors du groupe kvm)." >&2; exit 1; }

mkdir -p "$ETAT/tpm"
[ -e "$ETAT/disque.qcow2" ] || qemu-img create -f qcow2 "$ETAT/disque.qcow2" 40G >/dev/null
[ -e "$ETAT/vars.fd" ] || cp "$OVMF/OVMF_VARS.4m.fd" "$ETAT/vars.fd"

# Le TPM vit tant que QEMU tourne : swtpm s'arrête à la fermeture de la socket.
swtpm socket --tpm2 --tpmstate dir="$ETAT/tpm" --ctrl type=unixio,path="$ETAT/tpm.sock" --terminate --daemon

args=(-enable-kvm -machine q35 -cpu host -smp 4 -m 4G
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF/OVMF_CODE.4m.fd"
  -drive "if=pflash,format=raw,file=$ETAT/vars.fd"
  -drive "file=$ETAT/disque.qcow2,if=virtio"
  -chardev "socket,id=chrtpm,path=$ETAT/tpm.sock" -tpmdev "emulator,id=tpm0,chardev=chrtpm"
  -device "tpm-tis,tpmdev=tpm0"
  -device virtio-vga-gl -display "gtk,gl=on"
  -nic "user,model=virtio-net-pci")
[ $# -eq 0 ] || args+=(-cdrom "$1" -boot d)
exec qemu-system-x86_64 "${args[@]}"
