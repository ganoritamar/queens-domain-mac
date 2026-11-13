#!/bin/zsh
# Mac Steam runs this (through the QueensDomainMac stub in the game folder) when you press Play.
# Steam has just downloaded your cloud saves into CLOUD. The game itself, running in Wine,
# reads and writes the save folder inside the Whisky bottle (GAME). Newer cloud saves are
# copied in before playing and the game's saves copied back afterwards; Steam uploads them
# when this script exits.
D="${0:A:h}"
log() { echo "$(date '+%F %T') $*" >> "$D/sync.log"; }
mkdir -p "$D/backups"

eval "$(/Applications/Whisky.app/Contents/Resources/WhiskyCmd shellenv "Queens Domain")"
export WINEDEBUG=-all
GAMEDIR=$(/usr/bin/python3 -I "$D/qd_steam.py" gamedir)
# The game's save folder inside the bottle (Whisky's Windows user is normally "crossover")
WUSER=crossover
[[ -d "$WINEPREFIX/drive_c/users/$WUSER" ]] || WUSER=$(ls "$WINEPREFIX/drive_c/users" 2>/dev/null | grep -vx Public | head -1)
GAME="$WINEPREFIX/drive_c/users/${WUSER:-crossover}/AppData/Local/QueensDomain/Saved/SaveGames"
SID=$(/usr/bin/python3 -I "$D/qd_steam.py" steamid 2>/dev/null)
CLOUD="$HOME/Library/Application Support/QueensDomain/Saved/SaveGames/$SID"
mkdir -p "$GAME"

if [[ -n $SID ]]; then
  mkdir -p "$CLOUD"
  for f in "$CLOUD"/*.sav(N); do
    g="$GAME/${f:t}"
    if [[ ! -e "$g" || "$f" -nt "$g" ]] && ! cmp -s "$f" "$g"; then
      [[ -e "$g" ]] && cp -p "$g" "$D/backups/${f:t:r}.mac-$(date +%Y%m%d-%H%M%S).sav"
      cp -p "$f" "$g"; log "cloud -> mac: ${f:t}"
    fi
  done
else
  log "no Steam account found, cloud sync skipped"
fi

[[ -e "$D/hud" ]] && { export MTL_HUD_ENABLED=1; rm -f "$D/hud"; }

# The intro/loading movies hang on a black screen under Wine. Game updates bring them back.
mkdir -p "$D/movies-backup"
for m in "$GAMEDIR"/QueensDomain/Content/Movies/*.mp4(N); do
  mv -f "$m" "$D/movies-backup/"; log "moved movie aside: ${m:t}"
done

log "game start"
cd "$GAMEDIR/QueensDomain/Binaries/Win64" && wine64 QueensDomain-Win64-Shipping.exe -dx11 >/dev/null 2>&1
wineserver -w 2>/dev/null
log "game exit"

if [[ -n $SID ]]; then
  for g in "$GAME"/*.sav(N); do
    f="$CLOUD/${g:t}"
    cmp -s "$g" "$f" || { cp -p "$g" "$f"; log "mac -> cloud: ${g:t}"; }
  done
fi
# keep the last 20 backups
ls -t "$D"/backups/*.mac-*.sav(N) 2>/dev/null | tail -n +21 | xargs rm -f
