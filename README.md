# Queen's Domain on a Mac

Queen's Domain is a Windows-only Steam game. This sets it up to run on an Apple Silicon Mac (M1 or newer), started from a normal Mac app icon. Your saves sync through Steam Cloud, so you can switch between a Windows PC and the Mac.

Nothing from the game is included here. You buy the game on Steam, and Steam downloads it.

## What you need

- A Mac with an Apple chip (M1, M2, M3, M4…) running macOS 15 Sequoia or newer, signed in as an administrator
- About 8 GB of free disk space
- Your own Steam account that owns [Queen's Domain](https://store.steampowered.com/app/1799840/). The store says it's Windows-only; buy it anyway. 16 GB of memory is best: on 8 GB Macs it may stutter.

## Setup (about 15 minutes, mostly waiting for downloads)

**Easiest:** if you have Claude Code, paste the prompt from [CLAUDE_PROMPT.md](CLAUDE_PROMPT.md) and it walks you through everything. Or do it yourself:


1. Open **Terminal** (press ⌘ Space, type `Terminal`, press Enter).
2. Paste this into Terminal and press Enter:
   ```bash
   git clone https://github.com/ganoritamar/queens-domain-mac.git ~/queens-domain-mac && zsh ~/queens-domain-mac/install.sh
   ```
   If the Mac asks to install "command line developer tools", click **Install**, wait for it to finish, then paste the line again.
3. Follow what it says. Along the way it will:
   - ask you to type **A** to agree to Apple's Rosetta license, if Rosetta isn't installed yet
   - send you to the Steam website if Steam isn't installed yet (install it, sign in, then run the line again)
   - ask you to sign in to Steam and check that Queen's Domain is in your library
   - close and reopen Steam once (this is normal)
   - open Steam's **Install** window: click Install and wait for the 2.2 GB download
4. Open **Queen's Domain** from Applications or the Desktop shortcut.

The first launch can sit on a black screen for a minute or two while it prepares graphics. The first time you play, Steam may also show the game's license agreement. Accept it, then open the app again.

## Day to day

- Start the game from the **Queen's Domain** app. It checks that Steam is still set up for the Mac and repairs it if a game update reset it, then asks Steam to start the game.
- Steam updates the game by itself. Nothing to do.
- Saves upload to Steam Cloud when you quit the game. Quit from the game's menu rather than force-quitting.
- Hold **Option** while opening the app to show a frame-rate counter.
- Controllers: the installer turns off Steam Input for this game so the game sees the controller directly. If a controller still doesn't work, check in Steam: right-click Queen's Domain → **Properties** → **Controller** → **Disable Steam Input**.
- Achievements don't unlock when playing on the Mac (the game can't reach Steam from inside the Windows layer). Playtime is counted.
- Steam's refund rule (within 14 days, under 2 hours played) still applies if it doesn't work on your Mac.

## If something goes wrong

- Run `zsh ~/queens-domain-mac/install.sh --check` to see what's set up and what's missing. It changes nothing.
- Run `zsh ~/queens-domain-mac/install.sh` again. It skips whatever is already done.
- The sync log is at `~/Games/QueensDomainMac/sync.log`. Backups of your Mac saves are in `~/Games/QueensDomainMac/backups`.
- Or open Claude Code and paste the prompt from [CLAUDE_PROMPT.md](CLAUDE_PROMPT.md).

## How it works

- **[Whisky](https://github.com/IsaacMarovitz/Whisky)** (free) manages a Windows environment, called a "bottle". Its own Wine download no longer works, so the installer puts in Apple's **Game Porting Toolkit 3** instead (Wine 7.7 plus D3DMetal, which translates DirectX 11 to Metal), using [Gcenx's build](https://github.com/Gcenx/game-porting-toolkit).
- Mac Steam normally refuses Windows-only games. The installer edits Steam's cached copy of this one game's settings (`appcache/appinfo.vdf`) in three ways:
  - Mac is added to its platforms, so Steam will download it.
  - A Mac launch entry is added. It runs `~/Games/QueensDomainMac/steam-entry.sh`, which starts the game in Wine with `-dx11`.
  - A Mac save-folder rule is added, so Steam Cloud keeps working.

  Steam replaces this file when the game updates. That's why the app re-applies the edit before every launch.
- The game, running in Wine, saves inside the Whisky bottle. Before playing, `steam-entry.sh` copies in newer cloud saves; after you quit, it copies the game's saves back so Steam can upload them.
- The game's intro movies hang under Wine, so they're moved to `~/Games/QueensDomainMac/movies-backup`.

## Uninstall

```bash
zsh ~/queens-domain-mac/uninstall.sh
```
This removes the app and helper scripts. Steam, Whisky and the downloaded game stay; remove those yourself if you want.
