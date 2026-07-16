#!/usr/bin/env bash
# setup-clonezilla-deploy.sh - Configure le deploiement AUTOMATIQUE d'une image.
# Exporte le depot d'images en NFS et ajoute une entree PXE qui restaure l'image
# indiquee sur le disque cible, sans intervention, puis redemarre.
#
# Prerequis : une image deja capturee dans IMAGE_DIR/IMAGE_NAME (voir docs/WORKFLOW.md).

set -e
source "$(dirname "$0")/lib/common.sh"
load_config
require_root

if [ ! -d "${IMAGE_DIR}/${IMAGE_NAME}" ]; then
  c_err "Image introuvable : ${IMAGE_DIR}/${IMAGE_NAME}"
  c_info "Images disponibles dans ${IMAGE_DIR} :"
  ls "${IMAGE_DIR}" 2>/dev/null || true
  c_info "Capture d'abord un poste modele (voir docs/WORKFLOW.md)."
  exit 1
fi
c_ok "Image trouvee : ${IMAGE_NAME} ($(du -sh "${IMAGE_DIR}/${IMAGE_NAME}" | cut -f1))"

for f in vmlinuz initrd.img filesystem.squashfs; do
  [ -f "${TFTP_ROOT}/clonezilla/${f}" ] || { c_err "Clonezilla manquant : ${f}. Lance add-clonezilla.sh."; exit 1; }
done

# Export NFS du depot d'images
export DEBIAN_FRONTEND=noninteractive
command -v exportfs >/dev/null 2>&1 || apt-get install -y -qq nfs-kernel-server
sed -i "\|^${IMAGE_DIR}|d" /etc/exports 2>/dev/null || true
echo "${IMAGE_DIR} ${SUBNET}(ro,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
exportfs -ra
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server >/dev/null 2>&1 || true
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 2049/tcp >/dev/null; ufw allow 111/tcp >/dev/null; ufw allow 111/udp >/dev/null
  ufw reload >/dev/null
fi
c_ok "Depot d'images exporte en NFS."

CZ_BASE="boot=live components noswap edd=on nomodeset nosplash vga=normal locales=fr_FR.UTF-8 keyboard-layouts=fr fetch=http://${SERVER_IP}/clonezilla/filesystem.squashfs"
CZ_HOME="ocs_repository=\"nfs://${SERVER_IP}${IMAGE_DIR}\""
CZ_RUN="ocs-sr -e1 auto -e2 -r -j2 -k1 -scr -p reboot restoredisk ${IMAGE_NAME} ${TARGET_DISK}"
DEPLOY="${CZ_HOME} ocs_live_run=\"${CZ_RUN}\" ocs_live_extra_param=\"\" ocs_live_batch=yes"

# Priorite 20 : deploiement (entre ShredOS=10 et capture=30)
register_entry 20 "deploy" "Deploiement ${IMAGE_NAME} (AUTOMATIQUE - efface le disque)" \
"   linux /clonezilla/vmlinuz ${CZ_BASE} ${DEPLOY}
   initrd /clonezilla/initrd.img" \
"    KERNEL clonezilla/vmlinuz
    APPEND initrd=clonezilla/initrd.img ${CZ_BASE} ${DEPLOY}"

regenerate_menus
systemctl restart nginx dnsmasq

echo
echo "--- Image ---";      du -sh "${IMAGE_DIR}/${IMAGE_NAME}"
echo "--- Export NFS ---"; exportfs -v | grep "${IMAGE_DIR}" || true
echo "--- Menus ---";      grep -c "restoredisk" "${TFTP_ROOT}/grub/grub.cfg" | xargs echo "Entree deploiement (1 attendu) :"
echo
c_ok "Deploiement configure."
echo "  Sur un poste : PXE boot -> 'Deploiement ${IMAGE_NAME} (AUTOMATIQUE)'"
c_warn "Cette entree efface le disque du poste sans confirmation."
c_warn "Verifie TARGET_DISK=${TARGET_DISK} (nvme0n1 ou sda selon le parc)."
