# Workflow : préparer un modèle, capturer, déployer

Le déploiement se fait en deux temps : on prépare et on capture un poste modèle
une seule fois, puis on déploie son image sur autant de postes que voulu.

## Étape 1 : préparer le poste modèle

Installer un système avec bureau sur un poste, par le moyen le plus simple. Pour
un réseau isolé, une clé USB d'installation classique (Debian, Xubuntu…) fonctionne
sans difficulté, contrairement à l'installation par PXE (voir HISTORIQUE.md).

Sur ce poste, tout configurer comme on veut le retrouver sur l'ensemble du parc :
environnement de bureau, logiciels, réglages, comptes.

Avant de capturer, remettre à zéro l'identité machine, sinon tous les postes
clonés partageront le même identifiant (source de conflits réseau) :

```
sudo apt clean
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo poweroff
```

L'identifiant sera régénéré au premier démarrage de chaque poste cloné.
Avant la capture, figer aussi la langue et le clavier du système modèle pour
éviter toute question au premier démarrage des postes déployés :

```
sudo localectl set-locale LANG=fr_FR.UTF-8
sudo localectl set-keymap fr
sudo dpkg-reconfigure -f noninteractive locales
sudo dpkg-reconfigure -f noninteractive keyboard-configuration
```


## Étape 2 : capturer l'image

Sur le serveur, préparer le dépôt d'images :

```
sudo mkdir -p /home/partimag
sudo chmod 777 /home/partimag
```

Démarrer le poste modèle en PXE et choisir l'entrée
"Clonezilla - Capture/maintenance (manuel)". Dans les écrans Clonezilla :

1. Langue, clavier (garder la disposition).
2. Start Clonezilla.
3. Mode `device-image`.
4. Dépôt : `ssh_server`, puis IP du serveur (`10.10.10.21`), port `22`,
   utilisateur du serveur, dossier `/home/partimag`, mot de passe.
5. Mode `Beginner`.
6. Action `savedisk`.
7. Nom de l'image, par exemple `debian-xfce-img`.
8. Disque source : le disque du poste (`nvme0n1` ou `sda`).
9. Confirmer.

L'image est créée dans `/home/partimag/<nom>` sur le serveur.

Vérifier sur le serveur :

```
ls /home/partimag/<nom>/
```

On doit voir des fichiers `...-ptcl-img.gz` et les tables de partition. Le nom du
disque visible dans ces fichiers (par exemple `nvme0n1p1...`) donne la valeur à
mettre dans `TARGET_DISK`.

## Étape 3 : configurer le déploiement automatique

Renseigner `IMAGE_NAME` et `TARGET_DISK` dans `config.sh`, puis :

```
sudo ./setup-clonezilla-deploy.sh
```

## Étape 4 : déployer sur le parc

Sur chaque poste à reconditionner : démarrer en PXE, choisir
"Déploiement <image> (AUTOMATIQUE)". Le poste restaure l'image et redémarre seul
sur le système, à l'identique du modèle. Compter quelques minutes par poste.

Ordre conseillé pour un poste contenant des données : passer d'abord ShredOS
(effacement), puis le déploiement.

## Mettre à jour l'image modèle

Pour changer la configuration de référence : déployer l'image sur un poste,
le modifier, refaire l'étape 1 (nettoyage identité) puis l'étape 2 (capture) avec
le même nom d'image (ou un nouveau nom, puis mettre à jour `IMAGE_NAME`).

## Parc hétérogène

`TARGET_DISK` doit correspondre au disque des postes cibles. Si le parc mélange
NVMe (`nvme0n1`) et SATA (`sda`), prévoir une entrée de déploiement par type
(relancer `setup-clonezilla-deploy.sh` après avoir changé `TARGET_DISK`, les
fragments de menu ayant des identifiants distincts).

Clonezilla restaure la taille de partition du modèle. Si un poste cible a un
disque plus petit que le modèle, la restauration échoue ; l'option `-k1` incluse
dans la commande recrée la table de partition, et `-icds` permet d'ignorer les
différences de taille de disque si nécessaire.
