#!/bin/zsh
# Konwersja jednego zdjęcia na potrzeby strony.
# Użycie: CWEBP=/ścieżka/do/cwebp tools/convert.sh <plik-źródłowy.jpg> <katalog-wyjściowy> <nazwa> [cover]
# Tworzy: <nazwa>-640.webp, <nazwa>-1280.webp, <nazwa>-2048.webp (dłuższy bok w pikselach),
#         a dla okładki ("cover") także <nazwa>-1280.jpg — do podglądu linku na Facebooku/Messengerze.
# Wypisuje linię: <nazwa> <szerokość> <wysokość>
#
# cwebp: oficjalne narzędzie Google (libwebp), https://developers.google.com/speed/webp/download
# (AVIF z macOS-owego `sips` nie wyświetla się w Chrome, a `sips` nie zapisuje WebP — stąd cwebp).
set -e
src="$1"; out="$2"; name="$3"; cover="$4"
: ${CWEBP:?Ustaw zmienną CWEBP na ścieżkę do programu cwebp}
mkdir -p "$out"
w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
h=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
for s in 640 1280 2048; do
  # jakość podniesiona (2026-11-18): przy 72–78 było widać utratę jakości na śniegu i gładkich tłach
  q=88; [[ $s == 2048 ]] && q=90; [[ $s == 640 ]] && q=84
  if (( w >= h )); then rs=($s 0); else rs=(0 $s); fi
  [[ -f "$out/$name-$s.webp" ]] || "$CWEBP" -quiet -q $q -m 5 -sharp_yuv -resize $rs "$src" -o "$out/$name-$s.webp"
done
[[ "$cover" != cover || -f "$out/$name-1280.jpg" ]] || sips -s format jpeg -s formatOptions 74 -Z 1280 "$src" --out "$out/$name-1280.jpg" >/dev/null 2>&1
echo "$name $w $h"
