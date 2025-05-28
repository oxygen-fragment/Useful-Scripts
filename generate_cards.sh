#!/usr/bin/env bash
# generate_cards_overlay.sh  —  text drawn on a separate transparent layer
set -euo pipefail
IFS=$'\n'

# ── find the Montserrat font files automatically via fontconfig ────────────
find_font() { fc-match -f '%{file}\n' "$1" | head -n1; }

F_BOLD=$(find_font "Montserrat ExtraBold") || { echo "Need Montserrat ExtraBold"; exit 1; }
F_MED=$(find_font "Montserrat Medium")    || { echo "Need Montserrat Medium";  exit 1; }
F_REG=$(find_font "Montserrat Regular")   || { echo "Need Montserrat Regular"; exit 1; }

# ── colours ────────────────────────────────────────────────────────────────
WHITE="#ffffff"; GREY="#b0b0b0"
TEAL="#00c4cc";  ORANGE="#ff6b00"; PINK="#ff005c"; GOLD="#ffd600"

# ── card definitions  (% → %% ) ────────────────────────────────────────────
CARDS=(
#   BG | OUT | COL | BIG_PT | BIG_TEXT | SUB_PT | SUB_TEXT | SRC_PT | SRC_TEXT
"phone-bg.png|phone-on-desk-attention-drop-2024-study.png|$TEAL|180|10 %%|36|Immediate hit to attention when your silent phone sits on the desk.|20|(Schooler et al., 2024)"
"preschool-bg.png|preschool-screen-time-adhd-risk-7x-2023.png|$ORANGE|200|7.7×|32|Higher odds of ADHD-like symptoms with > 2 h screen time.|18|(Meta-analysis, 2023)"
"teen-bg.png|teen-social-apps-adhd-risk-10-percent-2024.png|$PINK|190|+10 %% risk|32|…for every extra social app teens use daily.|18|(Cohort study, 2024)"
"detox-bg.png|two-week-digital-detox-brain-10-years-younger-2025.png|$TEAL|160|Brains look\n10 yrs younger|32|after a 14-day mobile-internet block.|18|(RCT, 2025)"
"dopamine-bg.png|30-day-digital-detox-dopamine-reset-lembke.png|$GOLD|190|≈30 days|32|to rebalance reward pathways|18|(Lembke, 2021)"
)

trim () { printf '%s' "$1" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'; }

echo -e "\n=== Generating overlays ==="

for LINE in "${CARDS[@]}"; do
  IFS='|' read -r BG OUT COL BIG_PT BIG SUB_PT SUB SRC_PT SRC <<< "$LINE"
  BG=$(trim "$BG"); OUT=$(trim "$OUT"); COL=$(trim "$COL")
  [[ -f $BG ]] || { echo "✗ Missing $BG"; continue; }

  # native size of BG
  read -r W H <<< "$(identify -format '%w %h' "$BG")"

  # transparent overlay the same size
  OVER=$(mktemp --suffix=.png)

  # 1) text layer
  convert -size "${W}x${H}" canvas:none \
          -gravity center  -font "$F_BOLD" -pointsize "$BIG_PT" \
          -fill "$COL"     -annotate +0+0 "$BIG" \
          -gravity north   -font "$F_MED" -pointsize "$SUB_PT" \
          -fill "$WHITE"   -annotate +0+$((H*8/100)) "$SUB" \
          -gravity north   -font "$F_REG" -pointsize "$SRC_PT" \
          -fill "$GREY"    -annotate +0+$((H*3/100)) "$SRC" \
          "$OVER"

  # 2) (optional) subtle dim underlay  —  comment out if you don’t want dimming
  DIM=$(mktemp --suffix=.png)
  convert -size "${W}x${H}" xc:black -alpha set -channel A -evaluate set 30% "$DIM"

  # 3) composite: BG → dim → text
  convert "$BG" "$DIM" -compose over -composite \
          "$OVER" -compose over -composite "$OUT"

  rm "$OVER" "$DIM"
  echo "✓  $OUT (${W}×${H})"
done

echo "=== Done ==="
