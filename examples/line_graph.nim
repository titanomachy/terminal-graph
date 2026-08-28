## Feature tour for the asciigraph-style line renderer.
# Run with: nim r --path:src examples/line_graph.nim

when isMainModule:
  import std/strformat

  import ../src/terminal_graph

  let latency = [3.0, 4.0, 9.0, 6.0, 2.0, 4.0, 5.0, 8.0, 5.0,
    10.0, 2.0, 7.0, 2.0, 5.0, 6.0]

  echo plot(
    latency,
    graphHeight(8),
    graphWidth(40),
    graphCaption("Request latency"),
    graphCaptionColor(ModernGraphPalette.brightWhite),
    graphAxisColor(ModernGraphPalette.brightBlack),
    graphLabelColor(ModernGraphPalette.white),
    graphSeriesColors(ModernGraphSeriesColors),
    graphYAxisFormatter(proc(value: float64): string = &"{value:.1f} ms"),
    graphXAxisRange(0.0, 14.0),
    graphXAxisTickCount(4)
  )

  echo "\n"

  let services = @[
    @[0.0, 1.0, 2.0, 3.0, 3.0, 3.0, 2.0, 0.0],
    @[5.0, 4.0, 2.0, 1.0, 4.0, 6.0, 6.0]
  ]

  echo plotMany(
    services,
    graphSeriesColors(ModernGraphSeriesColors),
    graphSeriesLegends(["API", "worker"]),
    graphCaption("Colored service comparison"),
    graphCaptionColor(ModernGraphPalette.brightWhite),
    graphAxisColor(ModernGraphPalette.brightBlack),
    graphLabelColor(ModernGraphPalette.white)
  )

  echo "\n"

  echo plot(
    [42.0, 48.0, 55.0, 81.0, 85.0, 91.0, 87.0, 34.0, 12.0,
     17.0, 10.0, 18.0, 55.0, 50.0],
    graphHeight(10),
    graphWidth(30),
    lowerBound(0.0),
    upperBound(100.0),
    graphColorGradient(ModernGraphGradient),
    graphColorAbove(ModernGraphPalette.red, 80.0),
    graphColorBelow(ModernGraphPalette.green, 25.0),
    graphCaption("CPU %: rose critical, emerald idle"),
    graphCaptionColor(ModernGraphPalette.brightWhite),
    graphAxisColor(ModernGraphPalette.brightBlack),
    graphLabelColor(ModernGraphPalette.white)
  )
