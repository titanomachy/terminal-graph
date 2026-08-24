# Public API example map

Every exported graph symbol has an API doc comment in its defining module.
Focused programs under `examples/` cover bars, static and streaming OHLC
candles, line charts, scatter and XY charts, static frames, streaming displays,
sparklines, surfaces, contours, and multiplot grids. `all_graphs.nim` provides
the finite aggregate showcase.

`LiveDashboard` provides resize-safe full-screen lifecycle management for
arbitrary composed frames. `LiveGraph`, `LiveLineGraph`, and `LiveCandleGraph`
retain their focused data and rendering APIs and can supply frames through
`renderFrame()`.

All examples import sibling source modules and are compile-checked by
`nimble examples`. Streaming examples keep their terminal loops behind
`when isMainModule`; deterministic frame creation is covered separately by the
test suites.

Generate the API documentation locally with `nimble docs`. Open
`htmldocs/index.html`, or serve `htmldocs/` with a local HTTP server to enable
the generated symbol search. The generated directory is ignored by Git; the
same command builds the documentation published by GitHub Pages.
