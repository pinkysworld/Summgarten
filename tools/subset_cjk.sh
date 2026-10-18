#!/bin/bash
# Re-subsets the CJK fonts to the characters used in i18n/strings.csv and tools/.
# Usage: tools/subset_cjk.sh <folder with NotoSans{SC,JP,KR,TC}-Bold.otf>
# Arabic, Hebrew, Thai and Devanagari are bundled whole (small, and shaping needs all glyphs).
# (full fonts: github.com/notofonts/noto-cjk, Sans/SubsetOTF)
set -e
SRC="${1:?folder with the full Noto fonts}"
cd "$(dirname "$0")/.."
python3 - "$SRC" <<'PY'
import sys, glob
from fontTools import subset
text = open('i18n/strings.csv', encoding='utf-8').read()
for f in glob.glob('tools/*.gd') + glob.glob('scripts/*.gd'):
    text += open(f, encoding='utf-8').read()
chars = ''.join(sorted(set(c for c in text if ord(c) > 0x2E7F and not 0xFB1D <= ord(c) <= 0xFEFF))) + '0123456789:：，。！？（）%×=–- '
for name in ['NotoSansSC-Bold', 'NotoSansJP-Bold', 'NotoSansKR-Bold', 'NotoSansTC-Bold']:
    opts = subset.Options(); opts.layout_features = ['*']
    font = subset.load_font(f'{sys.argv[1]}/{name}.otf', opts)
    s = subset.Subsetter(opts); s.populate(text=chars); s.subset(font)
    subset.save_font(font, f'fonts/{name}-subset.otf', opts)
    print(name, len(chars), 'chars')
PY
