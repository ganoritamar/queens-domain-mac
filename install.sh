#!/bin/zsh
# Sets up Queen's Domain (Windows-only Steam game) to run on an Apple Silicon Mac.
# Safe to run again: every step checks whether it's already done.
#   zsh install.sh          install
#   zsh install.sh --check  only report what's done and what's missing; change nothing
set -u
REPO="${0:A:h}"
CHECK=0; [[ ${1:-} == --check ]] && CHECK=1

# Pinned downloads (tested versions) and their SHA-256 fingerprints
WHISKY_URL="https://github.com/IsaacMarovitz/Whisky/releases/download/v2.3.5/Whisky.zip"
WHISKY_SHA=62fce6aa7034cc84e4809a35cb46af37e7932368102450dd2b3d4a18cbc7b94e
GPTK_URL="https://github.com/Gcenx/game-porting-toolkit/releases/download/Game-Porting-Toolkit-3.0-3/game-porting-toolkit-3.0-3.tar.xz"
GPTK_SHA=d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e
CAPSULE="https://cdn.cloudflare.steamstatic.com/steam/apps/1799840/library_600x900_2x.jpg"

WHISKY=/Applications/Whisky.app
WCMD=$WHISKY/Contents/Resources/WhiskyCmd
LIBS="$HOME/Library/Application Support/com.isaacmarovitz.Whisky/Libraries"
HELPER=~/Games/QueensDomainMac
APP="/Applications/Queen's Domain.app"
TMP=$(mktemp -d /tmp/qd-install.XXXX)
trap 'rm -rf "$TMP"' EXIT

bold() { print -P "%B$*%b"; }
ok()   { print -P "  %F{green}✓%f $*"; }
todo() { print -P "  %F{yellow}•%f $*"; }
die()  { print -P "\n%F{red}✗ $*%f"; exit 1; }
# When run by Claude Code (no keyboard attached), stop with the instruction instead of waiting.
pause() {
  [[ -t 0 ]] || die "ACTION NEEDED: $1 Then run this installer again."
  print; read -r "?$1 Press Enter when done… "
}
PY() { /usr/bin/python3 -I "$REPO/lib/qd_steam.py" "$@"; }
steam_quit() {
  pgrep -x steam_osx >/dev/null || return 0
  echo "  Closing Steam for a moment (if macOS asks whether Terminal may control Steam, click Allow)…"
  osascript -e 'tell application "Steam" to quit' 2>/dev/null
  for i in {1..90}; do pgrep -x steam_osx >/dev/null || return 0; sleep 1; done
  die "Steam didn't close. Quit it yourself (Steam menu → Quit Steam), then run this again."
}
fetch() {  # fetch URL FILE SHA256
  curl -fL# --retry 3 -o "$2" "$1" || die "Couldn't download $1 — check the internet connection and run this again."
  [[ $(shasum -a 256 "$2" | cut -d' ' -f1) == $3 ]] || die "The download of ${1:t} doesn't match the tested version. Nothing was installed. (The file on GitHub may have changed — ask for help.)"
}
steam_check() {  # has-app, but stop on format errors
  PY has-app; local rc=$?
  (( rc == 3 )) && die "Steam has changed how it stores game settings, so this installer can't set the game up. Ask for help (see CLAUDE_PROMPT.md)."
  return $rc
}

bold "Queen's Domain for Mac — setup$([[ $CHECK == 1 ]] && echo ' (check only)')"

# 1. This Mac
bold "\n1. This Mac"
[[ $(uname -m) == arm64 ]] || die "This needs a Mac with an Apple chip (M1 or newer)."
ok "Apple chip"
major=$(sw_vers -productVersion | cut -d. -f1)
(( major >= 15 )) || die "This needs macOS 15 Sequoia or newer (this Mac has $(sw_vers -productVersion)). Update in System Settings → General → Software Update, then run this again."
ok "macOS $(sw_vers -productVersion)"
ram=$(( $(sysctl -n hw.memsize) / 1073741824 ))
(( ram >= 16 )) && ok "${ram} GB memory" || todo "${ram} GB memory — the game may stutter; close other apps while playing"
id -Gn | tr ' ' '\n' | grep -qx admin || die "Your Mac user account needs to be an administrator (System Settings → Users & Groups)."
ok "Administrator account"
free_gb=$(( $(df -k ~ | awk 'NR==2{print $4}') / 1048576 ))
(( free_gb >= 8 )) || die "Only ${free_gb} GB free. You need about 8 GB (game 2.2 GB + Windows layer 1.5 GB + room)."
ok "${free_gb} GB free"

if xcode-select -p >/dev/null 2>&1 && /usr/bin/python3 -c '' 2>/dev/null; then ok "Apple Command Line Tools"
else
  todo "Apple Command Line Tools missing"
  [[ $CHECK == 1 ]] || { xcode-select --install 2>/dev/null; die "A window opened to install Apple's Command Line Tools. Click Install, wait for it to finish (can take 10+ minutes), then run this again."; }
fi

if arch -x86_64 /usr/bin/true 2>/dev/null; then ok "Rosetta"
else
  todo "Rosetta missing (the Windows layer needs it)"
  if [[ $CHECK == 0 ]]; then
    echo "  Installing Rosetta. If asked, type A and press Enter to agree to Apple's license; it may ask for your Mac password."
    [[ -t 0 ]] || die "ACTION NEEDED: install Rosetta. Open Terminal, paste: softwareupdate --install-rosetta  — press Enter, type A to agree, enter your Mac password if asked. Then run this installer again."
    softwareupdate --install-rosetta || sudo softwareupdate --install-rosetta || die "Rosetta didn't install."
    arch -x86_64 /usr/bin/true 2>/dev/null || die "Rosetta didn't install."
    ok "Rosetta installed"
  fi
fi

# 2. Steam and the game licence
bold "\n2. Steam"
if [[ -d /Applications/Steam.app ]]; then ok "Steam installed"
else
  todo "Steam not installed"
  [[ $CHECK == 1 ]] || { open "https://store.steampowered.com/about/"; die "Install Steam from the page that just opened (click Install Steam, open the download, drag Steam to Applications), open it once, sign in, then run this again."; }
fi
if [[ $CHECK == 0 ]]; then
  until steam_check; do
    todo "Steam doesn't have Queen's Domain yet"
    open -a Steam
    pause "In Steam: sign in, buy Queen's Domain if you haven't (the store warns it's Windows-only — buy it anyway), and check it appears in your Library. Then come back here."
    steam_quit   # Steam saves its list of your games to disk when it closes
  done
fi
steam_check && ok "Queen's Domain is in your Steam library" || todo "Queen's Domain not in Steam's saved game list yet"
[[ $CHECK == 0 ]] && { SID=$(PY steamid) || die "No Steam account found. Sign in to Steam, then run this again."; }

# 3. Whisky + Windows layer (Apple Game Porting Toolkit)
bold "\n3. Whisky and the Windows layer"
if [[ -x $WCMD ]]; then ok "Whisky"
else
  todo "Whisky not installed"
  if [[ $CHECK == 0 ]]; then
    fetch "$WHISKY_URL" "$TMP/Whisky.zip" $WHISKY_SHA
    ditto -x -k "$TMP/Whisky.zip" /Applications/ || die "Couldn't copy Whisky into Applications."
    [[ -x $WCMD ]] || die "Whisky didn't install correctly."
    ok "Whisky installed"
  fi
fi
if [[ -e "$LIBS/Wine/lib/external/D3DMetal.framework" ]]; then ok "Game Porting Toolkit (Wine + D3DMetal)"
else
  todo "Game Porting Toolkit missing (240 MB download)"
  if [[ $CHECK == 0 ]]; then
    osascript -e 'quit app "Whisky"' 2>/dev/null
    fetch "$GPTK_URL" "$TMP/gptk.tar.xz" $GPTK_SHA
    echo "  Unpacking…"; tar -xf "$TMP/gptk.tar.xz" -C "$TMP" || die "Couldn't unpack the Game Porting Toolkit (disk full?)."
    src="$TMP/Game Porting Toolkit.app/Contents/Resources/wine"
    [[ -x $src/bin/wine64 ]] || die "The Game Porting Toolkit download looks wrong."
    mkdir -p "$LIBS"; [[ -e "$LIBS/Wine" ]] && mv "$LIBS/Wine" "$LIBS/Wine.old-$(date +%s)"
    ditto "$src" "$LIBS/Wine" || die "Couldn't install the Game Porting Toolkit."
    cat > "$LIBS/WhiskyWineVersion.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>version</key>
	<dict>
		<key>major</key><integer>99</integer>
		<key>minor</key><integer>0</integer>
		<key>patch</key><integer>0</integer>
		<key>preRelease</key><array/>
		<key>build</key><array/>
	</dict>
</dict>
</plist>
EOF
    ok "Game Porting Toolkit installed"
  fi
fi
if [[ -x $WCMD ]] && $WCMD list 2>/dev/null | grep -q "Queens Domain"; then ok "Whisky bottle \"Queens Domain\""
else
  todo "Whisky bottle missing"
  if [[ $CHECK == 0 ]]; then
    $WCMD create "Queens Domain" >/dev/null 2>&1
    $WCMD list 2>/dev/null | grep -q "Queens Domain" || die "Couldn't create the Whisky bottle. Try opening Whisky once (Applications → Whisky), close it, and run this again."
    ok "Whisky bottle created"
  fi
fi
if [[ $CHECK == 0 && -x $WCMD ]]; then
  eval "$($WCMD shellenv "Queens Domain")"
  if [[ ! -e "$WINEPREFIX/system.reg" ]]; then
    echo "  Preparing the Windows environment (1–2 minutes)…"
    # mscoree/mshtml= stops Wine offering to download .NET (Mono) and the Gecko browser, which the game doesn't need
    WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" wine64 wineboot --init >/dev/null 2>&1
    wineserver -w 2>/dev/null
    [[ -e "$WINEPREFIX/system.reg" ]] || die "The Windows environment didn't start. Ask for help (see CLAUDE_PROMPT.md)."
  fi
  ok "Windows environment ready"
fi

# 4. Teach Mac Steam to install, run and cloud-sync the game
bold "\n4. Steam settings for the Mac"
patch_steam() {
  steam_quit
  PY patch >/dev/null; local rc=$?
  (( rc == 3 )) && die "Steam has changed how it stores game settings, so this installer can't set the game up. Ask for help (see CLAUDE_PROMPT.md)."
  (( rc == 0 )) || die "Couldn't update Steam's settings for the game."
  PY steaminput-off >/dev/null 2>&1  # lets controllers reach the game instead of Steam
}
if PY is-patched 2>/dev/null; then ok "Steam knows how to run the game on a Mac"
else
  todo "Steam needs the Mac settings"
  [[ $CHECK == 0 ]] && { patch_steam; ok "Steam settings added"; }
fi

# 5. Helper scripts and the app
bold "\n5. The Queen's Domain app"
if [[ $CHECK == 0 ]]; then
  mkdir -p $HELPER
  cp "$REPO"/lib/{appinfo.py,qd_steam.py,steam-entry.sh,launch.sh} $HELPER/
  chmod +x $HELPER/*.sh
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  printf '#!/bin/zsh\nexec ~/Games/QueensDomainMac/launch.sh "$@"\n' > "$APP/Contents/MacOS/launch"
  chmod +x "$APP/Contents/MacOS/launch"
  cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Queen's Domain</string>
	<key>CFBundleDisplayName</key><string>Queen's Domain</string>
	<key>CFBundleIdentifier</key><string>local.queensdomain.mac</string>
	<key>CFBundleExecutable</key><string>launch</string>
	<key>CFBundleIconFile</key><string>QueensDomain</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.role-playing-games</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
</dict>
</plist>
EOF
  # Icon from the game's Steam library artwork (downloaded on this Mac, not stored in the repo)
  if [[ ! -e "$APP/Contents/Resources/QueensDomain.icns" ]] && curl -fsL -o "$TMP/cap.jpg" "$CAPSULE"; then
    w=$(sips -g pixelWidth "$TMP/cap.jpg" | awk '/pixelWidth/{print $2}')
    sips -s format png -c $w $w "$TMP/cap.jpg" --out "$TMP/sq.png" >/dev/null
    mkdir -p "$TMP/i.iconset"
    for s in 16 32 128 256 512; do
      sips -z $s $s "$TMP/sq.png" --out "$TMP/i.iconset/icon_${s}x${s}.png" >/dev/null
      sips -z $((s*2)) $((s*2)) "$TMP/sq.png" --out "$TMP/i.iconset/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$TMP/i.iconset" -o "$APP/Contents/Resources/QueensDomain.icns" 2>/dev/null
  fi
  codesign --force --deep -s - "$APP" 2>/dev/null
  touch "$APP"
  ln -sfh "$APP" ~/Desktop/"Queen's Domain" 2>/dev/null
  ok "App installed in Applications, with a shortcut on the Desktop"
else
  [[ -d $APP ]] && ok "App installed" || todo "App not installed"
fi

# 6. Download the game through Steam
bold "\n6. The game"
if PY installed; then ok "Game downloaded"
else
  todo "Game not downloaded yet"
  if [[ $CHECK == 0 ]]; then
    tries=0
    while ! PY installed; do
      open "steam://install/1799840"
      echo "  Steam is opening an Install window: click Install (keep the default folder if you can)."
      echo "  Waiting for the 2.2 GB download to finish — you can leave this running…"
      waited=0
      while ! PY installed; do
        sleep 15; (( waited += 15 )); printf "."
        # No install record after 10 minutes: Steam probably refreshed the game's settings and
        # forgot the Mac entries, so it refused ("not available on your platform"). Redo them.
        if (( waited >= 600 )) && ! PY has-manifest; then
          echo; (( ++tries > 2 )) && die "Steam won't start the download. Ask for help (see CLAUDE_PROMPT.md)."
          todo "Steam didn't start the download; re-applying the Mac settings and trying again"
          patch_steam; break
        fi
      done
    done
    echo; ok "Game downloaded"
  fi
fi
if [[ $CHECK == 0 ]]; then
  GAMEDIR=$(PY gamedir)
  printf '#!/bin/zsh\nexec ~/Games/QueensDomainMac/steam-entry.sh "$@"\n' > "$GAMEDIR/QueensDomainMac"
  chmod +x "$GAMEDIR/QueensDomainMac"
fi

bold "\nDone$([[ $CHECK == 1 ]] && echo ' checking')."
[[ $CHECK == 0 ]] && cat <<'EOF'

Open "Queen's Domain" from Applications or the Desktop shortcut.
 - The first time, Steam shows the game's license agreement: accept it. If the game doesn't
   start after that, open the app again.
 - The first launch can sit on a black screen for 1–2 minutes while it prepares graphics.
   Don't force-quit it.
 - Always start the game from this app. It repairs Steam's settings first if a game update
   reset them.
 - Saves upload to Steam Cloud when you quit the game from its menu.
EOF
exit 0
