# PXE Reconditioning Server

Serveur **PXE / DHCP / TFTP / HTTP** pour le reconditionnement de postes informatiques, sur **Ubuntu 26.04 LTS**. Il permet de démarrer un poste vierge par le réseau et de choisir dans un menu :

* **ShredOS** — effacement sécurisé des disques (conforme aux exigences d'effacement de données, type RGPD / réforme de matériel) ;
* **Ubuntu / Xubuntu** — réinstallation **entièrement automatisée** (autoinstall / cloud-init), sans intervention ;
* **Boot disque local** — démarrage normal sur le disque du poste.

Le tout gère à la fois les postes en **BIOS legacy** et en **UEFI**, et fonctionne sur un **réseau isolé sans accès Internet**.

\---

## Architecture en bref

```
                 ┌────────────────────────── Serveur PXE (10.10.10.21) ──────────────────────────┐
                 │                                                                                │
  Poste client   │   dnsmasq (DHCP + TFTP)      nginx (HTTP)            nfs-kernel-server (option) │
  (vierge)  ─────┼──► attribue IP + fichier ──► sert ISO + autoinstall ──► sert le live système    │
                 │      de boot (BIOS/UEFI)                                                        │
                 └────────────────────────────────────────────────────────────────────────────────┘
```

* **BIOS** reçoit `pxelinux.0` ; **UEFI** reçoit `grubx64.efi` (grub signé, booté **directement sans shim**).
* Les menus (`grub.cfg` pour UEFI, `pxelinux.cfg/default` pour BIOS) sont **régénérés automatiquement** à partir des OS installés.
* Deux méthodes de boot pour les OS live :

  * **RAM** (`url=`) : l'ISO est chargée en mémoire du client. Rapide, mais exige **≥ 8 Go de RAM**.
  * **NFS** (`netboot=nfs`) : l'ISO reste montée depuis le serveur. **Aucune contrainte de RAM**, idéal pour du matériel ancien.

Voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) pour le détail.

\---

## Démarrage rapide

```bash
git clone https://github.com/PETITt2/pxe-reconditioning.git
cd pxe-reconditioning

# 1. Adapter la configuration (IP, interface, identifiants…)
nano config.sh

# 2a. Déploiement clé en main (base + ShredOS + Xubuntu)
sudo ./deploy-xubuntu-shredos.sh

# 2b. …ou à la carte
sudo ./install-base.sh      # infrastructure PXE de base (obligatoire en premier)
sudo ./add-shredos.sh       # ajoute ShredOS au menu
sudo ./add-ubuntu.sh        # ajoute Ubuntu (Desktop ou Server)
sudo ./add-xubuntu.sh       # ajoute Xubuntu (XFCE léger)
```

Puis, sur le poste client : **désactiver Secure Boot**, mettre le **boot réseau IPv4** en tête, et démarrer.

Détails pas à pas : [docs/INSTALL.md](docs/INSTALL.md).

\---

## Scripts

|Script|Rôle|
|-|-|
|`install-base.sh`|Installe et configure l'infrastructure PXE (dnsmasq, nginx, boot BIOS+UEFI). **À lancer en premier.**|
|`add-shredos.sh`|Télécharge ShredOS et l'ajoute au menu.|
|`add-ubuntu.sh`|Télécharge Ubuntu (Desktop/Server), configure l'autoinstall, ajoute l'entrée.|
|`add-xubuntu.sh`|Idem pour Xubuntu (bureau XFCE léger).|
|`deploy-xubuntu-shredos.sh`|Combo clé en main : base + ShredOS + Xubuntu.|
|`config.sh`|**Toutes** les variables (réseau, identifiants, versions, méthodes).|
|`lib/common.sh`|Fonctions partagées (téléchargement, menus, autoinstall).|

\---

## Configuration

Tout se règle dans **`config.sh`**. Les réglages les plus utiles :

|Variable|Rôle|
|-|-|
|`SERVER\_IP`, `IFACE`|IP et interface du serveur PXE.|
|`DHCP\_START` / `DHCP\_END`|Plage d'adresses distribuées.|
|`AI\_USERNAME` / `AI\_PASSWORD`|Identifiants du compte créé à l'installation.|
|`UBUNTU\_FLAVOR`|`desktop` ou `live-server`.|
|`\*\_BOOT\_METHOD`|`ram` (≥8 Go) ou `nfs` (sans contrainte RAM).|
|`SHREDOS\_AUTONUKE`|`yes` = effacement **sans confirmation** (⚠️ dangereux).|

\---

## Prérequis côté poste client

1. **Secure Boot désactivé** — on boote grub directement (sans shim), voir [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
2. **Boot réseau en IPv4** en tête de l'ordre de boot.
3. Pour la méthode **RAM** uniquement : **≥ 8 Go de RAM**. Sinon, utiliser la méthode **NFS**.

Détail complet : [docs/CLIENT-SETUP.md](docs/CLIENT-SETUP.md).

\---

## Dépannage

Les problèmes classiques (erreur shim `revocations.efi`, boucle cloud-init, kernel panic mémoire, install qui retombe en interactif…) et leurs solutions sont documentés dans [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

\---

## Avertissement

**ShredOS efface définitivement les disques.** N'ajoutez `SHREDOS\_AUTONUKE=yes` qu'en connaissance de cause. Vérifiez toujours quel poste démarre sur ShredOS avant de lancer l'effacement.

## 

