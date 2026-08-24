# Changelog

This project follows Semantic Versioning. It has not yet made its first public
release.

[0.1.0] - 2026-08-24

### Added

- Add asciigraph-style single- and multi-series line charts.
- Add horizontal grouped and stacked bar charts.
- Add static OHLC candlestick charts with ordered labels, automatic or fixed
  price ranges, plain Unicode glyphs, and ANSI direction colors.
- Add bounded `LiveCandleGraph` histories with atomic batch appends,
  in-progress candle replacement, composable frame rendering, and the shared
  live terminal lifecycle.
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
