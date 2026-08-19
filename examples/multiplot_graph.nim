## Arrange independently rendered graph types in an auto-fitting dashboard.
## Widen or narrow the terminal to let the grid select a different column count.

when isMainModule:
  import ../src/terminal_graphs

  let latency = plot(
    [18.0, 24.0, 21.0, 29.0, 35.0, 31.0, 42.0, 38.0],
    graphWidth(26),
    graphHeight(7),
    graphCaption("Request latency"),
    graphSeriesColors([colorBrightCyan])
  )

  var barOptions = initBarGraphOptions()
  barOptions.width = 22
  barOptions.caption = "Requests by region"
  barOptions.seriesColors = @[colorBrightYellow]
  let requests = plotBars(
    ["North", "South", "East", "West"],
    [42.0, 31.0, 37.0, 28.0],
    barOptions
  )

  var xyOptions = initXYPlotOptions()
  xyOptions.width = 26
  xyOptions.height = 9
  xyOptions.caption = "Latency samples"
  xyOptions.xLabel = "time"
  xyOptions.yLabel = "ms"
  let samples = plotScatter([
    xyPoint(-3.0, 2.0), xyPoint(-1.2, 4.5), xyPoint(0.0, 3.0),
    xyPoint(1.8, 6.0), xyPoint(3.0, 5.0)
  ], xyOptions)

  var contourOptions = initSurfacePlotOptions()
  contourOptions.width = 26
  contourOptions.height = 9
  contourOptions.caption = "Service heatmap"
  contourOptions.showScale = false
  contourOptions.contourLevels = 7
  let heatmap = plotContour(@[
    @[0.0, 0.2, 0.5, 0.8, 1.0],
    @[0.1, 0.4, 0.9, 0.6, 0.3],
    @[0.2, 0.7, 1.0, 0.5, 0.1],
    @[0.0, 0.3, 0.6, 0.4, 0.2]
  ], contourOptions)

  var layout = initMultiplotOptions()
  layout.columns = autoColumns
  layout.minimumCellWidth = 34
  layout.horizontalGap = 4
  layout.verticalGap = 1
  layout.horizontalAlignment = mhaCenter
  layout.verticalAlignment = mvaMiddle
  layout.breakpoints = @[
    multiplotBreakpoint(0, 1),
    multiplotBreakpoint(90, 2),
    multiplotBreakpoint(140, 3)
  ]

  echo multiplot([latency, requests, samples, heatmap], layout)
