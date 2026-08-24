## Pure-Nim multiplot, surface, and filled-contour examples.

when isMainModule:
  import std/math

  import ../src/terminal_graph

  var field: seq[seq[float64]]
  for row in 0 ..< 20:
    var values: seq[float64]
    let y = -2.0 + 4.0 * float64(row) / 19.0
    for column in 0 ..< 40:
      let
        x = -3.0 + 6.0 * float64(column) / 39.0
        radius = x * x + y * y
      values.add exp(-radius) * cos(4.0 * sqrt(radius))
    field.add values

  var surfaceOptions = initSurfacePlotOptions()
  surfaceOptions.width = 40
  # A surface packs two samples into each terminal row, so forty sampled rows
  # align with the twenty rows in the contour plot beside it.
  surfaceOptions.height = 40
  surfaceOptions.showScale = false
  surfaceOptions.caption = "High-resolution surface"
  let surface = plotSurface(field, surfaceOptions)

  var contourOptions = surfaceOptions
  contourOptions.height = 20
  contourOptions.caption = "Filled contours"
  contourOptions.contourLevels = 8
  let contours = plotContour(field, contourOptions)

  var layout = initMultiplotOptions()
  layout.minimumCellWidth = 1
  layout.horizontalGap = 4
  layout.expandColumns = false
  echo multiplot([surface, contours], layout)
