# Changelog

This project follows Semantic Versioning. It has not yet made its first public
release.

## [0.1.0] - Unreleased

- Add asciigraph-style single- and multi-series line charts.
- Add horizontal grouped and stacked bar charts.
- Add scatter plots and connected irregular XY charts with zero-crossing axes.
- Add bounded static and streaming graph models.
- Add compact and streaming sparklines with custom palettes and gaps.
- Add responsive multiplot grids, surfaces, and filled contours.
- Keep responsive grids within the detected terminal width by reflowing
  fixed/breakpoint columns, clipping irreducibly wide plots at ANSI-safe cell
  boundaries, and isolating multiline styles between cells.
- Add a reusable `LiveDashboard` full-screen lifecycle with resize-safe redraws
  and POSIX alternate-screen support; use it in the streaming multiplot example
  so rewrapped fragments of older frames cannot remain visible.
- Re-export the shared `terminal_styles` API from the library façade.
- Support Nim 2.0.0 and newer.
