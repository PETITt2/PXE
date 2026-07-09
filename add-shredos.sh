#!/usr/bin/env bash
###############################################################################
#  add-shredos.sh
#  Télécharge la dernière release ShredOS, extrait le noyau (bzImage),
#  et ajoute l'entrée au menu PXE (BIOS + UEFI).
#
#  Usage : sudo ./add-shredos.sh
###############################################################################
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

###############################################################################
# 1. Trouver la dernière ISO ShredOS
###############################################################################
c_info "Recherche de la dernière release ShredOS..."
SHREDOS_URL=$(curl -s "https://api.github.com/repos/${SHREDOS_REPO}/releases/latest" \
  | grep "browser_download_url" | grep "x86-64" | grep '\.iso"' \
  | grep -v "lite" | grep -v "plus-partition" | cut -d '"' -f4 | head -n1)
if [[ -z "${SHREDOS_URL}" ]]; then
  c_err "URL ShredOS non trouvée (rate-limit GitHub ?)."
  c_err "Récupère l'ISO sur https://github.com/${SHREDOS_REPO}/releases/latest"
  c_err "et renseigne SHREDOS_URL en dur dans ce script."
  exit 1
fi
c_info "ShredOS : ${SHREDOS_URL}"

###############################################################################
# 2. Télécharger + extraire bzImage
###############################################################################
robust_download "${SHREDOS_URL}" /tmp/shredos.iso || exit 1
check_iso /tmp/shredos.iso || { c_err "ISO ShredOS invalide."; exit 1; }

mkdir -p /mnt/shredos "${TFTP_ROOT}/shredos"
mount -o loop,ro /tmp/shredos.iso /mnt/shredos
BZ=$(find /mnt/shredos -name "bzImage" 2>/dev/null | head -n1)
[[ -n "$BZ" ]] && cp "$BZ" "${TFTP_ROOT}/shredos/bzImage" \
  || { c_err "bzImage introuvable."; umount /mnt/shredos; exit 1; }
umount /mnt/shredos; rm -f /tmp/shredos.iso
c_ok "ShredOS installé ($(du -h "${TFTP_ROOT}/shredos/bzImage" | cut -f1))."

###############################################################################
# 3. Enregistrer l'entrée de menu
###############################################################################
if [[ "${SHREDOS_AUTONUKE}" == "yes" ]]; then
  APPEND="console=tty3 loglevel=3 nwipe_options=\"${SHREDOS_NUKE_OPTS}\""
  c_warn "AUTONUKE activé : ShredOS effacera SANS confirmation !"
else
  APPEND="console=tty3 loglevel=3"
fi

register_entry "shredos" "ShredOS - Effacement securise (nwipe)" \
"   linux /shredos/bzImage ${APPEND}" \
"    KERNEL shredos/bzImage
    APPEND ${APPEND}"

regenerate_menus
c_ok "Entrée ShredOS ajoutée au menu PXE."
