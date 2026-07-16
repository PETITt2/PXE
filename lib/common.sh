#!/usr/bin/env bash
# lib/common.sh - Fonctions partagées. Sourcé par les scripts.

c_ok(){   echo -e "\e[32m[ OK ]\e[0m $*"; }
c_info(){ echo -e "\e[36m[INFO]\e[0m $*"; }
c_warn(){ echo -e "\e[33m[WARN]\e[0m $*"; }
c_err(){  echo -e "\e[31m[ERR ]\e[0m $*" >&2; }

require_root(){
  if [ "$EUID" -ne 0 ]; then
    c_err "Ce script doit etre lance en root (sudo)."; exit 1
  fi
}

# Charge config.sh depuis le dossier du script appelant (racine du repo)
load_config(){
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  for base in "${here}" "${here}/.."; do
    if [ -f "${base}/config.sh" ]; then
      # shellcheck disable=SC1091
      source "${base}/config.sh"
      REPO_ROOT="$(cd "${base}" && pwd)"
      return 0
    fi
  done
  c_err "config.sh introuvable."; exit 1
}

# Téléchargement avec reprise + tentatives. usage: robust_download URL DEST [MAX]
robust_download(){
  local url="$1" dest="$2" max="${3:-10}" try=1
  c_info "Telechargement : ${url}"
  while [ "${try}" -le "${max}" ]; do
    if wget -c --tries=3 --timeout=30 --waitretry=10 --retry-connrefused \
            --progress=bar:force -O "${dest}" "${url}"; then
      c_ok "Telechargement termine."; return 0
    fi
    c_warn "Coupure (tentative ${try}/${max}). Reprise dans 5 s..."
    sleep 5; try=$((try+1))
  done
  c_err "Echec apres ${max} tentatives : ${url}"; return 1
}

# Enregistre une entrée de menu. usage:
#   register_entry PRIORITE ID "LABEL" "CORPS_GRUB" "CORPS_BIOS"
# PRIORITE (nombre) controle l'ordre d'affichage (petit = en haut).
register_entry(){
  local prio="$1" id="$2" label="$3" grub_body="$4" bios_body="$5"
  mkdir -p "${ENTRIES_DIR}"
  cat > "${ENTRIES_DIR}/${prio}-${id}.grub" <<EOF
menuentry "${label}" {
${grub_body}
}
EOF
  cat > "${ENTRIES_DIR}/${prio}-${id}.bios" <<EOF
LABEL ${id}
    MENU LABEL ${label}
${bios_body}
EOF
}

# Régénère grub.cfg (UEFI) + pxelinux.cfg/default (BIOS) depuis les fragments.
regenerate_menus(){
  mkdir -p "${TFTP_ROOT}/grub" "${TFTP_ROOT}/pxelinux.cfg" "${ENTRIES_DIR}"

  {
    cat <<EOF
set default="0"
set timeout=25
terminal_output console

EOF
    for f in $(ls "${ENTRIES_DIR}"/*.grub 2>/dev/null | sort); do
      cat "$f"; echo
    done
    cat <<EOF
menuentry "Boot disque local" {
   exit
}
EOF
  } > "${TFTP_ROOT}/grub/grub.cfg"

  {
    cat <<EOF
DEFAULT menu.c32
PROMPT 0
TIMEOUT 250
MENU TITLE === Serveur PXE - Reconditionnement ===

EOF
    for f in $(ls "${ENTRIES_DIR}"/*.bios 2>/dev/null | sort); do
      cat "$f"; echo
    done
    cat <<EOF
LABEL local
    MENU LABEL Boot disque local
    LOCALBOOT 0
EOF
  } > "${TFTP_ROOT}/pxelinux.cfg/default"

  c_ok "Menus BIOS + UEFI regeneres."
}

# --- Helpers autoinstall ---

# Hash SHA-512 d'un mot de passe
pw_hash(){ openssl passwd -6 "$1"; }

# Rend un template en substituant les placeholders __CLE__.
# usage: render_template SRC DEST KEY1 VAL1 KEY2 VAL2 ...
render_template(){
  local src="$1" dest="$2"; shift 2
  cp "${src}" "${dest}"
  while [ "$#" -ge 2 ]; do
    local key="$1" val="$2"; shift 2
    # separateur | ; on echappe | et & dans la valeur
    val=$(printf '%s' "${val}" | sed 's/[|&]/\\&/g')
    sed -i "s|${key}|${val}|g" "${dest}"
  done
}

# Verifie qu'un fichier est une image ISO
check_iso(){ file "$1" | grep -qi "ISO 9660"; }
