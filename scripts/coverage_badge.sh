#!/usr/bin/env bash
set -euo pipefail

coverage_info="${1:-coverage.info}"
badge_path="${2:-htmldocs/coverage.svg}"

if [[ ! -s "$coverage_info" ]]; then
  echo "coverage trace file not found or empty: $coverage_info" >&2
  exit 1
fi

read -r covered total percent color < <(
  awk -F: '
    /^LH:/ { covered += $2 }
    /^LF:/ { total += $2 }
    END {
      if (total == 0) {
        exit 2
      }

      percent = covered * 100 / total
      color = percent >= 90 ? "#4c1" : percent >= 75 ? "#97ca00" : percent >= 50 ? "#dfb317" : "#e05d44"
      printf "%d %d %.1f %s\n", covered, total, percent, color
    }
  ' "$coverage_info"
)

mkdir -p "$(dirname "$badge_path")"

label="coverage"
value="${percent}%"
label_width=63
value_chars=${#value}
value_text_length=$((value_chars * 70))
value_width=$(((value_text_length / 10) + 10))
if (( value_width < 42 )); then
  value_width=42
fi
width=$((label_width + value_width))
label_text_x=$((label_width * 5))
value_text_x=$(((label_width * 10) + (value_width * 5)))

cat > "$badge_path" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="20" role="img" aria-label="$label: $value">
  <title>$label: $value</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r">
    <rect width="$width" height="20" rx="3" fill="#fff"/>
  </clipPath>
  <g clip-path="url(#r)">
    <rect width="$label_width" height="20" fill="#555"/>
    <rect x="$label_width" width="$value_width" height="20" fill="$color"/>
    <rect width="$width" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text aria-hidden="true" x="$label_text_x" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="530">$label</text>
    <text x="$label_text_x" y="140" transform="scale(.1)" textLength="530">$label</text>
    <text aria-hidden="true" x="$value_text_x" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="$value_text_length">$value</text>
    <text x="$value_text_x" y="140" transform="scale(.1)" textLength="$value_text_length">$value</text>
  </g>
</svg>
SVG

echo "Generated $badge_path: $percent% ($covered/$total lines)"
