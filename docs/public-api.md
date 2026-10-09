# Public API example map

Every exported graph symbol has an API doc comment in its defining module.
Focused programs under `examples/` cover bars, static and streaming OHLC
candles, line charts, scatter and XY charts, static frames, streaming displays,
sparklines, surfaces, contours, and multiplot grids. `all_graphs.nim` provides
the finite aggregate showcase.

The examples share `ModernGraphPalette`, `ModernGraphSeriesColors`, and
`ModernGraphGradient` from the public `terminal_graph/palettes` module.

`LiveDashboard` provides resize-safe full-screen lifecycle management for
arbitrary composed frames. `LiveGraph`, `LiveLineGraph`, and `LiveCandleGraph`
retain their focused data and rendering APIs and can supply frames through
`renderFrame()`.

All examples import sibling source modules and are compile-checked by
`nimble examples`. Streaming examples keep their terminal loops behind
`when isMainModule`; deterministic frame creation is covered separately by the
test suites.

## Dimension and redraw coverage

| Behavior | Public API | Focused examples | Regression suites |
| --- | --- | --- | --- |
| Automatic height capped at 20 intervals (21 plot rows), with larger explicit heights | `plot`, `plotMany`, `graphHeight`, `AsciiGraphConfig.height` | [line_graph.nim](../examples/line_graph.nim) | [test_line_graphs.nim](../tests/test_line_graphs.nim) covers large positive and negative ranges and explicit heights. |
| Complete frames constrained to their requested display width and height | `StaticGraph.render`, `LiveGraph.renderFrame`, `statistics` | [static_graph.nim](../examples/static_graph.nim), [live_graph.nim](../examples/live_graph.nim) | [test_terminal_graph.nim](../tests/test_terminal_graph.nim) covers plain and colored frames at 80×24 and the minimum size, plus Unicode title truncation. |
| Wrapped previous frames replaced using the current output-column width | `LiveLineGraph.draw(width = 0)`, `LiveCandleGraph.draw(width = 0)` | [streaming_line_graph.nim](../examples/streaming_line_graph.nim), [streaming_candle_graph.nim](../examples/streaming_candle_graph.nim) | [test_advanced_graphs.nim](../tests/test_advanced_graphs.nim) and [test_candle_graphs.nim](../tests/test_candle_graphs.nim) cover explicit output widths, width changes, ANSI styling, and Unicode captions. |

For live line and candle charts, the `draw` width describes terminal columns
for cursor movement. Canvas dimensions stay in `AsciiGraphConfig` or
`CandlePlotOptions`, and `renderFrame()` remains available for string-based
composition. The output terminal width is detected only during `draw`.

## Generated documentation

Generate the API documentation locally with `nimble docs`. Open
`htmldocs/index.html`, or serve `htmldocs/` with a local HTTP server to enable
the generated symbol search. The generated directory is ignored by Git; the
same command builds the documentation published by GitHub Pages.
