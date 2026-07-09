# Installation pas à pas

Ce guide décrit le déploiement complet du serveur PXE sur une machine **Ubuntu 26.04 LTS** déjà installée.

## 1. Prérequis serveur

- Ubuntu 26.04 LTS (server ou desktop).
- Un accès `sudo`.
- Une interface réseau reliée au segment des postes à reconditionner.
- De l'espace disque : ~7 Go par ISO (davantage si méthode NFS, qui duplique le contenu de l'ISO).
- Idéalement, un **réseau isolé** (switch ou VLAN dédié) pour éviter tout conflit avec un autre serveur DHCP.

> ⚠️ Ne branchez pas ce serveur sur un réseau qui a déjà un serveur DHCP actif : les deux entreraient en conflit. Isolez-le.

## 2. Récupérer le dépôt

```bash
git clone https://github.com/PETITt2/pxe-reconditioning.git
cd pxe-reconditioning
chmod +x *.sh
```

## 3. Configurer

Éditez `config.sh` et adaptez au minimum :

```bash
nano config.sh
```

- `IFACE` — nom de votre interface (vérifiez avec `ip -brief link`).
- `SERVER_IP`, `GATEWAY`, `SUBNET`, plage DHCP.
- `AI_USERNAME` / `AI_PASSWORD` — le compte qui sera créé sur les postes.
- `UBUNTU_FLAVOR` et les `*_BOOT_METHOD` selon votre matériel (voir plus bas).

Si votre serveur n'a pas encore d'IP fixe, mettez `CONFIGURE_STATIC_IP="yes"`.

## 4. Choisir la méthode de boot

| Méthode | Avantage | Contrainte |
|---|---|---|
| `ram` | Simple, rapide, robuste | Le poste client doit avoir **≥ 8 Go de RAM** |
| `nfs` | **Aucune** contrainte de RAM | Duplique l'ISO sur le serveur, config un peu plus lourde |

Pour des postes récents (≥ 8 Go), gardez `ram`. Pour du matériel ancien, passez en `nfs`.

## 5. Installer

### Option A — clé en main (ShredOS + Xubuntu)

```bash
sudo ./deploy-xubuntu-shredos.sh
```

### Option B — à la carte

```bash
sudo ./install-base.sh     # TOUJOURS en premier
sudo ./add-shredos.sh
sudo ./add-ubuntu.sh       # si vous voulez Ubuntu
sudo ./add-xubuntu.sh      # si vous voulez Xubuntu
```

Chaque `add-*.sh` télécharge l'ISO (reprise auto en cas de coupure), configure l'autoinstall et régénère les menus. Vous pouvez en ajouter/retirer à tout moment.

## 6. Pas d'accès Internet sur le serveur ?

Les scripts tentent de télécharger les ISO. Si le serveur est isolé :

1. Téléchargez l'ISO sur une autre machine.
2. Déposez-la dans `/var/www/html/iso/` avec le nom exact attendu (ex. `xubuntu-26.04-minimal-amd64.iso`).
3. Relancez le `add-*.sh` : il détecte l'ISO présente et saute le téléchargement.

Transfert typique depuis un poste Windows :

```powershell
scp .\xubuntu-26.04-minimal-amd64.iso utilisateur@10.10.10.21:/home/utilisateur/
```

Puis sur le serveur :

```bash
sudo mv /home/utilisateur/xubuntu-26.04-minimal-amd64.iso /var/www/html/iso/
```

## 7. Vérifier

```bash
# Services
systemctl is-active dnsmasq nginx

# Fichiers de boot
ls -lh /srv/tftp/grubx64.efi /srv/tftp/pxelinux.0

# Autoinstall servi
curl -s http://10.10.10.21/autoinstall/user-data | grep -E "username|updates"

# Suivi en direct des demandes DHCP des clients
journalctl -u dnsmasq -f
```

## 8. Booter un poste

Voir [CLIENT-SETUP.md](CLIENT-SETUP.md) pour les réglages BIOS/UEFI du poste client.
