#!/usr/bin/env bash
# build-debian-mirror.sh - Construit un miroir Debian LOCAL complet (paquets +
# images d'installation), pour installer Debian par PXE 100% hors-ligne.
#
# A LANCER pendant que le SERVEUR a Internet. Ensuite, add-debian.sh en mode
# "local" utilise ce miroir, et les clients n'ont plus besoin d'Internet.
#
# Volumineux (~80-90 Go) et long (plusieurs heures). C'est le prix d'un
# installateur et de paquets parfaitement alignes (evite "aucun module trouve").
#
# Usage : sudo ./build-debian-mirror.sh

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

MIRROR_DIR="/srv/debian-mirror"
ARCH="amd64"

# Internet requis
if ! curl -s --max-time 15 -o /dev/null "http://${DEBIAN_MIRROR_HOST}/debian/dists/${DEBIAN_SUITE}/Release"; then
  c_err "Le serveur n'a pas acces a Internet. Cette etape l'exige (pas la prod)."
  exit 1
fi
c_ok "Acces Internet OK."

FREE_GB=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
c_info "Espace libre : ${FREE_GB} Go"
if [ "${FREE_GB}" -lt 100 ]; then
  c_warn "Moins de 100 Go libres. Le miroir complet peut ne pas tenir."
  c_warn "Ctrl+C pour annuler, sinon on continue dans 5 s..."
  sleep 5
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq debmirror debian-archive-keyring rsync

c_info "Construction du miroir (LONG)..."
mkdir -p "${MIRROR_DIR}"
# --di-dist / --di-arch : recupere AUSSI les images d'installation (netboot)
# -> installateur et udebs coherents avec les paquets du miroir.
debmirror "${MIRROR_DIR}" \
  --nosource \
  --host="${DEBIAN_MIRROR_HOST}" \
  --root="debian" \
  --method=http \
  --dist="${DEBIAN_SUITE}" \
  --section=main \
  --arch="${ARCH}" \
  --di-dist="${DEBIAN_SUITE}" \
  --di-arch="${ARCH}" \
  --rsync-extra=none \
  --ignore-missing-release \
  --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
  --progress

c_ok "Miroir construit dans ${MIRROR_DIR}."
echo "  Etape suivante : mettre DEBIAN_MIRROR_MODE=\"local\" dans config.sh,"
echo "  puis : sudo ./add-debian.sh"
