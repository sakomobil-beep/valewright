#!/bin/sh
# Baut fonts/emoji.ttf neu – nur mit den Emojis, die im Spiel vorkommen (klein für die Web-Version).
python3 - <<'P'
import glob
txt=''.join(open(f,encoding='utf-8').read() for f in glob.glob('scripts/*.gd')+['translations/texts.tsv','data/game.json'])
open('/tmp/emoji_chars.txt','w',encoding='utf-8').write(''.join(sorted({c for c in txt if ord(c)>0x2000}))+'️‍')
P
pyftsubset /usr/share/fonts/truetype/noto/NotoColorEmoji.ttf --text-file=/tmp/emoji_chars.txt --output-file=fonts/emoji.ttf
# Sonderzeichen (☰ ➜ ⟳ → − ▲ ▼ …), die weder die Standardschrift noch die Emoji-Schrift hat
pyftsubset /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf --text-file=/tmp/emoji_chars.txt --output-file=fonts/symbols.ttf
