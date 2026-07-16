# Installation pas à pas

Déploiement du serveur sur une machine Ubuntu 26.04 LTS déjà installée.

## 1. Récupérer le dépôt

```
git clone https://github.com/PETITt2/pxe-reconditioning.git
cd pxe-reconditioning
chmod +x *.sh
```

## 2. Configurer

Éditer `config.sh` et adapter au minimum :

- `IFACE` : interface réseau du serveur (vérifier avec `ip -brief link`).
- `SERVER_IP`, `GATEWAY`, `SUBNET`, plage DHCP.
- `IMAGE_NAME` : nom du dossier d'image (par défaut `debian-xfce-img`).
- `TARGET_DISK` : disque des postes cibles (`nvme0n1` pour du NVMe, `sda` pour du SATA).

Si le serveur n'a pas encore d'IP fixe, mettre `CONFIGURE_STATIC_IP="yes"`.

## 3. Infrastructure de base

```
sudo ./install-base.sh
```

Installe dnsmasq (DHCP+TFTP), nginx (HTTP), les fichiers de boot BIOS et UEFI,
et un menu vide. Vérifie à la fin que dnsmasq et nginx sont actifs.

## 4. Ajouter les entrées

```
sudo ./add-shredos.sh
sudo ./add-clonezilla.sh
```

`add-clonezilla.sh` a besoin des fichiers de Clonezilla Live. Deux cas :

- Ils sont déjà présents dans `/srv/tftp/clonezilla/` (`vmlinuz`, `initrd.img`,
  `filesystem.squashfs`) : le script les détecte et se contente d'ajouter le menu.
- Ils sont absents : renseigner `CLONEZILLA_ZIP_URL` dans `config.sh` (lien du zip
  "alternative" amd64 depuis https://clonezilla.org/downloads.php), ou déposer les
  trois fichiers à la main dans `/srv/tftp/clonezilla/`.

## 5. Capturer un modèle puis configurer le déploiement

Suivre [WORKFLOW.md](WORKFLOW.md) pour préparer un poste modèle et le capturer.
Une fois l'image présente dans `/home/partimag/<nom>` :

```
sudo ./setup-clonezilla-deploy.sh
```

## 6. Choisir l'entrée de menu par défaut

Par défaut, la première entrée du menu (ShredOS) est présélectionnée et se lance
si le minuteur expire. Pour éviter tout effacement accidentel d'un poste qui
démarrerait sur le réseau par erreur, on peut forcer le boot local par défaut.

Éditer `/srv/tftp/grub/grub.cfg` et remplacer `set default="0"` par le numéro de
l'entrée "Boot disque local" (la dernière). L'ordre est visible avec :

```
grep menuentry /srv/tftp/grub/grub.cfg
```

## 7. Vérifier

```
systemctl is-active dnsmasq nginx
ls -lh /srv/tftp/grubx64.efi /srv/tftp/pxelinux.0
grep menuentry /srv/tftp/grub/grub.cfg
journalctl -u dnsmasq -f      # suivi des demandes DHCP des clients
```

## 8. Réglages du poste client

Dans le BIOS/UEFI du poste : désactiver Secure Boot, activer le boot réseau
IPv4 et le mettre en tête de l'ordre de boot. Détail dans
[ARCHITECTURE.md](ARCHITECTURE.md).
