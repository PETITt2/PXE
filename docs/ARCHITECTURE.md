# Architecture

## Vue d'ensemble

Le serveur assure quatre rôles, portés par trois services :

| Service | Rôle | Port(s) |
|---|---|---|
| **dnsmasq** | Serveur **DHCP** (attribue IP + fichier de boot) et **TFTP** (sert les fichiers de boot) | 67/udp, 69/udp |
| **nginx** | Serveur **HTTP** (sert les ISO et les fichiers autoinstall) | 80/tcp |
| **nfs-kernel-server** | (optionnel) sert le système live par **NFS** quand la méthode `nfs` est choisie | 2049/tcp, 111 |

## Séquence de démarrage d'un client

```
1. Le poste démarre en PXE (réseau).
2. dnsmasq (DHCP) lui donne une IP + le nom du fichier de boot :
      - BIOS legacy  -> pxelinux.0
      - UEFI x86-64  -> grubx64.efi   (détecté via l'option DHCP 93 / client-arch)
3. Le poste télécharge ce fichier par TFTP.
4. Le chargeur (pxelinux ou grub) lit son menu :
      - BIOS -> /srv/tftp/pxelinux.cfg/default
      - UEFI -> /srv/tftp/grub/grub.cfg
5. L'utilisateur choisit une entrée (ShredOS / Ubuntu / Xubuntu / local).
6. Le noyau + initrd sont chargés par TFTP.
7. Selon la méthode :
      - RAM : le noyau télécharge l'ISO complète en HTTP et la monte en mémoire.
      - NFS : le noyau monte le système live directement depuis le serveur (NFS).
8. Pour Ubuntu/Xubuntu : l'installateur récupère le fichier autoinstall
   (user-data) en HTTP et installe le système sans interaction, puis redémarre.
```

## Pourquoi grub directement (sans shim) en UEFI

Le shim signé de Canonical, en boot réseau, tente de récupérer un fichier
`revocations.efi` par TFTP. Ce fichier n'existant pas dans un déploiement PXE
classique, le shim échoue avec `TFTP Error` **sans** basculer vers grub —
c'est un bug connu du shim ≥ 15.8.

**Solution retenue :** servir directement `grubx64.efi` (le grub réseau signé),
en sautant le shim. Contrepartie : **Secure Boot doit être désactivé** sur le
poste client, puisque la chaîne de vérification du shim n'est plus présente.
Pour un contexte de reconditionnement (postes réinstallés de toute façon),
c'est un compromis parfaitement acceptable.

## Régénération des menus

Plutôt que d'éditer les menus à la main, chaque `add-*.sh` dépose deux
**fragments** dans `/srv/pxe-state/entries/` :

- `<os>.grub` — le bloc `menuentry { … }` pour UEFI ;
- `<os>.bios` — le bloc `LABEL … / APPEND …` pour BIOS.

La fonction `regenerate_menus` (dans `lib/common.sh`) assemble ces fragments
avec un en-tête et l'entrée « Boot disque local » pour produire
`grub.cfg` et `pxelinux.cfg/default`. Ajouter ou retirer un OS revient donc à
ajouter/supprimer ses fragments puis régénérer — sans jamais casser les autres
entrées.

## Arborescence sur le serveur

```
/srv/tftp/                        # racine TFTP (servie par dnsmasq)
├── pxelinux.0                    # chargeur BIOS
├── grubx64.efi                   # chargeur UEFI (grub signé)
├── *.c32                         # modules pxelinux (menu)
├── pxelinux.cfg/default          # menu BIOS (généré)
├── grub/grub.cfg                 # menu UEFI (généré)
├── shredos/bzImage               # noyau ShredOS
├── ubuntu/{vmlinuz,initrd}       # noyau/initrd Ubuntu
└── xubuntu/{vmlinuz,initrd}      # noyau/initrd Xubuntu

/var/www/html/                    # racine HTTP (servie par nginx)
├── iso/*.iso                     # ISO servies (méthode RAM)
└── autoinstall/{user-data,meta-data}

/srv/nfs/                         # partages NFS (méthode NFS uniquement)
├── ubuntu/                       # contenu de l'ISO Ubuntu
└── xubuntu/                      # contenu de l'ISO Xubuntu

/srv/pxe-state/entries/           # fragments de menu (état interne)
```
