#!/usr/bin/env bash
# config.sh - Variables centrales du serveur PXE de reconditionnement.
# Sourcé par tous les scripts. A éditer une fois avant de lancer les scripts.
# Ne pas exécuter directement.

# --- Réseau ---
IFACE="eth0"                 # interface réseau du serveur (voir: ip -brief link)
SERVER_IP="10.10.10.21"      # IP du serveur PXE
GATEWAY="10.10.10.1"
NETMASK="255.255.255.0"
SUBNET="10.10.10.0/24"       # utilisé pour l'export NFS
DHCP_START="10.10.10.100"
DHCP_END="10.10.10.200"
DHCP_LEASE="12h"
DNS1="8.8.8.8"
DNS2="1.1.1.1"

# Poser l'IP statique via netplan lors de install-base.sh ? (yes/no)
CONFIGURE_STATIC_IP="no"

# --- Chemins (rarement à changer) ---
TFTP_ROOT="/srv/tftp"
WWW_ROOT="/var/www/html"
IMAGE_DIR="/home/partimag"           # dépôt d'images Clonezilla
STATE_DIR="/srv/pxe-state"
ENTRIES_DIR="${STATE_DIR}/entries"   # fragments de menu (un par entrée)

# --- ShredOS ---
SHREDOS_REPO="PartialVolume/shredos.x86_64"

# --- Clonezilla ---
# Laisser vide pour tenter le dernier stable auto ; sinon URL directe d'un zip
# "alternative" Clonezilla Live (amd64) contenant live/vmlinuz, live/initrd.img,
# live/filesystem.squashfs.
CLONEZILLA_ZIP_URL=""

# --- Déploiement d'image ---
IMAGE_NAME="debian-xfce-img"   # nom du dossier d'image dans IMAGE_DIR
TARGET_DISK="nvme0n1"          # disque cible des postes (nvme0n1 ou sda)

# ===========================================================================
# AUTOINSTALL (alternative a Clonezilla, voir docs/AUTOINSTALL.md)
# A n'utiliser que dans les conditions favorables decrites dans la doc.
# ===========================================================================

# --- Identite du compte cree par l'autoinstall ---
AI_HOSTNAME="poste"
AI_USERNAME="utilisateur"     # ne PAS utiliser "admin" (reserve par Ubuntu)
AI_PASSWORD="utilisateur"     # hashe automatiquement (SHA-512)
AI_LOCALE="fr_FR.UTF-8"
AI_KEYBOARD="fr"
AI_TIMEZONE="Europe/Paris"

# --- Ubuntu (add-ubuntu.sh) ---
UBUNTU_VERSION="26.04"
UBUNTU_FLAVOR="live-server"   # "live-server" (console, OK 4 Go) ou "desktop" (>=8 Go RAM)
UBUNTU_BOOT_METHOD="ram"      # "ram" (url=, charge l'ISO en RAM) ou "nfs"
UBUNTU_MIRROR="https://releases.ubuntu.com/${UBUNTU_VERSION}"

# --- Debian (add-debian.sh) ---
DEBIAN_SUITE="trixie"         # stable actuelle
# Mode de source des paquets :
#   "online" : les CLIENTS telechargent depuis un miroir Internet (necessite Internet cote client)
#   "local"  : miroir local construit avec build-debian-mirror.sh (hors-ligne, ~80-90 Go)
DEBIAN_MIRROR_MODE="online"
DEBIAN_MIRROR_HOST="deb.debian.org"   # utilise en mode "online"
DEBIAN_TASKS="xfce-desktop, standard, ssh-server"   # bureau installe par tasksel

# --- Langue/clavier de l'interface Clonezilla (evite les questions au demarrage) ---
CLONEZILLA_LOCALE="fr_FR.UTF-8"
CLONEZILLA_KEYBOARD="fr"
