#!/bin/zsh
# Removes the Queen's Domain app and helper scripts. Leaves Steam, Whisky and the game alone.
rm -rf "/Applications/Queen's Domain.app" ~/Desktop/"Queen's Domain"
rm -f "$HOME/Library/Application Support/Steam/steamapps/common/QueensDomain/QueensDomainMac"
if [[ -d ~/Games/QueensDomainMac ]]; then
  mv ~/Games/QueensDomainMac ~/Games/QueensDomainMac.removed-$(date +%Y%m%d)
  echo "Helper scripts moved to ~/Games/QueensDomainMac.removed-$(date +%Y%m%d) (your save backups are in there)."
fi
echo "Removed. Steam will put its own settings for the game back the next time it updates them."
