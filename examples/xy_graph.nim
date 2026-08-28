## Scatter and irregularly spaced connected XY plots.
# Run with: nim r --path:src examples/xy_graph.nim

when isMainModule:
  import ../src/terminal_graph

  let irregular = @[
    xyPoint(-5.0, -1.0),
    xyPoint(-3.8, 2.5),
    xyPoint(-0.4, 0.5),
    xyPoint(0.2, 4.0),
    xyPoint(3.7, -2.0),
    xyPoint(5.0, 1.0)
  ]
  let observations = @[
    xyPoint(-4.5, 1.0),
    xyPoint(-2.0, -2.0),
    xyPoint(-0.8, 3.0),
    xyPoint(1.5, 2.0),
    xyPoint(2.2, -1.5),
    xyPoint(4.3, 3.5)
  ]

  var options = initXYPlotOptions()
  options.width = 34
  options.height = 14
  options.xLabel = "time"
  options.yLabel = "value"
  options.axisColor = ModernGraphPalette.brightBlack
  options.labelColor = ModernGraphPalette.white

  options.caption = "Irregular XY line"
  let connected = plotXYMany([
    initXYSeries("signal", irregular, ModernGraphSeriesColors[0], marker = "●")
  ], options)

  options.caption = "Scatter observations"
  let scattered = plotScatterMany([
    initXYSeries("samples", observations, ModernGraphSeriesColors[1], marker = "◆")
  ], options)

  var layout = initMultiplotOptions()
  layout.minimumCellWidth = 1
  layout.horizontalGap = 4
  layout.expandColumns = false
  echo multiplot([connected, scattered], layout)
