#!/usr/bin/env bash
###############################################################################
#  lib/common.sh — Fonctions partagées. Sourcé par tous les scripts.
###############################################################################

# --- Affichage coloré ---
c_ok(){   echo -e "\e[32m[ OK ]\e[0m $*"; }
c_info(){ echo -e "\e[36m[INFO]\e[0m $*"; }
c_warn(){ echo -e "\e[33m[WARN]\e[0m $*"; }
c_err(){  echo -e "\e[31m[ERR ]\e[0m $*" >&2; }

# --- Vérifie qu'on est root ---
require_root(){
  if [[ $EUID -ne 0 ]]; then
    c_err "Ce script doit être lancé en root (sudo)."; exit 1
  fi
}

# --- Charge config.sh, quel que soit le dossier d'appel ---
load_config(){
  local here; here="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  # scripts à la racine du repo, ou dans scripts/
  for base in "${here}" "${here}/.." ; do
    if [[ -f "${base}/config.sh" ]]; then
      # shellcheck disable=SC1091
      source "${base}/config.sh"
      REPO_ROOT="$(cd "${base}" && pwd)"
      return 0
    fi
  done
  c_err "config.sh introuvable."; exit 1
}

# --- Télécharge une URL vers un fichier, avec reprise + tentatives ---
# usage : robust_download <url> <dest> [max_tries]
robust_download(){
  local url="$1" dest="$2" max="${3:-10}" try=1
  c_info "Téléchargement : ${url}"
  while (( try <= max )); do
    if wget -c --tries=3 --timeout=30 --waitretry=10 --retry-connrefused \
            --progress=bar:force -O "${dest}" "${url}"; then
      c_ok "Téléchargement terminé."
      return 0
    fi
    c_warn "Coupure (tentative ${try}/${max}). Reprise dans 5 s..."
    sleep 5; (( try++ ))
  done
  c_err "Échec après ${max} tentatives : ${url}"
  return 1
}

# --- Vérifie qu'un fichier est bien une ISO ---
check_iso(){
  local f="$1"
  file "$f" | grep -qi "ISO 9660"
}

# --- Génère le hash SHA-512 d'un mot de passe ---
pw_hash(){ openssl passwd -6 "$1"; }

# --- Écrit le user-data + meta-data autoinstall ---
# usage : write_autoinstall <hostname>
write_autoinstall(){
  local hostname="$1"
  local dir="${WWW_ROOT}/autoinstall"
  mkdir -p "${dir}"
  local hash; hash="$(pw_hash "${AI_PASSWORD}")"
  local tmpl="${REPO_ROOT}/autoinstall/user-data.template"

  if [[ -f "${tmpl}" ]]; then
    sed -e "s|__HOSTNAME__|${hostname}|g" \
        -e "s|__USERNAME__|${AI_USERNAME}|g" \
        -e "s|__PWHASH__|${hash}|g" \
        -e "s|__LOCALE__|${AI_LOCALE}|g" \
        -e "s|__KEYBOARD__|${AI_KEYBOARD}|g" \
        -e "s|__TIMEZONE__|${AI_TIMEZONE}|g" \
        "${tmpl}" > "${dir}/user-data"
  else
    c_err "Template autoinstall introuvable : ${tmpl}"; exit 1
  fi

  echo "instance-id: ${hostname}" > "${dir}/meta-data"
  chown -R www-data:www-data "${dir}"

  python3 -c "import yaml; yaml.safe_load(open('${dir}/user-data'))" 2>/dev/null \
    && c_ok "Autoinstall écrit (user: ${AI_USERNAME})." \
    || { c_err "YAML user-data invalide."; exit 1; }
}

# --- Enregistre une entrée de menu pour un OS ---
# usage : register_entry <id> <label> <grub_body> <bios_body>
#   grub_body / bios_body = lignes internes (sans le menuentry / LABEL wrapper)
register_entry(){
  local id="$1" label="$2" grub_body="$3" bios_body="$4"
  mkdir -p "${ENTRIES_DIR}"
  # Fragment GRUB (UEFI)
  cat > "${ENTRIES_DIR}/${id}.grub" <<EOF
menuentry '${label}' {
${grub_body}
}
EOF
  # Fragment PXELINUX (BIOS)
  cat > "${ENTRIES_DIR}/${id}.bios" <<EOF
LABEL ${id}
    MENU LABEL ${label}
${bios_body}
EOF
}

# --- Régénère grub.cfg + pxelinux.cfg à partir des fragments enregistrés ---
regenerate_menus(){
  mkdir -p "${TFTP_ROOT}/grub" "${TFTP_ROOT}/pxelinux.cfg" "${ENTRIES_DIR}"

  # ---- GRUB (UEFI) ----
  {
    cat <<EOF
set default="0"
set timeout=15

if loadfont unicode ; then
   set gfxmode=auto
   set locale_dir=\$prefix/locale
   set lang=en_US
fi
terminal_output gfxterm

EOF
    for f in "${ENTRIES_DIR}"/*.grub; do
      [[ -e "$f" ]] && { cat "$f"; echo; }
    done
    cat <<EOF
menuentry 'Boot disque local' {
   exit
}
EOF
  } > "${TFTP_ROOT}/grub/grub.cfg"

  # ---- PXELINUX (BIOS) ----
  {
    cat <<EOF
DEFAULT menu.c32
PROMPT 0
TIMEOUT 150
MENU TITLE === Serveur PXE - Reconditionnement ===

EOF
    for f in "${ENTRIES_DIR}"/*.bios; do
      [[ -e "$f" ]] && { cat "$f"; echo; }
    done
    cat <<EOF
LABEL local
    MENU LABEL Boot disque local
    LOCALBOOT 0
EOF
  } > "${TFTP_ROOT}/pxelinux.cfg/default"

  c_ok "Menus BIOS + UEFI régénérés."
}
