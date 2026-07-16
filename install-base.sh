#!/usr/bin/env bash
# install-base.sh - Infrastructure PXE de base.
# Installe et configure DHCP+TFTP (dnsmasq), HTTP (nginx), les fichiers de boot
# BIOS (pxelinux.0) et UEFI (grubx64.efi, boot direct sans shim), et un menu vide.
# A lancer en premier. Idempotent.
#
# UEFI : on sert grubx64.efi directement, pas le shim. Cela evite le bug
# "revocations.efi TFTP Error" du shim recent en boot reseau. Contrepartie :
# Secure Boot doit etre DESACTIVE sur les postes clients.

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

if ! ip link show "${IFACE}" >/dev/null 2>&1; then
  c_err "Interface '${IFACE}' inexistante. Disponibles :"
  ip -brief link show | awk '{print "       - "$1}'
  exit 1
fi
c_ok "Interface '${IFACE}' trouvee."

if [ "${CONFIGURE_STATIC_IP}" = "yes" ]; then
  c_info "Configuration IP statique ${SERVER_IP}..."
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
  c_ok "IP statique appliquee."
else
  c_warn "IP statique non geree (CONFIGURE_STATIC_IP=no). On suppose ${SERVER_IP} en place."
fi

c_info "Installation des paquets..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  dnsmasq syslinux-common pxelinux nginx wget curl file whois xz-utils \
  rsync openssl
c_ok "Paquets installes."

mkdir -p "${TFTP_ROOT}"/{pxelinux.cfg,grub,shredos,clonezilla}
mkdir -p "${WWW_ROOT}"
mkdir -p "${ENTRIES_DIR}"
c_ok "Arborescence prete."

# --- BIOS ---
c_info "Fichiers BIOS/PXELINUX..."
if [ -f /usr/lib/PXELINUX/pxelinux.0 ]; then
  cp /usr/lib/PXELINUX/pxelinux.0 "${TFTP_ROOT}/"
elif [ -f /usr/lib/syslinux/pxelinux.0 ]; then
  cp /usr/lib/syslinux/pxelinux.0 "${TFTP_ROOT}/"
else
  c_err "pxelinux.0 introuvable."; exit 1
fi
for m in ldlinux.c32 menu.c32 libutil.c32 libcom32.c32; do
  f=$(find /usr/lib/syslinux/modules/bios -name "$m" 2>/dev/null | head -n1 || true)
  [ -n "$f" ] && cp "$f" "${TFTP_ROOT}/" || c_warn "Module $m introuvable."
done
c_ok "Fichiers BIOS prets."

# --- UEFI (grub signe, boot direct) ---
c_info "Binaires UEFI (grub reseau signe)..."
TMP_EFI=$(mktemp -d)
( cd "${TMP_EFI}"
  apt-get download grub-efi-amd64-signed grub-common 2>/dev/null
  for deb in *.deb; do dpkg-deb -x "$deb" extracted; done )
GRUB=$(find "${TMP_EFI}/extracted" -name "grubnetx64.efi.signed" 2>/dev/null | head -n1)
[ -z "$GRUB" ] && { c_err "grubnetx64.efi.signed introuvable."; rm -rf "${TMP_EFI}"; exit 1; }
cp "$GRUB" "${TFTP_ROOT}/grubx64.efi"
FONT=$(find "${TMP_EFI}/extracted" -name "unicode.pf2" 2>/dev/null | head -n1)
[ -n "$FONT" ] && cp "$FONT" "${TFTP_ROOT}/unicode.pf2" || true
rm -rf "${TMP_EFI}"
c_ok "grubx64.efi pret (boot UEFI direct)."

# --- dnsmasq ---
c_info "Configuration dnsmasq..."
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.orig ]; then
  mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
fi
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
c_ok "dnsmasq configure."

chown -R root:root "${TFTP_ROOT}"
chmod -R 755 "${TFTP_ROOT}"
regenerate_menus

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 67/udp >/dev/null; ufw allow 69/udp >/dev/null; ufw allow 80/tcp >/dev/null
  ufw reload >/dev/null
  c_ok "Ports 67/udp, 69/udp, 80/tcp ouverts."
else
  c_info "ufw inactif - aucune regle ajoutee."
fi

systemctl enable --now nginx >/dev/null 2>&1 || true
systemctl restart nginx
systemctl enable dnsmasq >/dev/null 2>&1 || true
systemctl restart dnsmasq
c_ok "Services demarres."

echo
systemctl is-active --quiet dnsmasq && c_ok "dnsmasq actif" || c_err "dnsmasq INACTIF"
systemctl is-active --quiet nginx   && c_ok "nginx actif"   || c_err "nginx INACTIF"
[ -s "${TFTP_ROOT}/grubx64.efi" ] && c_ok "grubx64.efi present" || c_err "grubx64.efi MANQUANT"
[ -s "${TFTP_ROOT}/pxelinux.0" ]  && c_ok "pxelinux.0 present"  || c_err "pxelinux.0 MANQUANT"
echo
c_ok "Infrastructure de base prete."
echo "  Etapes suivantes :"
echo "    sudo ./add-shredos.sh"
echo "    sudo ./add-clonezilla.sh"
echo "    sudo ./setup-clonezilla-deploy.sh"
