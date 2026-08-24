## A finite tour of every graph family exposed by ``terminal_graph``.
##
## The live graph examples render snapshots here instead of taking over the
## terminal, so this showcase always completes on its own.

when isMainModule:
  import std/[math, terminal]

  import ../src/terminal_graph

  proc section(title: string) =
    echo "\n", bold(cyan("=== ", title, " ==="))

  proc responsiveMultiplot(
      plots: openArray[string]; horizontalGap = 4; verticalGap = 1;
      horizontalAlignment = mhaLeft;
      verticalAlignment = mvaTop): string =
    ## Detect the terminal width for every section instead of baking a fixed
    ## viewport into this resize-oriented showcase.
    var layout = initMultiplotOptions()
    layout.minimumCellWidth = 1
    layout.horizontalGap = horizontalGap
    layout.verticalGap = verticalGap
    layout.horizontalAlignment = horizontalAlignment
    layout.verticalAlignment = verticalAlignment
    layout.expandColumns = false
    multiplot(plots, layout)

  section("Terminal styling")
  let heading = initTerminalStyle(
    foreground = hexColor("#78c8ff"),
    background = indexedColor(17),
    attributes = {taBold, taUnderline}
  )
  echo styled(heading, " standard, ANSI-256, and RGB styling ")
  echo bold("nested ", brightMagenta("styles"), " restore correctly"),
    "  ", onRgb(35, 42, 58, brightYellow(" true color "))

  section("Sparklines")
  echo "Latency  ", sparkline([18, 21, 19, 26, 34, 31, 45, 38, 29, 24])
  echo "Load     ", sparkline([10, 25, 40, 75, 100])

  section("Connected line graph")
  echo plot(
    [3.0, 4.0, 9.0, 6.0, 2.0, 4.0, 5.0, 8.0],
    graphWidth(34),
    graphHeight(8),
    graphCaption("Request latency")
  )

  section("Horizontal bar graphs")
  let
    regions = ["North", "South", "East", "West"]
    results = @[
      @[18.0, 24.0, -7.0, 15.0],
      @[12.0, -5.0, 11.0, 19.0]
    ]
  var barOptions = initBarGraphOptions()
  barOptions.width = 24
  barOptions.caption = "Grouped change"
  barOptions.unit = "%"
  barOptions.seriesLegends = @["current", "previous"]
  barOptions.seriesColors = @[colorBrightCyan, colorBrightYellow]
  let groupedBars = plotBars(regions, results, barOptions)
  barOptions.mode = bmStacked
  barOptions.caption = "Stacked change"
  let stackedBars = plotBars(regions, results, barOptions)
  echo responsiveMultiplot([groupedBars, stackedBars])

  var requestOptions = initBarGraphOptions()
  requestOptions.width = 28
  requestOptions.caption = "Simple bar graph"
  requestOptions.seriesColors = @[colorBrightYellow]
  echo "\n", plotBars(
    regions,
    [42.0, 31.0, 37.0, 28.0],
    requestOptions
  )

  section("Irregular XY line and scatter plot")
  let
    irregular = @[
      xyPoint(-5.0, -1.0), xyPoint(-3.8, 2.5), xyPoint(-0.4, 0.5),
      xyPoint(0.2, 4.0), xyPoint(3.7, -2.0), xyPoint(5.0, 1.0)
    ]
    observations = @[
      xyPoint(-4.5, 1.0), xyPoint(-2.0, -2.0), xyPoint(-0.8, 3.0),
      xyPoint(1.5, 2.0), xyPoint(2.2, -1.5), xyPoint(4.3, 3.5)
    ]
  var xyOptions = initXYPlotOptions()
  xyOptions.width = 28
  xyOptions.height = 10
  xyOptions.xLabel = "time"
  xyOptions.yLabel = "value"
  xyOptions.caption = "Irregular line"
  let connected = plotXYMany([
    initXYSeries("signal", irregular, colorBrightCyan, marker = "●")
  ], xyOptions)
  xyOptions.caption = "Scatter samples"
  let scattered = plotScatterMany([
    initXYSeries("samples", observations, colorBrightYellow, marker = "◆")
  ], xyOptions)
  echo responsiveMultiplot([connected, scattered])

  section("Multiplot grid")
  echo responsiveMultiplot(
    [groupedBars, connected, stackedBars, scattered],
    horizontalAlignment = mhaCenter,
    verticalAlignment = mvaMiddle)

  section("Static graph")
  var staticGraph = initStaticGraph("Weekly requests", unit = "requests")
  let requests = staticGraph.addSeries(
    "requests", style = psFill, color = fgGreen, marker = "▄"
  )
  staticGraph.push(requests, [12.0, 18.0, 15.0, 27.0, 35.0, 31.0, 42.0])
  echo staticGraph.render(width = 54, height = 10, useColor = false)

  section("Live marker graph snapshot")
  var liveGraph = initLiveGraph(
    "Live service metrics", unit = "req/s", width = 54, height = 10,
    useColor = true
  )
  let throughput = liveGraph.addSeries(
    "throughput", style = psFill, color = fgCyan, marker = "▄"
  )
  liveGraph.push(throughput,
    [40.0, 48.0, 55.0, 51.0, 64.0, 58.0, 70.0, 66.0])
  echo liveGraph.renderFrame()

  section("Streaming line graph snapshot")
  var streamConfig = initAsciiGraphConfig()
  streamConfig.width = 40
  streamConfig.height = 8
  streamConfig.caption = "Streaming API latency"
  streamConfig.seriesColors = @[colorBrightCyan, colorBrightYellow]
  streamConfig.seriesLegends = @["p50", "p95"]
  var streaming = initLiveLineGraph(
    seriesCount = 2, maxSamples = 40, config = streamConfig
  )
  streaming.push(0, [18.0, 21.0, 19.0, 24.0, 23.0, 27.0, 25.0])
  streaming.push(1, [35.0, 42.0, 38.0, 51.0, 47.0, 56.0, 49.0])
  echo streaming.renderFrame()

  section("Streaming multiplot snapshot")
  var throughputConfig = initAsciiGraphConfig()
  throughputConfig.width = 27
  throughputConfig.height = 7
  throughputConfig.caption = "Throughput (req/s)"
  throughputConfig.seriesColors = @[colorBrightCyan]
  var latencyConfig = throughputConfig
  latencyConfig.caption = "Latency (ms)"
  latencyConfig.seriesColors = @[colorBrightYellow]
  var
    streamingThroughput = initLiveLineGraph(
      maxSamples = 30, config = throughputConfig)
    streamingLatency = initLiveLineGraph(
      maxSamples = 30, config = latencyConfig)
  streamingThroughput.push(0,
    [60.0, 68.0, 73.0, 70.0, 81.0, 78.0, 86.0])
  streamingLatency.push(0,
    [31.0, 28.0, 35.0, 29.0, 26.0, 32.0, 27.0])
  var streamingLayout = initMultiplotOptions()
  streamingLayout.minimumCellWidth = 30
  streamingLayout.horizontalGap = 4
  streamingLayout.expandColumns = false
  echo multiplot([
    streamingThroughput.renderFrame(),
    streamingLatency.renderFrame()
  ], streamingLayout)

  section("Surface and contour plots")
  var field: seq[seq[float64]]
  for row in 0 ..< 12:
    var values: seq[float64]
    let y = -2.0 + 4.0 * float64(row) / 11.0
    for column in 0 ..< 24:
      let x = -3.0 + 6.0 * float64(column) / 23.0
      values.add sin(x) * cos(y)
    field.add values

  var surfaceOptions = initSurfacePlotOptions()
  surfaceOptions.width = 24
  surfaceOptions.height = 16
  surfaceOptions.showScale = false
  surfaceOptions.caption = "2D surface"
  let surface = plotSurface(field, surfaceOptions)
  var contourOptions = surfaceOptions
  contourOptions.height = 8
  contourOptions.caption = "Filled contours"
  contourOptions.contourLevels = 8
  let contours = plotContour(field, contourOptions)
  var heatmapOptions = contourOptions
  heatmapOptions.caption = "Service heatmap"
  heatmapOptions.contourLevels = 7
  let serviceHeatmap = plotContour(@[
    @[0.0, 0.2, 0.5, 0.8, 1.0],
    @[0.1, 0.4, 0.9, 0.6, 0.3],
    @[0.2, 0.7, 1.0, 0.5, 0.1],
    @[0.0, 0.3, 0.6, 0.4, 0.2]
  ], heatmapOptions)
  echo responsiveMultiplot([surface, contours, serviceHeatmap])
