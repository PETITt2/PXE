#!/usr/bin/env bash
###############################################################################
#  deploy-xubuntu-shredos.sh
#  Déploiement complet "clé en main" : infra de base + ShredOS + Xubuntu.
#  C'est le scénario type pour du reconditionnement de postes légers :
#    - ShredOS pour effacer les disques (RGPD / réforme matériel)
#    - Xubuntu (XFCE) pour réinstaller un OS léger automatiquement
#
#  Équivaut à lancer, dans l'ordre :
#    ./install-base.sh  &&  ./add-shredos.sh  &&  ./add-xubuntu.sh
#
#  Usage : sudo ./deploy-xubuntu-shredos.sh
###############################################################################
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/lib/common.sh"
load_config
require_root

c_info "=== Déploiement Xubuntu + ShredOS ==="

c_info "[1/3] Infrastructure PXE de base..."
bash "${HERE}/install-base.sh"

c_info "[2/3] Ajout de ShredOS..."
bash "${HERE}/add-shredos.sh"

c_info "[3/3] Ajout de Xubuntu..."
bash "${HERE}/add-xubuntu.sh"

echo
c_ok "=== Déploiement terminé ==="
echo
echo "  Menu PXE disponible (BIOS + UEFI) :"
echo "    - ShredOS  : effacement securise des disques"
echo "    - Xubuntu  : reinstallation automatique (XFCE leger)"
echo "    - Boot disque local"
echo
c_warn "CÔTÉ CLIENT : Secure Boot désactivé + boot réseau IPv4."
echo "  Suivi DHCP en direct :  journalctl -u dnsmasq -f"
