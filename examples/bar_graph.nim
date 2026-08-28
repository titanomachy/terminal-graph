## Grouped and stacked horizontal bars with a shared zero baseline.
# Run with: nim r --path:src examples/bar_graph.nim

when isMainModule:
  import ../src/terminal_graph

  let
    regions = ["North", "South", "East", "West"]
    results = @[
      @[18.0, 24.0, -7.0, 15.0],
      @[12.0, -5.0, 11.0, 19.0]
    ]

  var options = initBarGraphOptions()
  options.width = 32
  options.caption = "Regional change"
  options.unit = "%"
  options.seriesLegends = @["current", "previous"]
  options.seriesColors = @ModernGraphSeriesColors

  echo plotBars(regions, results, options)

  options.mode = bmStacked
  options.caption = "Regional change (stacked)"
  echo "\n", plotBars(regions, results, options)
