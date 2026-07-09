# Dépannage

Problèmes rencontrés le plus souvent, du plus précoce (démarrage réseau) au plus tardif (installation), avec la cause et la solution.

---

## Le client tente un « PXE over IPv6 » / n'obtient pas de boot

**Cause :** la carte réseau tente l'IPv6 alors que le serveur ne répond qu'en IPv4.

**Solution :** dans le BIOS/UEFI du poste, désactiver « IPv6 PXE », activer « IPv4 PXE », et remonter le boot réseau IPv4 en tête de l'ordre de boot.

Vérifier côté serveur que la demande arrive :

```bash
journalctl -u dnsmasq -f
```

Si rien n'apparaît quand le client démarre, le paquet DHCP n'atteint pas le serveur : mauvaise interface (`IFACE`), ou client/serveur pas sur le même segment L2.

---

## UEFI : `Unable to fetch TFTP image` sur `revocations.efi`

```
Fetching Netboot Image revocations.efi
Unable to fetch TFTP image: TFTP Error
start_image() returned TFTP Error
```

**Cause :** bug connu du shim ≥ 15.8 en boot réseau. Le shim réclame un fichier `revocations.efi` absent et ne bascule pas vers grub.

**Solution :** ce dépôt sert **grubx64.efi directement** (sans shim) — le problème ne se pose donc pas si l'infra a été montée avec `install-base.sh`. Il faut en contrepartie **désactiver Secure Boot** sur le poste client.

Vérifier que dnsmasq sert bien grub en UEFI :

```bash
grep grubx64 /etc/dnsmasq.conf
# doit contenir : dhcp-boot=tag:efi-x86_64,grubx64.efi
```

---

## L'installation Ubuntu démarre en mode interactif (choix de langue)

**Cause :** l'installateur n'a pas récupéré/validé un autoinstall exploitable.

**Vérifications, dans l'ordre :**

1. Le user-data est joignable et son en-tête correct :
   ```bash
   curl http://10.10.10.21/autoinstall/user-data | head -1   # doit être : #cloud-config
   curl -I http://10.10.10.21/autoinstall/meta-data          # doit être : 200 OK
   ```
2. Le `meta-data` **n'est pas vide** (il doit contenir `instance-id:`). Un meta-data vide invalide tout le datasource.
3. Les URL dans le menu pointent vers la **bonne IP** :
   ```bash
   grep vmlinuz /srv/tftp/grub/grub.cfg
   ```
4. Le YAML est valide **et conforme au schéma** (voir plus bas).

---

## `AutoinstallError: Username is reserved by the system: admin`

**Cause :** `admin` est un nom réservé sur Ubuntu.

**Solution :** utiliser un autre identifiant (`AI_USERNAME` dans `config.sh`), par exemple `utilisateur`. À éviter aussi : `root`, `daemon`, `sync`, `games`…

---

## `Malformed autoinstall in 'updates' section` / `False is not of type 'string'`

**Cause :** le champ `updates` attend une **chaîne** (`security` ou `all`), pas un booléen.

**Solution :** garder `updates: security`. Ne jamais mettre `updates: false`.

> À noter : `python3 -c "yaml.safe_load(...)"` ne détecte pas ce type d'erreur (le YAML est syntaxiquement valide) — seul le **schéma** de l'installateur le rejette. Pour valider le schéma, utiliser le validateur officiel de subiquity.

---

## Blocage très long sur `curtin command apt-config`

**Cause :** l'installateur teste un miroir APT sur Internet, absent sur un réseau isolé, et attend le timeout.

**Solution :** le template autoinstall de ce dépôt contient déjà :

```yaml
apt:
  fallback: offline-install
  geoip: false
```

`geoip: false` supprime la détection du miroir, `offline-install` poursuit avec les paquets de l'ISO. Sur un réseau isolé, garder `packages: []` (pas de paquet à télécharger).

---

## Boucle sur `cloud-init-network.service` / `snapd.seeded.service`

**Cause :** ces services attendent un réseau/DNS vers Internet qui n'existe pas.

**Solutions :**

1. **Patienter** : ces jobs finissent par expirer (2–5 min chacun) et l'install reprend souvent seule.
2. Ajouter `network-config=disabled` à la ligne de boot (déjà présent pour la méthode NFS dans ce dépôt) pour couper la config réseau automatique de cloud-init.

---

## Kernel panic : `system is deadlocked on memory`

**Cause :** méthode **RAM** (`url=`) sur un poste qui n'a pas assez de mémoire pour charger l'ISO (~6 Go) en RAM.

**Solution :** passer la méthode de boot en **NFS** dans `config.sh` :

```bash
UBUNTU_BOOT_METHOD="nfs"     # ou XUBUNTU_BOOT_METHOD="nfs"
```

puis relancer le `add-*.sh` correspondant. En NFS, l'ISO reste montée depuis le serveur : un poste de 2–4 Go suffit.

---

## Écran noir avec un simple `_` après le démarrage

**Causes possibles :**

- **Chargement long** (surtout en NFS) : patienter 5 minutes.
- **Installation silencieuse en cours** (`interactive-sections: []`) : c'est peut-être normal. Vérifier sur une console (**Ctrl+Alt+F2**) :
  ```bash
  systemctl list-jobs
  tail -f /var/log/installer/subiquity-server-debug.log
  ```
  Si les logs défilent, l'install travaille — laisser finir.
- **Problème graphique** : ajouter `nomodeset` à la ligne de boot pour forcer un mode vidéo générique.

Pour rendre le boot **verbeux** et voir où ça se fige :

```bash
sudo sed -i 's/ quiet//g; s/ splash//g' /srv/tftp/grub/grub.cfg /srv/tftp/pxelinux.cfg/default
```

---

## Boot NFS : `nfs: server 10.10.10.21 not responding`

**Cause :** le montage NFS ne se fait pas.

**Vérifications côté serveur :**

```bash
exportfs -v                       # l'export /srv/nfs/<os> doit apparaître
systemctl is-active nfs-kernel-server
```

Pare-feu : les ports **2049** et **111** doivent être ouverts. Vérifier aussi que le client est bien sur le sous-réseau autorisé (`SUBNET` dans `config.sh`).

---

## Où lire les logs d'installation (sur le client)

Depuis une console de l'installateur (**Ctrl+Alt+F2**) :

```bash
cat /proc/cmdline                                   # paramètres réellement reçus
tail -n 40 /var/log/installer/subiquity-server-debug.log
grep -i -E "error|fail|traceback" /var/log/installer/subiquity-server-debug.log
cat /var/log/cloud-init.log | grep -i nocloud
lsblk                                               # disques vus par l'installateur
```
