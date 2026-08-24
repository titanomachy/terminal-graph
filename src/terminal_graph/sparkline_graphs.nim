## Compact, single-line graphs for small numeric sequences.
##
## Sparklines support automatic or explicit ranges, NaN gaps, custom glyphs,
## standard, indexed, or RGB palettes and configurable handling for constant
## nonzero data.
## Most applications should access this API through ``import terminal_graph``.

import std/[math, options, unicode]

import ./line_graphs

export line_graphs

const
  SparklineTicks*: array[8, string] =
    ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    ## Default glyphs ordered from the lowest to the highest value.

  FireSparklinePalette*: array[8, TerminalColor] = [
    indexedColor(226), indexedColor(220), indexedColor(214), indexedColor(208),
    indexedColor(202), indexedColor(196), indexedColor(160), indexedColor(124)
  ]
    ## Built-in ANSI-256 gradient from yellow to deep red.

type
  SparklineConstantMode* = enum
    ## Selects the glyph used when every finite value is equal and nonzero.
    scmLowest,
    scmMiddle

  SparklineOptions* = object
    ## Complete sparkline rendering configuration.
    minimum*: Option[float64]
    maximum*: Option[float64]
    ticks*: seq[string]
    gapGlyph*: string
    useColor*: bool
    palette*: seq[TerminalColor]
    constantMode*: SparklineConstantMode

proc initSparklineOptions*(): SparklineOptions =
  ## Returns defaults with automatic scaling and a fire palette available.
  ##
  ## Coloring remains disabled until ``useColor`` is set. Constant nonzero
  ## data uses the middle glyph, while an all-zero series uses the lowest.
  SparklineOptions(
    minimum: none(float64),
    maximum: none(float64),
    ticks: @SparklineTicks,
    gapGlyph: " ",
    useColor: false,
    palette: @FireSparklinePalette,
    constantMode: scmMiddle
  )

proc setSparklineRange*(options: var SparklineOptions;
                        minimum, maximum: float64) =
  ## Sets an explicit scale shared by every value in the sparkline.
  if minimum.classify in {fcNan, fcInf, fcNegInf} or
      maximum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "sparkline range must be finite")
  if minimum >= maximum:
    raise newException(ValueError,
      "sparkline minimum must be below maximum")
  options.minimum = some(minimum)
  options.maximum = some(maximum)

proc setSparklineMinimum*(options: var SparklineOptions; minimum: float64) =
  ## Sets only the lower scale bound; the upper bound remains automatic.
  if minimum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "sparkline minimum must be finite")
  options.minimum = some(minimum)

proc clearSparklineMinimum*(options: var SparklineOptions) =
  ## Restores automatic lower-bound calculation.
  options.minimum = none(float64)

proc setSparklineMaximum*(options: var SparklineOptions; maximum: float64) =
  ## Sets only the upper scale bound; the lower bound remains automatic.
  if maximum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "sparkline maximum must be finite")
  options.maximum = some(maximum)

proc clearSparklineMaximum*(options: var SparklineOptions) =
  ## Restores automatic upper-bound calculation.
  options.maximum = none(float64)

proc clearSparklineRange*(options: var SparklineOptions) =
  ## Restores automatic minimum and maximum calculation.
  options.minimum = none(float64)
  options.maximum = none(float64)

proc normalizedOptions(options: SparklineOptions): SparklineOptions =
  result = options
  if result.ticks.len < 2:
    raise newException(ValueError,
      "sparkline requires at least two tick glyphs")
  for tick in result.ticks:
    if tick.runeLen != 1:
      raise newException(ValueError,
        "each sparkline tick must contain one Unicode code point")
  if result.gapGlyph.runeLen != 1:
    raise newException(ValueError,
      "sparkline gap glyph must contain one Unicode code point")
  if result.palette.len == 0:
    result.palette = @FireSparklinePalette
  if result.minimum.isSome:
    let minimum = result.minimum.get()
    if minimum.classify in {fcNan, fcInf, fcNegInf}:
      raise newException(ValueError, "sparkline minimum must be finite")
  if result.maximum.isSome:
    let maximum = result.maximum.get()
    if maximum.classify in {fcNan, fcInf, fcNegInf}:
      raise newException(ValueError, "sparkline maximum must be finite")
  if result.minimum.isSome and result.maximum.isSome and
      result.minimum.get() >= result.maximum.get():
    raise newException(ValueError,
      "sparkline minimum must be below maximum")

proc paletteColor(options: SparklineOptions; tickIndex: int): TerminalColor =
  let paletteIndex = clamp(int(round(
    float64(tickIndex) * float64(options.palette.high) /
    float64(options.ticks.high)
  )), options.palette.low, options.palette.high)
  options.palette[paletteIndex]

proc addGlyph(result: var string; glyph: string; color: TerminalColor;
              useColor: bool; activeColor: var TerminalColor) =
  if useColor and color != activeColor:
    result.add ansiCode(color)
    activeColor = color
  result.add glyph

proc sparkline*[T: SomeNumber](data: openArray[T];
                               rawOptions: SparklineOptions): string =
  ## Renders ``data`` as a compact sparkline using ``rawOptions``.
  ##
  ## NaN values produce ``gapGlyph`` without affecting automatic scaling.
  ## Infinite values raise ``ValueError``. Values outside an explicit range
  ## are clamped to the lowest or highest tick.
  let options = normalizedOptions(rawOptions)
  if data.len == 0:
    return ""

  var
    dataMinimum = Inf
    dataMaximum = -Inf
    finiteCount = 0
  for rawValue in data:
    let value = float64(rawValue)
    if value.classify in {fcInf, fcNegInf}:
      raise newException(ValueError,
        "sparkline values must be finite numbers or NaN gaps")
    if not value.isNaN:
      dataMinimum = min(dataMinimum, value)
      dataMaximum = max(dataMaximum, value)
      inc finiteCount

  if finiteCount == 0:
    for _ in data:
      result.add options.gapGlyph
    return

  let fullyAutomatic = options.minimum.isNone and options.maximum.isNone
  if fullyAutomatic and dataMinimum == dataMaximum:
    let tickIndex = if dataMinimum == 0.0 or
        options.constantMode == scmLowest:
      0
    else:
      options.ticks.len div 2
    var activeColor = colorDefault
    for rawValue in data:
      let value = float64(rawValue)
      if value.isNaN:
        if options.useColor and activeColor != colorDefault:
          result.add termClear
          activeColor = colorDefault
        result.add options.gapGlyph
      else:
        result.addGlyph(options.ticks[tickIndex],
          options.paletteColor(tickIndex), options.useColor, activeColor)
    if options.useColor and activeColor != colorDefault:
      result.add termClear
    return

  var
    minimum = if options.minimum.isSome:
      options.minimum.get()
    else:
      dataMinimum
    maximum = if options.maximum.isSome:
      options.maximum.get()
    else:
      dataMaximum

  # A single explicit bound can intentionally place every sample at that end
  # of the scale. Supply a harmless unit span so normalization remains valid.
  if minimum >= maximum:
    if options.minimum.isSome and options.maximum.isNone:
      maximum = minimum + 1.0
    elif options.maximum.isSome and options.minimum.isNone:
      minimum = maximum - 1.0
    else:
      maximum = minimum + 1.0

  let valueSpan = maximum - minimum
  var activeColor = colorDefault
  for rawValue in data:
    let value = float64(rawValue)
    if value.isNaN:
      if options.useColor and activeColor != colorDefault:
        result.add termClear
        activeColor = colorDefault
      result.add options.gapGlyph
      continue
    let
      normalized = clamp((value - minimum) / valueSpan, 0.0, 1.0)
      tickIndex = clamp(
        int(round(normalized * float64(options.ticks.high))),
        options.ticks.low,
        options.ticks.high
      )
    result.addGlyph(options.ticks[tickIndex],
      options.paletteColor(tickIndex), options.useColor, activeColor)
  if options.useColor and activeColor != colorDefault:
    result.add termClear

proc sparkline*[T: SomeNumber](data: openArray[T]): string =
  ## Renders ``data`` with automatic scaling and default options.
  sparkline(data, initSparklineOptions())
