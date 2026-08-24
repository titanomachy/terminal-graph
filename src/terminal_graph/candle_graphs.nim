## Pure-Nim OHLC candlestick charts for terminal applications.
##
## Candles are placed at equally spaced columns in their supplied order. The
## renderer returns a string and never writes to or changes terminal state.
## Optional labels identify ordered periods; they do not affect spacing.

import std/[algorithm, math, options, sequtils, strformat, strutils, unicode]

import ./line_graphs

export line_graphs

type
  Candle* = object
    ## One open-high-low-close price interval.
    open*: float64
    high*: float64
    low*: float64
    close*: float64

  CandlePlotOptions* = object
    ## Complete candlestick-chart configuration.
    ##
    ## ``width`` and ``height`` describe the price canvas. Axis labels,
    ## caption, baseline, and period-label rows are outside that canvas.
    width*: int
    height*: int
    useColor*: bool
    showAxis*: bool
    showLabels*: bool
    caption*: string
    unit*: string
    risingColor*: TerminalColor
    fallingColor*: TerminalColor
    unchangedColor*: TerminalColor
    axisColor*: TerminalColor
    labelColor*: TerminalColor
    wickGlyph*: string
    risingGlyph*: string
    fallingGlyph*: string
    unchangedGlyph*: string
    minimum*: Option[float64]
    maximum*: Option[float64]
    yAxisValueFormatter*: AxisValueFormatter
    lineEnding*: string

  CandleCell = object
    glyph: string
    color: TerminalColor
    priority: int

  PlacedLabel = object
    start: int
    width: int
    text: string

proc candle*[O, H, L, C: SomeNumber](open: O; high: H; low: L;
                                     close: C): Candle =
  ## Constructs a candle from integer or floating-point prices.
  Candle(
    open: float64(open),
    high: float64(high),
    low: float64(low),
    close: float64(close)
  )

proc initCandlePlotOptions*(): CandlePlotOptions =
  ## Returns defaults for a colored 60 by 16 candlestick canvas.
  CandlePlotOptions(
    width: 60,
    height: 16,
    useColor: true,
    showAxis: true,
    showLabels: true,
    risingColor: colorBrightGreen,
    fallingColor: colorBrightRed,
    unchangedColor: colorBrightYellow,
    axisColor: colorWhite,
    labelColor: colorDefault,
    wickGlyph: "│",
    risingGlyph: "█",
    fallingGlyph: "█",
    unchangedGlyph: "█",
    minimum: none(float64),
    maximum: none(float64),
    lineEnding: "\n"
  )

proc validateRange(minimum, maximum: float64) =
  if minimum.classify in {fcNan, fcInf, fcNegInf} or
      maximum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "candle range must be finite")
  if minimum >= maximum:
    raise newException(ValueError,
      "candle minimum must be below maximum")

proc setCandleRange*(options: var CandlePlotOptions;
                     minimum, maximum: float64) =
  ## Sets a fixed price viewport.
  validateRange(minimum, maximum)
  options.minimum = some(minimum)
  options.maximum = some(maximum)

proc clearCandleRange*(options: var CandlePlotOptions) =
  ## Restores automatic price bounds.
  options.minimum = none(float64)
  options.maximum = none(float64)

proc validateCandle(value: Candle) =
  for price in [value.open, value.high, value.low, value.close]:
    if price.classify in {fcNan, fcInf, fcNegInf}:
      raise newException(ValueError, "candle prices must be finite")
  if value.low > value.high or value.open < value.low or
      value.open > value.high or value.close < value.low or
      value.close > value.high:
    raise newException(ValueError,
      "candle prices must satisfy low <= open/close <= high")

proc validateGlyph(value, name: string) =
  if value.runeLen != 1:
    raise newException(ValueError,
      name & " must contain one Unicode code point")
  if value.displayWidth != 1:
    raise newException(ValueError,
      name & " must occupy one terminal cell")

proc normalizedOptions(options: CandlePlotOptions): CandlePlotOptions =
  result = options
  if result.width < 3 or result.height < 3:
    raise newException(ValueError,
      "candle width and height must both be at least three")
  result.wickGlyph.validateGlyph("candle wick glyph")
  result.risingGlyph.validateGlyph("candle rising glyph")
  result.fallingGlyph.validateGlyph("candle falling glyph")
  result.unchangedGlyph.validateGlyph("candle unchanged glyph")
  if result.minimum.isSome != result.maximum.isSome:
    raise newException(ValueError,
      "candle minimum and maximum must both be set or both be automatic")
  if result.minimum.isSome:
    validateRange(result.minimum.get(), result.maximum.get())
  if result.lineEnding.len == 0:
    result.lineEnding = "\n"

proc validateData(candles: openArray[Candle]; labels: openArray[string];
                  width: int) =
  if candles.len == 0:
    raise newException(ValueError,
      "candle chart requires at least one candle")
  if candles.len > width:
    raise newException(ValueError,
      "candle count cannot exceed the chart width")
  if labels.len > 0 and labels.len != candles.len:
    raise newException(ValueError,
      "candle label count must match the candle count")
  for value in candles:
    value.validateCandle()
  for label in labels:
    if '\n' in label or '\r' in label:
      raise newException(ValueError,
        "candle labels cannot contain line breaks")

proc automaticRange(candles: openArray[Candle]): tuple[
    minimum, maximum: float64] =
  result = (Inf, -Inf)
  for value in candles:
    result.minimum = min(result.minimum, value.low)
    result.maximum = max(result.maximum, value.high)
  if result.minimum == result.maximum:
    let padding = max(abs(result.minimum) * 0.05, 1.0)
    result.minimum -= padding
    result.maximum += padding

proc yCoordinate(value, minimum, maximum: float64; height: int): int =
  height - 1 - clamp(int(round((value - minimum) /
    (maximum - minimum) * float64(height - 1))), 0, height - 1)

proc xCoordinate(index, count, width: int): int =
  if count == 1:
    width div 2
  else:
    int(round(float64(index) * float64(width - 1) /
      float64(count - 1)))

proc put(canvas: var seq[seq[CandleCell]]; x, y: int; glyph: string;
         color: TerminalColor; priority: int) =
  if x < 0 or x >= canvas[0].len or y < 0 or y >= canvas.len:
    return
  if priority >= canvas[y][x].priority:
    canvas[y][x] = CandleCell(
      glyph: glyph, color: color, priority: priority)

proc drawSegment(canvas: var seq[seq[CandleCell]]; column: int;
                 first, second, minimum, maximum: float64; glyph: string;
                 color: TerminalColor; priority: int) =
  let
    visibleLow = max(min(first, second), minimum)
    visibleHigh = min(max(first, second), maximum)
  if visibleLow > visibleHigh:
    return
  let
    top = yCoordinate(visibleHigh, minimum, maximum, canvas.len)
    bottom = yCoordinate(visibleLow, minimum, maximum, canvas.len)
  for row in top .. bottom:
    canvas.put(column, row, glyph, color, priority)

proc formatPrice(value: float64; options: CandlePlotOptions): string =
  if options.yAxisValueFormatter.isNil:
    result = &"{value:.3g}"
  else:
    result = options.yAxisValueFormatter(value)
  if '\n' in result or '\r' in result:
    raise newException(ValueError,
      "candle axis formatter cannot return line breaks")
  if options.unit.len > 0:
    result.add " " & options.unit

proc renderCells(row: openArray[CandleCell]; useColor: bool): string =
  var
    activeColor = colorDefault
    activeSolidBlock = false
  for cell in row:
    let solidBlock = useColor and cell.color != colorDefault and
      cell.glyph == "█"
    if useColor and (cell.color != activeColor or
        solidBlock != activeSolidBlock):
      if activeColor != colorDefault:
        result.add termClear
      if cell.color != colorDefault:
        result.add ansiCode(cell.color)
        if solidBlock:
          result.add ansiCode(cell.color, cpBackground)
      activeColor = cell.color
      activeSolidBlock = solidBlock
    result.add cell.glyph
  if useColor and activeColor != colorDefault:
    result.add termClear

proc colored(value: string; color: TerminalColor; useColor: bool): string =
  if useColor and color != colorDefault:
    ansiCode(color) & value & termClear
  else:
    value

proc labelLine(labels: openArray[string]; candleCount, width: int): string =
  var
    occupied = newSeq[bool](width)
    placed: seq[PlacedLabel]
    order: seq[int]
  if labels.len == 0:
    return ""
  order.add 0
  if labels.high > 0:
    order.add labels.high
  for index in 1 ..< labels.high:
    order.add index

  for index in order:
    if labels[index].len == 0:
      continue
    let clipped = sliceAnsi(labels[index], 0, width)
    let labelWidth = clipped.displayWidth
    if labelWidth == 0:
      continue
    let center = xCoordinate(index, candleCount, width)
    let start = clamp(center - labelWidth div 2, 0, width - labelWidth)
    let
      reservedStart = max(start - 1, 0)
      reservedEnd = min(start + labelWidth + 1, width)
    var available = true
    for column in reservedStart ..< reservedEnd:
      if occupied[column]:
        available = false
        break
    if not available:
      continue
    for column in reservedStart ..< reservedEnd:
      occupied[column] = true
    placed.add PlacedLabel(start: start, width: labelWidth, text: clipped)

  placed.sort(proc(first, second: PlacedLabel): int =
    cmp(first.start, second.start))
  var column = 0
  for item in placed:
    result.add repeat(' ', item.start - column)
    result.add item.text
    column = item.start + item.width
  result.add repeat(' ', width - column)

proc plotCandlesFloat(candles: openArray[Candle]; labels: openArray[string];
                      rawOptions: CandlePlotOptions): string =
  let options = normalizedOptions(rawOptions)
  candles.validateData(labels, options.width)
  let automatic = automaticRange(candles)
  let
    minimum = if options.minimum.isSome: options.minimum.get()
      else: automatic.minimum
    maximum = if options.maximum.isSome: options.maximum.get()
      else: automatic.maximum
  var canvas = newSeqWith(options.height,
    newSeqWith(options.width,
      CandleCell(glyph: " ", color: colorDefault, priority: 0)))

  for index, value in candles:
    let column = xCoordinate(index, candles.len, options.width)
    let color = if value.close > value.open:
      options.risingColor
    elif value.close < value.open:
      options.fallingColor
    else:
      options.unchangedColor
    let bodyGlyph = if value.close > value.open:
      options.risingGlyph
    elif value.close < value.open:
      options.fallingGlyph
    else:
      options.unchangedGlyph
    canvas.drawSegment(column, value.low, value.high,
      minimum, maximum, options.wickGlyph, color, 1)
    canvas.drawSegment(column, value.open, value.close,
      minimum, maximum, bodyGlyph, color, 2)

  let middleRow = options.height div 2
  var
    tickLabels: array[3, string]
    labelWidth = 0
  if options.showAxis:
    let middlePrice = maximum - float64(middleRow) /
      float64(options.height - 1) * (maximum - minimum)
    tickLabels = [
      formatPrice(maximum, options),
      formatPrice(middlePrice, options),
      formatPrice(minimum, options)
    ]
    for label in tickLabels:
      labelWidth = max(labelWidth, label.displayWidth)

  if options.caption.len > 0:
    result.add colored(options.caption, options.labelColor, options.useColor)
    result.add options.lineEnding

  for row in 0 ..< options.height:
    if row > 0:
      result.add options.lineEnding
    if options.showAxis:
      let tickIndex = if row == 0: 0
        elif row == middleRow: 1
        elif row == options.height - 1: 2
        else: -1
      if tickIndex >= 0:
        let label = tickLabels[tickIndex]
        result.add repeat(' ', labelWidth - label.displayWidth)
        result.add colored(label, options.labelColor, options.useColor)
      else:
        result.add repeat(' ', labelWidth)
      result.add " "
      result.add colored("┤", options.axisColor, options.useColor)
    result.add renderCells(canvas[row], options.useColor)

  if options.showAxis:
    result.add options.lineEnding
    result.add repeat(' ', labelWidth + 1)
    result.add colored("└" & repeat("─", options.width),
      options.axisColor, options.useColor)

  if options.showLabels and labels.len > 0:
    let labelsRendered = labelLine(labels, candles.len, options.width)
    if strutils.strip(labelsRendered).len > 0:
      result.add options.lineEnding
      if options.showAxis:
        result.add repeat(' ', labelWidth + 2)
      result.add colored(labelsRendered, options.labelColor, options.useColor)

proc plotCandles*(candles: openArray[Candle];
                  options: CandlePlotOptions): string =
  ## Renders an ordered OHLC sequence without period labels.
  plotCandlesFloat(candles, newSeq[string](), options)

proc plotCandles*(candles: openArray[Candle]): string =
  ## Renders an ordered OHLC sequence using default options.
  plotCandles(candles, initCandlePlotOptions())

proc plotCandles*(labels: openArray[string]; candles: openArray[Candle];
                  options: CandlePlotOptions): string =
  ## Renders an ordered OHLC sequence with optional period labels.
  plotCandlesFloat(candles, labels, options)

proc plotCandles*(labels: openArray[string];
                  candles: openArray[Candle]): string =
  ## Renders a labelled OHLC sequence using default options.
  plotCandles(labels, candles, initCandlePlotOptions())
