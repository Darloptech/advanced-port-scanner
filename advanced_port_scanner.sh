#!/bin/bash

###############################################
#  PORT SCANNER AVANCÉ – CYBERSEC EDITION
#  Fonctionnalités :
#   - Interface graphique Zenity
#   - Scan TCP / UDP
#   - Scan de services (-sV)
#   - Multithread (T3/T4/T5)
#   - Rapport TXT / JSON / CSV / HTML
#   - Choix de l'emplacement du rapport
#   - Logs + couleurs + bannière ASCII
###############################################

### Dépendances :
# sudo apt install zenity nmap -y

# Couleurs terminal
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

# Bannière ASCII
echo -e "${BLUE}========================================"
echo -e "   PORT SCANNER – CYBERSEC EDITION"
echo -e "========================================${RESET}"

# Dossier logs
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/scan_${TIMESTAMP}.log"

###############################################
# 1. Cible
###############################################
TARGET=$(zenity --entry --title="Cible" --text="Entrez l'adresse IP ou le nom de domaine :")
[ -z "$TARGET" ] && zenity --error --text="Aucune cible fournie." && exit 1

###############################################
# 2. Emplacement du rapport
###############################################
SAVE_PATH=$(zenity --file-selection --save \
    --title="Choisir l'emplacement du rapport" \
    --confirm-overwrite \
    --filename="rapport_scan_${TIMESTAMP}.txt")

[ -z "$SAVE_PATH" ] && zenity --error --text="Aucun emplacement choisi." && exit 1

BASE_NAME="${SAVE_PATH%.*}"
REPORT_TXT="${BASE_NAME}.txt"
REPORT_JSON="${BASE_NAME}.json"
REPORT_CSV="${BASE_NAME}.csv"
REPORT_HTML="${BASE_NAME}.html"

###############################################
# 3. Choix des ports
###############################################
PORT_MODE=$(zenity --list --radiolist \
    --title="Choix des ports" \
    --column="Choix" --column="Description" \
    TRUE "Ports courants" \
    FALSE "Ports personnalisés")

if [ "$PORT_MODE" == "Ports courants" ]; then
    PORTS="20,21,22,23,25,53,80,110,139,443,445,3389"
else
    PORTS=$(zenity --entry --title="Ports personnalisés" --text="Ex: 22,80,443")
    [ -z "$PORTS" ] && zenity --error --text="Aucun port fourni." && exit 1
fi

###############################################
# 4. Options avancées (UDP, -sV)
###############################################
OPTIONS=$(zenity --list --checklist \
    --title="Options avancées" \
    --column="Activer" --column="Option" \
    FALSE "Scan UDP (-sU)" \
    FALSE "Scan de services (-sV)" \
    FALSE "Scan agressif (-A)" \
    FALSE "Détection OS (-O)" \
    FALSE "Traceroute (--traceroute)" \
    --separator=" ")

NMAP_EXTRA=""

[[ $OPTIONS == *"Scan UDP"* ]] && NMAP_EXTRA="$NMAP_EXTRA -sU"
[[ $OPTIONS == *"Scan de services"* ]] && NMAP_EXTRA="$NMAP_EXTRA -sV"
[[ $OPTIONS == *"Scan agressif"* ]] && NMAP_EXTRA="$NMAP_EXTRA -A"
[[ $OPTIONS == *"Détection OS"* ]] && NMAP_EXTRA="$NMAP_EXTRA -O"
[[ $OPTIONS == *"Traceroute"* ]] && NMAP_EXTRA="$NMAP_EXTRA --traceroute"

###############################################
# 5. Vitesse du scan
###############################################
SPEED=$(zenity --list --radiolist \
    --title="Vitesse du scan" \
    --column="Choix" --column="Profil" \
    TRUE "Rapide (T4)" \
    FALSE "Très rapide (T5)" \
    FALSE "Normal (T3)")

case "$SPEED" in
    "Rapide (T4)" ) NMAP_SPEED="-T4" ;;
    "Très rapide (T5)" ) NMAP_SPEED="-T5" ;;
    "Normal (T3)" ) NMAP_SPEED="-T3" ;;
esac

###############################################
# 6. Scan avec barre de progression
###############################################
(
echo "10"; echo "# Initialisation..."

echo "30"; echo "# Scan Nmap en cours..."

nmap $NMAP_SPEED -p "$PORTS" $NMAP_EXTRA "$TARGET" -oG - > "$LOG_FILE"

echo "70"; echo "# Génération des rapports..."

###############################################
# 7. Génération TXT / JSON / CSV
###############################################
> "$REPORT_TXT"
> "$REPORT_JSON"
> "$REPORT_CSV"

echo "Rapport de scan" >> "$REPORT_TXT"
echo "Cible : $TARGET" >> "$REPORT_TXT"
echo "Ports : $PORTS" >> "$REPORT_TXT"
echo "Options : $NMAP_EXTRA" >> "$REPORT_TXT"
echo "Date : $(date)" >> "$REPORT_TXT"
echo "----------------------------------------" >> "$REPORT_TXT"

echo "{" >> "$REPORT_JSON"
echo "  \"target\": \"$TARGET\"," >> "$REPORT_JSON"
echo "  \"date\": \"$(date)\"," >> "$REPORT_JSON"
echo "  \"options\": \"$NMAP_EXTRA\"," >> "$REPORT_JSON"
echo "  \"ports\": [" >> "$REPORT_JSON"

echo "port,status" >> "$REPORT_CSV"

FIRST=1
grep "Ports:" "$LOG_FILE" | while read -r line; do
    PORT_LINE=$(echo "$line" | sed -n 's/.*Ports: //p')
    IFS=',' read -ra PORT_ARRAY <<< "$PORT_LINE"

    for entry in "${PORT_ARRAY[@]}"; do
        PORT=$(echo "$entry" | cut -d'/' -f1)
        STATE=$(echo "$entry" | cut -d'/' -f2)

        echo "Port $PORT : $STATE" >> "$REPORT_TXT"
        echo "$PORT,$STATE" >> "$REPORT_CSV"

        if [ $FIRST -eq 1 ]; then FIRST=0; else echo "," >> "$REPORT_JSON"; fi
        echo "    { \"port\": $PORT, \"status\": \"$STATE\" }" >> "$REPORT_JSON"
    done
done

echo "  ]" >> "$REPORT_JSON"
echo "}" >> "$REPORT_JSON"

###############################################
# 8. Rapport HTML (portfolio-ready)
###############################################
cat <<EOF > "$REPORT_HTML"
<html>
<head>
<title>Rapport de scan – $TARGET</title>
<style>
body { font-family: Arial; background:#111; color:#eee; padding:20px; }
h1 { color:#4CAF50; }
table { width:100%; border-collapse: collapse; margin-top:20px; }
td, th { border:1px solid #555; padding:8px; }
th { background:#333; }
.open { color:#4CAF50; font-weight:bold; }
.closed { color:#F44336; }
</style>
</head>
<body>
<h1>Rapport de scan – $TARGET</h1>
<p><b>Date :</b> $(date)</p>
<p><b>Ports :</b> $PORTS</p>
<p><b>Options :</b> $NMAP_EXTRA</p>

<table>
<tr><th>Port</th><th>État</th></tr>
EOF

grep "Ports:" "$LOG_FILE" | sed 's/.*Ports: //' | tr ',' '\n' | while read -r entry; do
    PORT=$(echo "$entry" | cut -d'/' -f1)
    STATE=$(echo "$entry" | cut -d'/' -f2)
    CLASS="closed"
    [[ "$STATE" == "open" ]] && CLASS="open"
    echo "<tr><td>$PORT</td><td class=\"$CLASS\">$STATE</td></tr>" >> "$REPORT_HTML"
done

echo "</table></body></html>" >> "$REPORT_HTML"

echo "100"; echo "# Terminé !"
) | zenity --progress --title="Scan de ports" --percentage=0 --auto-close

###############################################
# 9. Message final
###############################################
zenity --info --text="Scan terminé !\n\nRapports générés :\n- $REPORT_TXT\n- $REPORT_JSON\n- $REPORT_CSV\n- $REPORT_HTML\n\nLogs : $LOG_FILE"

