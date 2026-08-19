## Static terminal graph rendering for numeric data.
##
## This module contains the shared plot data model and renders complete graph
## frames without changing terminal state. Most applications should import the
## ``terminal_graphs`` façade instead of this submodule directly.
##
## .. code-block:: nim
##
##   import terminal_graphs
##
##   var graph = initStaticGraph("Request latency", unit = "ms")
##   let latency = graph.addSeries("p95")
##   graph.push(latency, [18.0, 20.5, 19.0, 23.0])
##   echo graph.render(width = 60, height = 14, useColor = false)

import std/[deques, math, options, sequtils, strformat, strutils, terminal,
  unicode]

const
  DefaultMaxSamples* = 1_000
    ## Default number of samples retained per series.
  MinimumRenderWidth* = 24
    ## Smallest supported render width, including the y-axis.
  MinimumRenderHeight* = 8
    ## Smallest supported total render height.

type
  PlotStyle* = enum
    psLine,  ## Draw one marker at the sample value.
    psFill   ## Draw a filled column from the lower bound to the sample value.

  Series* = object
    ## Configuration for one series. Samples are managed through ``Plotter``.
    name*: string
    style*: PlotStyle
    color*: ForegroundColor
    marker*: string
    data: Deque[float64]

  SeriesStats* = object
    ## Summary statistics for the retained samples in a series.
    current*: float64
    minimum*: float64
    maximum*: float64
    average*: float64
    sampleCount*: int

  Plotter* = object
    ## A collection of named series that can be rendered as a terminal graph.
    title*: string
    unit*: string
    series: seq[Series]
    fixedRange: Option[tuple[minimum, maximum: float64]]
    sampleLimit: int

  StaticGraph* = Plotter
    ## Descriptive alias for ``Plotter`` when rendering standalone frames.

proc requireFinite(value: float64; argumentName: string) =
  if value.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, argumentName & " must be a finite number")

proc requireSeries(plotter: Plotter; seriesIdx: int) =
  if seriesIdx < 0 or seriesIdx >= plotter.series.len:
    raise newException(IndexDefect,
      &"series index {seriesIdx} is outside 0 ..< {plotter.series.len}")

proc trimToLimit(series: var Series; limit: int) =
  while series.data.len > limit:
    discard series.data.popFirst()

proc initPlotter*(title: string; unit = "";
                  maxSamples = DefaultMaxSamples): Plotter =
  ## Creates an empty plotter.
  ##
  ## ``maxSamples`` bounds memory usage for long-running applications. When a
  ## series exceeds the limit, its oldest samples are discarded.
  if maxSamples <= 0:
    raise newException(ValueError, "maxSamples must be greater than zero")

  Plotter(
    title: title,
    unit: unit,
    series: @[],
    fixedRange: none(tuple[minimum, maximum: float64]),
    sampleLimit: maxSamples
  )

proc initStaticGraph*(title: string; unit = "";
                      maxSamples = DefaultMaxSamples): StaticGraph =
  ## Creates a static graph. This is the descriptive equivalent of
  ## ``initPlotter``; both constructors return the same graph type.
  initPlotter(title, unit, maxSamples)

proc addSeries*(plotter: var Plotter; name: string; style = psLine;
                color = fgCyan; marker = "•"): int {.discardable.} =
  ## Adds a series and returns the index used by ``push`` and related procs.
  ##
  ## A marker must contain exactly one Unicode code point so every sample maps
  ## to one cell in the graph grid.
  if marker.runeLen != 1:
    raise newException(ValueError,
      "marker must contain exactly one Unicode code point")

  plotter.series.add Series(
    name: name,
    style: style,
    color: color,
    marker: marker,
    data: initDeque[float64]()
  )
  plotter.series.high

proc seriesCount*(plotter: Plotter): int =
  ## Returns the number of configured series.
  plotter.series.len

proc maxSamples*(plotter: Plotter): int =
  ## Returns the maximum number of retained samples per series.
  plotter.sampleLimit

proc setMaxSamples*(plotter: var Plotter; maxSamples: int) =
  ## Changes the retention limit and immediately trims existing series.
  if maxSamples <= 0:
    raise newException(ValueError, "maxSamples must be greater than zero")

  plotter.sampleLimit = maxSamples
  for series in plotter.series.mitems:
    series.trimToLimit(maxSamples)

proc push*(plotter: var Plotter; seriesIdx: int; value: float64) =
  ## Appends one finite sample to a series.
  plotter.requireSeries(seriesIdx)
  value.requireFinite("value")

  plotter.series[seriesIdx].data.addLast(value)
  plotter.series[seriesIdx].trimToLimit(plotter.sampleLimit)

proc push*(plotter: var Plotter; seriesIdx: int;
           values: openArray[float64]) =
  ## Appends several samples to a series in order.
  ##
  ## All values are validated before the series is changed.
  plotter.requireSeries(seriesIdx)
  for value in values:
    value.requireFinite("value")
  for value in values:
    plotter.series[seriesIdx].data.addLast(value)
  plotter.series[seriesIdx].trimToLimit(plotter.sampleLimit)

proc sampleCount*(plotter: Plotter; seriesIdx: int): int =
  ## Returns the number of retained samples for a series.
  plotter.requireSeries(seriesIdx)
  plotter.series[seriesIdx].data.len

proc samples*(plotter: Plotter; seriesIdx: int): seq[float64] =
  ## Returns a copy of the retained samples, oldest first.
  plotter.requireSeries(seriesIdx)
  result = newSeqOfCap[float64](plotter.series[seriesIdx].data.len)
  for value in plotter.series[seriesIdx].data:
    result.add value

proc latest*(plotter: Plotter; seriesIdx: int): Option[float64] =
  ## Returns the newest sample, or ``none`` when the series is empty.
  plotter.requireSeries(seriesIdx)
  let series = plotter.series[seriesIdx]
  if series.data.len > 0:
    some(series.data[^1])
  else:
    none(float64)

proc clear*(plotter: var Plotter; seriesIdx: int) =
  ## Removes every sample from one series without removing its configuration.
  plotter.requireSeries(seriesIdx)
  plotter.series[seriesIdx].data.clear()

proc clear*(plotter: var Plotter) =
  ## Removes every sample from every series.
  for series in plotter.series.mitems:
    series.data.clear()

proc setRange*(plotter: var Plotter; minimum, maximum: float64) =
  ## Uses a fixed y-axis range until ``clearRange`` is called.
  minimum.requireFinite("minimum")
  maximum.requireFinite("maximum")
  if minimum >= maximum:
    raise newException(ValueError, "minimum must be less than maximum")
  plotter.fixedRange = some((minimum: minimum, maximum: maximum))

proc clearRange*(plotter: var Plotter) =
  ## Restores automatic y-axis scaling.
  plotter.fixedRange = none(tuple[minimum, maximum: float64])

proc statistics*(plotter: Plotter;
                 seriesIdx: int): Option[SeriesStats] =
  ## Computes statistics for a series, or ``none`` if it has no samples.
  plotter.requireSeries(seriesIdx)
  let series = plotter.series[seriesIdx]
  if series.data.len == 0:
    return none(SeriesStats)

  var
    minimum = Inf
    maximum = -Inf
    sum = 0.0
  for value in series.data:
    minimum = min(minimum, value)
    maximum = max(maximum, value)
    sum += value

  some(SeriesStats(
    current: series.data[^1],
    minimum: minimum,
    maximum: maximum,
    average: sum / float64(series.data.len),
    sampleCount: series.data.len
  ))

proc valueRange*(plotter: Plotter): tuple[minimum, maximum: float64] =
  ## Returns the fixed range or the automatically computed range.
  ##
  ## Empty plots use ``0.0 .. 1.0``. A single-valued plot is padded by one on
  ## either side so rendering never has to divide by zero.
  if plotter.fixedRange.isSome:
    return plotter.fixedRange.get()

  var
    minimum = Inf
    maximum = -Inf
  for series in plotter.series:
    for value in series.data:
      minimum = min(minimum, value)
      maximum = max(maximum, value)

  if minimum == Inf:
    return (minimum: 0.0, maximum: 1.0)
  if minimum == maximum:
    return (minimum: minimum - 1.0, maximum: maximum + 1.0)
  (minimum: minimum, maximum: maximum)

proc resolvedDimension(requested, detected, minimum: int;
                       name: string): int =
  if requested < 0:
    raise newException(ValueError, name & " cannot be negative")
  if requested == 0:
    return max(detected, minimum)
  if requested < minimum:
    raise newException(ValueError,
      &"{name} must be at least {minimum}, or zero for automatic sizing")
  requested

proc formattedAxisValue(value: float64): string =
  result = formatFloat(value, ffDecimal, 1)
  if result.len > 7:
    result = formatFloat(value, ffScientific, 0)
  result = strutils.align(result, 7)

proc appendColor(buffer: var string; color: ForegroundColor;
                 useColor: bool) =
  if useColor:
    buffer.add ansiForegroundColorCode(color)

proc appendReset(buffer: var string; useColor: bool) =
  if useColor:
    buffer.add ansiResetCode

proc render*(plotter: Plotter; width = 0; height = 0;
             useColor = true; showStats = true): string =
  ## Renders the current graph to a string without changing the plotter.
  ##
  ## ``width`` and ``height`` describe the complete frame. Pass zero (the
  ## default) to use the detected terminal size. Explicit dimensions make
  ## snapshots and redirected output deterministic. Set ``useColor`` to false
  ## to omit ANSI escape sequences. When multiple series occupy the same cell,
  ## the series added last is visible.
  let
    frameWidth = resolvedDimension(
      width, terminalWidth(), MinimumRenderWidth, "width")
    frameHeight = resolvedDimension(
      height, terminalHeight(), MinimumRenderHeight, "height")
    yLabelWidth = 8
    plotWidth = frameWidth - yLabelWidth - 1
    reservedRows = if showStats: 4 else: 3
    plotHeight = frameHeight - reservedRows
    valueBounds = plotter.valueRange()
    valueSpan = valueBounds.maximum - valueBounds.minimum

  result = newStringOfCap(frameWidth * frameHeight * 2)

  if useColor:
    result.add ansiForegroundColorCode(fgWhite)
    result.add ansiStyleCode(styleBright)
  result.add plotter.title
  if plotter.unit.len > 0:
    result.add &" ({plotter.unit})"
  result.appendReset(useColor)
  result.add '\n'

  if showStats:
    var hasStats = false
    for index, series in plotter.series:
      let summary = plotter.statistics(index)
      if summary.isNone:
        continue
      if hasStats:
        result.add "  "
      hasStats = true
      let stats = summary.get()
      result.appendColor(series.color, useColor)
      result.add &"{series.name} [{series.marker}]"
      result.appendReset(useColor)
      result.add &" cur {stats.current:.2f} min {stats.minimum:.2f}" &
        &" max {stats.maximum:.2f} avg {stats.average:.2f}"
    result.add '\n'

  var
    grid = newSeqWith(plotHeight, newSeqWith(plotWidth, " "))
    colors = newSeqWith(plotHeight, newSeqWith(plotWidth, fgDefault))

  for series in plotter.series:
    let
      visibleCount = min(series.data.len, plotWidth)
      firstVisible = series.data.len - visibleCount
      startX = plotWidth - visibleCount

    for index, value in series.data:
      if index < firstVisible:
        continue
      let
        x = startX + index - firstVisible
        normalized = clamp(
          (value - valueBounds.minimum) / valueSpan, 0.0, 1.0)
        targetRow = clamp(
          plotHeight - 1 - int(round(normalized * float64(plotHeight - 1))),
          0,
          plotHeight - 1
        )

      case series.style
      of psLine:
        grid[targetRow][x] = series.marker
        colors[targetRow][x] = series.color
      of psFill:
        for row in targetRow ..< plotHeight:
          grid[row][x] = if row == targetRow: series.marker else: "█"
          colors[row][x] = series.color

  for row in 0 ..< plotHeight:
    let
      rowFraction = 1.0 - float64(row) / float64(max(plotHeight - 1, 1))
      rowValue = valueBounds.minimum + rowFraction * valueSpan
      showLabel = row == 0 or row == plotHeight div 2 or
        row == plotHeight - 1
      label = if showLabel:
        formattedAxisValue(rowValue) & " "
      else:
        repeat(' ', yLabelWidth)

    result.appendColor(fgWhite, useColor)
    result.add label & "┤"
    result.appendReset(useColor)

    var activeColor = fgDefault
    for column in 0 ..< plotWidth:
      let cellColor = colors[row][column]
      if cellColor != activeColor:
        result.appendReset(useColor)
        if cellColor != fgDefault:
          result.appendColor(cellColor, useColor)
        activeColor = cellColor
      result.add grid[row][column]
    result.appendReset(useColor)
    result.add '\n'

  result.add repeat(' ', yLabelWidth) & "└" & repeat("─", plotWidth) & '\n'
  let timeline = &"← last {plotWidth} samples"
  result.add repeat(' ', yLabelWidth + 1)
  if useColor:
    result.add ansiForegroundColorCode(fgBlack)
    result.add ansiStyleCode(styleBright)
  result.add timeline
  result.appendReset(useColor)
