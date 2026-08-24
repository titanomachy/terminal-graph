## Responsive, ANSI-aware layouts for combining rendered terminal graphs.
##
## The classic ``multiplot`` overload accepts a fixed integer column count.
## ``MultiplotOptions`` adds CSS-grid-like auto fitting, shared track widths,
## horizontal and vertical alignment, and optional expansion across the
## available terminal width:
##
## .. code-block:: nim
##
##   var layout = initMultiplotOptions()
##   layout.columns = autoColumns
##   layout.availableWidth = 100 # Zero detects the terminal width.
##   layout.minimumCellWidth = 32
##   layout.horizontalAlignment = mhaCenter
##   layout.breakpoints = @[
##     multiplotBreakpoint(0, 1),
##     multiplotBreakpoint(80, 2),
##     multiplotBreakpoint(120, 3)
##   ]
##   echo multiplot(renderedPlots, layout)
##
## Already-rendered strings can reflow but cannot change their own dimensions.
## Use ``multiplotResponsive`` with ``MultiplotRenderer`` callbacks when each
## graph should be rendered at the width assigned to its grid track. Importing
## this module never queries or modifies the terminal; width detection occurs
## only when a responsive layout is rendered with ``availableWidth = 0``.

import std/[sequtils, strutils, terminal]

import terminal_style

export terminal_style

type
  MultiplotColumnKind* = enum
    ## Chooses whether the grid auto-fits or targets an explicit column count.
    mckAuto,
    mckFixed

  MultiplotColumns* = object
    ## Typed column selection used by ``MultiplotOptions``.
    case kind*: MultiplotColumnKind
    of mckAuto:
      discard
    of mckFixed:
      count*: int

  MultiplotHorizontalAlignment* = enum
    ## Positions content within the shared width of its grid column.
    mhaLeft,
    mhaCenter,
    mhaRight

  MultiplotVerticalAlignment* = enum
    ## Positions shorter plots within the shared height of their grid row.
    mvaTop,
    mvaMiddle,
    mvaBottom

  MultiplotBreakpoint* = object
    ## A minimum available width and the column count selected at that width.
    minimumWidth*: int
    columns*: int

  MultiplotOptions* = object
    ## Complete responsive-grid configuration.
    ##
    ## ``availableWidth = 0`` detects the current terminal width at render
    ## time. ``expandColumns`` distributes unused width across column tracks,
    ## while ``constrainToAvailableWidth`` prevents physical line wrapping.
    ## Optional breakpoints override content-based auto-fit in ``autoColumns``
    ## mode; the matching breakpoint with the greatest minimum width wins.
    columns*: MultiplotColumns
    availableWidth*: int
    minimumCellWidth*: int
    horizontalGap*: int
    verticalGap*: int
    horizontalAlignment*: MultiplotHorizontalAlignment
    verticalAlignment*: MultiplotVerticalAlignment
    expandColumns*: bool
    constrainToAvailableWidth*: bool
      ## Prevents terminal wrapping by reflowing tracks and clipping an
      ## individually over-wide, already-rendered line. The concise
      ## ``multiplot`` overload disables this for deterministic legacy output.
    breakpoints*: seq[MultiplotBreakpoint]

  MultiplotRenderer* = proc(width: int): string {.closure.}
    ## Deferred graph renderer receiving its complete grid-cell width budget.

  PreparedPlot = object
    lines: seq[string]
    width: int

const
  autoColumns* = MultiplotColumns(kind: mckAuto)
    ## Selects the largest column count that fits ``availableWidth``.

proc fixedColumns*(count: int): MultiplotColumns =
  ## Requests an explicit positive number of grid columns.
  ##
  ## Constrained responsive layouts still reduce this count when necessary to
  ## prevent physical terminal wrapping.
  if count <= 0:
    raise newException(ValueError, "fixed column count must be positive")
  MultiplotColumns(kind: mckFixed, count: count)

proc multiplotBreakpoint*(minimumWidth, columns: int): MultiplotBreakpoint =
  ## Creates a CSS-like responsive breakpoint.
  if minimumWidth < 0:
    raise newException(ValueError, "breakpoint width cannot be negative")
  if columns <= 0:
    raise newException(ValueError, "breakpoint columns must be positive")
  MultiplotBreakpoint(minimumWidth: minimumWidth, columns: columns)

proc initMultiplotOptions*(): MultiplotOptions =
  ## Returns a responsive, auto-fitting layout configuration.
  MultiplotOptions(
    columns: autoColumns,
    availableWidth: 0,
    minimumCellWidth: 24,
    horizontalGap: 3,
    verticalGap: 1,
    horizontalAlignment: mhaLeft,
    verticalAlignment: mvaTop,
    expandColumns: true,
    constrainToAvailableWidth: true,
    breakpoints: @[]
  )

proc validate(options: MultiplotOptions) =
  if options.columns.kind == mckFixed and options.columns.count <= 0:
    raise newException(ValueError, "fixed column count must be positive")
  if options.availableWidth < 0:
    raise newException(ValueError, "available width cannot be negative")
  if options.minimumCellWidth <= 0:
    raise newException(ValueError, "minimum cell width must be positive")
  if options.horizontalGap < 0 or options.verticalGap < 0:
    raise newException(ValueError, "multiplot gaps cannot be negative")
  for index, breakpoint in options.breakpoints:
    if breakpoint.minimumWidth < 0:
      raise newException(ValueError, "breakpoint width cannot be negative")
    if breakpoint.columns <= 0:
      raise newException(ValueError, "breakpoint columns must be positive")
    for prior in 0 ..< index:
      if options.breakpoints[prior].minimumWidth == breakpoint.minimumWidth:
        raise newException(ValueError,
          "multiplot breakpoint widths must be unique")

proc resolvedWidth(options: MultiplotOptions): int =
  if options.availableWidth > 0:
    options.availableWidth
  else:
    max(terminalWidth(), 1)

proc prepare(rendered: string): PreparedPlot =
  let originalLines = rendered.splitLines()
  result.width = rendered.displayWidth
  # ``splitLines`` alone can leave an SGR style or OSC-8 hyperlink open at a
  # cell boundary. Character wrapping at the natural width preserves the same
  # physical lines while closing and restoring ANSI state on each line.
  let normalizedLines = wrapAnsi(
    rendered, max(result.width, 1), wrapCharacters)
  if originalLines.len > 0 and normalizedLines.len >= originalLines.len:
    result.lines = normalizedLines[0 ..< originalLines.len]
  else:
    result.lines = originalLines
  if result.lines.len == 0:
    result.lines = @[""]

proc naturalColumnWidths(plots: openArray[PreparedPlot];
                         columnCount, minimumWidth: int): seq[int] =
  result = newSeq[int](columnCount)
  for column in 0 ..< columnCount:
    result[column] = minimumWidth
  for index, plot in plots:
    let column = index mod columnCount
    result[column] = max(result[column], plot.width)

proc totalWidth(widths: openArray[int]; gap: int): int =
  for width in widths:
    result += width
  result += max(widths.len - 1, 0) * gap

proc autoColumnCount(plots: openArray[PreparedPlot]; options: MultiplotOptions;
                     availableWidth: int): int =
  for candidate in countdown(plots.len, 1):
    let widths = naturalColumnWidths(
      plots, candidate, options.minimumCellWidth)
    if widths.totalWidth(options.horizontalGap) <= availableWidth:
      return candidate
  1

proc breakpointColumnCount(options: MultiplotOptions; availableWidth,
                           itemCount: int): int =
  var
    selectedWidth = -1
    selectedColumns = 1
  for breakpoint in options.breakpoints:
    if breakpoint.minimumWidth <= availableWidth and
        breakpoint.minimumWidth >= selectedWidth:
      selectedWidth = breakpoint.minimumWidth
      selectedColumns = breakpoint.columns
  min(selectedColumns, itemCount)

proc selectedColumnCount(plots: openArray[PreparedPlot];
                         options: MultiplotOptions;
                         availableWidth: int): int =
  case options.columns.kind
  of mckAuto:
    if options.breakpoints.len > 0:
      breakpointColumnCount(options, availableWidth, plots.len)
    else:
      autoColumnCount(plots, options, availableWidth)
  of mckFixed:
    min(options.columns.count, plots.len)

proc fittingColumnCount(plots: openArray[PreparedPlot]; requested: int;
                        options: MultiplotOptions;
                        availableWidth: int): int =
  ## Treat fixed and breakpoint column counts as targets when constraining the
  ## layout. Fewer columns are preferable to letting the terminal wrap a row.
  result = requested
  if not options.constrainToAvailableWidth:
    return
  while result > 1:
    let widths = naturalColumnWidths(
      plots, result, options.minimumCellWidth)
    if widths.totalWidth(options.horizontalGap) <= availableWidth:
      break
    dec result

proc expand(widths: var seq[int]; availableWidth, gap: int) =
  let spare = availableWidth - widths.totalWidth(gap)
  if spare <= 0 or widths.len == 0:
    return
  let
    perColumn = spare div widths.len
    remainder = spare mod widths.len
  for column in 0 ..< widths.len:
    widths[column] += perColumn
    if column < remainder:
      inc widths[column]

proc horizontalPadding(contentWidth, cellWidth: int;
                       alignment: MultiplotHorizontalAlignment):
                       tuple[left, right: int] =
  let spare = max(cellWidth - contentWidth, 0)
  case alignment
  of mhaLeft:
    (0, spare)
  of mhaCenter:
    (spare div 2, spare - spare div 2)
  of mhaRight:
    (spare, 0)

proc verticalOffset(contentHeight, rowHeight: int;
                    alignment: MultiplotVerticalAlignment): int =
  let spare = max(rowHeight - contentHeight, 0)
  case alignment
  of mvaTop:
    0
  of mvaMiddle:
    spare div 2
  of mvaBottom:
    spare

proc renderPrepared(plots: openArray[PreparedPlot]; options: MultiplotOptions;
                    availableWidth, columnCount: int): string =
  let rowCount = (plots.len + columnCount - 1) div columnCount
  var columnWidths = naturalColumnWidths(
    plots, columnCount, options.minimumCellWidth)
  if options.constrainToAvailableWidth and columnCount == 1:
    columnWidths[0] = min(columnWidths[0], availableWidth)
  if options.expandColumns:
    columnWidths.expand(availableWidth, options.horizontalGap)

  for plotRow in 0 ..< rowCount:
    let
      firstPlot = plotRow * columnCount
      lastPlot = min(firstPlot + columnCount, plots.len)
    var rowHeight = 0
    for index in firstPlot ..< lastPlot:
      rowHeight = max(rowHeight, plots[index].lines.len)

    if plotRow > 0:
      for _ in 0 .. options.verticalGap:
        result.add '\n'

    for lineIndex in 0 ..< rowHeight:
      if lineIndex > 0:
        result.add '\n'
      for index in firstPlot ..< lastPlot:
        let
          column = index - firstPlot
          plot = plots[index]
          startLine = verticalOffset(
            plot.lines.len, rowHeight, options.verticalAlignment)
          contentIndex = lineIndex - startLine
          rawLine = if contentIndex >= 0 and contentIndex < plot.lines.len:
            plot.lines[contentIndex]
          else:
            ""
          line = if options.constrainToAvailableWidth:
            truncateAnsi(rawLine, columnWidths[column], suffix = "")
          else:
            rawLine
          # Align the complete plot rectangle, not each ragged line. Centering
          # individual lines makes axes and graph canvases drift horizontally.
          plotWidth = min(plot.width, columnWidths[column])
          blockPadding = horizontalPadding(
            plotWidth, columnWidths[column],
            options.horizontalAlignment)
          rightPadding = max(
            columnWidths[column] - blockPadding.left - line.displayWidth, 0)

        if index > firstPlot:
          result.add repeat(' ', options.horizontalGap)
        result.add repeat(' ', blockPadding.left)
        result.add line
        # Preserve stable column starts without adding trailing whitespace to
        # the final occupied cell in a row.
        if index < lastPlot - 1:
          result.add repeat(' ', rightPadding)

proc multiplot*(plots: openArray[string];
                options: MultiplotOptions): string =
  ## Arranges rendered plots in an aligned, optionally responsive grid.
  ##
  ## ANSI sequences are preserved but ignored for measurement. Auto columns
  ## reflow the plots without resizing them; use ``multiplotResponsive`` when
  ## the graph renderers should receive and honor a width budget.
  if plots.len == 0:
    return ""
  options.validate()
  let availableWidth = options.resolvedWidth()
  var prepared = newSeqOfCap[PreparedPlot](plots.len)
  for rendered in plots:
    prepared.add prepare(rendered)
  let columnCount = fittingColumnCount(
    prepared,
    selectedColumnCount(prepared, options, availableWidth),
    options,
    availableWidth
  )
  renderPrepared(prepared, options, availableWidth, columnCount)

proc multiplot*(plots: openArray[string]; columns = 0; horizontalGap = 3;
                verticalGap = 1): string =
  ## Arranges already-rendered plots using a deterministic column count.
  ##
  ## ``columns = 0`` places every plot side by side. Logical columns share a
  ## width across grid rows. For responsive behavior use ``MultiplotOptions``.
  if plots.len == 0:
    return ""
  if columns < 0:
    raise newException(ValueError, "columns cannot be negative")
  if horizontalGap < 0 or verticalGap < 0:
    raise newException(ValueError, "multiplot gaps cannot be negative")
  var options = initMultiplotOptions()
  options.columns = fixedColumns(if columns == 0: plots.len else: columns)
  options.availableWidth = 1
  options.minimumCellWidth = 1
  options.horizontalGap = horizontalGap
  options.verticalGap = verticalGap
  options.expandColumns = false
  options.constrainToAvailableWidth = false
  multiplot(plots, options)

proc responsiveColumnCount(rendererCount: int; options: MultiplotOptions;
                           availableWidth: int): int =
  case options.columns.kind
  of mckFixed:
    result = min(options.columns.count, rendererCount)
  of mckAuto:
    if options.breakpoints.len > 0:
      result = breakpointColumnCount(
        options, availableWidth, rendererCount)
    else:
      result = max(min(
        (availableWidth + options.horizontalGap) div
          (options.minimumCellWidth + options.horizontalGap),
        rendererCount
      ), 1)
  if options.constrainToAvailableWidth:
    while result > 1 and
        result * options.minimumCellWidth +
          (result - 1) * options.horizontalGap > availableWidth:
      dec result

proc responsiveTrackWidths(columnCount, availableWidth, minimumWidth,
                           gap: int; expandColumns,
                           constrainToAvailableWidth: bool): seq[int] =
  let usableWidth = max(
    availableWidth - max(columnCount - 1, 0) * gap, 1)
  if not expandColumns:
    let width = if constrainToAvailableWidth:
      min(minimumWidth, usableWidth div columnCount)
    else:
      minimumWidth
    return newSeqWith(columnCount, width)
  result = newSeq[int](columnCount)
  for column in 0 ..< columnCount:
    result[column] = if constrainToAvailableWidth:
      usableWidth div columnCount
    else:
      max(usableWidth div columnCount, minimumWidth)
  let remainder = max(usableWidth - result.totalWidth(0), 0)
  for column in 0 ..< remainder:
    inc result[column mod columnCount]

proc multiplotResponsive*(renderers: openArray[MultiplotRenderer];
                          options = initMultiplotOptions()): string =
  ## Assigns grid-track widths before rendering and returns the combined grid.
  ##
  ## The callback width is a complete cell budget. A renderer that emits wider
  ## content is clipped unless ``constrainToAvailableWidth`` is disabled. Auto
  ## mode recalculates its column count on every call, making this overload
  ## suitable for terminal-resize-aware streaming dashboards.
  if renderers.len == 0:
    return ""
  options.validate()
  let
    availableWidth = options.resolvedWidth()
    columnCount = responsiveColumnCount(
      renderers.len, options, availableWidth)
    trackWidths = responsiveTrackWidths(
      columnCount, availableWidth, options.minimumCellWidth,
      options.horizontalGap, options.expandColumns,
      options.constrainToAvailableWidth)
  var rendered = newSeqOfCap[string](renderers.len)
  for index, renderer in renderers:
    if renderer.isNil:
      raise newException(ValueError, "multiplot renderer cannot be nil")
    rendered.add renderer(trackWidths[index mod columnCount])

  var layout = options
  layout.columns = fixedColumns(columnCount)
  multiplot(rendered, layout)
