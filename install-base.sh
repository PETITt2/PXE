#!/usr/bin/env bash
###############################################################################
#  install-base.sh
#  Installe et configure l'infrastructure PXE de base :
#    - paquets (dnsmasq, nginx, pxelinux, grub signé…)
#    - arborescence TFTP + HTTP
#    - fichiers de boot BIOS (pxelinux.0) et UEFI (grubx64.efi, boot DIRECT)
#    - DHCP + TFTP (dnsmasq) + HTTP (nginx)
#    - menus vides (les OS s'ajoutent ensuite via add-*.sh)
#
#  UEFI : on sert grubx64.efi directement (pas le shim) -> évite le bug
#         "revocations.efi TFTP Error". Secure Boot DOIT être désactivé côté client.
#
#  Usage : sudo ./install-base.sh
#  Idempotent.
###############################################################################
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

###############################################################################
# 1. Interface
###############################################################################
if ! ip link show "${IFACE}" &>/dev/null; then
  c_err "Interface '${IFACE}' inexistante. Disponibles :"
  ip -brief link show | awk '{print "       - "$1}'
  exit 1
fi
c_ok "Interface '${IFACE}' trouvée."

###############################################################################
# 2. IP statique (optionnel)
###############################################################################
if [[ "${CONFIGURE_STATIC_IP}" == "yes" ]]; then
  c_info "IP statique ${SERVER_IP}..."
  tee /etc/netplan/01-pxe-server.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses: [${SERVER_IP}/24]
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${DNS1}, ${DNS2}]
EOF
  chmod 600 /etc/netplan/01-pxe-server.yaml
  netplan apply
  c_ok "IP statique appliquée."
else
  c_warn "IP statique non gérée (voir CONFIGURE_STATIC_IP). On suppose ${SERVER_IP} en place."
fi

###############################################################################
# 3. Paquets
###############################################################################
c_info "Installation des paquets..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  dnsmasq syslinux-common pxelinux nginx wget curl file whois xz-utils \
  rsync python3-yaml openssl
c_ok "Paquets installés."

###############################################################################
# 4. Arborescence
###############################################################################
mkdir -p "${TFTP_ROOT}"/{pxelinux.cfg,grub,shredos,ubuntu,xubuntu}
mkdir -p "${WWW_ROOT}"/{iso,autoinstall}
mkdir -p "${ENTRIES_DIR}"
c_ok "Arborescence prête."

###############################################################################
# 5. Fichiers BIOS (PXELINUX)
###############################################################################
c_info "Fichiers BIOS/PXELINUX..."
if [[ -f /usr/lib/PXELINUX/pxelinux.0 ]]; then
  cp /usr/lib/PXELINUX/pxelinux.0 "${TFTP_ROOT}/"
elif [[ -f /usr/lib/syslinux/pxelinux.0 ]]; then
  cp /usr/lib/syslinux/pxelinux.0 "${TFTP_ROOT}/"
else
  c_err "pxelinux.0 introuvable."; exit 1
fi
for m in ldlinux.c32 menu.c32 libutil.c32 libcom32.c32; do
  f=$(find /usr/lib/syslinux/modules/bios -name "$m" 2>/dev/null | head -n1 || true)
  [[ -n "$f" ]] && cp "$f" "${TFTP_ROOT}/" || c_warn "Module $m introuvable."
done
c_ok "Fichiers BIOS prêts."

###############################################################################
# 6. Fichiers UEFI (grub signé, booté DIRECTEMENT sans shim)
###############################################################################
c_info "Binaires UEFI (grub réseau signé)..."
TMP_EFI=$(mktemp -d)
pushd "${TMP_EFI}" >/dev/null
apt-get download grub-efi-amd64-signed grub-common 2>/dev/null || {
  c_err "Téléchargement grub EFI impossible."; popd >/dev/null; exit 1; }
for deb in *.deb; do dpkg-deb -x "$deb" extracted; done
GRUB=$(find extracted -name "grubnetx64.efi.signed" 2>/dev/null | head -n1)
[[ -z "$GRUB" ]] && { c_err "grubnetx64.efi.signed introuvable."; popd >/dev/null; exit 1; }
cp "$GRUB" "${TFTP_ROOT}/grubx64.efi"
FONT=$(find extracted -name "unicode.pf2" 2>/dev/null | head -n1)
[[ -n "$FONT" ]] && cp "$FONT" "${TFTP_ROOT}/unicode.pf2" || true
popd >/dev/null; rm -rf "${TMP_EFI}"
c_ok "grubx64.efi prêt (boot UEFI direct)."

###############################################################################
# 7. dnsmasq (DHCP + TFTP)
###############################################################################
c_info "Configuration dnsmasq..."
[[ -f /etc/dnsmasq.conf && ! -f /etc/dnsmasq.conf.orig ]] && \
  mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
cat > /etc/dnsmasq.conf <<EOF
interface=${IFACE}
bind-interfaces
port=0

dhcp-range=${DHCP_START},${DHCP_END},${NETMASK},${DHCP_LEASE}
dhcp-option=3,${GATEWAY}
dhcp-option=6,${DNS1},${DNS2}

# BIOS -> pxelinux.0 ; UEFI x86-64 -> grubx64.efi (boot direct, Secure Boot OFF)
dhcp-boot=pxelinux.0
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,grubx64.efi

enable-tftp
tftp-root=${TFTP_ROOT}
log-dhcp
EOF
c_ok "dnsmasq configuré."

###############################################################################
# 8. Permissions + menus vides
###############################################################################
chown -R root:root "${TFTP_ROOT}"
chmod -R 755 "${TFTP_ROOT}"
chown -R www-data:www-data "${WWW_ROOT}/iso" "${WWW_ROOT}/autoinstall"
regenerate_menus   # menus avec seulement "Boot disque local" pour l'instant

###############################################################################
# 9. Pare-feu
###############################################################################
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 67/udp >/dev/null; ufw allow 69/udp >/dev/null; ufw allow 80/tcp >/dev/null
  ufw reload >/dev/null
  c_ok "Ports 67/udp, 69/udp, 80/tcp ouverts."
else
  c_info "ufw inactif — aucune règle ajoutée."
fi

###############################################################################
# 10. Services
###############################################################################
systemctl enable --now nginx >/dev/null 2>&1 || true
systemctl restart nginx
systemctl enable dnsmasq >/dev/null 2>&1 || true
systemctl restart dnsmasq
c_ok "Services démarrés."

###############################################################################
# 11. Vérifs
###############################################################################
echo
systemctl is-active --quiet dnsmasq && c_ok "dnsmasq actif" || c_err "dnsmasq INACTIF"
systemctl is-active --quiet nginx   && c_ok "nginx actif"   || c_err "nginx INACTIF"
[[ -s "${TFTP_ROOT}/grubx64.efi" ]] && c_ok "grubx64.efi présent" || c_err "grubx64.efi MANQUANT"
[[ -s "${TFTP_ROOT}/pxelinux.0" ]]  && c_ok "pxelinux.0 présent"  || c_err "pxelinux.0 MANQUANT"
echo
c_ok "Infrastructure de base prête."
echo "  Étape suivante : ajouter des OS avec"
echo "    sudo ./add-shredos.sh"
echo "    sudo ./add-ubuntu.sh"
echo "    sudo ./add-xubuntu.sh"
