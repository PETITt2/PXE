# Réglages du poste client

Avant de démarrer un poste en PXE, trois réglages sont à faire dans son BIOS/UEFI.

## 1. Désactiver Secure Boot

Obligatoire : ce serveur boote **grub directement, sans shim** (voir [ARCHITECTURE.md](ARCHITECTURE.md#pourquoi-grub-directement-sans-shim-en-uefi)). Avec Secure Boot activé, la chaîne échouerait.

Emplacement typique : *Security → Secure Boot → Disabled*.

## 2. Activer et prioriser le boot réseau IPv4

- Activer le **Network Stack / PXE / Onboard NIC**.
- Choisir **IPv4** (désactiver l'IPv6 PXE s'il existe : il ferait échouer/traîner le boot).
- Mettre l'entrée réseau IPv4 **en tête** de l'ordre de boot (ou utiliser le menu de boot ponctuel, souvent **F12 / F9 / F8** selon la marque).

## 3. Vérifier la RAM (méthode RAM uniquement)

Si l'OS est configuré en méthode **`ram`** (voir `config.sh`), le poste charge l'ISO (~6 Go) en mémoire : il lui faut **≥ 8 Go de RAM**.

Pour du matériel avec moins de RAM, demander à l'administrateur de basculer l'OS en méthode **`nfs`** — il n'y a alors aucune contrainte de mémoire.

La quantité de RAM est généralement affichée sur la page d'accueil du BIOS/UEFI.

---

## Déroulé normal d'une réinstallation

1. Le poste démarre en réseau, obtient une IP, télécharge le chargeur.
2. Le menu PXE s'affiche : choisir l'entrée voulue (ex. « Xubuntu … AUTO »).
3. Le noyau se charge, puis l'ISO (RAM) ou le montage NFS.
4. L'installateur s'exécute **sans aucune question** (installation automatique).
5. Le poste **redémarre seul** à la fin.
6. Au redémarrage, choisir le boot **sur le disque** (ou laisser le menu PXE expirer) : le nouvel OS démarre, connexion avec le compte défini dans `config.sh`.

---

## Déroulé d'un effacement (ShredOS)

1. Choisir l'entrée **ShredOS** dans le menu PXE.
2. ShredOS démarre l'outil **nwipe**.
3. Sélectionner le(s) disque(s), la méthode d'effacement, puis lancer.
4. En fin d'effacement, éteindre le poste.

> ⚠️ Si `SHREDOS_AUTONUKE=yes` a été activé sur le serveur, ShredOS **efface immédiatement et sans confirmation** dès le démarrage de cette entrée. À n'utiliser qu'en connaissance de cause, et en vérifiant bien quel poste démarre dessus.
