#!/bin/zsh
# The "Queen's Domain" app in /Applications runs this. It makes sure Steam still knows how to
# run the game on a Mac (Steam forgets after game updates), then asks Steam to start it, so
# Steam Cloud syncs your saves and tracks playtime.
# Hold Option while opening the app to show the FPS overlay.
D=~/Games/QueensDomainMac
PY() { /usr/bin/python3 -I $D/qd_steam.py "$@" 2>>$D/sync.log; }
log() { echo "$(date '+%F %T') $*" >> $D/sync.log; }
say() { osascript -e "display dialog \"$1\" with title \"Queen's Domain\" buttons {\"OK\"} default button 1" >/dev/null 2>&1; }
steam_quit() {
  pgrep -x steam_osx >/dev/null || return 0
  osascript -e 'tell application "Steam" to quit' 2>/dev/null
  for i in {1..60}; do pgrep -x steam_osx >/dev/null || return 0; sleep 1; done
  return 1
}

if [[ "$(osascript -l JavaScript -e 'ObjC.import("AppKit"); ($.NSEvent.modifierFlags & 524288) != 0')" == "true" ]]; then
  touch $D/hud
fi

PY has-app; rc=$?
if (( rc == 3 )); then
  say "Steam has changed how it stores game settings, so this app can't set the game up any more. Run the installer's check (see the README) or ask for help."
  exit 1
elif (( rc != 0 )); then
  open -a Steam
  say "Open Steam, sign in, and make sure Queen's Domain is in your library. Then quit Steam (Steam menu → Quit Steam) and open this app again."
  exit 0
fi

if ! PY is-patched; then
  if ! steam_quit; then
    say "Steam needs to close for a moment so the game can be set up, but it didn't close. Quit Steam yourself (Steam menu → Quit Steam), then open this app again. If macOS asked whether this app may control Steam, choose Allow."
    exit 1
  fi
  if ! PY patch >> $D/sync.log; then
    say "Couldn't update Steam's settings for the game. Details are in ~/Games/QueensDomainMac/sync.log."
    exit 1
  fi
  log "re-applied Steam patch"
  PY steaminput-off >> $D/sync.log
fi

if ! PY installed; then
  open "steam://install/1799840"
  say "Steam is installing the game (about 2.2 GB). Click Install in Steam if it asks. When the download has finished, open this app again."
  exit 0
fi

# The small script Steam starts when you press Play.
GAMEDIR=$(PY gamedir)
if [[ ! -x "$GAMEDIR/QueensDomainMac" ]]; then
  printf '#!/bin/zsh\nexec ~/Games/QueensDomainMac/steam-entry.sh "$@"\n' > "$GAMEDIR/QueensDomainMac"
  chmod +x "$GAMEDIR/QueensDomainMac"
fi

open "steam://rungameid/1799840"
