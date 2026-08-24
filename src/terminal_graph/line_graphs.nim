## High-fidelity ASCII line graphs inspired by guptarohit/asciigraph.
##
## The upstream implementation is Copyright (c) 2018 Rohit Gupta and licensed
## under BSD-3-Clause; see ``THIRD_PARTY_NOTICES.md`` in the package root.
##
## The renderer supports one or many series, interpolation, soft bounds,
## captions, legends, custom characters and axis formatters, X-axis labels,
## standard, indexed, and RGB colors, value gradients, threshold colors, NaN
## gaps, and custom
## line endings. Most applications should import the ``terminal_graph``
## façade rather than this submodule directly.

import std/[math, options, sequtils, strformat, strutils, unicode]

import terminal_style

export terminal_style

type
  LineCharSet* = object
    ## Characters used to connect adjacent samples in one series.
    horizontal*: string
    verticalLine*: string
    arcDownRight*: string
    arcDownLeft*: string
    arcUpRight*: string
    arcUpLeft*: string
    endCap*: string
    startCap*: string
    upRight*: string
    downHorizontal*: string

  AxisValueFormatter* = proc(value: float64): string {.closure.}
    ## Callback used to format an X- or Y-axis value.

  AsciiGraphConfig* = object
    ## Complete line-graph configuration. ``initAsciiGraphConfig`` supplies
    ## defaults; option builders are the more concise public interface.
    width*: int
    height*: int
    lowerBound*: Option[float64]
    upperBound*: Option[float64]
    offset*: int
    caption*: string
    precision*: Option[int]
    captionColor*: TerminalColor
    axisColor*: TerminalColor
    labelColor*: TerminalColor
    seriesColors*: seq[TerminalColor]
    gradient*: seq[TerminalColor]
    aboveThreshold*: Option[float64]
    aboveColor*: TerminalColor
    belowThreshold*: Option[float64]
    belowColor*: TerminalColor
    seriesLegends*: seq[string]
    lineEnding*: string
    seriesChars*: seq[LineCharSet]
    yAxisValueFormatter*: AxisValueFormatter
    xAxisRange*: Option[tuple[minimum, maximum: float64]]
    xAxisTickCount*: int
    xAxisValueFormatter*: AxisValueFormatter

  LineGraphOption* = proc(config: var AsciiGraphConfig) {.closure.}
    ## A composable option accepted by ``plot`` and ``plotMany``.

  Cell = object
    text: string
    color: TerminalColor

const
  DefaultLineCharSet* = LineCharSet(
    horizontal: "─",
    verticalLine: "│",
    arcDownRight: "╭",
    arcDownLeft: "╮",
    arcUpRight: "╰",
    arcUpLeft: "╯",
    endCap: "╴",
    startCap: "╶",
    upRight: "└",
    downHorizontal: "┬"
  )

  HeatmapSpectrum*: array[21, TerminalColor] = [
    indexedColor(21), indexedColor(27), indexedColor(33), indexedColor(39),
    indexedColor(45), indexedColor(51), indexedColor(50), indexedColor(49),
    indexedColor(48), indexedColor(47), indexedColor(46), indexedColor(82),
    indexedColor(118), indexedColor(154), indexedColor(190), indexedColor(226),
    indexedColor(220), indexedColor(214), indexedColor(208), indexedColor(202),
    indexedColor(196)
  ]
    ## Built-in cool-to-warm ANSI-256 palette.

proc createLineCharSet*(character: string): LineCharSet =
  ## Creates a character set with every field set to ``character``.
  LineCharSet(
    horizontal: character,
    verticalLine: character,
    arcDownRight: character,
    arcDownLeft: character,
    arcUpRight: character,
    arcUpLeft: character,
    endCap: character,
    startCap: character,
    upRight: character,
    downHorizontal: character
  )

proc initAsciiGraphConfig*(): AsciiGraphConfig =
  ## Returns the default line-graph configuration.
  AsciiGraphConfig(
    offset: 3,
    lineEnding: "\n",
    lowerBound: none(float64),
    upperBound: none(float64),
    precision: none(int),
    aboveThreshold: none(float64),
    belowThreshold: none(float64),
    xAxisRange: none(tuple[minimum, maximum: float64]),
    xAxisTickCount: 5
  )

proc graphWidth*(value: int): LineGraphOption =
  ## Sets the interpolated plot width. Non-positive values restore auto width.
  result = proc(config: var AsciiGraphConfig) =
    config.width = max(value, 0)

proc graphHeight*(value: int): LineGraphOption =
  ## Sets the plot height. Non-positive values restore automatic height.
  result = proc(config: var AsciiGraphConfig) =
    config.height = max(value, 0)

proc lowerBound*(value: float64): LineGraphOption =
  ## Extends the y-axis down to ``value`` unless the data is lower.
  result = proc(config: var AsciiGraphConfig) =
    config.lowerBound = some(value)

proc upperBound*(value: float64): LineGraphOption =
  ## Extends the y-axis up to ``value`` unless the data is higher.
  result = proc(config: var AsciiGraphConfig) =
    config.upperBound = some(value)

proc axisOffset*(value: int): LineGraphOption =
  ## Sets the horizontal axis offset. Non-positive values use the default 3.
  result = proc(config: var AsciiGraphConfig) =
    config.offset = value

proc labelPrecision*(value: Natural): LineGraphOption =
  ## Sets the number of decimal places on default Y-axis labels.
  result = proc(config: var AsciiGraphConfig) =
    config.precision = some(int(value))

proc graphCaption*(value: string): LineGraphOption =
  ## Sets a centered caption; surrounding whitespace is removed.
  let captured = strutils.strip(value)
  result = proc(config: var AsciiGraphConfig) =
    config.caption = captured

proc graphCaptionColor*(value: TerminalColor): LineGraphOption =
  ## Sets the caption color.
  result = proc(config: var AsciiGraphConfig) =
    config.captionColor = value

proc graphAxisColor*(value: TerminalColor): LineGraphOption =
  ## Sets both axis lines' color.
  result = proc(config: var AsciiGraphConfig) =
    config.axisColor = value

proc graphLabelColor*(value: TerminalColor): LineGraphOption =
  ## Sets X- and Y-axis label color.
  result = proc(config: var AsciiGraphConfig) =
    config.labelColor = value

proc graphSeriesColors*(values: openArray[TerminalColor]): LineGraphOption =
  ## Sets colors corresponding to each series.
  let captured = @values
  result = proc(config: var AsciiGraphConfig) =
    config.seriesColors = captured

proc graphColorGradient*(stops: openArray[TerminalColor]): LineGraphOption =
  ## Colors plotted points by value along the supplied low-to-high palette.
  let captured = @stops
  result = proc(config: var AsciiGraphConfig) =
    config.gradient = captured

proc graphColorAbove*(color: TerminalColor; threshold: float64): LineGraphOption =
  ## Colors graph points strictly above ``threshold``.
  result = proc(config: var AsciiGraphConfig) =
    config.aboveThreshold = some(threshold)
    config.aboveColor = color

proc graphColorBelow*(color: TerminalColor; threshold: float64): LineGraphOption =
  ## Colors graph points strictly below ``threshold``.
  result = proc(config: var AsciiGraphConfig) =
    config.belowThreshold = some(threshold)
    config.belowColor = color

proc graphSeriesLegends*(values: openArray[string]): LineGraphOption =
  ## Sets legend text corresponding to each series.
  let captured = @values
  result = proc(config: var AsciiGraphConfig) =
    config.seriesLegends = captured

proc graphLineEnding*(value: string): LineGraphOption =
  ## Sets the line ending, such as ``"\r\n"`` for raw Windows terminals.
  result = proc(config: var AsciiGraphConfig) =
    config.lineEnding = value

proc graphSeriesChars*(values: openArray[LineCharSet]): LineGraphOption =
  ## Sets drawing characters corresponding to each series.
  let captured = @values
  result = proc(config: var AsciiGraphConfig) =
    config.seriesChars = captured

proc graphYAxisFormatter*(formatter: AxisValueFormatter): LineGraphOption =
  ## Sets a custom Y-axis value formatter.
  result = proc(config: var AsciiGraphConfig) =
    config.yAxisValueFormatter = formatter

proc graphXAxisRange*(minimum, maximum: float64): LineGraphOption =
  ## Enables an X-axis and maps this domain across the plot width.
  result = proc(config: var AsciiGraphConfig) =
    config.xAxisRange = some((minimum: minimum, maximum: maximum))

proc graphXAxisTickCount*(value: int): LineGraphOption =
  ## Sets X-axis tick count. Values below two leave the default unchanged.
  result = proc(config: var AsciiGraphConfig) =
    if value >= 2:
      config.xAxisTickCount = value

proc graphXAxisFormatter*(formatter: AxisValueFormatter): LineGraphOption =
  ## Sets a custom X-axis value formatter.
  result = proc(config: var AsciiGraphConfig) =
    config.xAxisValueFormatter = formatter

proc portRound(value: float64): float64 =
  if value.isNaN:
    return NaN
  let sign = if value < 0.0: -1.0 else: 1.0
  let absolute = abs(value)
  let fraction = absolute - floor(absolute)
  sign * (if fraction >= 0.5: ceil(absolute) else: floor(absolute))

proc calculateHeight(interval: float64): int =
  if interval <= 0.0:
    return 1
  if interval >= 1.0:
    return int(interval)
  let
    scaleFactor = pow(10.0, floor(log10(interval)))
    scaledDelta = interval / scaleFactor
  if scaledDelta < 2.0:
    int(ceil(scaledDelta))
  else:
    int(floor(scaledDelta))

proc interpolate(data: seq[float64]; fitCount: int): seq[float64] =
  if fitCount <= 0:
    return data
  if fitCount == 1:
    return @[data[0]]
  if data.len == 1:
    return newSeqWith(fitCount, data[0])

  result = newSeqOfCap[float64](fitCount)
  let springFactor = float64(data.high) / float64(fitCount - 1)
  result.add data[0]
  for index in 1 ..< fitCount - 1:
    let
      spring = float64(index) * springFactor
      before = int(floor(spring))
      after = int(ceil(spring))
      fraction = spring - float64(before)
    result.add data[before] + (data[after] - data[before]) * fraction
  result.add data[^1]

proc effectiveCharSet(config: AsciiGraphConfig; index: int): LineCharSet =
  if index >= config.seriesChars.len:
    return DefaultLineCharSet
  result = config.seriesChars[index]
  template fill(field: untyped) =
    if result.field.len == 0:
      result.field = DefaultLineCharSet.field
  fill(horizontal)
  fill(verticalLine)
  fill(arcDownRight)
  fill(arcDownLeft)
  fill(arcUpRight)
  fill(arcUpLeft)
  fill(endCap)
  fill(startCap)
  fill(upRight)
  fill(downHorizontal)

proc colorToRgb(color: TerminalColor): tuple[red, green, blue: int] =
  const ansi16 = [
    (0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0),
    (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
    (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0),
    (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)
  ]
  case color.kind
  of tckDefault:
    return ansi16[0]
  of tckRgb:
    return (int(color.red), int(color.green), int(color.blue))
  of tckAnsi16:
    return ansi16[int(color.index)]
  of tckAnsi256:
    discard
  let index = int(color.index)
  if index < 232:
    let cubeIndex = index - 16
    proc level(value: int): int =
      if value == 0: 0 else: 55 + 40 * value
    return (
      level(cubeIndex div 36),
      level((cubeIndex div 6) mod 6),
      level(cubeIndex mod 6)
    )
  let gray = 8 + 10 * (index - 232)
  (gray, gray, gray)

proc gradientColor(stops: openArray[TerminalColor]; value, minimum,
                   maximum: float64): TerminalColor =
  if stops.len == 0:
    return colorDefault
  if stops.len == 1 or maximum <= minimum:
    return stops[0]
  var position = (value - minimum) / (maximum - minimum)
  if position.isNaN:
    return stops[0]
  position = clamp(position, 0.0, 1.0) * float64(stops.high)
  let lower = int(position)
  if lower >= stops.high:
    return stops[^1]
  let fraction = position - float64(lower)
  if fraction == 0.0:
    return stops[lower]
  let
    startColor = colorToRgb(stops[lower])
    endColor = colorToRgb(stops[lower + 1])
    red = int(float64(startColor.red) +
      fraction * float64(endColor.red - startColor.red) + 0.5)
    green = int(float64(startColor.green) +
      fraction * float64(endColor.green - startColor.green) + 0.5)
    blue = int(float64(startColor.blue) +
      fraction * float64(endColor.blue - startColor.blue) + 0.5)
  rgbColor(red, green, blue)

proc formattedDecimal(value: float64; precision: int): string =
  formatFloat(value, ffDecimal, precision)

proc compactNumber(value: float64): string =
  if value == floor(value) and value >= float64(low(int64)) and
      value <= float64(high(int64)):
    return $int64(value)
  result = formatFloat(value, ffDecimal, 12)
  while result.len > 0 and result[^1] == '0':
    result.setLen(result.len - 1)
  if result.len > 0 and result[^1] == '.':
    result.setLen(result.len - 1)

proc trimCells(cells: openArray[string]): string =
  var last = cells.high
  while last >= 0 and cells[last] == " ":
    dec last
  if last < 0:
    return ""
  for index in 0 .. last:
    result.add cells[index]

proc addXAxis(buffer: var string; config: AsciiGraphConfig; dataWidth,
              leftPad: int; charSet: LineCharSet) =
  if dataWidth <= 0 or config.xAxisRange.isNone:
    return
  let domain = config.xAxisRange.get()
  var tickCount = config.xAxisTickCount
  if dataWidth == 1:
    tickCount = 1
  else:
    tickCount = clamp(if tickCount < 2: 5 else: tickCount, 2, dataWidth)

  type Tick = object
    column: int
    value: float64
    label: string

  var ticks = newSeq[Tick](tickCount)
  for index in 0 ..< tickCount:
    if tickCount == 1:
      ticks[index].value = domain.minimum
    else:
      let fraction = float64(index) / float64(tickCount - 1)
      ticks[index].value = domain.minimum +
        fraction * (domain.maximum - domain.minimum)
      ticks[index].column = int(round(
        float64(dataWidth - 1) * fraction))

  var useDecimals = false
  if config.xAxisValueFormatter.isNil:
    var lastEnd = -1
    for tick in ticks:
      let
        label = compactNumber(tick.value)
        startColumn = max(leftPad + tick.column - label.runeLen div 2, 0)
      if startColumn > lastEnd:
        if tick.value != floor(tick.value):
          useDecimals = true
          break
        lastEnd = startColumn + label.runeLen

  for tick in ticks.mitems:
    if not config.xAxisValueFormatter.isNil:
      tick.label = config.xAxisValueFormatter(tick.value)
    elif useDecimals:
      tick.label = formattedDecimal(tick.value, 2)
    else:
      tick.label = compactNumber(tick.value)

  let totalWidth = leftPad + dataWidth
  var axisCells = newSeqWith(totalWidth, " ")
  axisCells[leftPad - 1] = charSet.upRight
  for index in 0 ..< dataWidth:
    axisCells[leftPad + index] = charSet.horizontal
  for tick in ticks:
    axisCells[leftPad + tick.column] = charSet.downHorizontal

  buffer.add config.lineEnding
  if config.axisColor != colorDefault:
    buffer.add ansiCode(config.axisColor)
  buffer.add trimCells(axisCells)
  if config.axisColor != colorDefault:
    buffer.add termClear

  var maxExtent = totalWidth
  for tick in ticks:
    maxExtent = max(maxExtent,
      leftPad + tick.column + tick.label.runeLen - tick.label.runeLen div 2)
  var labelCells = newSeqWith(maxExtent, " ")
  var lastEnd = -1
  for tick in ticks:
    let startColumn = max(
      leftPad + tick.column - tick.label.runeLen div 2, 0)
    if startColumn <= lastEnd:
      continue
    var position = startColumn
    for rune in tick.label.runes:
      if position < labelCells.len:
        labelCells[position] = $rune
      inc position
    lastEnd = startColumn + tick.label.runeLen

  let labels = trimCells(labelCells)
  if labels.len > 0:
    buffer.add config.lineEnding
    if config.labelColor != colorDefault:
      buffer.add ansiCode(config.labelColor)
    buffer.add labels
    if config.labelColor != colorDefault:
      buffer.add termClear

proc addLegends(buffer: var string; config: AsciiGraphConfig; dataWidth,
                leftPad: int) =
  if config.seriesLegends.len == 0:
    return
  var
    content = ""
    displayLength = 0
  for index, legend in config.seriesLegends:
    let color = if config.gradient.len == 0 and
        index < config.seriesColors.len:
      config.seriesColors[index]
    else:
      colorDefault
    content.add ansiCode(color) & "■" & termClear & " " & legend
    displayLength += legend.runeLen + 2
    if index < config.seriesLegends.high:
      content.add "   "
      displayLength += 3
  buffer.add config.lineEnding & config.lineEnding
  buffer.add repeat(' ', leftPad)
  if displayLength < dataWidth:
    buffer.add repeat(' ', (dataWidth - displayLength) div 2)
  buffer.add content

proc prepareConfig(options: openArray[LineGraphOption]): AsciiGraphConfig =
  result = initAsciiGraphConfig()
  for option in options:
    if not option.isNil:
      option(result)
  if result.lineEnding.len == 0:
    result.lineEnding = "\n"
  if result.offset <= 0:
    result.offset = 3

proc plotManyImpl(input: openArray[seq[float64]];
                  initialConfig: AsciiGraphConfig): string =
  if input.len == 0:
    raise newException(ValueError, "plotMany requires at least one series")

  var
    config = initialConfig
    data = newSeq[seq[float64]](input.len)
    dataWidth = 0
  if config.lineEnding.len == 0:
    config.lineEnding = "\n"
  if config.offset <= 0:
    config.offset = 3

  for index, series in input:
    if series.len == 0:
      raise newException(ValueError, "line graph series cannot be empty")
    data[index] = series
    dataWidth = max(dataWidth, series.len)
    for value in series:
      if value.classify in {fcInf, fcNegInf}:
        raise newException(ValueError,
          "line graph values must be finite numbers or NaN gaps")

  if config.width > 0:
    for series in data.mitems:
      while series.len < dataWidth:
        series.add NaN
      series = interpolate(series, config.width)
    dataWidth = config.width

  var
    minimum = Inf
    maximum = -Inf
  for series in data:
    for value in series:
      if value.isNaN:
        continue
      minimum = min(minimum, value)
      maximum = max(maximum, value)
  if minimum == Inf:
    raise newException(ValueError,
      "line graph requires at least one non-NaN value")
  if config.lowerBound.isSome:
    minimum = min(minimum, config.lowerBound.get())
  if config.upperBound.isSome:
    maximum = max(maximum, config.upperBound.get())

  let interval = abs(maximum - minimum)
  if config.height <= 0:
    config.height = calculateHeight(interval)
  let ratio = if interval != 0.0:
    float64(config.height) / interval
  else:
    1.0
  let
    scaledMinimum = portRound(minimum * ratio)
    scaledMaximum = portRound(maximum * ratio)
    integerMinimum = int(scaledMinimum)
    integerMaximum = int(scaledMaximum)
    rowCount = abs(integerMaximum - integerMinimum)
    gridWidth = dataWidth + config.offset

  var grid = newSeqWith(rowCount + 1,
    newSeqWith(gridWidth, Cell(text: " ", color: colorDefault)))

  var precision = if config.precision.isSome:
    config.precision.get()
  else:
    2
  let absoluteMaximum = max(abs(maximum), abs(minimum))
  var logarithm = if absoluteMaximum == 0.0: -1.0 else: log10(absoluteMaximum)
  if logarithm < 0.0:
    let fraction = logarithm - floor(logarithm)
    if fraction != 0.0:
      precision += int(abs(logarithm))
    else:
      precision += max(int(abs(logarithm) - 1.0), 0)
  elif logarithm > 2.0 and config.precision.isNone:
    precision = 0

  var magnitudes = newSeq[float64](rowCount + 1)
  var maximumLabelWidth = 0
  if config.yAxisValueFormatter.isNil:
    maximumLabelWidth = max(
      formattedDecimal(maximum, precision).runeLen,
      formattedDecimal(minimum, precision).runeLen
    )
  for row in 0 .. rowCount:
    let magnitude = if rowCount > 0 and interval > 0.0:
      maximum - float64(row) * interval / float64(rowCount)
    elif interval == 0.0:
      minimum
    else:
      float64(integerMinimum + row)
    magnitudes[row] = magnitude
    if not config.yAxisValueFormatter.isNil:
      maximumLabelWidth = max(maximumLabelWidth,
        config.yAxisValueFormatter(magnitude).runeLen)

  let leftPad = config.offset + maximumLabelWidth
  for row, magnitude in magnitudes:
    let value = if config.yAxisValueFormatter.isNil:
      formattedDecimal(magnitude, precision)
    else:
      config.yAxisValueFormatter(magnitude)
    let label = repeat(' ', maximumLabelWidth + 1 - value.runeLen) & value
    let labelColumn = max(config.offset - label.runeLen, 0)
    grid[row][labelColumn] = Cell(text: label, color: config.labelColor)
    grid[row][config.offset - 1] = Cell(text: "┤", color: config.axisColor)

  var rowColors: seq[TerminalColor]
  if config.gradient.len > 0:
    rowColors = newSeq[TerminalColor](magnitudes.len)
    for row, magnitude in magnitudes:
      rowColors[row] = gradientColor(
        config.gradient, magnitude, minimum, maximum)

  proc pickColor(row: int; seriesColor: TerminalColor): TerminalColor =
    let magnitude = magnitudes[row]
    if config.aboveThreshold.isSome and
        magnitude > config.aboveThreshold.get():
      return config.aboveColor
    if config.belowThreshold.isSome and
        magnitude < config.belowThreshold.get():
      return config.belowColor
    if rowColors.len > 0:
      return rowColors[row]
    seriesColor

  for seriesIndex, series in data:
    let
      seriesColor = if seriesIndex < config.seriesColors.len:
        config.seriesColors[seriesIndex]
      else:
        colorDefault
      chars = config.effectiveCharSet(seriesIndex)
    if not series[0].isNaN:
      let firstY = int(portRound(series[0] * ratio) - scaledMinimum)
      grid[rowCount - firstY][config.offset - 1] =
        Cell(text: "┼", color: config.axisColor)

    for x in 0 ..< series.high:
      let
        first = series[x]
        second = series[x + 1]
      if first.isNaN and second.isNaN:
        continue
      if second.isNaN:
        let y = int(portRound(first * ratio) - float64(integerMinimum))
        grid[rowCount - y][x + config.offset] =
          Cell(text: chars.endCap,
            color: pickColor(rowCount - y, seriesColor))
        continue
      if first.isNaN:
        let y = int(portRound(second * ratio) - float64(integerMinimum))
        grid[rowCount - y][x + config.offset] =
          Cell(text: chars.startCap,
            color: pickColor(rowCount - y, seriesColor))
        continue

      let
        firstY = int(portRound(first * ratio) - float64(integerMinimum))
        secondY = int(portRound(second * ratio) - float64(integerMinimum))
        column = x + config.offset
      if firstY == secondY:
        grid[rowCount - firstY][column].text = chars.horizontal
      elif firstY > secondY:
        grid[rowCount - secondY][column].text = chars.arcUpRight
        grid[rowCount - firstY][column].text = chars.arcDownLeft
      else:
        grid[rowCount - secondY][column].text = chars.arcDownRight
        grid[rowCount - firstY][column].text = chars.arcUpLeft

      if firstY != secondY:
        for y in min(firstY, secondY) + 1 ..< max(firstY, secondY):
          grid[rowCount - y][column].text = chars.verticalLine
      for y in min(firstY, secondY) .. max(firstY, secondY):
        grid[rowCount - y][column].color =
          pickColor(rowCount - y, seriesColor)

  for rowIndex, row in grid:
    if rowIndex > 0:
      result.add config.lineEnding
    var last = row.high
    while last > 0 and row[last].text == " ":
      dec last
    var activeColor = colorDefault
    for column in 0 .. last:
      let cell = row[column]
      if cell.color != activeColor:
        activeColor = cell.color
        result.add ansiCode(activeColor)
      result.add cell.text
    if activeColor != colorDefault:
      result.add termClear

  result.addXAxis(config, dataWidth, leftPad, DefaultLineCharSet)
  if config.caption.len > 0:
    result.add config.lineEnding & repeat(' ', leftPad)
    if config.caption.runeLen < dataWidth:
      result.add repeat(' ', (dataWidth - config.caption.runeLen) div 2)
    if config.captionColor != colorDefault:
      result.add ansiCode(config.captionColor)
    result.add config.caption
    if config.captionColor != colorDefault:
      result.add termClear
  result.addLegends(config, dataWidth, leftPad)

proc plot*[T: SomeNumber](series: openArray[T];
                          options: varargs[LineGraphOption]): string =
  ## Plots one numeric series using composable graph options.
  var converted = newSeqOfCap[float64](series.len)
  for value in series:
    converted.add float64(value)
  plotManyImpl(@[converted], prepareConfig(options))

proc plot*[T: SomeNumber](series: openArray[T];
                          config: AsciiGraphConfig): string =
  ## Plots one numeric series using a reusable configuration object.
  var converted = newSeqOfCap[float64](series.len)
  for value in series:
    converted.add float64(value)
  plotManyImpl(@[converted], config)

proc plotMany*[T: SomeNumber](data: openArray[seq[T]];
                              options: varargs[LineGraphOption]): string =
  ## Plots multiple numeric series on the same axes.
  var converted = newSeq[seq[float64]](data.len)
  for index, series in data:
    converted[index] = newSeqOfCap[float64](series.len)
    for value in series:
      converted[index].add float64(value)
  plotManyImpl(converted, prepareConfig(options))

proc plotMany*[T: SomeNumber](data: openArray[seq[T]];
                              config: AsciiGraphConfig): string =
  ## Plots multiple numeric series using a reusable configuration object.
  var converted = newSeq[seq[float64]](data.len)
  for index, series in data:
    converted[index] = newSeqOfCap[float64](series.len)
    for value in series:
      converted[index].add float64(value)
  plotManyImpl(converted, config)

proc clearLinesSequence*(lineCount: int): string =
  ## Returns the ANSI sequence that clears the previous ``lineCount`` lines.
  if lineCount > 0:
    &"\e[{lineCount}A\e[J"
  else:
    ""

proc synchronizedOutputSequence*(update: string): string =
  ## Wraps a terminal update in DEC synchronized-output mode.
  ##
  ## Supporting terminals hold rendering until the closing sequence, so a
  ## complete frame becomes visible at once. Unsupported terminals ignore the
  ## private mode and process ``update`` normally.
  "\e[?2026h" & update & "\e[?2026l"

proc replaceLinesSequence*(frame: string; previousLineCount: int): string =
  ## Returns an ANSI update that replaces a previously rendered frame.
  ##
  ## The new lines are painted before their stale tails and any obsolete lower
  ## rows are erased. This avoids exposing a cleared intermediate frame, which
  ## can appear as flicker or black scan lines on some terminals.
  if previousLineCount < 0:
    raise newException(ValueError,
      "previousLineCount cannot be negative")
  var update: string
  if previousLineCount > 0:
    update.add &"\e[{previousLineCount}A"
  update.add '\r'
  let lines = frame.splitLines()
  if lines.len == 0:
    update.add "\e[J"
  else:
    for index, line in lines:
      update.add line
      if index == lines.high:
        update.add "\e[J"
      else:
        update.add "\e[K\r\n"
  update.add "\r\n"
  result = update.synchronizedOutputSequence()

proc clearLines*(lineCount: int) =
  ## Clears recently rendered lines while preserving terminal content above.
  stdout.write clearLinesSequence(lineCount)
  stdout.flushFile()

proc clearTerminal*() =
  ## Clears the entire terminal and moves the cursor home.
  stdout.write "\e[2J\e[H"
  stdout.flushFile()
