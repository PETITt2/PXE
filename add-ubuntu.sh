#!/usr/bin/env bash
# add-ubuntu.sh - Ajoute une installation Ubuntu AUTOMATISEE (autoinstall) au menu.
#
# ALTERNATIVE a Clonezilla. A n'utiliser que dans les conditions favorables :
#   - live-server : OK meme sur 4 Go (installe en console).
#   - desktop     : necessite >= 8 Go de RAM en methode "ram" (ISO chargee en RAM).
# Voir docs/AUTOINSTALL.md.
#
# Reglages dans config.sh : UBUNTU_FLAVOR, UBUNTU_BOOT_METHOD, UBUNTU_VERSION.
# Usage : sudo ./add-ubuntu.sh

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

ISO_NAME="ubuntu-${UBUNTU_VERSION}-${UBUNTU_FLAVOR}-amd64.iso"
ISO_URL="${UBUNTU_MIRROR}/${ISO_NAME}"
ISO_PATH="${WWW_ROOT}/iso/${ISO_NAME}"
NFS_ROOT="/srv/nfs/ubuntu"
AI_DIR="${WWW_ROOT}/autoinstall-ubuntu"

c_info "Ubuntu ${UBUNTU_VERSION} ${UBUNTU_FLAVOR} - methode : ${UBUNTU_BOOT_METHOD}"
[ "${UBUNTU_FLAVOR}" = "desktop" ] && [ "${UBUNTU_BOOT_METHOD}" = "ram" ] && \
  c_warn "Desktop en RAM : les postes doivent avoir >= 8 Go de RAM."

mkdir -p "${WWW_ROOT}/iso" "${TFTP_ROOT}/ubuntu" "${AI_DIR}"

# 1. ISO
if [ -f "${ISO_PATH}" ] && check_iso "${ISO_PATH}"; then
  c_info "ISO deja presente."
else
  robust_download "${ISO_URL}" "${ISO_PATH}" || {
    c_err "Telechargement impossible. Depose l'ISO a la main : ${ISO_PATH}"; exit 1; }
  check_iso "${ISO_PATH}" || { c_err "ISO invalide."; exit 1; }
fi
chown www-data:www-data "${ISO_PATH}"

# 2. Kernel + initrd
mkdir -p /mnt/ubuntu-iso
mount -o loop,ro "${ISO_PATH}" /mnt/ubuntu-iso
cp /mnt/ubuntu-iso/casper/vmlinuz "${TFTP_ROOT}/ubuntu/vmlinuz"
cp /mnt/ubuntu-iso/casper/initrd  "${TFTP_ROOT}/ubuntu/initrd"

# 3. NFS si demande
if [ "${UBUNTU_BOOT_METHOD}" = "nfs" ]; then
  command -v exportfs >/dev/null 2>&1 || apt-get install -y -qq nfs-kernel-server
  c_info "Copie de l'ISO vers ${NFS_ROOT}..."
  mkdir -p "${NFS_ROOT}"
  rsync -a /mnt/ubuntu-iso/ "${NFS_ROOT}/"
  sed -i "\|^${NFS_ROOT} |d" /etc/exports 2>/dev/null || true
  echo "${NFS_ROOT} ${SUBNET}(ro,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
  exportfs -ra; systemctl restart nfs-kernel-server
  systemctl enable nfs-kernel-server >/dev/null 2>&1 || true
  if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw allow 2049/tcp >/dev/null; ufw allow 111/tcp >/dev/null; ufw allow 111/udp >/dev/null; ufw reload >/dev/null
  fi
fi
umount /mnt/ubuntu-iso
c_ok "Kernel/initrd extraits."

# 4. Autoinstall (user-data + meta-data)
HASH=$(pw_hash "${AI_PASSWORD}")
render_template "${REPO_ROOT}/autoinstall/user-data.template" "${AI_DIR}/user-data" \
  "__HOSTNAME__" "${AI_HOSTNAME}" \
  "__USERNAME__" "${AI_USERNAME}" \
  "__PWHASH__"   "${HASH}" \
  "__LOCALE__"   "${AI_LOCALE}" \
  "__KEYBOARD__" "${AI_KEYBOARD}" \
  "__TIMEZONE__" "${AI_TIMEZONE}"
echo "instance-id: ${AI_HOSTNAME}" > "${AI_DIR}/meta-data"
chown -R www-data:www-data "${AI_DIR}"
python3 -c "import yaml; yaml.safe_load(open('${AI_DIR}/user-data'))" 2>/dev/null \
  && c_ok "Autoinstall ecrit (user: ${AI_USERNAME})." \
  || { c_err "YAML user-data invalide."; exit 1; }

# 5. Entree de menu (priorite 40)
DS="autoinstall ds=\"nocloud-net;s=http://${SERVER_IP}/autoinstall-ubuntu/\""
DS_BIOS="autoinstall ds=nocloud-net;s=http://${SERVER_IP}/autoinstall-ubuntu/"
LABEL="Installation Ubuntu ${UBUNTU_VERSION} ${UBUNTU_FLAVOR} (AUTO)"

if [ "${UBUNTU_BOOT_METHOD}" = "ram" ]; then
  P="root=/dev/ram0 ramdisk_size=8388608 ip=dhcp cloud-config-url=/dev/null url=http://${SERVER_IP}/iso/${ISO_NAME} ${DS}"
  PB="root=/dev/ram0 ramdisk_size=8388608 ip=dhcp cloud-config-url=/dev/null url=http://${SERVER_IP}/iso/${ISO_NAME} ${DS_BIOS}"
else
  P="boot=casper netboot=nfs nfsroot=${SERVER_IP}:${NFS_ROOT} ip=dhcp network-config=disabled cloud-config-url=/dev/null ${DS}"
  PB="boot=casper netboot=nfs nfsroot=${SERVER_IP}:${NFS_ROOT} ip=dhcp network-config=disabled cloud-config-url=/dev/null ${DS_BIOS}"
fi

register_entry 40 "ubuntu" "${LABEL}" \
"   set gfxpayload=keep
   linux /ubuntu/vmlinuz ${P}
   initrd /ubuntu/initrd" \
"    KERNEL ubuntu/vmlinuz
    APPEND initrd=ubuntu/initrd ${PB}"

regenerate_menus
c_ok "Entree Ubuntu (autoinstall) ajoutee."
