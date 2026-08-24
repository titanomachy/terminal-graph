## Grouped and stacked horizontal bars with a shared zero baseline.

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
  options.seriesColors = @[colorBrightCyan, colorBrightYellow]

  echo plotBars(regions, results, options)

  options.mode = bmStacked
  options.caption = "Regional change (stacked)"
  echo "\n", plotBars(regions, results, options)
