#!/usr/bin/env bash
###############################################################################
#  config.sh — Variables centrales du serveur PXE
#  Sourcé par tous les scripts. Modifie ce fichier UNE fois, puis lance
#  les scripts. Ne pas exécuter directement.
###############################################################################

# ---------------------------------------------------------------------------
# RÉSEAU
# ---------------------------------------------------------------------------
IFACE="eth0"                        # interface réseau du serveur PXE
SERVER_IP="10.10.10.21"             # IP du serveur PXE
GATEWAY="10.10.10.1"
NETMASK="255.255.255.0"
SUBNET="10.10.10.0/24"              # utilisé pour l'export NFS
DHCP_START="10.10.10.100"
DHCP_END="10.10.10.200"
DHCP_LEASE="12h"
DNS1="8.8.8.8"
DNS2="1.1.1.1"

# Poser l'IP statique via netplan lors de l'install de base ? (yes/no)
CONFIGURE_STATIC_IP="no"

# ---------------------------------------------------------------------------
# CHEMINS (rarement à changer)
# ---------------------------------------------------------------------------
TFTP_ROOT="/srv/tftp"
WWW_ROOT="/var/www/html"
NFS_ROOT_BASE="/srv/nfs"            # les OS en NFS vont dans /srv/nfs/<os>
STATE_DIR="/srv/pxe-state"          # fragments de menu + métadonnées
ENTRIES_DIR="${STATE_DIR}/entries"  # un fichier par OS enregistré

# ---------------------------------------------------------------------------
# AUTOINSTALL — identité de la machine installée (Ubuntu / Xubuntu)
# ---------------------------------------------------------------------------
AI_USERNAME="utilisateur"
AI_PASSWORD="utilisateur"           # hashé automatiquement (SHA-512)
AI_LOCALE="fr_FR.UTF-8"
AI_KEYBOARD="fr"
AI_TIMEZONE="Europe/Paris"

# ---------------------------------------------------------------------------
# UBUNTU
# ---------------------------------------------------------------------------
UBUNTU_VERSION="26.04"
# "desktop" (bureau GNOME) ou "live-server" (console)
UBUNTU_FLAVOR="desktop"
# Méthode de boot : "ram" (url=, rapide, exige >=8 Go RAM client)
#                   "nfs" (monté depuis le serveur, pas de contrainte RAM)
UBUNTU_BOOT_METHOD="ram"
UBUNTU_MIRROR="https://releases.ubuntu.com/${UBUNTU_VERSION}"

# ---------------------------------------------------------------------------
# XUBUNTU
# ---------------------------------------------------------------------------
XUBUNTU_VERSION="26.04"
# "minimal" (léger) ou "" pour l'édition standard
XUBUNTU_EDITION="minimal"
XUBUNTU_BOOT_METHOD="ram"           # "ram" ou "nfs"
XUBUNTU_MIRROR="http://ftp.free.fr/mirrors/ftp.xubuntu.com/releases/${XUBUNTU_VERSION}/release"

# ---------------------------------------------------------------------------
# SHREDOS
# ---------------------------------------------------------------------------
SHREDOS_REPO="PartialVolume/shredos.x86_64"
# Effacement automatique SANS confirmation ? (yes/no) — DANGER si yes
SHREDOS_AUTONUKE="no"
SHREDOS_NUKE_OPTS="--autonuke --method=zero --verify=off --noblank --nousb --autopoweroff"
