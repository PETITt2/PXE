# Serveur PXE de reconditionnement

Serveur de démarrage réseau (PXE) pour reconditionner un parc de postes, sur
Ubuntu 26.04 LTS. Il permet, depuis un poste vierge démarré par le réseau :

- d'effacer les disques de façon sécurisée (ShredOS / nwipe) ;
- de redéployer un système complet avec bureau, à partir d'une image clonée
  (Clonezilla), sans intervention et sans accès Internet côté client ;
- de refaire ou mettre à jour l'image modèle (Clonezilla, mode manuel).

Il gère les postes en BIOS legacy et en UEFI, et fonctionne sur un réseau isolé.

## Approche retenue : image plutôt qu'installation

Ce dépôt déploie un système par **clonage d'image**, pas par installation
automatisée. Ce choix n'est pas arbitraire : l'installation PXE hors-ligne d'un
bureau (Ubuntu autoinstall ou Debian preseed) s'est révélée impraticable sur le
matériel visé, pour des raisons détaillées dans
[docs/HISTORIQUE.md](docs/HISTORIQUE.md). Le clonage évite toute cette classe de
problèmes : on prépare une fois un poste modèle, on le capture, puis on le
redéploie à l'identique en quelques minutes par poste.

Le résultat pour l'utilisateur final est identique à une installation classique
(un poste avec un bureau fonctionnel) ; seule la méthode diffère.

Une méthode d'**installation automatisée** (Ubuntu autoinstall, Debian preseed)
est aussi fournie en alternative, utilisable dans des conditions favorables
(postes avec assez de RAM, ou accès Internet, ou miroir Debian local). Voir
[docs/AUTOINSTALL.md](docs/AUTOINSTALL.md).

## Prérequis

Serveur : Ubuntu 26.04 LTS, accès sudo, une interface reliée au segment des
postes, de l'espace disque pour les images (quelques Go par image).

Poste client : Secure Boot désactivé (voir
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)), boot réseau IPv4 en tête.

Réseau : idéalement isolé (switch ou VLAN dédié) pour éviter tout conflit avec
un autre serveur DHCP.

## Mise en place

```
git clone https://github.com/PETITt2/pxe-reconditioning.git
cd pxe-reconditioning
chmod +x *.sh

# 1. Adapter la configuration (IP, interface, nom d'image, disque cible)
nano config.sh

# 2. Infrastructure PXE de base (obligatoire en premier)
sudo ./install-base.sh

# 3. Ajouter ShredOS
sudo ./add-shredos.sh

# 4. Ajouter Clonezilla
sudo ./add-clonezilla.sh

# 5. Préparer et capturer un poste modèle (voir docs/WORKFLOW.md), puis :
sudo ./setup-clonezilla-deploy.sh
```

Le menu PXE final propose, dans l'ordre : ShredOS, Déploiement de l'image,
Clonezilla (capture/maintenance), Boot disque local.

## Scripts

| Script | Rôle |
|---|---|
| `install-base.sh` | Infrastructure PXE (dnsmasq, nginx, boot BIOS+UEFI). À lancer en premier. |
| `add-shredos.sh` | Télécharge ShredOS et l'ajoute au menu. |
| `add-clonezilla.sh` | Met en place Clonezilla Live en PXE (capture/maintenance). |
| `setup-clonezilla-deploy.sh` | Configure le déploiement automatique d'une image capturée. |
| `add-ubuntu.sh` | (Alternative) Installation Ubuntu automatisée. Voir docs/AUTOINSTALL.md. |
| `add-debian.sh` | (Alternative) Installation Debian automatisée (preseed). Voir docs/AUTOINSTALL.md. |
| `build-debian-mirror.sh` | (Alternative) Construit un miroir Debian local pour une install hors-ligne. |
| `config.sh` | Toutes les variables. |
| `lib/common.sh` | Fonctions partagées (téléchargement, génération des menus). |

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) — installation pas à pas.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — fonctionnement technique.
- [docs/WORKFLOW.md](docs/WORKFLOW.md) — capturer un modèle, déployer sur le parc.
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — problèmes rencontrés et solutions.
- [docs/AUTOINSTALL.md](docs/AUTOINSTALL.md) — méthode alternative : installation automatisée (Ubuntu/Debian) et ses conditions d'emploi.
- [docs/HISTORIQUE.md](docs/HISTORIQUE.md) — approches essayées et pourquoi elles ont été abandonnées.

