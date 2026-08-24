## Pure-Nim 2D surface and filled-contour plots for terminal applications.
##
## Surface plots use Unicode half blocks to encode two samples per terminal row
## with independent foreground/background colors. Contour plots quantize the
## same matrix into value bands. No Python runtime or plotting backend is used.

import std/[math, options, sequtils, strformat]

import ./line_graphs

export line_graphs

const SurfaceGlyphs*: array[10, string] =
  [" ", "·", ":", "░", "▒", "▓", "▄", "▆", "▇", "█"]
  ## Low-to-high glyph ramp used for plain-text surfaces and contours.

type SurfacePlotOptions* = object
  ## Configuration shared by surface and filled-contour renderers.
  width*: int
  height*: int
  useColor*: bool
  showScale*: bool
  caption*: string
  palette*: seq[TerminalColor]
  minimum*: Option[float64]
  maximum*: Option[float64]
  contourLevels*: int
  lineEnding*: string

proc initSurfacePlotOptions*(): SurfacePlotOptions =
  ## Returns defaults suitable for ANSI-capable terminals.
  SurfacePlotOptions(
    useColor: true,
    showScale: true,
    palette: @HeatmapSpectrum,
    minimum: none(float64),
    maximum: none(float64),
    contourLevels: 8,
    lineEnding: "\n"
  )

proc setSurfaceRange*(options: var SurfacePlotOptions;
                      minimum, maximum: float64) =
  ## Sets a fixed color/contour scale.
  if minimum.classify in {fcNan, fcInf, fcNegInf} or
      maximum.classify in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "surface range must be finite")
  if minimum >= maximum:
    raise newException(ValueError, "surface minimum must be below maximum")
  options.minimum = some(minimum)
  options.maximum = some(maximum)

proc clearSurfaceRange*(options: var SurfacePlotOptions) =
  ## Restores automatic value scaling.
  options.minimum = none(float64)
  options.maximum = none(float64)

proc normalizedOptions(options: SurfacePlotOptions): SurfacePlotOptions =
  result = options
  if result.width < 0 or result.height < 0:
    raise newException(ValueError, "surface dimensions cannot be negative")
  if result.contourLevels < 2:
    result.contourLevels = 2
  if result.palette.len == 0:
    result.palette = @HeatmapSpectrum
  if result.lineEnding.len == 0:
    result.lineEnding = "\n"
  if result.minimum.isSome != result.maximum.isSome:
    raise newException(ValueError,
      "surface minimum and maximum must either both be set or both be automatic")
  if result.minimum.isSome and result.minimum.get() >= result.maximum.get():
    raise newException(ValueError, "surface minimum must be below maximum")

proc validateMatrix(data: openArray[seq[float64]]): tuple[
    rows, columns: int; minimum, maximum: float64] =
  if data.len == 0:
    raise newException(ValueError, "surface data cannot be empty")
  if data[0].len == 0:
    raise newException(ValueError, "surface rows cannot be empty")

  result.rows = data.len
  result.columns = data[0].len
  result.minimum = Inf
  result.maximum = -Inf
  for row in data:
    if row.len != result.columns:
      raise newException(ValueError, "surface data must be rectangular")
    for value in row:
      if value.classify in {fcInf, fcNegInf}:
        raise newException(ValueError,
          "surface values must be finite numbers or NaN gaps")
      if not value.isNaN:
        result.minimum = min(result.minimum, value)
        result.maximum = max(result.maximum, value)
  if result.minimum == Inf:
    raise newException(ValueError,
      "surface data requires at least one non-NaN value")

proc resample(data: openArray[seq[float64]]; rows,
              columns: int): seq[seq[float64]] =
  result = newSeqWith(rows, newSeq[float64](columns))
  for row in 0 ..< rows:
    let sourceRow = if rows == 1:
      0
    else:
      int(round(float64(row) * float64(data.high) / float64(rows - 1)))
    for column in 0 ..< columns:
      let sourceColumn = if columns == 1:
        0
      else:
        int(round(float64(column) * float64(data[0].high) /
          float64(columns - 1)))
      result[row][column] = data[sourceRow][sourceColumn]

proc valueFraction(value, minimum, maximum: float64): float64 =
  if value.isNaN:
    return NaN
  if minimum == maximum:
    return 0.0
  clamp((value - minimum) / (maximum - minimum), 0.0, 1.0)

proc paletteColor(palette: openArray[TerminalColor]; fraction: float64): TerminalColor =
  if fraction.isNaN:
    return colorDefault
  palette[clamp(int(round(fraction * float64(palette.high))),
    palette.low, palette.high)]

proc backgroundCode(color: TerminalColor): string =
  ansiCode(color, cpBackground)

proc solidCellCode(color: TerminalColor): string =
  ## Matching foreground and background colors cover font-cell seams around
  ## a full-block glyph while preserving the glyph in copied/plain text.
  ansiCode(color) & backgroundCode(color)

proc glyphFor(fraction: float64; levelCount = SurfaceGlyphs.len): string =
  if fraction.isNaN:
    return " "
  let maximumIndex = clamp(levelCount, 2, SurfaceGlyphs.len) - 1
  SurfaceGlyphs[clamp(int(round(fraction * float64(maximumIndex))),
    0, maximumIndex)]

proc addCaption(result: var string; options: SurfacePlotOptions) =
  if options.caption.len > 0:
    if result.len > 0:
      result.add options.lineEnding
    result.add options.caption

proc addScale(result: var string; options: SurfacePlotOptions;
              minimum, maximum: float64) =
  if not options.showScale:
    return
  result.add options.lineEnding
  result.add &"{minimum:.3g} "
  if options.useColor:
    let swatchCount = min(options.palette.len, 16)
    for index in 0 ..< swatchCount:
      let sourceIndex = if swatchCount == 1:
        0
      else:
        int(round(float64(index) * float64(options.palette.high) /
          float64(swatchCount - 1)))
      result.add solidCellCode(options.palette[sourceIndex]) & "█"
    result.add termClear
  else:
    for glyph in SurfaceGlyphs:
      result.add glyph
  result.add &" {maximum:.3g}"

proc prepareMatrix(data: openArray[seq[float64]];
                   rawOptions: SurfacePlotOptions): tuple[
    data: seq[seq[float64]]; options: SurfacePlotOptions;
    minimum, maximum: float64] =
  let details = validateMatrix(data)
  result.options = normalizedOptions(rawOptions)
  result.minimum = if result.options.minimum.isSome:
    result.options.minimum.get()
  else:
    details.minimum
  result.maximum = if result.options.maximum.isSome:
    result.options.maximum.get()
  else:
    details.maximum
  let
    targetColumns = if result.options.width > 0:
      result.options.width
    else:
      details.columns
    targetRows = if result.options.height > 0:
      result.options.height
    else:
      details.rows
  result.data = resample(data, targetRows, targetColumns)

proc plotSurfaceFloat(data: openArray[seq[float64]];
                      rawOptions: SurfacePlotOptions): string =
  let prepared = prepareMatrix(data, rawOptions)
  result.addCaption(prepared.options)
  if result.len > 0:
    result.add prepared.options.lineEnding

  var outputRow = 0
  while outputRow * 2 < prepared.data.len:
    if outputRow > 0:
      result.add prepared.options.lineEnding
    let
      topRow = outputRow * 2
      bottomRow = topRow + 1
    for column in 0 ..< prepared.data[0].len:
      let
        top = prepared.data[topRow][column]
        bottom = if bottomRow < prepared.data.len:
          prepared.data[bottomRow][column]
        else:
          NaN
        topFraction = valueFraction(
          top, prepared.minimum, prepared.maximum)
        bottomFraction = valueFraction(
          bottom, prepared.minimum, prepared.maximum)

      if prepared.options.useColor:
        if top.isNaN and bottom.isNaN:
          result.add " "
        elif bottom.isNaN:
          result.add ansiCode(paletteColor(
            prepared.options.palette, topFraction)) & "▀" &
            termClear
        elif top.isNaN:
          result.add ansiCode(paletteColor(
            prepared.options.palette, bottomFraction)) & "▄" &
            termClear
        else:
          result.add ansiCode(paletteColor(
            prepared.options.palette, topFraction))
          result.add backgroundCode(paletteColor(
            prepared.options.palette, bottomFraction))
          result.add "▀" & termClear
      else:
        let average = if top.isNaN: bottomFraction
          elif bottom.isNaN: topFraction
          else: (topFraction + bottomFraction) / 2.0
        result.add glyphFor(average)
    inc outputRow
  result.addScale(prepared.options, prepared.minimum, prepared.maximum)

proc plotContourFloat(data: openArray[seq[float64]];
                      rawOptions: SurfacePlotOptions): string =
  let prepared = prepareMatrix(data, rawOptions)
  result.addCaption(prepared.options)
  if result.len > 0:
    result.add prepared.options.lineEnding

  for rowIndex, row in prepared.data:
    if rowIndex > 0:
      result.add prepared.options.lineEnding
    var activeColor = colorDefault
    for value in row:
      let fraction = valueFraction(value, prepared.minimum, prepared.maximum)
      if fraction.isNaN:
        if activeColor != colorDefault:
          result.add termClear
          activeColor = colorDefault
        result.add " "
        continue
      let quantized = round(fraction *
        float64(prepared.options.contourLevels - 1)) /
        float64(prepared.options.contourLevels - 1)
      if prepared.options.useColor:
        let color = paletteColor(prepared.options.palette, quantized)
        if color != activeColor:
          result.add solidCellCode(color)
          activeColor = color
        result.add "█"
      else:
        result.add glyphFor(quantized, prepared.options.contourLevels)
    if activeColor != colorDefault:
      result.add termClear
  result.addScale(prepared.options, prepared.minimum, prepared.maximum)

proc convertedMatrix[T: SomeNumber](data: openArray[seq[T]]): seq[seq[float64]] =
  result = newSeq[seq[float64]](data.len)
  for rowIndex, row in data:
    result[rowIndex] = newSeqOfCap[float64](row.len)
    for value in row:
      result[rowIndex].add float64(value)

proc matrixFromFlat[T: SomeNumber](data: openArray[T];
                                   columns: int): seq[seq[float64]] =
  if columns <= 0:
    raise newException(ValueError, "surface columns must be greater than zero")
  if data.len == 0 or data.len mod columns != 0:
    raise newException(ValueError,
      "flat surface data length must be a non-zero multiple of columns")
  let rows = data.len div columns
  result = newSeqWith(rows, newSeq[float64](columns))
  for index, value in data:
    result[index div columns][index mod columns] = float64(value)

proc plotSurface*[T: SomeNumber](data: openArray[seq[T]];
                                 options: SurfacePlotOptions): string =
  ## Renders a rectangular matrix as a high-resolution terminal surface.
  ##
  ## Each terminal row contains two sampled matrix rows when Unicode half
  ## blocks and ANSI colors are enabled.
  plotSurfaceFloat(convertedMatrix(data), options)

proc plotSurface*[T: SomeNumber](data: openArray[seq[T]]): string =
  ## Renders a surface using default options.
  plotSurface(data, initSurfacePlotOptions())

proc plotSurface*[T: SomeNumber](data: openArray[T]; columns: int;
                                 options: SurfacePlotOptions): string =
  ## Renders flat row-major data with the supplied number of columns.
  plotSurfaceFloat(matrixFromFlat(data, columns), options)

proc plotSurface*[T: SomeNumber](data: openArray[T]; columns: int): string =
  ## Renders flat row-major data using default options.
  plotSurface(data, columns, initSurfacePlotOptions())

proc plotContour*[T: SomeNumber](data: openArray[seq[T]];
                                 options: SurfacePlotOptions): string =
  ## Renders a rectangular matrix as quantized filled contour bands.
  plotContourFloat(convertedMatrix(data), options)

proc plotContour*[T: SomeNumber](data: openArray[seq[T]]): string =
  ## Renders filled contours using default options.
  plotContour(data, initSurfacePlotOptions())

proc plotContour*[T: SomeNumber](data: openArray[T]; columns: int;
                                 options: SurfacePlotOptions): string =
  ## Renders flat row-major data as filled contours.
  plotContourFloat(matrixFromFlat(data, columns), options)

proc plotContour*[T: SomeNumber](data: openArray[T]; columns: int): string =
  ## Renders flat row-major contours using default options.
  plotContour(data, columns, initSurfacePlotOptions())

proc plot2D*[T: SomeNumber](data: openArray[T]; columns: int;
                            options = initSurfacePlotOptions()): string =
  ## Compatibility-friendly alias for ``plotSurface`` with flat data.
  plotSurface(data, columns, options)
