# Architecture

## Services

| Service | Rôle | Ports |
|---|---|---|
| dnsmasq | DHCP (attribue IP + fichier de boot) et TFTP (sert les fichiers de boot) | 67/udp, 69/udp |
| nginx | HTTP (sert le squashfs Clonezilla, éventuellement les images) | 80/tcp |
| nfs-kernel-server | Sert le dépôt d'images Clonezilla au déploiement | 2049/tcp, 111 |

## Séquence de démarrage d'un client

```
1. Le poste démarre en PXE (réseau).
2. dnsmasq (DHCP) lui donne une IP + le nom du fichier de boot :
      - BIOS legacy  -> pxelinux.0
      - UEFI x86-64  -> grubx64.efi   (détecté via l'option DHCP 93 / client-arch)
3. Le poste télécharge ce fichier par TFTP.
4. Le chargeur lit son menu :
      - BIOS -> /srv/tftp/pxelinux.cfg/default
      - UEFI -> /srv/tftp/grub/grub.cfg
5. L'utilisateur choisit une entrée :
      - ShredOS     : charge bzImage, lance nwipe.
      - Déploiement : charge Clonezilla Live, restaure une image, redémarre.
      - Clonezilla  : charge Clonezilla Live en mode manuel (capture/maintenance).
      - Boot local  : démarre sur le disque du poste.
```

## Boot UEFI sans shim

En boot réseau, le shim signé récent de Canonical tente de récupérer un fichier
`revocations.efi` par TFTP ; absent d'un déploiement PXE classique, cela fait
échouer le shim avec `TFTP Error` sans qu'il passe la main à grub.

Ce dépôt sert donc **grubx64.efi directement** (le grub réseau signé), en sautant
le shim. Conséquence : Secure Boot doit être désactivé sur les postes clients.
Pour du reconditionnement (postes réinstallés de toute façon), c'est acceptable.

## Clonezilla : capture et déploiement

Clonezilla Live est chargé par le réseau : le noyau (`vmlinuz`) et l'initrd
(`initrd.img`) viennent du TFTP, et le système live (`filesystem.squashfs`) est
récupéré en HTTP via le paramètre `fetch=`.

Les images sont stockées dans `/home/partimag` sur le serveur et servies aux
clients par NFS (`ocs_repository=nfs://...`). Le déploiement automatique passe la
commande de restauration directement en paramètre de boot (`ocs_live_run` avec
`ocs-sr ... restoredisk`), ce qui évite toute navigation dans les menus.

Les paramètres `nomodeset nosplash vga=normal` sur les lignes Clonezilla forcent
un mode vidéo compatible ; ils évitent l'écran noir observé au démarrage sur
certains postes.

## Génération des menus

Chaque script `add-*` / `setup-*` dépose deux fragments dans
`/srv/pxe-state/entries/` : un pour grub (UEFI), un pour pxelinux (BIOS), préfixés
par un numéro de priorité. `regenerate_menus` (dans `lib/common.sh`) assemble ces
fragments par ordre de priorité et produit `grub.cfg` et `pxelinux.cfg/default`.
Ajouter ou retirer une entrée revient à ajouter/supprimer ses fragments puis
régénérer, sans toucher aux autres entrées.

Ordre des priorités : 10 ShredOS, 20 Déploiement, 30 Clonezilla manuel.

## Arborescence serveur

```
/srv/tftp/                       racine TFTP (dnsmasq)
├── pxelinux.0                   chargeur BIOS
├── grubx64.efi                  chargeur UEFI (grub signé)
├── *.c32                        modules pxelinux (menu)
├── pxelinux.cfg/default         menu BIOS (généré)
├── grub/grub.cfg                menu UEFI (généré)
├── shredos/bzImage              noyau ShredOS
└── clonezilla/                  vmlinuz, initrd.img, filesystem.squashfs

/var/www/html/                   racine HTTP (nginx)
└── clonezilla -> /srv/tftp/clonezilla   (lien, sert le squashfs en fetch=)

/home/partimag/                  dépôt d'images Clonezilla (exporté en NFS)
└── <nom-image>/                 fichiers d'une image capturée

/srv/pxe-state/entries/          fragments de menu (état interne)
```
