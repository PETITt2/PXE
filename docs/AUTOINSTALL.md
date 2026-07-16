# Autoinstall (méthode alternative)

Cette page décrit l'installation automatisée d'un OS par PXE (Ubuntu autoinstall,
Debian preseed), proposée en **alternative** au déploiement d'image Clonezilla.

## Quand l'utiliser, quand ne pas l'utiliser

L'autoinstall n'a pas fonctionné de bout en bout sur le parc initial (postes à
4 Go de RAM, réseau isolé, problèmes d'affichage). Voir
[HISTORIQUE.md](HISTORIQUE.md). Elle reste pertinente **dans des conditions
favorables** :

| Cas | Autoinstall utilisable ? |
|---|---|
| Poste >= 8 Go de RAM | Oui (y compris Desktop en RAM) |
| Poste 4 Go de RAM | Seulement Ubuntu live-server (console), ou Debian |
| Clients avec accès Internet | Oui, sans contrainte de miroir local |
| Clients sur réseau isolé | Ubuntu : OK (ISO servie en local). Debian : miroir local requis. |
| Matériel avec affichage capricieux | Debian (installateur texte) plutôt qu'Ubuntu |

Pour un parc modeste et isolé, le déploiement Clonezilla reste la méthode
recommandée (voir [WORKFLOW.md](WORKFLOW.md)).

## Ubuntu (add-ubuntu.sh)

Réglages dans `config.sh` :

- `UBUNTU_FLAVOR` : `live-server` (console, léger, OK 4 Go) ou `desktop`
  (bureau GNOME, nécessite >= 8 Go de RAM en méthode `ram`).
- `UBUNTU_BOOT_METHOD` : `ram` (l'ISO est chargée en RAM) ou `nfs` (l'ISO reste
  sur le serveur, pas de contrainte de RAM mais démarrage plus fragile).
- `UBUNTU_VERSION`.

```
sudo ./add-ubuntu.sh
```

Le script télécharge l'ISO, en extrait le noyau/initrd, sert l'ISO en local,
génère le user-data/meta-data (compte `AI_USERNAME`) et ajoute l'entrée au menu.
L'installation est entièrement automatique (`interactive-sections: []`) et
efface le disque.

Points de configuration déjà intégrés (issus du débogage, voir
TROUBLESHOOTING.md) : identifiant non réservé, `updates: security`,
`apt geoip:false` + `offline-install`, `cloud-config-url=/dev/null`, meta-data
avec `instance-id`.

## Debian (add-debian.sh)

Installateur en mode texte (évite l'écran noir de certains matériels). Réglages
dans `config.sh` :

- `DEBIAN_SUITE` : la version stable (ex. `trixie`).
- `DEBIAN_MIRROR_MODE` :
  - `online` : les clients tirent les paquets d'un miroir Debian public. Simple,
    mais **les postes doivent avoir Internet pendant l'installation**.
  - `local` : installation 100% hors-ligne depuis un miroir local. Nécessite de
    construire ce miroir au préalable (voir ci-dessous).
- `DEBIAN_TASKS` : le(s) environnement(s) installés par tasksel (ex.
  `xfce-desktop, standard, ssh-server`).

### Mode online

```
sudo ./add-debian.sh
```

Récupère le netboot officiel et écrit un preseed pointant vers le miroir public.

### Mode local (hors-ligne)

Le point délicat de Debian par PXE est l'alignement entre l'installateur et les
paquets : ils doivent venir de la même build, sinon l'installateur échoue avec
"aucun module de noyau trouvé". Le DVD-1 seul ne suffit pas (il ne contient pas
d'installateur netboot). La solution fiable est un miroir complet construit avec
`debmirror`, qui récupère aussi les images d'installation alignées :

```
# 1. Construire le miroir (serveur avec Internet, long, ~80-90 Go)
sudo ./build-debian-mirror.sh

# 2. Basculer le mode et ajouter l'entree
#    (mettre DEBIAN_MIRROR_MODE="local" dans config.sh)
sudo ./add-debian.sh
```

Le miroir conserve le `InRelease` signé par Debian (reconnu nativement, pas
d'erreur de signature) et le netboot est pris dans le miroir (installateur et
udebs alignés). Les clients installent alors entièrement hors-ligne.

## Diagnostic

En cas de blocage pendant une installation, consulter les logs sur le client :

```
cat /proc/cmdline
tail -n 40 /var/log/syslog                                  # Debian
tail -n 40 /var/log/installer/subiquity-server-debug.log    # Ubuntu
```

Les erreurs classiques et leurs correctifs sont dans
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).
