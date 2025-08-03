#!/bin/bash

# Vérifie l'existence des commandes requises
check_required_commands() {
    local missing=0
    local cmds=(curl jq xmllint)
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Erreur : commande requise non trouvée : $cmd" >&2
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        echo "Veuillez installer les commandes manquantes et relancer le script." >&2
        exit 1
    fi
}

# Appel de la vérification au début du script
check_required_commands

# Chargement des variables sensibles depuis .env
if [ -f "$curdir/.env" ]; then
    source "$curdir/.env"
else
    echo "Fichier .env introuvable. Veuillez créer .env en prenant exemple sur .env.example." >&2
    exit 1
fi

# Fonction pour extraire la date de publication à partir du champ dth
# dth est un JSON avec les champs day, month, hours, minutes
# Exemple dth : {"day": "1", "month": "Janv.", "hours": "12", "minutes": "30"}
# Retourne une chaîne de caractères au format YYYYMMDDHHMM
get_postdate_from_dth() {
    local dth="$1"
    # Extraction des champs de dth
    local day month hours minutes monthnum year postdate

    day=$(echo "$dth" | jq -r '.day')
    month=$(echo "$dth" | jq -r '.month')
    hours=$(echo "$dth" | jq -r '.hours')
    minutes=$(echo "$dth" | jq -r '.minutes')

    # Conversion du mois texte en numéro
    case "$month" in
        "Janv."*) monthnum="01" ;;
        "Févr."*) monthnum="02" ;;
        "Mars"*) monthnum="03" ;;
        "Avr."*) monthnum="04" ;;
        "Mai"*) monthnum="05" ;;
        "Juin"*) monthnum="06" ;;
        "Juil."*) monthnum="07" ;;
        "Août"*) monthnum="08" ;;
        "Sept."*) monthnum="09" ;;
        "Oct."*) monthnum="10" ;;
        "Nov."*) monthnum="11" ;;
        "Déc."*) monthnum="12" ;;
        *) monthnum="00" ;;
    esac

    # Année courante (ou à adapter si besoin)
    year=$(date +%Y)

    # Ajout du padding zéro si besoin (suppression du zéro initial pour éviter l'octal)
    printf -v day "%02d" "$((10#$day))"
    printf -v hours "%02d" "$((10#$hours))"
    printf -v minutes "%02d" "$((10#$minutes))"

    postdate="${year}${monthnum}${day}${hours}${minutes}"
    echo "$postdate"
}

urlbase="https://www.ondonnedesnouvelles.com"
connect="/connect"
checkuser="$connect/check-email-username"
signin="$connect/signin"
spaceslist="/spaces/list"

curdir=$(dirname "$0")
wdir="$curdir/working"
ddir="$curdir/data"
mkdir -p "$wdir"
mkdir -p "$ddir"



# Gestion du paramètre overwrite via .env
if [ -z "$OVERWRITE" ]; then
    overwrite=0
else
    overwrite="$OVERWRITE"
fi

# Gestion du paramètre de vérification SSL via .env
if [ -z "$VERIFY_SSL" ]; then
    VERIFY_SSL=0
fi
if [ "$VERIFY_SSL" -eq 0 ]; then
    CURL_INSECURE="--insecure"
else
    CURL_INSECURE=""
fi

ficlistspaces="$wdir/listspaces"



username="$USERNAME"
password="$PASSWORD"

cookiejar="$wdir/cookies.txt"

# echo "Fichier temporaire : $cookiejar"


clicurl="curl -b $cookiejar -c $cookiejar $CURL_INSECURE "
#clicurl="curl $CURL_INSECURE "

tmp_file="$wdir/tmp.html"

$clicurl "$urlbase$connect" > $tmp_file
csrftoken=$(cat $tmp_file | xmllint --html --xpath 'string(/html/head/meta[@name="csrf-token"]/@content)' - )
echo "$csrftoken"

$clicurl "$urlbase$checkuser" -X POST \
  -H "x-csrf-token: $csrftoken" \
  -H "x-requested-from: Reactor" \
  -H "x-requested-with: XMLHttpRequest" \
  -d @- \
  -H 'Content-Type: application/json' <<BODY
 {"username":"$username"}
BODY

clicurl="curl -s -b $cookiejar -c $cookiejar --insecure "
$clicurl "$urlbase$signin" \
  -X POST \
  -H "x-csrf-token: $csrftoken" \
  -H "x-requested-from: Reactor" \
  -H "x-requested-with: XMLHttpRequest" \
  -H 'Content-Type: multipart/form-data; boundary=---------------------------3887306087328791569216753937' \
  -H 'Referer: https://www.ondonnedesnouvelles.com/connect' \
  --data-binary \
  $'-----------------------------3887306087328791569216753937\r\nContent-Disposition: form-data; name="username"\r\n\r\n'$username$'\r\n-----------------------------3887306087328791569216753937\r\nContent-Disposition: form-data; name="password"\r\n\r\n'$password$'\r\n-----------------------------3887306087328791569216753937\r\nContent-Disposition: form-data; name="remember"\r\n\r\ntrue\r\n-----------------------------3887306087328791569216753937--\r\n'
  
$clicurl "$urlbase/dashboard" > $tmp_file
csrftoken=$(cat $tmp_file | xmllint --html --xpath 'string(/html/head/meta[@name="csrf-token"]/@content)' - )
echo "$csrftoken"

$clicurl "$urlbase$spaceslist" > "$ficlistspaces"

ficjournal="$wdir/listjournal"
ficpost="$wdir/post"

cat "$ficlistspaces" | jq -r '.spaces[].uuid, .spaces_soon_archived[].uuid' | while read -r idjournal
do 
    echo "traitement journal : $idjournal"; 
    journalpid=1
    while [ "$journalpid" != "null" ]
    do
        echo "page $journalpid"
        $clicurl "$urlbase/journal/$idjournal/list?published_date_order=1&page=$journalpid" > "$ficjournal"
        journalpid=$(cat "${ficjournal}" | jq -r ".next_page")

        cat "$ficjournal" | jq -r '.data[] | select(.model == "post") | "\(.id)\t\(.activity_date_detailed)"' | while read -r idpost dth
        do
            echo "traitement post : $idpost"; 

            postdate=$(get_postdate_from_dth "$dth")
            echo "postdate : $postdate"

            # journalpid pour la pagination
            postpid=1
            postlastpage=10
            while [ $postpid -le $postlastpage ]
            do
                echo "page $postpid"
                $clicurl "$urlbase/journal/$idjournal/posts/photos/$idpost?page=$postpid&per_page=25" > "$ficpost"
                postlastpage=$(cat "${ficpost}" | jq -r ".last_page")

                cat "$ficpost" | jq -r '.data[] | "\(.id)\t\(.src)\t\(.extension)"' | while read -r idimg src extension
                do
                    echo "traitement image : $idimg";
                    #echo "src : $src"
                    #echo "extension : $extension"
                    # Ici, vous pouvez ajouter le traitement de l'image si nécessaire
                    mkdir -p "$ddir/$idjournal/$postdate"
                    imgfile="$ddir/$idjournal/$postdate/$idimg.$extension"
                    if [ ! -f "$imgfile" ] || [ "$overwrite" -eq 1 ]; then
                        echo "Téléchargement de l'image $idimg à $imgfile"
                        $clicurl "$src" -o "$imgfile"
                    else
                        echo "Image $imgfile déjà existante, saut du téléchargement."
                    fi
                    

                done


                # Incrémentation de postpid
                postpid=$((postpid + 1))
            done
        done

    done
done


# $clicurl "$urlbase$spaceslist"
