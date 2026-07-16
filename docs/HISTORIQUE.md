# Historique des approches

Ce document retrace les méthodes essayées avant d'arriver à la solution par
image (Clonezilla), et explique pourquoi chacune a été écartée. Il sert de
mémoire technique et justifie le choix final.

## Objectif de départ

Serveur PXE pour reconditionner des postes : effacer les disques, puis
réinstaller un système avec bureau, de façon automatisée, sur un réseau isolé
(pas d'Internet côté client). Matériel typique : portables Dell, dont certains
avec 4 Go de RAM.

## Ce qui a fonctionné d'emblée

- Infrastructure PXE : DHCP, TFTP, HTTP, boot BIOS et UEFI.
- ShredOS : effacement des disques.
- Ubuntu Server en autoinstall, chargé en RAM : l'installation allait jusqu'au
  bout et redémarrait sur un système fonctionnel (en mode console).

## Approche 1 : Ubuntu Desktop, ISO chargée en RAM

Méthode `url=` : l'installateur télécharge l'ISO complète et la monte en RAM.

Écarté : l'ISO Desktop (environ 6 Go) ne tient pas dans 4 Go de RAM. Résultat :
kernel panic "system is deadlocked on memory".

## Approche 2 : boot NFS (ISO montée depuis le serveur)

Pour lever la contrainte de RAM, l'ISO reste sur le serveur et est montée par
NFS. Le montage NFS fonctionnait (visible côté serveur : `authenticated mount
request`).

Écarté : blocages en chaîne au démarrage du système live Desktop sur ce
matériel — écran noir, services attendant un réseau absent
(cloud-init-network, snapd.seeded), vérification MD5 du squashfs très lente via
NFS (casper-md5check), puis tâches bloquées sur des I/O NFS. Chaque contournement
(nomodeset, masquage de services) débloquait une étape pour buter sur la
suivante. Trop fragile pour un parc.

## Approche 3 : Xubuntu (XFCE, plus léger)

Même mécanique que ci-dessus, avec un bureau plus léger adapté à 4 Go.

Écarté : même famille de blocages d'affichage/boot. Constat important : ShredOS
lui-même donnait un écran noir sur ce poste, ce qui a montré que le problème
d'affichage venait du poste (gestion du framebuffer), pas de la distribution.

## Approche 4 : Ubuntu Server + bureau depuis un dépôt APT local

Installer la base Server (qui marchait), puis tirer le bureau depuis un dépôt
APT hébergé sur le serveur. Le dépôt local a été construit (cloture de
dépendances, environ 1900 paquets).

Écarté : l'installateur refusait le dépôt local à cause de métadonnées
manquantes ou invalides (`InRelease` 404, `Release` non signé/rejeté). La
génération correcte de ces métadonnées et l'installation par `dpkg` en fin
d'install se sont révélées laborieuses et instables (ordre des dépendances,
paquets restés non configurés).

## Approche 5 : Debian preseed hors-ligne (DVD servi en miroir)

Debian s'installe nativement hors-ligne depuis un DVD, et son installateur est
en mode texte (pas de framebuffer, donc pas d'écran noir). Le DVD-1 a été monté
et servi par nginx comme miroir local.

Blocages successifs, tous identifiés :

- `Release is unsigned` : résolu avec `allow_unauthenticated`.
- `aucun module de noyau trouvé` : l'installateur netboot (téléchargé depuis
  Internet, build "current") ne correspondait pas aux `.udeb` du DVD (build de la
  point-release). Désalignement installateur/paquets.
- `installation media couldn't be mounted` : l'installateur intégré au DVD
  (`install.amd/initrd.gz`) est un initrd CD-ROM qui exige un média physique et
  ne gère pas la récupération réseau (`fetch=`).

Cause de fond : le DVD-1 ne contient pas d'installateur netboot (réseau),
seulement un installateur CD. Faire du PXE hors-ligne oblige à aligner
l'installateur et les paquets sur la même build, ce qui n'a pas de solution
simple à partir du seul DVD-1.

Deux solutions propres existaient, non retenues :

- Miroir complet avec `debmirror` (installateur et paquets de la même source,
  donc alignés) : fiable, mais volumineux (environ 80 à 90 Go) et long
  (plusieurs heures), disproportionné ici.
- Mini-dépôt sur mesure : plus léger mais fragile (mêmes problèmes de métadonnées
  et d'alignement que l'approche 4).

## Solution retenue : Clonezilla (image)

Constat : l'installation d'un bureau par PXE en hors-ligne cumule des contraintes
(alignement installateur/paquets, affichage du matériel, RAM limitée) qui, prises
ensemble, la rendent impraticable sur ce parc.

Le clonage d'image contourne tout cela : on installe un poste modèle une fois,
par le moyen le plus simple (clé USB, où l'install hors-ligne marche nativement),
on le capture, puis on le déploie à l'identique par le réseau. Pas d'installateur
réseau, pas de dépôt à aligner, pas de questions à l'écran, pas de dépendance
Internet côté client. C'est la méthode standard du reconditionnement de parc.

Ce que la solution conserve des étapes précédentes : toute l'infrastructure PXE
(DHCP, TFTP, HTTP, boot BIOS+UEFI sans shim) et ShredOS, qui ont fonctionné dès
le début.
