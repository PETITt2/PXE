#!/usr/bin/env bash
###############################################################################
#  add-ubuntu.sh
#  Télécharge une ISO Ubuntu (Desktop ou Server), configure l'autoinstall,
#  et ajoute l'entrée au menu PXE selon la méthode de boot choisie.
#
#  Réglages dans config.sh :
#    UBUNTU_FLAVOR       desktop | live-server
#    UBUNTU_BOOT_METHOD  ram | nfs
#
#  Usage : sudo ./add-ubuntu.sh
###############################################################################
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

ISO_NAME="ubuntu-${UBUNTU_VERSION}-${UBUNTU_FLAVOR}-amd64.iso"
ISO_URL="${UBUNTU_MIRROR}/${ISO_NAME}"
ISO_PATH="${WWW_ROOT}/iso/${ISO_NAME}"
NFS_ROOT="${NFS_ROOT_BASE}/ubuntu"
HOSTNAME="ubuntu"

c_info "Ubuntu ${UBUNTU_VERSION} ${UBUNTU_FLAVOR} — méthode : ${UBUNTU_BOOT_METHOD}"

###############################################################################
# 1. Récupérer l'ISO (si absente) + vérifier
###############################################################################
mkdir -p "${WWW_ROOT}/iso" "${TFTP_ROOT}/ubuntu"
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
mkdir -p /mnt/ubuntu-iso
mount -o loop,ro "${ISO_PATH}" /mnt/ubuntu-iso
cp /mnt/ubuntu-iso/casper/vmlinuz "${TFTP_ROOT}/ubuntu/vmlinuz"
cp /mnt/ubuntu-iso/casper/initrd  "${TFTP_ROOT}/ubuntu/initrd"

###############################################################################
# 3. Si NFS : peupler le partage + exporter
###############################################################################
if [[ "${UBUNTU_BOOT_METHOD}" == "nfs" ]]; then
  command -v exportfs >/dev/null || apt-get install -y -qq nfs-kernel-server
  c_info "Copie de l'ISO vers le partage NFS ${NFS_ROOT}..."
  mkdir -p "${NFS_ROOT}"
  rsync -a --info=progress2 /mnt/ubuntu-iso/ "${NFS_ROOT}/"
  sed -i "\|^${NFS_ROOT} |d" /etc/exports 2>/dev/null || true
  echo "${NFS_ROOT} ${SUBNET}(ro,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
  exportfs -ra
  systemctl restart nfs-kernel-server
  systemctl enable nfs-kernel-server >/dev/null 2>&1 || true
  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 2049/tcp >/dev/null; ufw allow 111/tcp >/dev/null; ufw allow 111/udp >/dev/null
    ufw reload >/dev/null
  fi
  c_ok "Partage NFS Ubuntu prêt."
fi
umount /mnt/ubuntu-iso
c_ok "Kernel/initrd extraits."

###############################################################################
# 4. Autoinstall
###############################################################################
write_autoinstall "${HOSTNAME}"

###############################################################################
# 5. Entrée de menu selon la méthode
###############################################################################
DS="autoinstall ds=\"nocloud-net;s=http://${SERVER_IP}/autoinstall/\""
DS_BIOS="autoinstall ds=nocloud-net;s=http://${SERVER_IP}/autoinstall/"
LABEL="Installation Ubuntu ${UBUNTU_VERSION} (${UBUNTU_FLAVOR}, AUTO)"

if [[ "${UBUNTU_BOOT_METHOD}" == "ram" ]]; then
  COMMON="root=/dev/ram0 ramdisk_size=8388608 ip=dhcp cloud-config-url=/dev/null url=http://${SERVER_IP}/iso/${ISO_NAME} ${DS}"
  COMMON_BIOS="root=/dev/ram0 ramdisk_size=8388608 ip=dhcp cloud-config-url=/dev/null url=http://${SERVER_IP}/iso/${ISO_NAME} ${DS_BIOS}"
else
  COMMON="boot=casper netboot=nfs nfsroot=${SERVER_IP}:${NFS_ROOT} ip=dhcp network-config=disabled cloud-config-url=/dev/null ${DS}"
  COMMON_BIOS="boot=casper netboot=nfs nfsroot=${SERVER_IP}:${NFS_ROOT} ip=dhcp network-config=disabled cloud-config-url=/dev/null ${DS_BIOS}"
fi

register_entry "ubuntu-auto" "${LABEL}" \
"   set gfxpayload=keep
   linux /ubuntu/vmlinuz ${COMMON}
   initrd /ubuntu/initrd" \
"    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd ${COMMON_BIOS}"

regenerate_menus
c_ok "Entrée Ubuntu ajoutée."
[[ "${UBUNTU_BOOT_METHOD}" == "ram" ]] && \
  c_warn "Méthode RAM : les postes clients doivent avoir >= 8 Go de RAM."
