## Pure-Nim horizontal bar charts for terminal applications.
##
## Bars may be rendered as independent grouped rows or as stacked segments.
## The value range always contains zero, giving positive and negative values a
## meaningful shared baseline. Most applications should import the
## ``terminal_graphs`` façade instead of this submodule directly.

import std/[math, options, sequtils, strformat, strutils, unicode]

import ./line_graphs

export line_graphs

type
  BarMode* = enum
    ## Controls how multiple values for each category are arranged.
    bmGrouped,
    bmStacked

  BarGraphOptions* = object
    ## Complete horizontal bar-chart configuration.
    width*: int
    mode*: BarMode
    useColor*: bool
    showValues*: bool
    caption*: string
    unit*: string
    glyph*: string
    axisGlyph*: string
    seriesColors*: seq[TerminalColor]
    seriesLegends*: seq[string]
    minimum*: Option[float64]
    maximum*: Option[float64]
    lineEnding*: string

  BarCell = object
    glyph: string
    color: TerminalColor

const DefaultBarColors*: array[8, TerminalColor] = [
  colorBrightCyan, colorBrightYellow, colorBrightMagenta, colorBrightGreen,
  colorBrightRed, colorBrightBlue, colorBrightWhite, colorGreen
]
  ## Default colors assigned cyclically to bar series.

proc initBarGraphOptions*(): BarGraphOptions =
  ## Returns defaults for a colored, value-labelled grouped chart.
  BarGraphOptions(
    width: 40,
    mode: bmGrouped,
    useColor: true,
    showValues: true,
    glyph: "█",
    axisGlyph: "│",
    seriesColors: @DefaultBarColors,
    minimum: none(float64),
    maximum: none(float64),
    lineEnding: "\n"
  )

proc setBarRange*(options: var BarGraphOptions;
                  minimum, maximum: float64) =
  ## Fixes the chart range. The range must contain zero.
  if minimum.classify in {fcNan, fcInf, fcNegInf} or
      maximum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "bar range must be finite")
  if minimum >= maximum:
    raise newException(ValueError, "bar minimum must be below maximum")
  if minimum > 0.0 or maximum < 0.0:
    raise newException(ValueError, "bar range must contain zero")
  options.minimum = some(minimum)
  options.maximum = some(maximum)

proc clearBarRange*(options: var BarGraphOptions) =
  ## Restores automatic range calculation.
  options.minimum = none(float64)
  options.maximum = none(float64)

proc validateGlyph(value, name: string) =
  if value.runeLen != 1:
    raise newException(ValueError, name & " must contain one Unicode code point")

proc normalizedOptions(options: BarGraphOptions;
                       seriesCount: int): BarGraphOptions =
  result = options
  if result.width < 3:
    raise newException(ValueError, "bar width must be at least three")
  result.glyph.validateGlyph("bar glyph")
  result.axisGlyph.validateGlyph("bar axis glyph")
  if result.lineEnding.len == 0:
    result.lineEnding = "\n"
  if result.seriesColors.len == 0:
    result.seriesColors = @DefaultBarColors
  if result.seriesLegends.len > 0 and
      result.seriesLegends.len != seriesCount:
    raise newException(ValueError,
      "bar legend count must match the number of series")
  if result.minimum.isSome != result.maximum.isSome:
    raise newException(ValueError,
      "bar minimum and maximum must both be set or both be automatic")
  if result.minimum.isSome:
    let
      minimum = result.minimum.get()
      maximum = result.maximum.get()
    if minimum.classify in {fcNan, fcInf, fcNegInf} or
        maximum.classify in {fcNan, fcInf, fcNegInf}:
      raise newException(ValueError, "bar range must be finite")
    if minimum >= maximum:
      raise newException(ValueError, "bar minimum must be below maximum")
    if minimum > 0.0 or maximum < 0.0:
      raise newException(ValueError, "bar range must contain zero")

proc validateData(labels: openArray[string];
                  series: openArray[seq[float64]]) =
  if labels.len == 0:
    raise newException(ValueError, "bar labels cannot be empty")
  if series.len == 0:
    raise newException(ValueError, "bar chart requires at least one series")
  for label in labels:
    if '\n' in label or '\r' in label:
      raise newException(ValueError, "bar labels cannot contain line breaks")
  for values in series:
    if values.len != labels.len:
      raise newException(ValueError,
        "every bar series must contain one value per label")
    for value in values:
      if value.classify in {fcNan, fcInf, fcNegInf}:
        raise newException(ValueError, "bar values must be finite")

proc automaticRange(series: openArray[seq[float64]];
                    mode: BarMode; categoryCount: int): tuple[
    minimum, maximum: float64] =
  result = (0.0, 0.0)
  case mode
  of bmGrouped:
    for values in series:
      for value in values:
        result.minimum = min(result.minimum, value)
        result.maximum = max(result.maximum, value)
  of bmStacked:
    for category in 0 ..< categoryCount:
      var positive, negative = 0.0
      for values in series:
        if values[category] >= 0.0:
          positive += values[category]
        else:
          negative += values[category]
      result.minimum = min(result.minimum, negative)
      result.maximum = max(result.maximum, positive)
  if result.minimum == result.maximum:
    if result.minimum == 0.0:
      result.maximum = 1.0
    elif result.minimum > 0.0:
      result.minimum = 0.0
    else:
      result.maximum = 0.0

proc coordinate(value, minimum, maximum: float64; width: int): int =
  clamp(int(round((value - minimum) / (maximum - minimum) *
    float64(width - 1))), 0, width - 1)

proc blankBar(options: BarGraphOptions; zeroColumn: int): seq[BarCell] =
  result = newSeqWith(options.width, BarCell(glyph: " ", color: colorDefault))
  result[zeroColumn].glyph = options.axisGlyph

proc fillSegment(cells: var seq[BarCell]; startValue, endValue,
                 minimum, maximum: float64; glyph: string;
                 color: TerminalColor) =
  if startValue == endValue:
    return
  let
    startColumn = coordinate(startValue, minimum, maximum, cells.len)
    endColumn = coordinate(endValue, minimum, maximum, cells.len)
  if endColumn > startColumn:
    for column in startColumn + 1 .. endColumn:
      cells[column] = BarCell(glyph: glyph, color: color)
  elif endColumn < startColumn:
    for column in endColumn ..< startColumn:
      cells[column] = BarCell(glyph: glyph, color: color)

proc renderCells(cells: openArray[BarCell]; useColor: bool): string =
  var
    activeColor = colorDefault
    activeSolidBlock = false
  for cell in cells:
    let solidBlock = useColor and cell.color != colorDefault and
      cell.glyph == "█"
    if useColor and (cell.color != activeColor or
        solidBlock != activeSolidBlock):
      if activeColor != colorDefault:
        result.add termClear
      if cell.color != colorDefault:
        if solidBlock:
          result.add ansiCode(cell.color)
          result.add ansiCode(cell.color, cpBackground)
        else:
          result.add ansiCode(cell.color)
      activeColor = cell.color
      activeSolidBlock = solidBlock
    result.add cell.glyph
  if useColor and activeColor != colorDefault:
    result.add termClear

proc formattedValue(value: float64; unit: string): string =
  result = &"{value:.3g}"
  if unit.len > 0:
    result.add " " & unit

proc paddedLabel(label: string; width: int): string =
  label & repeat(' ', max(width - label.runeLen, 0))

proc legendName(options: BarGraphOptions; seriesIndex: int): string =
  if options.seriesLegends.len > 0:
    options.seriesLegends[seriesIndex]
  else:
    "series " & $(seriesIndex + 1)

proc addLegend(result: var string; options: BarGraphOptions;
               seriesCount: int) =
  if seriesCount <= 1 or options.seriesLegends.len == 0:
    return
  result.add options.lineEnding
  for index in 0 ..< seriesCount:
    if index > 0:
      result.add "  "
    let color = options.seriesColors[index mod options.seriesColors.len]
    if options.useColor:
      if options.glyph == "█" and color != colorDefault:
        result.add ansiCode(color)
        result.add ansiCode(color, cpBackground)
      else:
        result.add ansiCode(color)
    result.add options.glyph
    if options.useColor:
      result.add termClear
    result.add " " & options.seriesLegends[index]

proc plotBarsFloat(labels: openArray[string];
                   series: openArray[seq[float64]];
                   rawOptions: BarGraphOptions): string =
  labels.validateData(series)
  let options = normalizedOptions(rawOptions, series.len)
  let automatic = automaticRange(series, options.mode, labels.len)
  let
    minimum = if options.minimum.isSome: options.minimum.get()
      else: automatic.minimum
    maximum = if options.maximum.isSome: options.maximum.get()
      else: automatic.maximum
    zeroColumn = coordinate(0.0, minimum, maximum, options.width)

  var rowLabels: seq[string]
  case options.mode
  of bmGrouped:
    for category, label in labels:
      for seriesIndex in 0 ..< series.len:
        if series.len == 1:
          rowLabels.add label
        else:
          rowLabels.add label & " / " & options.legendName(seriesIndex)
  of bmStacked:
    rowLabels = @labels

  var labelWidth = 0
  for label in rowLabels:
    labelWidth = max(labelWidth, label.runeLen)

  if options.caption.len > 0:
    result.add options.caption & options.lineEnding

  var rowIndex = 0
  case options.mode
  of bmGrouped:
    for category in 0 ..< labels.len:
      for seriesIndex, values in series:
        if rowIndex > 0:
          result.add options.lineEnding
        var cells = blankBar(options, zeroColumn)
        cells.fillSegment(0.0, values[category], minimum, maximum,
          options.glyph,
          options.seriesColors[seriesIndex mod options.seriesColors.len])
        result.add paddedLabel(rowLabels[rowIndex], labelWidth) & " "
        result.add renderCells(cells, options.useColor)
        if options.showValues:
          result.add "  " & formattedValue(values[category], options.unit)
        inc rowIndex
  of bmStacked:
    for category, label in labels:
      if category > 0:
        result.add options.lineEnding
      var
        cells = blankBar(options, zeroColumn)
        positive = 0.0
        negative = 0.0
      for seriesIndex, values in series:
        let value = values[category]
        let startValue = if value >= 0.0: positive else: negative
        let endValue = startValue + value
        cells.fillSegment(startValue, endValue, minimum, maximum,
          options.glyph,
          options.seriesColors[seriesIndex mod options.seriesColors.len])
        if value >= 0.0:
          positive = endValue
        else:
          negative = endValue
      result.add paddedLabel(label, labelWidth) & " "
      result.add renderCells(cells, options.useColor)
      if options.showValues:
        result.add "  "
        for seriesIndex, values in series:
          if seriesIndex > 0:
            result.add ", "
          if options.seriesLegends.len > 0:
            result.add options.seriesLegends[seriesIndex] & "="
          result.add formattedValue(values[category], options.unit)

  result.addLegend(options, series.len)

proc convertedSeries[T: SomeNumber](
    series: openArray[seq[T]]): seq[seq[float64]] =
  result = newSeq[seq[float64]](series.len)
  for seriesIndex, values in series:
    result[seriesIndex] = newSeqOfCap[float64](values.len)
    for value in values:
      result[seriesIndex].add float64(value)

proc plotBars*[T: SomeNumber](labels: openArray[string];
                              values: openArray[T];
                              options: BarGraphOptions): string =
  ## Renders one horizontal bar series.
  var converted = newSeqOfCap[float64](values.len)
  for value in values:
    converted.add float64(value)
  plotBarsFloat(labels, @[converted], options)

proc plotBars*[T: SomeNumber](labels: openArray[string];
                              values: openArray[T]): string =
  ## Renders one horizontal bar series using default options.
  plotBars(labels, values, initBarGraphOptions())

proc plotBars*[T: SomeNumber](labels: openArray[string];
                              series: openArray[seq[T]];
                              options: BarGraphOptions): string =
  ## Renders multiple grouped or stacked horizontal bar series.
  plotBarsFloat(labels, convertedSeries(series), options)

proc plotBars*[T: SomeNumber](labels: openArray[string];
                              series: openArray[seq[T]]): string =
  ## Renders multiple horizontal bar series using default options.
  plotBars(labels, series, initBarGraphOptions())
