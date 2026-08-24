# Changelog

This project follows Semantic Versioning.

[0.1.1] - 2026-08-24

### Added

- Add `Candle`, the generic numeric `candle` constructor, and `plotCandles`
  overloads for static OHLC charts with optional ordered period labels.
- Add `CandlePlotOptions` with automatic financial price bounds, fixed range
  clipping, captions, units, axis formatting, custom glyphs and colors,
  deterministic line endings, and plain-text rendering.
- Add validation for malformed or non-finite OHLC values, dimensions, ranges,
  glyph display widths, labels, formatter output, and oversized static data.
- Add bounded `LiveCandleGraph` histories with atomic batch appends,
  in-progress candle and label replacement, range controls, newest-window
  autoranging, composable `renderFrame` output, and the shared live terminal
  lifecycle.
- Export the static and live candle APIs from the `terminal_graph` façade and
  document their focused module coverage.
- Add static and streaming candle examples, comprehensive candle tests, static
  screenshots, and an animated live-candle showcase.

### Changed

- Reorganize the README around the API overview table, with focused examples
  and screenshots under each graph family and live animations in their own
  gallery.
- Show three same-height live animations in the README header, including the
  streaming OHLC candle chart.
- Extend the aggregate showcase, package description, documentation task,
  example compile checks, and test task to cover candle charts.
- Keep the streaming candle example visually sparse with a bounded 20-candle
  window on its 60-column canvas.

### Fixed

- Use the same full-cell body glyph and matching background color for rising,
  falling, and unchanged candles so every direction has consistent thickness.
- Keep period labels separated by at least one terminal cell so dense live
  labels remain readable instead of running together.
- Roll streaming example timestamps from `09:59` to `10:00` instead of
  producing invalid minute values.
- Remove the light top border from the animated streaming candle example while
  preserving its frames, timing, and loop behavior.

[0.1.0] - 2026-08-24

### Added

- Add asciigraph-style single- and multi-series line charts.
- Add horizontal grouped and stacked bar charts.
- Add scatter plots and connected irregular XY charts with zero-crossing axes.
- Add bounded static and streaming graph models.
- Add compact and streaming sparklines with custom palettes and gaps.
- Add responsive multiplot grids, surfaces, and filled contours.
- Add deferred `MultiplotRenderer` callbacks so graphs can render directly at
  their assigned responsive-grid width.
- Add a reusable `LiveDashboard` full-screen lifecycle with resize-safe redraws
  and POSIX alternate-screen support.
- Re-export the shared `terminal_style` API from the library façade.

### Changed

- Adopt singular repository, package, import, and dependency naming.
- Constrain responsive grids to the detected terminal width by default.
- Reflow fixed and breakpoint column layouts when their requested column count
  no longer fits the available width.
- Update graph examples to use responsive layouts instead of hard-coded
  terminal widths.
- Use `LiveDashboard` in the streaming multiplot example so each frame fully
  replaces the previous frame and animated output stays out of scrollback.
- Support Nim 2.0.0 and newer.

### Fixed

- Prevent terminal resizing from wrapping partial graph lines by clipping
  irreducibly wide plots at ANSI- and Unicode-safe cell boundaries.
- Isolate ANSI styles and hyperlinks between multiline grid cells to prevent
  formatting from leaking into neighboring plots.
- Align each plot as one rectangular block for centered and right-aligned
  multiplots, keeping axes and graph canvases straight when lines have
  different lengths.
- Clear the complete live-dashboard frame after a resize so fragments of older
  frames do not remain above the current streaming graphs.
