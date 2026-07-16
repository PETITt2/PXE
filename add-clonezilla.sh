#!/usr/bin/env bash
# add-clonezilla.sh - Met en place Clonezilla Live en PXE.
# Recupere le noyau, l'initrd et le squashfs de Clonezilla Live, les place dans
# le TFTP, sert le squashfs en HTTP, et ajoute une entree "capture/maintenance"
# au menu. Le deploiement automatique d'image se configure ensuite avec
# setup-clonezilla-deploy.sh.
#
# Si les trois fichiers sont deja presents dans TFTP_ROOT/clonezilla, le script
# saute le telechargement et se contente d'ajouter l'entree de menu.

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

CZ_DIR="${TFTP_ROOT}/clonezilla"
mkdir -p "${CZ_DIR}"

have_files(){
  [ -f "${CZ_DIR}/vmlinuz" ] && [ -f "${CZ_DIR}/initrd.img" ] && [ -f "${CZ_DIR}/filesystem.squashfs" ]
}

if have_files; then
  c_info "Fichiers Clonezilla deja presents, telechargement saute."
else
  if [ -z "${CLONEZILLA_ZIP_URL}" ]; then
    c_err "Fichiers Clonezilla absents et CLONEZILLA_ZIP_URL vide."
    c_err "Deux options :"
    c_err " 1) Renseigne CLONEZILLA_ZIP_URL dans config.sh (zip 'alternative' amd64)"
    c_err "    depuis https://clonezilla.org/downloads.php"
    c_err " 2) Place a la main vmlinuz, initrd.img et filesystem.squashfs dans :"
    c_err "    ${CZ_DIR}"
    exit 1
  fi
  c_info "Recuperation de Clonezilla Live..."
  robust_download "${CLONEZILLA_ZIP_URL}" /tmp/clonezilla.zip || exit 1
  TMPZ=$(mktemp -d)
  ( cd "${TMPZ}" && unzip -q /tmp/clonezilla.zip )
  V=$(find "${TMPZ}" -path "*live*" -name "vmlinuz" | head -n1)
  I=$(find "${TMPZ}" -path "*live*" -name "initrd.img" | head -n1)
  S=$(find "${TMPZ}" -path "*live*" -name "filesystem.squashfs" | head -n1)
  [ -n "$V" ] && [ -n "$I" ] && [ -n "$S" ] || { c_err "Fichiers live introuvables dans le zip."; exit 1; }
  cp "$V" "${CZ_DIR}/vmlinuz"
  cp "$I" "${CZ_DIR}/initrd.img"
  cp "$S" "${CZ_DIR}/filesystem.squashfs"
  rm -rf "${TMPZ}" /tmp/clonezilla.zip
  c_ok "Clonezilla Live en place."
fi

# Le squashfs doit etre servi en HTTP (fetch=)
ln -sf "${CZ_DIR}/filesystem.squashfs" "${WWW_ROOT}/clonezilla_filesystem.squashfs" 2>/dev/null || true
# On sert directement depuis /clonezilla via un lien
rm -f "${WWW_ROOT}/clonezilla"
ln -s "${CZ_DIR}" "${WWW_ROOT}/clonezilla"
grep -q "disable_symlinks off" /etc/nginx/nginx.conf || \
  sed -i '/http {/a \    disable_symlinks off;' /etc/nginx/nginx.conf
systemctl reload nginx 2>/dev/null || systemctl restart nginx

CZ_BASE="boot=live components noswap edd=on nomodeset nosplash vga=normal locales=fr_FR.UTF-8 keyboard-layouts=fr fetch=http://${SERVER_IP}/clonezilla/filesystem.squashfs"

# Priorite 30 : Clonezilla capture/maintenance (mode manuel)
register_entry 30 "clonezilla" "Clonezilla - Capture/maintenance (manuel)" \
"   linux /clonezilla/vmlinuz ${CZ_BASE} ocs_live_run=\"ocs-live-general\" ocs_live_extra_param=\"\" ocs_live_batch=no
   initrd /clonezilla/initrd.img" \
"    KERNEL clonezilla/vmlinuz
    APPEND initrd=clonezilla/initrd.img ${CZ_BASE} ocs_live_run=\"ocs-live-general\" ocs_live_extra_param=\"\" ocs_live_batch=no"

regenerate_menus
c_ok "Entree Clonezilla (capture/maintenance) ajoutee."
echo "  Pour configurer le deploiement automatique d'une image :"
echo "    sudo ./setup-clonezilla-deploy.sh"
