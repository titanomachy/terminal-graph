# TerminalGraph API documentation

TerminalGraph is a pure-Nim library for rendering charts as Unicode and ANSI
styled strings. Most applications only need the `terminal_graph` façade; the
focused modules are available when a smaller import surface is preferable.

- [Main `terminal_graph` façade](terminal_graph.html)
- [Search all exported symbols](theindex.html)
- [Package README](https://github.com/titanomachy/terminal-graph#readme)
- [Examples](https://github.com/titanomachy/terminal-graph/tree/master/examples)

## Install

```
nimble install terminal_style
nimble install terminal_graph
```

## Quick start

```nim
import terminal_graph

echo plot(
  [3, 4, 9, 6, 2, 4, 5, 8],
  graphWidth(40),
  graphHeight(8),
  graphCaption("Request latency"),
  graphSeriesColors(ModernGraphSeriesColors)
)
```

## Chart modules

- [`palettes`](terminal_graph/palettes.html) — a modern dark-terminal
  TerminalStyle palette, categorical series colors, value gradient, and
  reusable heading styles.

- [`line_graphs`](terminal_graph/line_graphs.html) — connected single- and
  multi-series charts, axes, labels, legends, gradients, and thresholds.
- [`bar_graphs`](terminal_graph/bar_graphs.html) — horizontal single-series,
  grouped, and stacked positive or negative bars.
- [`candle_graphs`](terminal_graph/candle_graphs.html) — static OHLC candle
  rendering with automatic or fixed price ranges.
- [`xy_graphs`](terminal_graph/xy_graphs.html) — connected XY and scatter plots
  with explicit coordinates, viewports, clipping, markers, and legends.
- [`sparkline_graphs`](terminal_graph/sparkline_graphs.html) — compact inline
  trends with shared ranges, custom ticks, gaps, and palettes.
- [`surface_graphs`](terminal_graph/surface_graphs.html) — matrix and flat-data
  surfaces, filled contours, resampling, palettes, and fixed ranges.

## Stateful rendering and composition

- [`static_graphs`](terminal_graph/static_graphs.html) — bounded series data,
  statistics, deterministic frames, markers, and filled columns.
- [`live_graphs`](terminal_graph/live_graphs.html) — streaming line and candle
  graphs plus resize-safe full-screen dashboard lifecycle management.
- [`multiplot_graphs`](terminal_graph/multiplot_graphs.html) — ANSI- and
  Unicode-aware grids with responsive width-aware renderers.

## Generate locally

```
nimble docs
python3 -m http.server 8000 --directory htmldocs
```

Then open [http://localhost:8000](http://localhost:8000). Serving the files over
HTTP allows the generated documentation search to load its index.
