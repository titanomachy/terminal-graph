## Scatter plots and irregularly spaced connected XY graphs.
##
## Unlike the sample-indexed renderer in ``line_graphs``, this module maps
## explicit numeric X and Y coordinates onto a terminal canvas. Axes cross at
## zero whenever zero is visible; automatic ranges include zero by default.
## NaN points break connected paths, while infinities are rejected.

import std/[math, options, sequtils, strformat, unicode]

import ./line_graphs

export line_graphs

type
  XYPoint* = object
    ## One point in a two-dimensional numeric coordinate system.
    x*: float64
    y*: float64

  XYSeries* = object
    ## One named XY series. Points are connected in their supplied order.
    name*: string
    points*: seq[XYPoint]
    color*: TerminalColor
    marker*: string
    connect*: bool

  XYPlotOptions* = object
    ## Complete scatter/XY graph configuration.
    width*: int
    height*: int
    useColor*: bool
    showAxes*: bool
    includeZero*: bool
    showRanges*: bool
    caption*: string
    xLabel*: string
    yLabel*: string
    axisColor*: TerminalColor
    labelColor*: TerminalColor
    minimumX*: Option[float64]
    maximumX*: Option[float64]
    minimumY*: Option[float64]
    maximumY*: Option[float64]
    lineEnding*: string

  XYCell = object
    glyph: string
    color: TerminalColor
    priority: int

const DefaultXYColors*: array[8, TerminalColor] = [
  colorBrightCyan, colorBrightYellow, colorBrightMagenta, colorBrightGreen,
  colorBrightRed, colorBrightBlue, colorBrightWhite, colorGreen
]
  ## Default colors assigned cyclically to XY series.

proc xyPoint*[X, Y: SomeNumber](x: X; y: Y): XYPoint =
  ## Constructs an ``XYPoint`` from integer or floating-point coordinates.
  XYPoint(x: float64(x), y: float64(y))

proc xyPoints*[X, Y: SomeNumber](xValues: openArray[X];
                                 yValues: openArray[Y]): seq[XYPoint] =
  ## Pairs equally sized X and Y arrays into points.
  if xValues.len != yValues.len:
    raise newException(ValueError,
      "X and Y arrays must contain the same number of values")
  result = newSeqOfCap[XYPoint](xValues.len)
  for index in 0 ..< xValues.len:
    result.add xyPoint(xValues[index], yValues[index])

proc initXYSeries*(name: string; points: openArray[XYPoint];
                   color = colorDefault; marker = "●";
                   connect = true): XYSeries =
  ## Creates a series without rendering it.
  XYSeries(
    name: name,
    points: @points,
    color: color,
    marker: marker,
    connect: connect
  )

proc initXYPlotOptions*(): XYPlotOptions =
  ## Returns defaults suitable for a colored terminal plot.
  XYPlotOptions(
    width: 60,
    height: 20,
    useColor: true,
    showAxes: true,
    includeZero: true,
    showRanges: true,
    axisColor: colorWhite,
    labelColor: colorDefault,
    minimumX: none(float64),
    maximumX: none(float64),
    minimumY: none(float64),
    maximumY: none(float64),
    lineEnding: "\n"
  )

proc validateRange(minimum, maximum: float64; axis: string) =
  if minimum.classify in {fcNan, fcInf, fcNegInf} or
      maximum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, axis & " range must be finite")
  if minimum >= maximum:
    raise newException(ValueError, axis & " minimum must be below maximum")

proc setXRange*(options: var XYPlotOptions; minimum, maximum: float64) =
  ## Sets a fixed horizontal viewport.
  validateRange(minimum, maximum, "X")
  options.minimumX = some(minimum)
  options.maximumX = some(maximum)

proc clearXRange*(options: var XYPlotOptions) =
  ## Restores automatic horizontal scaling.
  options.minimumX = none(float64)
  options.maximumX = none(float64)

proc setYRange*(options: var XYPlotOptions; minimum, maximum: float64) =
  ## Sets a fixed vertical viewport.
  validateRange(minimum, maximum, "Y")
  options.minimumY = some(minimum)
  options.maximumY = some(maximum)

proc clearYRange*(options: var XYPlotOptions) =
  ## Restores automatic vertical scaling.
  options.minimumY = none(float64)
  options.maximumY = none(float64)

proc normalizedOptions(options: XYPlotOptions): XYPlotOptions =
  result = options
  if result.width < 3 or result.height < 3:
    raise newException(ValueError,
      "XY width and height must both be at least three")
  if result.lineEnding.len == 0:
    result.lineEnding = "\n"
  if result.minimumX.isSome != result.maximumX.isSome:
    raise newException(ValueError,
      "X minimum and maximum must both be set or both be automatic")
  if result.minimumY.isSome != result.maximumY.isSome:
    raise newException(ValueError,
      "Y minimum and maximum must both be set or both be automatic")
  if result.minimumX.isSome:
    validateRange(result.minimumX.get(), result.maximumX.get(), "X")
  if result.minimumY.isSome:
    validateRange(result.minimumY.get(), result.maximumY.get(), "Y")

proc isGap(point: XYPoint): bool =
  point.x.isNaN or point.y.isNaN

proc validateSeries(series: openArray[XYSeries]) =
  if series.len == 0:
    raise newException(ValueError, "XY plot requires at least one series")
  var validPointCount = 0
  for item in series:
    if item.marker.runeLen != 1:
      raise newException(ValueError,
        "XY markers must contain one Unicode code point")
    for point in item.points:
      if point.x.classify in {fcInf, fcNegInf} or
          point.y.classify in {fcInf, fcNegInf}:
        raise newException(ValueError,
          "XY coordinates must be finite numbers or NaN gaps")
      if not point.isGap:
        inc validPointCount
  if validPointCount == 0:
    raise newException(ValueError,
      "XY plot requires at least one non-NaN point")

proc expandedRange(minimum, maximum: float64): tuple[
    minimum, maximum: float64] =
  if minimum < maximum:
    return (minimum, maximum)
  let padding = max(abs(minimum) * 0.05, 1.0)
  (minimum - padding, maximum + padding)

proc dataRanges(series: openArray[XYSeries]; options: XYPlotOptions): tuple[
    minimumX, maximumX, minimumY, maximumY: float64] =
  result = (Inf, -Inf, Inf, -Inf)
  for item in series:
    for point in item.points:
      if point.isGap:
        continue
      result.minimumX = min(result.minimumX, point.x)
      result.maximumX = max(result.maximumX, point.x)
      result.minimumY = min(result.minimumY, point.y)
      result.maximumY = max(result.maximumY, point.y)

  if options.includeZero:
    result.minimumX = min(result.minimumX, 0.0)
    result.maximumX = max(result.maximumX, 0.0)
    result.minimumY = min(result.minimumY, 0.0)
    result.maximumY = max(result.maximumY, 0.0)

  let
    xRange = expandedRange(result.minimumX, result.maximumX)
    yRange = expandedRange(result.minimumY, result.maximumY)
  result.minimumX = if options.minimumX.isSome:
    options.minimumX.get()
  else:
    xRange.minimum
  result.maximumX = if options.maximumX.isSome:
    options.maximumX.get()
  else:
    xRange.maximum
  result.minimumY = if options.minimumY.isSome:
    options.minimumY.get()
  else:
    yRange.minimum
  result.maximumY = if options.maximumY.isSome:
    options.maximumY.get()
  else:
    yRange.maximum

proc xCoordinate(value, minimum, maximum: float64; width: int): int =
  clamp(int(round((value - minimum) / (maximum - minimum) *
    float64(width - 1))), 0, width - 1)

proc yCoordinate(value, minimum, maximum: float64; height: int): int =
  height - 1 - clamp(int(round((value - minimum) / (maximum - minimum) *
    float64(height - 1))), 0, height - 1)

proc put(canvas: var seq[seq[XYCell]]; x, y: int; glyph: string;
         color: TerminalColor; priority: int) =
  if x < 0 or x >= canvas[0].len or y < 0 or y >= canvas.len:
    return
  if priority >= canvas[y][x].priority:
    canvas[y][x] = XYCell(glyph: glyph, color: color, priority: priority)

proc lineGlyph(x1, y1, x2, y2: int): string =
  let
    deltaX = x2 - x1
    deltaY = y2 - y1
  if deltaY == 0:
    "─"
  elif deltaX == 0:
    "│"
  elif (deltaX > 0 and deltaY > 0) or (deltaX < 0 and deltaY < 0):
    "╲"
  else:
    "╱"

proc drawLine(canvas: var seq[seq[XYCell]]; x1, y1, x2, y2: int;
              color: TerminalColor) =
  let glyph = lineGlyph(x1, y1, x2, y2)
  var
    x = x1
    y = y1
    deltaX = abs(x2 - x1)
    stepX = if x1 < x2: 1 else: -1
    deltaY = -abs(y2 - y1)
    stepY = if y1 < y2: 1 else: -1
    error = deltaX + deltaY
  while true:
    canvas.put(x, y, glyph, color, 2)
    if x == x2 and y == y2:
      break
    let doubledError = error * 2
    if doubledError >= deltaY:
      error += deltaY
      x += stepX
    if doubledError <= deltaX:
      error += deltaX
      y += stepY

proc clipTest(p, q: float64; lower, upper: var float64): bool =
  if p == 0.0:
    return q >= 0.0
  let ratio = q / p
  if p < 0.0:
    if ratio > upper:
      return false
    if ratio > lower:
      lower = ratio
  else:
    if ratio < lower:
      return false
    if ratio < upper:
      upper = ratio
  true

proc clipSegment(first, second: XYPoint;
                 minimumX, maximumX, minimumY, maximumY: float64;
                 clippedFirst, clippedSecond: var XYPoint): bool =
  let
    deltaX = second.x - first.x
    deltaY = second.y - first.y
  var lower = 0.0
  var upper = 1.0
  if not clipTest(-deltaX, first.x - minimumX, lower, upper) or
      not clipTest(deltaX, maximumX - first.x, lower, upper) or
      not clipTest(-deltaY, first.y - minimumY, lower, upper) or
      not clipTest(deltaY, maximumY - first.y, lower, upper):
    return false
  clippedFirst = XYPoint(
    x: first.x + lower * deltaX,
    y: first.y + lower * deltaY
  )
  clippedSecond = XYPoint(
    x: first.x + upper * deltaX,
    y: first.y + upper * deltaY
  )
  true

proc inside(point: XYPoint; minimumX, maximumX,
            minimumY, maximumY: float64): bool =
  point.x >= minimumX and point.x <= maximumX and
    point.y >= minimumY and point.y <= maximumY

proc renderCanvas(canvas: openArray[seq[XYCell]];
                  options: XYPlotOptions): string =
  for rowIndex, row in canvas:
    if rowIndex > 0:
      result.add options.lineEnding
    var activeColor = colorDefault
    for cell in row:
      if options.useColor and cell.color != activeColor:
        result.add ansiCode(cell.color)
        activeColor = cell.color
      result.add cell.glyph
    if options.useColor and activeColor != colorDefault:
      result.add termClear

proc addLegend(result: var string; series: openArray[XYSeries];
               options: XYPlotOptions) =
  var hasName = false
  for item in series:
    hasName = hasName or item.name.len > 0
  if not hasName:
    return
  result.add options.lineEnding
  for index, item in series:
    if index > 0:
      result.add "  "
    if options.useColor:
      result.add ansiCode(item.color)
    result.add item.marker
    if options.useColor:
      result.add termClear
    result.add " " & (if item.name.len > 0: item.name else: "series " & $(index + 1))

proc rangeLabel(label, fallback: string; minimum, maximum: float64): string =
  let prefix = if label.len > 0: label else: fallback
  &"{prefix}: {minimum:.3g} .. {maximum:.3g}"

proc plotXYFloat(rawSeries: openArray[XYSeries];
                 rawOptions: XYPlotOptions): string =
  rawSeries.validateSeries()
  let options = normalizedOptions(rawOptions)
  var series = @rawSeries
  for index in 0 ..< series.len:
    if series[index].color == colorDefault:
      series[index].color = DefaultXYColors[index mod DefaultXYColors.len]

  let ranges = dataRanges(series, options)
  var canvas = newSeqWith(options.height,
    newSeqWith(options.width,
      XYCell(glyph: " ", color: colorDefault, priority: 0)))

  if options.showAxes:
    let
      verticalAxis = if ranges.minimumX <= 0.0 and ranges.maximumX >= 0.0:
        xCoordinate(0.0, ranges.minimumX, ranges.maximumX, options.width)
      elif ranges.minimumX > 0.0:
        0
      else:
        options.width - 1
      horizontalAxis = if ranges.minimumY <= 0.0 and ranges.maximumY >= 0.0:
        yCoordinate(0.0, ranges.minimumY, ranges.maximumY, options.height)
      elif ranges.minimumY > 0.0:
        options.height - 1
      else:
        0
    for row in 0 ..< options.height:
      canvas.put(verticalAxis, row, "│", options.axisColor, 1)
    for column in 0 ..< options.width:
      canvas.put(column, horizontalAxis, "─", options.axisColor, 1)
    canvas.put(verticalAxis, horizontalAxis, "┼", options.axisColor, 1)

  for item in series:
    if item.connect and item.points.len > 1:
      for index in 1 ..< item.points.len:
        let
          first = item.points[index - 1]
          second = item.points[index]
        if first.isGap or second.isGap:
          continue
        var clippedFirst, clippedSecond: XYPoint
        if clipSegment(first, second,
            ranges.minimumX, ranges.maximumX,
            ranges.minimumY, ranges.maximumY,
            clippedFirst, clippedSecond):
          canvas.drawLine(
            xCoordinate(clippedFirst.x, ranges.minimumX,
              ranges.maximumX, options.width),
            yCoordinate(clippedFirst.y, ranges.minimumY,
              ranges.maximumY, options.height),
            xCoordinate(clippedSecond.x, ranges.minimumX,
              ranges.maximumX, options.width),
            yCoordinate(clippedSecond.y, ranges.minimumY,
              ranges.maximumY, options.height),
            item.color
          )
    for point in item.points:
      if not point.isGap and point.inside(
          ranges.minimumX, ranges.maximumX,
          ranges.minimumY, ranges.maximumY):
        canvas.put(
          xCoordinate(point.x, ranges.minimumX,
            ranges.maximumX, options.width),
          yCoordinate(point.y, ranges.minimumY,
            ranges.maximumY, options.height),
          item.marker, item.color, 3
        )

  if options.caption.len > 0:
    if options.useColor and options.labelColor != colorDefault:
      result.add ansiCode(options.labelColor)
    result.add options.caption
    if options.useColor and options.labelColor != colorDefault:
      result.add termClear
    result.add options.lineEnding
  result.add renderCanvas(canvas, options)
  if options.showRanges:
    result.add options.lineEnding
    if options.useColor and options.labelColor != colorDefault:
      result.add ansiCode(options.labelColor)
    result.add rangeLabel(options.xLabel, "x",
      ranges.minimumX, ranges.maximumX)
    result.add "  "
    result.add rangeLabel(options.yLabel, "y",
      ranges.minimumY, ranges.maximumY)
    if options.useColor and options.labelColor != colorDefault:
      result.add termClear
  result.addLegend(series, options)

proc plotXYMany*(series: openArray[XYSeries];
                 options: XYPlotOptions): string =
  ## Renders multiple XY series, honoring each series' ``connect`` setting.
  plotXYFloat(series, options)

proc plotXYMany*(series: openArray[XYSeries]): string =
  ## Renders multiple XY series using default options.
  plotXYMany(series, initXYPlotOptions())

proc plotScatterMany*(series: openArray[XYSeries];
                      options: XYPlotOptions): string =
  ## Renders multiple series as unconnected points.
  var pointsOnly = @series
  for item in pointsOnly.mitems:
    item.connect = false
  plotXYFloat(pointsOnly, options)

proc plotScatterMany*(series: openArray[XYSeries]): string =
  ## Renders multiple scatter series using default options.
  plotScatterMany(series, initXYPlotOptions())

proc plotXY*(points: openArray[XYPoint];
             options: XYPlotOptions): string =
  ## Renders one irregularly spaced connected series.
  plotXYMany([initXYSeries("", points, connect = true)], options)

proc plotXY*(points: openArray[XYPoint]): string =
  ## Renders one connected XY series using default options.
  plotXY(points, initXYPlotOptions())

proc plotScatter*(points: openArray[XYPoint];
                  options: XYPlotOptions): string =
  ## Renders one unconnected scatter series.
  plotScatterMany([initXYSeries("", points, connect = false)], options)

proc plotScatter*(points: openArray[XYPoint]): string =
  ## Renders one scatter series using default options.
  plotScatter(points, initXYPlotOptions())

proc plotXY*[X, Y: SomeNumber](xValues: openArray[X];
                               yValues: openArray[Y];
                               options: XYPlotOptions): string =
  ## Renders paired X and Y arrays as an irregular connected series.
  plotXY(xyPoints(xValues, yValues), options)

proc plotXY*[X, Y: SomeNumber](xValues: openArray[X];
                               yValues: openArray[Y]): string =
  ## Renders paired arrays using default options.
  plotXY(xValues, yValues, initXYPlotOptions())

proc plotScatter*[X, Y: SomeNumber](xValues: openArray[X];
                                    yValues: openArray[Y];
                                    options: XYPlotOptions): string =
  ## Renders paired X and Y arrays as a scatter plot.
  plotScatter(xyPoints(xValues, yValues), options)

proc plotScatter*[X, Y: SomeNumber](xValues: openArray[X];
                                    yValues: openArray[Y]): string =
  ## Renders paired arrays as a scatter plot using default options.
  plotScatter(xValues, yValues, initXYPlotOptions())
