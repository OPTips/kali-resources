#!/usr/bin/env bash
# vpn-connect.sh — Menu interactif de sélection de profil OpenVPN
# Usage : ./vpn-connect.sh [répertoire]  (défaut : répertoire courant)

OVPN_DIR="${1:-$(pwd)}"

# ── Styles terminal ────────────────────────────────────────────────────────────
RESET=$(tput sgr0)
BOLD=$(tput bold)
REV=$(tput rev)
FG_CYAN=$(tput setaf 6)
FG_GREEN=$(tput setaf 2)
FG_YELLOW=$(tput setaf 3)
FG_RED=$(tput setaf 1)
FG_GRAY=$(tput setaf 8 2>/dev/null || tput setaf 7)

# ── Vérifications ──────────────────────────────────────────────────────────────
if [[ ! -d "$OVPN_DIR" ]]; then
    echo "${FG_RED}Erreur :${RESET} répertoire '$OVPN_DIR' introuvable." >&2
    exit 1
fi

mapfile -t FILES < <(find "$OVPN_DIR" -maxdepth 1 -name "*.ovpn" -type f | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "${FG_RED}Erreur :${RESET} aucun fichier .ovpn trouvé dans '$OVPN_DIR'." >&2
    exit 1
fi

TOTAL=${#FILES[@]}

# ── Dessin du menu ─────────────────────────────────────────────────────────────
draw_menu() {
    local selected=$1

    tput clear
    echo ""
    echo "  ${BOLD}${FG_CYAN}╔══════════════════════════════════════╗${RESET}"
    echo "  ${BOLD}${FG_CYAN}║       OpenVPN — Choix du profil      ║${RESET}"
    echo "  ${BOLD}${FG_CYAN}╚══════════════════════════════════════╝${RESET}"
    echo ""
    echo "  ${FG_YELLOW}Répertoire :${RESET} $OVPN_DIR"
    echo ""
    echo "  ${FG_GRAY}↑ ↓  naviguer   Entrée  lancer   q  quitter${RESET}"
    echo "  ${FG_GRAY}──────────────────────────────────────────${RESET}"
    echo ""

    for i in "${!FILES[@]}"; do
        local name
        name=$(basename "${FILES[$i]}")
        if [[ $i -eq $selected ]]; then
            printf "  ${BOLD}${REV}  ▶  %-34s ${RESET}\n" "$name"
        else
            printf "     ${FG_GRAY}%-34s${RESET}\n" "$name"
        fi
    done

    echo ""
    printf "  ${FG_GRAY}Profil %d / %d${RESET}\n" $(( selected + 1 )) "$TOTAL"
}

# ── Nettoyage à la sortie ──────────────────────────────────────────────────────
cleanup() {
    tput cnorm   # Restaure le curseur
    tput rmcup   # Restaure l'écran d'origine (si supporté)
}
trap cleanup INT TERM EXIT

# ── Boucle principale ──────────────────────────────────────────────────────────
tput smcup      # Sauvegarde l'écran
tput civis      # Cache le curseur

selected=0

while true; do
    draw_menu "$selected"

    IFS= read -rs -n1 key

    # Séquences d'échappement (flèches, etc.)
    if [[ $key == $'\x1b' ]]; then
        read -rs -n2 -t 0.15 seq
        key+="$seq"
    fi

    case "$key" in
        $'\x1b[A' | k)   # ↑ ou k (vim)
            (( selected-- ))
            (( selected < 0 )) && selected=$(( TOTAL - 1 ))
            ;;
        $'\x1b[B' | j)   # ↓ ou j (vim)
            (( selected++ ))
            (( selected >= TOTAL )) && selected=0
            ;;
        $'\x0a' | $'\x0d' | ' ')  # Entrée ou Espace
            break
            ;;
        $'\x1b' | q | Q)   # Échap, q
            tput cnorm
            tput rmcup
            echo "Connexion annulée."
            exit 0
            ;;
    esac
done

# ── Lancement ─────────────────────────────────────────────────────────────────
chosen="${FILES[$selected]}"
name=$(basename "$chosen")

tput cnorm
tput rmcup

echo ""
echo "${BOLD}${FG_GREEN}▶  Connexion :${RESET} $name"
echo "${FG_GRAY}   sudo openvpn \"$chosen\"${RESET}"
echo ""

sudo openvpn "$chosen"