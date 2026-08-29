#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
media_dir="$repo_root/examples/images"
recording_dir="$repo_root/docs/recordings"
work_dir="${TMPDIR:-/tmp}/terminal-graphs-media"
bin_dir="$work_dir/bin"
nimcache_dir="$work_dir/nimcache"
font_family="JetBrainsMono Nerd Font Mono"

for tool in nim asciinema agg magick fc-match awk; do
  command -v "$tool" >/dev/null || {
    echo "missing required tool: $tool" >&2
    exit 1
  }
done

resolved_font=$(fc-match --format '%{family}\n' "$font_family" | head -n 1)
if [[ "$resolved_font" != "$font_family" &&
      "$resolved_font" != "$font_family,"* ]]; then
  echo "expected '$font_family', resolved '$resolved_font'" >&2
  exit 1
fi

mkdir -p "$media_dir" "$recording_dir" "$bin_dir" "$nimcache_dir"

examples=(
  advanced_graphs
  all_graphs
  bar_graph
  candle_graph
  line_graph
  live_graph
  multiplot_graph
  sparkline_graph
  static_graph
  streaming_candle_graph
  streaming_line_graph
  streaming_multiplot_graph
  streaming_sparklines
  xy_graph
)

for example in "${examples[@]}"; do
  nim c \
    --hints:off \
    --warnings:off \
    --path:"$repo_root/src" \
    --nimcache:"$nimcache_dir/$example" \
    --out:"$bin_dir/$example" \
    "$repo_root/examples/$example.nim"
done

render_options=(
  --text-font-family "$font_family"
  --font-size 18
  --line-height 1.4
  --renderer swash
  --theme github-dark
  --idle-time-limit 1
  --last-frame-duration 2
)

record_static() {
  local example=$1
  local geometry=$2
  local title=$3
  local cast_path="$work_dir/$example.cast"
  local gif_path="$work_dir/$example.gif"

  TERM=xterm-256color asciinema record \
    --headless \
    --quiet \
    --return \
    --capture-env TERM \
    --window-size "$geometry" \
    --title "$title" \
    --command "printf '\\033[?25l'; exec '$bin_dir/$example'" \
    --overwrite \
    "$cast_path"

  agg "${render_options[@]}" --select 100% "$cast_path" "$gif_path"
  magick "$gif_path[0]" "$media_dir/$example.png"
}

static_recordings=(
  'advanced_graphs|90x22|Surfaces and filled contours'
  'all_graphs|120x158|TerminalGraph feature tour'
  'bar_graph|76x18|Grouped and stacked bars'
  'candle_graph|66x18|Static OHLC candles'
  'line_graph|56x39|Connected line charts'
  'multiplot_graph|120x22|Responsive multiplot dashboard'
  'sparkline_graph|36x13|Sparklines'
  'static_graph|68x15|Static request graph'
  'xy_graph|90x18|XY and scatter charts'
)

for specification in "${static_recordings[@]}"; do
  IFS='|' read -r example geometry title <<<"$specification"
  record_static "$example" "$geometry" "$title"
done

record_animation() {
  local example=$1
  local geometry=$2
  local title=$3
  local output_name=$4
  local cast_path="$recording_dir/$example.cast"
  local gif_path="$media_dir/$output_name.gif"

  TERM=xterm-256color asciinema record \
    --headless \
    --quiet \
    --return \
    --capture-env TERM \
    --window-size "$geometry" \
    --title "$title" \
    --command "env TERMINAL_GRAPH_RECORDING=1 '$bin_dir/$example'" \
    --overwrite \
    "$cast_path"

  local end_time
  end_time=$(awk -F, '
    NR > 1 {
      delta = $1
      sub(/^\[/, "", delta)
      elapsed += delta
      if ($0 ~ /\[\?25h/) {
        printf "%.3f", elapsed - 0.001
        exit
      }
    }
  ' "$cast_path")
  if [[ -z "$end_time" ]]; then
    echo "could not find cursor-restoration event in $cast_path" >&2
    exit 1
  fi

  agg "${render_options[@]}" \
    --select "0.010..$end_time" \
    "$cast_path" \
    "$gif_path"
}

animated_recordings=(
  'live_graph|100x24|Live service metrics|live_graph2'
  'streaming_line_graph|80x18|Streaming API latency|streaming_line_graph2'
  'streaming_candle_graph|80x20|Streaming OHLC candles|streaming_candle_graph'
  'streaming_multiplot_graph|150x16|Streaming multiplot dashboard|streaming_multiplot_graph2'
  'streaming_sparklines|56x8|Streaming sparklines|streaming_sparklines'
)

for specification in "${animated_recordings[@]}"; do
  IFS='|' read -r example geometry title output_name <<<"$specification"
  record_animation "$example" "$geometry" "$title" "$output_name"
done

# Keep the historical filenames synchronized with their README masters.
cp "$media_dir/live_graph2.gif" "$media_dir/live_graph.gif"
cp "$media_dir/streaming_line_graph2.gif" "$media_dir/streaming_line_graph.gif"
cp "$media_dir/streaming_multiplot_graph2.gif" \
  "$media_dir/streaming_multiplot_graph.gif"

echo "Regenerated static images, source casts, and animated GIFs."
