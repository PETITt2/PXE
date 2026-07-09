#!/usr/bin/env bash
###############################################################################
#  add-xubuntu.sh
#  Télécharge une ISO Xubuntu (XFCE, léger), configure l'autoinstall
#  (supporté depuis 24.04 via Subiquity), et ajoute l'entrée au menu PXE.
#
#  Réglages dans config.sh :
#    XUBUNTU_EDITION      minimal | ""  (vide = édition standard)
#    XUBUNTU_BOOT_METHOD  ram | nfs
#
#  Usage : sudo ./add-xubuntu.sh
###############################################################################
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

if [[ -n "${XUBUNTU_EDITION}" ]]; then
  ISO_NAME="xubuntu-${XUBUNTU_VERSION}-${XUBUNTU_EDITION}-amd64.iso"
else
  ISO_NAME="xubuntu-${XUBUNTU_VERSION}-desktop-amd64.iso"
fi
ISO_URL="${XUBUNTU_MIRROR}/${ISO_NAME}"
ISO_PATH="${WWW_ROOT}/iso/${ISO_NAME}"
NFS_ROOT="${NFS_ROOT_BASE}/xubuntu"
HOSTNAME="xubuntu"

c_info "Xubuntu ${XUBUNTU_VERSION} ${XUBUNTU_EDITION:-desktop} — méthode : ${XUBUNTU_BOOT_METHOD}"

###############################################################################
# 1. Récupérer l'ISO
###############################################################################
mkdir -p "${WWW_ROOT}/iso" "${TFTP_ROOT}/xubuntu"
if [[ -f "${ISO_PATH}" ]] && check_iso "${ISO_PATH}"; then
  c_info "ISO déjà présente : ${ISO_PATH}"
else
  robust_download "${ISO_URL}" "${ISO_PATH}" || {
    c_err "Téléchargement impossible. Si pas d'accès Internet, dépose l'ISO à la main :"
    c_err "  ${ISO_PATH}"
    exit 1; }
  check_iso "${ISO_PATH}" || { c_err "ISO invalide."; exit 1; }
fi
chown www-data:www-data "${ISO_PATH}"

###############################################################################
# 2. Extraire kernel + initrd
###############################################################################
mkdir -p /mnt/xubuntu-iso
mount -o loop,ro "${ISO_PATH}" /mnt/xubuntu-iso
cp /mnt/xubuntu-iso/casper/vmlinuz "${TFTP_ROOT}/xubuntu/vmlinuz"
cp /mnt/xubuntu-iso/casper/initrd  "${TFTP_ROOT}/xubuntu/initrd"

###############################################################################
# 3. NFS si demandé
###############################################################################
if [[ "${XUBUNTU_BOOT_METHOD}" == "nfs" ]]; then
  command -v exportfs >/dev/null || apt-get install -y -qq nfs-kernel-server
  c_info "Copie de l'ISO vers le partage NFS ${NFS_ROOT}..."
  mkdir -p "${NFS_ROOT}"
  rsync -a --info=progress2 /mnt/xubuntu-iso/ "${NFS_ROOT}/"
  sed -i "\|^${NFS_ROOT} |d" /etc/exports 2>/dev/null || true
  echo "${NFS_ROOT} ${SUBNET}(ro,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
  exportfs -ra
  systemctl restart nfs-kernel-server
  systemctl enable nfs-kernel-server >/dev/null 2>&1 || true
  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 2049/tcp >/dev/null; ufw allow 111/tcp >/dev/null; ufw allow 111/udp >/dev/null
    ufw reload >/dev/null
  fi
  c_ok "Partage NFS Xubuntu prêt."
fi
umount /mnt/xubuntu-iso
c_ok "Kernel/initrd extraits."

###############################################################################
# 4. Autoinstall
###############################################################################
write_autoinstall "${HOSTNAME}"

###############################################################################
# 5. Entrée de menu
###############################################################################
DS="autoinstall ds=\"nocloud-net;s=http://${SERVER_IP}/autoinstall/\""
DS_BIOS="autoinstall ds=nocloud-net;s=http://${SERVER_IP}/autoinstall/"
LABEL="Installation Xubuntu ${XUBUNTU_VERSION} (${XUBUNTU_EDITION:-desktop}, AUTO)"

if [[ "${XUBUNTU_BOOT_METHOD}" == "ram" ]]; then
  COMMON="root=/dev/ram0 ramdisk_size=8388608 ip=dhcp cloud-config-url=/dev/null url=http://${SERVER_IP}/iso/${ISO_NAME} ${DS}"
  COMMON_BIOS="root=/dev/ram0 ramdisk_size=8388608 ip=dhcp cloud-config-url=/dev/null url=http://${SERVER_IP}/iso/${ISO_NAME} ${DS_BIOS}"
else
  COMMON="boot=casper netboot=nfs nfsroot=${SERVER_IP}:${NFS_ROOT} ip=dhcp network-config=disabled cloud-config-url=/dev/null ${DS}"
  COMMON_BIOS="boot=casper netboot=nfs nfsroot=${SERVER_IP}:${NFS_ROOT} ip=dhcp network-config=disabled cloud-config-url=/dev/null ${DS_BIOS}"
fi

register_entry "xubuntu-auto" "${LABEL}" \
"   set gfxpayload=keep
   linux /xubuntu/vmlinuz ${COMMON}
   initrd /xubuntu/initrd" \
"    KERNEL xubuntu/vmlinuz
    APPEND initrd=xubuntu/initrd ${COMMON_BIOS}"

regenerate_menus
c_ok "Entrée Xubuntu ajoutée."
[[ "${XUBUNTU_BOOT_METHOD}" == "ram" ]] && \
  c_warn "Méthode RAM : les postes clients doivent avoir >= 8 Go de RAM."
