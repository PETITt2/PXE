#!/usr/bin/env bash
# add-shredos.sh - Telecharge ShredOS et l'ajoute au menu PXE.
# ShredOS sert a effacer les disques de facon securisee (nwipe) avant
# reconditionnement ou reforme du materiel.

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

c_info "Recherche de la derniere release ShredOS..."
SHREDOS_URL=$(curl -s "https://api.github.com/repos/${SHREDOS_REPO}/releases/latest" \
  | grep "browser_download_url" | grep "x86-64" | grep '\.iso"' \
  | grep -v "lite" | grep -v "plus-partition" | cut -d '"' -f4 | head -n1)
if [ -z "${SHREDOS_URL}" ]; then
  c_err "URL ShredOS non trouvee (rate-limit GitHub ?)."
  c_err "Recupere l'ISO sur https://github.com/${SHREDOS_REPO}/releases/latest"
  c_err "et renseigne SHREDOS_URL en dur dans ce script."
  exit 1
fi
c_info "ShredOS : ${SHREDOS_URL}"

robust_download "${SHREDOS_URL}" /tmp/shredos.iso || exit 1
file /tmp/shredos.iso | grep -qi "ISO 9660" || { c_err "ISO ShredOS invalide."; exit 1; }

mkdir -p /mnt/shredos "${TFTP_ROOT}/shredos"
mount -o loop,ro /tmp/shredos.iso /mnt/shredos
BZ=$(find /mnt/shredos -name "bzImage" 2>/dev/null | head -n1)
if [ -n "$BZ" ]; then
  cp "$BZ" "${TFTP_ROOT}/shredos/bzImage"
else
  c_err "bzImage introuvable dans l'ISO."; umount /mnt/shredos; exit 1
fi
umount /mnt/shredos; rm -f /tmp/shredos.iso
c_ok "ShredOS installe ($(du -h "${TFTP_ROOT}/shredos/bzImage" | cut -f1))."

# Priorite 10 : ShredOS en tete de menu
register_entry 10 "shredos" "ShredOS - Effacement securise (nwipe)" \
"   linux /shredos/bzImage console=tty3 loglevel=3" \
"    KERNEL shredos/bzImage
    APPEND console=tty3 loglevel=3"

regenerate_menus
c_ok "Entree ShredOS ajoutee."
