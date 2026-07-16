# Dépannage

Problèmes rencontrés et solutions, du démarrage réseau au déploiement.

## Le client tente un "PXE over IPv6" / n'obtient pas de boot

Cause : la carte réseau tente l'IPv6 alors que le serveur ne répond qu'en IPv4.

Solution : dans le BIOS/UEFI du poste, désactiver "IPv6 PXE", activer "IPv4 PXE",
et mettre le boot réseau IPv4 en tête. Vérifier côté serveur que la demande
arrive : `journalctl -u dnsmasq -f`. Si rien n'apparaît au démarrage du client,
le paquet DHCP n'atteint pas le serveur (mauvaise `IFACE`, ou client/serveur pas
sur le même segment L2).

## UEFI : "Unable to fetch TFTP image" sur revocations.efi

```
Fetching Netboot Image revocations.efi
Unable to fetch TFTP image: TFTP Error
```

Cause : bug du shim récent en boot réseau ; il réclame un `revocations.efi`
absent et ne bascule pas vers grub.

Solution : ce dépôt sert grubx64.efi directement (sans shim), le problème ne se
pose donc pas si l'infra a été montée avec `install-base.sh`. Désactiver Secure
Boot sur le poste. Vérifier : `grep grubx64 /etc/dnsmasq.conf`.

## Kernel panic : "system is deadlocked on memory"

Cause : méthode de chargement en RAM (`url=`) sur un poste dont la mémoire est
insuffisante pour l'ISO. Un poste à 4 Go ne peut pas charger une ISO de bureau
(3 à 6 Go) en RAM.

Solution : ne pas utiliser cette méthode pour du bureau sur poste modeste. Le
déploiement Clonezilla ne charge pas d'ISO en RAM et n'a pas cette limite.

## Écran noir avec un underscore au démarrage

Cause : le noyau écrit sur une console/framebuffer que le moniteur n'affiche pas.
Observé sur certains postes, y compris avec ShredOS (donc lié à l'affichage du
poste, pas à l'OS chargé).

Solution : forcer un mode vidéo compatible avec `nomodeset nosplash vga=normal`
sur la ligne de boot (déjà présent sur les entrées Clonezilla de ce dépôt).

## Installation Ubuntu qui repart en mode interactif

Symptôme : l'autoinstall ne s'applique pas, on retombe sur le choix de langue.

Points à vérifier :

- Le user-data est joignable et commence exactement par `#cloud-config`.
- Le meta-data n'est pas vide (il doit contenir `instance-id:`).
- Les URL du menu pointent vers la bonne IP.
- Un meta-data vide invalide le datasource : mettre `instance-id: <nom>`.

## AutoinstallError: Username is reserved by the system: admin

Cause : `admin` est un nom réservé sur Ubuntu.

Solution : utiliser un autre identifiant. À éviter aussi : `root`, `daemon`,
`sync`, `games`.

## Malformed autoinstall in 'updates' / False is not of type 'string'

Cause : le champ `updates` attend une chaîne (`security` ou `all`), pas un booléen.

Solution : `updates: security`. Ne pas mettre `updates: false`. À noter : la
validation YAML simple ne détecte pas cette erreur (le YAML est valide), seul le
schéma de l'installateur la rejette.

## Blocage sur "curtin command apt-config" (Ubuntu)

Cause : l'installateur teste un miroir APT Internet, absent sur réseau isolé, et
attend le timeout.

Solution : `apt: geoip: false` et `fallback: offline-install`, `packages: []`.

## Blocage sur cloud-init-network / snapd.seeded / casper-md5check (NFS)

Cause : services qui attendent un réseau/Internet inexistant, ou vérification MD5
du squashfs lue via NFS (très lente).

Solution : `network-config=disabled` en paramètre de boot, et masquer les
services concernés (`systemd.mask=casper-md5check.service`,
`systemd.mask=snapd.seeded.service`, etc.). Ces contournements ont permis de
démarrer mais restent fragiles ; c'est une des raisons du passage à Clonezilla.

## Dépôt APT local rejeté (Release unsigned / InRelease 404)

Cause : un dépôt local plat sans métadonnées `Release`/`InRelease` correctes est
refusé par l'installateur.

Solution pour Debian : `apt-setup/no-verify=true` /
`debian-installer/allow_unauthenticated=true`. Mais la vraie difficulté est
ailleurs (voir ci-dessous).

## Debian : "aucun module de noyau trouvé"

Cause : l'installateur netboot et la source de paquets (DVD ou miroir) ne sont
pas la même build. Les `.udeb` de l'installateur ne correspondent pas au noyau.

Solution de fond : installateur et paquets doivent venir de la même source
cohérente. Le DVD-1 ne contient pas d'installateur netboot, seulement un
installateur CD ; le netboot officiel est mis à jour plus souvent que le DVD,
d'où le décalage. C'est la principale raison de l'abandon de l'install PXE Debian
au profit de Clonezilla.

## Debian : "installation media couldn't be mounted"

Cause : l'installateur du DVD (`install.amd/initrd.gz`) est un initrd CD-ROM qui
exige un média physique et ne gère pas `fetch=`.

Solution de fond : il faudrait l'initrd netboot ou hd-media, non présent sur le
DVD-1. Impasse contournée par le passage à Clonezilla.

## Clonezilla demande la langue et le clavier au démarrage

Symptôme : écran bleu "Free Software Labs, NCHC Taiwan" demandant de choisir la
langue et le clavier avant que Clonezilla ne travaille.

Cause : ce sont les questions d'accueil de Clonezilla (l'outil), pas une
installation. Elles apparaissent quand la langue/le clavier ne sont pas fournis
en paramètre de boot, ou quand on utilise l'entrée "Capture/maintenance"
(interactive par nature).

Solution : les entrées de ce dépôt passent `locales=fr_FR.UTF-8` et
`keyboard-layouts=fr` sur la ligne de boot, ce qui supprime ces questions. Pour
un déploiement sans aucune interaction, utiliser l'entrée
"Deploiement ... (AUTOMATIQUE)", pas "Capture/maintenance".

## Clonezilla : le déploiement automatique s'arrête ou pose une question

Cause : la commande `ocs-sr` non interactive peut nécessiter un ajustement selon
la version de Clonezilla, ou le disque cible diffère.

Solution : utiliser l'entrée "Clonezilla - Capture/maintenance (manuel)" pour
piloter la restauration écran par écran (`device-image` -> `restoredisk`), et
vérifier `TARGET_DISK`. Voir aussi la note "parc hétérogène" dans WORKFLOW.md.

## Disque du serveur "plein" alors qu'il reste de la place

Cause possible : `/tmp` est un tmpfs en RAM (limité) saturé par une ISO
temporaire, alors que `/` a de la place.

Solution : `df -h` pour repérer la partition pleine ; vider les gros fichiers de
`/tmp` (`find /tmp -type f -size +100M -delete`).

## Lire les logs d'installation sur un client

Depuis une console de l'installateur (Ctrl+Alt+F2, ou F4 pour les logs) :

```
cat /proc/cmdline                                   # paramètres reçus
tail -n 40 /var/log/syslog                          # Debian d-i
tail -n 40 /var/log/installer/subiquity-server-debug.log   # Ubuntu
```
