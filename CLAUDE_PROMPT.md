# Prompt for Claude Code

Copy everything inside the box below and paste it into Claude Code on the Mac. Claude will do the setup and tell you whenever it needs you to click or type something.

---

```
Hi Claude. Please set up the Windows-only Steam game "Queen's Domain" (Steam app 1799840) so I can play it on this Mac. I'm not technical: explain everything in plain, short, friendly language, one step at a time, and tell me exactly what to click.

My situation
- This is an Apple Silicon Mac (M1 or newer). I only use Macs.
- I've just bought (or am about to buy) Queen's Domain on Steam with my own Steam account. I have never played it, so there are no saves to worry about.
- The installer for this is in a public GitHub repo: https://github.com/ganoritamar/queens-domain-mac

Rules
- Never type or ask for my passwords, and never sign in for me. I sign in myself (Steam, the Mac password).
- Never accept license agreements for me (Apple's Rosetta, Steam's or the game's). Tell me when one comes up and I'll accept it.
- Don't buy anything and don't change any Steam settings other than what the repo's scripts do.
- Don't install the Windows version of Steam inside Wine. It crashes; the repo's method uses Mac Steam instead.
- If something unexpected happens, stop and explain it to me before trying anything risky.

Step 1: Get the repo into ~/queens-domain-mac
- If ~/queens-domain-mac already exists, run `git -C ~/queens-domain-mac pull` and skip to step 2.
- Otherwise run `git clone https://github.com/ganoritamar/queens-domain-mac.git ~/queens-domain-mac`. No GitHub account is needed.
- If macOS shows a window asking to install "command line developer tools", tell me to click Install and wait for it to finish (can take 10+ minutes). The installer needs these for python3.

Step 2: Read before running
Read ~/queens-domain-mac/README.md, install.sh and the files in lib/, so you understand what they do. Then give me a 3–4 line summary of what will happen.

Step 3: Check
Run `zsh ~/queens-domain-mac/install.sh --check` (it changes nothing) and tell me in plain words what's already in place and what's still missing.

Step 4: Install
Run `zsh ~/queens-domain-mac/install.sh`. It's safe to run as many times as needed; every step skips what's already done. When it stops with a line starting "ACTION NEEDED:", tell me what to do in simple words, wait until I say it's done, then run it again. The things I may need to do:
  - Update macOS, if it's older than macOS 15 Sequoia. The installer stops and says so.
  - Install Steam from the page it opens: drag Steam into Applications, open it, and sign in with my account.
  - Buy Queen's Domain in Steam. The store warns it's Windows-only; that's expected. Then make sure it shows in my Steam Library.
  - Install Rosetta: I paste `softwareupdate --install-rosetta` into Terminal, type A to agree to Apple's license, and enter my Mac password if asked.
  - Click "Allow" if macOS asks whether the app may control Steam or access folders.
  - Click "Install" in the Steam window that appears for Queen's Domain (keep the default install folder).
The game download (2.2 GB) can take a while, and the installer waits for it to finish. Run it in the background or with a long timeout, and check on it rather than letting it be killed.

Step 5: First launch
- Open "/Applications/Queen's Domain.app". The first time, Steam shows the game's license agreement: tell me to accept it, then open the app again if the game didn't start.
- The first start can show a black screen for 1–2 minutes while it prepares graphics. Tell me not to force-quit.
- Confirm it worked: ~/Games/QueensDomainMac/sync.log has a "game start" line, and the process QueensDomain-Win64-Shipping.exe is running. Then ask me whether I can see the game's menu.
- Tell me how to play from now on: always open the "Queen's Domain" app (Applications or the Desktop shortcut), not Steam's Play button. Quit from the game's own menu so the save uploads to Steam Cloud.

Step 6: Finish
Give me a short summary, plus a reminder that if something breaks later, I can paste this same prompt again or run `zsh ~/queens-domain-mac/install.sh --check`.

----------------------------------------------------------------
Background for you (Claude) to debug with: how the setup works
----------------------------------------------------------------
- Translation layers:
  - Whisky 2.3.5 (/Applications/Whisky.app) manages the Windows environment. It's abandoned upstream, and its own Wine download server is gone.
  - So install.sh puts Gcenx's build of Apple's Game Porting Toolkit 3.0-3 (Wine 7.7 + D3DMetal, which turns DirectX 11 into Metal) into ~/Library/Application Support/com.isaacmarovitz.Whisky/Libraries/Wine, with a hand-written WhiskyWineVersion.plist (version 99.0.0).
  - Both downloads are pinned with SHA-256 checksums in install.sh.
  - The Whisky bottle is named "Queens Domain". Its Windows user is "crossover". It's initialised with `WINEDLLOVERRIDES="mscoree,mshtml=" wine64 wineboot --init`, which avoids Mono/Gecko download pop-ups.
  - Get the environment with: `eval "$(/Applications/Whisky.app/Contents/Resources/WhiskyCmd shellenv "Queens Domain")"`.
- Rosetta 2 is required: the Wine build is x86_64.
- Mac Steam normally refuses Windows-only games. lib/qd_steam.py edits Mac Steam's binary cache ~/Library/Application Support/Steam/appcache/appinfo.vdf (format v29, magic 0x07564429) for app 1799840. Steam must be fully quit while it does this. It adds:
  - "macos" to common/oslist, so Steam offers Install/Play and downloads the Windows depot 1799841
  - ufs/rootoverrides {WinAppDataLocal → MacAppSupport}, so Steam Cloud works
  - a launch entry with a NUMERIC key (Steam ignores non-numeric keys): executable "QueensDomainMac", config/oslist "macos"
  It backs up the file to appinfo.vdf.before-queensdomain and reads it back to verify. Exit code 3 means Steam changed the file format; don't hand-edit it then, report it to me.
- Steam rewrites appinfo.vdf when the game updates or its info refreshes, which drops the edit. The app (~/Games/QueensDomainMac/launch.sh) re-applies it before every launch. install.sh re-applies it if Steam hasn't started the download after 10 minutes.
- `qd_steam.py steaminput-off` sets localconfig.vdf → apps/1799840/UseSteamControllerConfig = "0" (only with Steam quit). Otherwise Steam Input grabs game controllers and the game sees none.
- Play flow:
  - Steam runs <game folder>/QueensDomainMac, a 2-line stub that runs ~/Games/QueensDomainMac/steam-entry.sh.
  - That script copies newer Steam Cloud saves into the bottle and moves the intro .mp4 movies aside (they hang on a black screen under Wine).
  - It then runs `wine64 QueensDomain-Win64-Shipping.exe -dx11` from QueensDomain/Binaries/Win64. Don't use QueensDomain.exe; it hangs.
  - After the game exits, it copies saves to ~/Library/Application Support/QueensDomain/Saved/SaveGames/<SteamID64>/, and Steam uploads them.
- The game folder is found via steamapps/libraryfolders.vdf (`qd_steam.py gamedir`), so non-default Steam libraries work.
- Useful logs:
  - ~/Games/QueensDomainMac/sync.log
  - ~/Library/Application Support/Steam/logs/console_log.txt. AppError_29 means the Mac entries are missing (open the app again). AppError_28 means Steam chose a Windows launch entry.
  - logs/cloud_log.txt. "failed to resolve path" means the Mac entries are missing.
- Known limits:
  - Achievements don't unlock on the Mac, because the game can't reach Steam from inside Wine. Playtime does count.
  - The game is heavier on 8 GB Macs.
  - Don't lower the game's frame rate or graphics quality yourself to "fix" performance; tell me the option and let me decide.
```
