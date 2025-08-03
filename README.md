# oddn_dl_photos

Ce dépôt permet de télécharger automatiquement les photos des journaux du site [ondonnedesnouvelles.com](https://www.ondonnedesnouvelles.com) via un script Bash.

## Fonctionnalités
- Authentification automatique (avec gestion des cookies)
- Téléchargement des photos par journal et par post
- Organisation des images dans des dossiers structurés
- Gestion de l'écrasement des fichiers existants
- Paramétrage via un fichier `.env` (identifiants, options)
- Vérification des dépendances nécessaires

## Installation
1. Clonez le dépôt :
   ```bash
   git clone https://github.com/neopi21/oddn_dl_photos.git
   ```
2. Installez les dépendances nécessaires :
   - `curl`, `jq`, `xmllint`, `bash`
3. Copiez le fichier `.env` et renseignez vos identifiants :
   ```bash
   cp .env.example .env
   # puis éditez .env
   ```

## Utilisation
Lancez le script principal :
```bash
bash oddn.sh
```

### Paramètres du fichier `.env`
- `USERNAME` : votre identifiant de connexion
- `PASSWORD` : votre mot de passe
- `OVERWRITE` : mettre à 1 pour forcer le téléchargement des images même si elles existent
- `VERIFY_SSL` : mettre à 1 pour vérifier le certificat SSL, 0 pour ignorer (option `--insecure`)

## Dépendances
- `curl`
- `jq`
- `xmllint`
- `bash`

## Remerciements
Ce projet s'inspire fortement du dépôt GitHub [skippylegrandgourou/oddn_photos_dl](https://github.com/skippylegrandgourou/oddn_photos_dl).

## Licence
Ce projet est sous licence MIT. Voir le fichier LICENSE.
