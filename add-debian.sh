#!/usr/bin/env bash
# add-debian.sh - Ajoute une installation Debian AUTOMATISEE (preseed) au menu.
#
# ALTERNATIVE a Clonezilla. Installateur Debian en mode texte (pas d'ecran noir).
# Conditions selon DEBIAN_MIRROR_MODE (config.sh) :
#   "online" : les CLIENTS ont besoin d'un acces Internet pendant l'install
#              (paquets tires d'un miroir Debian public).
#   "local"  : necessite un miroir local complet construit AU PREALABLE avec
#              build-debian-mirror.sh (installe entierement hors-ligne).
# Voir docs/AUTOINSTALL.md.
#
# Usage : sudo ./add-debian.sh

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

AI_DIR="${WWW_ROOT}"      # preseed.cfg servi a la racine web
MIRROR_LOCAL_DIR="/srv/debian-mirror"

# --- Determiner la source des paquets + du netboot selon le mode ---
if [ "${DEBIAN_MIRROR_MODE}" = "local" ]; then
  c_info "Mode LOCAL : miroir ${MIRROR_LOCAL_DIR} (hors-ligne)."
  if [ ! -d "${MIRROR_LOCAL_DIR}/dists/${DEBIAN_SUITE}" ]; then
    c_err "Miroir local absent. Lance d'abord : sudo ./build-debian-mirror.sh"
    exit 1
  fi
  M_HOST="${SERVER_IP}"
  M_DIR="/debian-mirror"
  # netboot pris DANS le miroir local -> aligne avec les paquets
  NB="${MIRROR_LOCAL_DIR}/dists/${DEBIAN_SUITE}/main/installer-amd64/current/images/netboot/debian-installer/amd64"
  if [ ! -f "${NB}/linux" ]; then
    c_err "Images netboot absentes du miroir local (${NB})."
    c_err "Reconstruis le miroir avec les images d'installation (build-debian-mirror.sh)."
    exit 1
  fi
  mkdir -p "${TFTP_ROOT}/debian"
  cp "${NB}/linux"     "${TFTP_ROOT}/debian/linux"
  cp "${NB}/initrd.gz" "${TFTP_ROOT}/debian/initrd.gz"
  # publier le miroir en HTTP
  rm -f "${WWW_ROOT}/debian-mirror"
  ln -s "${MIRROR_LOCAL_DIR}" "${WWW_ROOT}/debian-mirror"
  grep -q "disable_symlinks off" /etc/nginx/nginx.conf || \
    sed -i '/http {/a \    disable_symlinks off;' /etc/nginx/nginx.conf
  systemctl reload nginx 2>/dev/null || systemctl restart nginx
else
  c_info "Mode ONLINE : miroir public ${DEBIAN_MIRROR_HOST} (Internet requis cote client)."
  M_HOST="${DEBIAN_MIRROR_HOST}"
  M_DIR="/debian"
  # netboot officiel (meme suite que le miroir online)
  mkdir -p "${TFTP_ROOT}/debian"
  if [ ! -f "${TFTP_ROOT}/debian/linux" ] || [ ! -f "${TFTP_ROOT}/debian/initrd.gz" ]; then
    c_info "Telechargement du netboot Debian (${DEBIAN_SUITE})..."
    robust_download \
      "http://${DEBIAN_MIRROR_HOST}/debian/dists/${DEBIAN_SUITE}/main/installer-amd64/current/images/netboot/netboot.tar.gz" \
      /tmp/netboot.tar.gz || exit 1
    tar -xzf /tmp/netboot.tar.gz -C /tmp
    cp /tmp/debian-installer/amd64/linux     "${TFTP_ROOT}/debian/linux"
    cp /tmp/debian-installer/amd64/initrd.gz "${TFTP_ROOT}/debian/initrd.gz"
    rm -f /tmp/netboot.tar.gz
  fi
fi
c_ok "Installateur Debian en place."

# --- preseed ---
HASH=$(pw_hash "${AI_PASSWORD}")
render_template "${REPO_ROOT}/autoinstall/preseed.cfg.template" "${AI_DIR}/preseed.cfg" \
  "__HOSTNAME__"    "${AI_HOSTNAME}" \
  "__FULLNAME__"    "Utilisateur" \
  "__USERNAME__"    "${AI_USERNAME}" \
  "__PWHASH__"      "${HASH}" \
  "__LOCALE__"      "${AI_LOCALE}" \
  "__KEYBOARD__"    "${AI_KEYBOARD}" \
  "__TIMEZONE__"    "${AI_TIMEZONE}" \
  "__MIRROR_HOST__" "${M_HOST}" \
  "__MIRROR_DIR__"  "${M_DIR}" \
  "__SUITE__"       "${DEBIAN_SUITE}" \
  "__TASKS__"       "${DEBIAN_TASKS}"
chown www-data:www-data "${AI_DIR}/preseed.cfg"
c_ok "preseed.cfg ecrit (user: ${AI_USERNAME})."

# --- Entree de menu (priorite 50), installateur en mode texte ---
DI="auto=true priority=critical url=http://${SERVER_IP}/preseed.cfg interface=auto hostname=${AI_HOSTNAME} domain=local vga=normal fb=false nomodeset DEBIAN_FRONTEND=text ---"
LABEL="Installation Debian ${DEBIAN_SUITE} (AUTO, mode texte)"

register_entry 50 "debian" "${LABEL}" \
"   linux /debian/linux ${DI}
   initrd /debian/initrd.gz" \
"    KERNEL debian/linux
    APPEND initrd=debian/initrd.gz ${DI}"

regenerate_menus
c_ok "Entree Debian (preseed) ajoutee."
[ "${DEBIAN_MIRROR_MODE}" = "online" ] && \
  c_warn "Mode online : les postes doivent avoir Internet pendant l'installation."
