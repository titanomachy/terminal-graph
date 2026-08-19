## Live terminal graph display helpers.
##
## ``LiveGraph`` streams the marker/fill renderer, while ``LiveLineGraph``
## streams the connected ASCII line renderer with its ANSI colors, gradients,
## legends, and thresholds. ``LiveDashboard`` owns a full-screen lifecycle for
## arbitrary composed frames, including responsive multiplots. Constructing or
## importing these types never changes terminal state. Call ``startLive`` before
## ``draw`` and ensure ``stopLive`` runs from a ``finally`` block.
##
## Most applications should access this API through ``import terminal_graphs``.

import std/[deques, math, sequtils, strutils, terminal]

import ./[line_graphs, static_graphs]

export line_graphs, static_graphs

type LiveGraph* = object
  ## A plotter configured for repeated, in-place terminal rendering.
  plotter*: Plotter
  width*: int
  height*: int
  useColor*: bool
  showStats*: bool
  active: bool

type LiveDashboard* = object
  ## Full-screen terminal lifecycle for an arbitrary rendered frame.
  ##
  ## Every draw clears the complete screen from its home position, so old
  ## physical rows cannot survive when a terminal resize rewraps the previous
  ## frame. On POSIX terminals, ``alternateScreen`` keeps animation frames out
  ## of the application's normal screen and scrollback.
  alternateScreen*: bool
  output: File
  active: bool
  usingAlternateScreen: bool

type LiveLineGraph* = object
  ## A bounded collection of series rendered repeatedly by ``plotMany``.
  config*: AsciiGraphConfig
  sampleLimit*: int
  series: seq[Deque[float64]]
  active: bool
  previousFrameLines: int

proc initLiveDashboard*(alternateScreen = true;
                        output: File = stdout): LiveDashboard =
  ## Creates a side-effect-free full-screen dashboard controller.
  ##
  ## ``output`` defaults to standard output and is retained for the complete
  ## lifecycle. Alternate-screen mode is enabled only for a POSIX TTY; other
  ## outputs still receive deterministic full-screen redraws.
  if output == nil:
    raise newException(ValueError, "live dashboard output cannot be nil")
  LiveDashboard(alternateScreen: alternateScreen, output: output)

proc isActive*(dashboard: LiveDashboard): bool =
  ## Returns whether the dashboard owns the configured terminal output.
  dashboard.active

proc startLive*(dashboard: var LiveDashboard) =
  ## Enters full-screen mode and hides the cursor.
  ##
  ## Calling this procedure again while active has no effect.
  if dashboard.active:
    return
  when defined(posix):
    if dashboard.alternateScreen and dashboard.output.isatty:
      dashboard.output.write "\e[?1049h"
      dashboard.usingAlternateScreen = true
  dashboard.output.setCursorPos(0, 0)
  dashboard.output.eraseScreen()
  dashboard.output.hideCursor()
  dashboard.output.flushFile()
  dashboard.active = true

proc draw*(dashboard: LiveDashboard; frame: string) =
  ## Clears and replaces the complete dashboard frame.
  ##
  ## Full redraws deliberately avoid saved logical line counts: after a resize,
  ## a terminal may have rewrapped each old line into several physical rows.
  if not dashboard.active:
    raise newException(ValueError,
      "call startLive before drawing a live dashboard")
  dashboard.output.setCursorPos(0, 0)
  dashboard.output.eraseScreen()
  dashboard.output.write frame
  dashboard.output.flushFile()

proc stopLive*(dashboard: var LiveDashboard) =
  ## Restores attributes, the normal screen, and cursor visibility.
  ##
  ## Calling this procedure for an inactive dashboard has no effect.
  if not dashboard.active:
    return
  dashboard.output.resetAttributes()
  when defined(posix):
    if dashboard.usingAlternateScreen:
      dashboard.output.write "\e[?1049l"
  dashboard.output.showCursor()
  dashboard.output.flushFile()
  dashboard.active = false
  dashboard.usingAlternateScreen = false

proc initLiveGraph*(title: string; unit = "";
                    maxSamples = DefaultMaxSamples; width = 0; height = 0;
                    useColor = true; showStats = true): LiveGraph =
  ## Creates a live graph without modifying the terminal.
  ##
  ## Zero dimensions follow the current terminal size on every draw, allowing
  ## the graph to adapt when the terminal is resized.
  LiveGraph(
    plotter: initPlotter(title, unit, maxSamples),
    width: width,
    height: height,
    useColor: useColor,
    showStats: showStats,
    active: false
  )

proc addSeries*(graph: var LiveGraph; name: string; style = psLine;
                color = fgCyan; marker = "•"): int {.discardable.} =
  ## Adds a series to the underlying plotter and returns its index.
  graph.plotter.addSeries(name, style, color, marker)

proc push*(graph: var LiveGraph; seriesIdx: int; value: float64) =
  ## Appends one sample to a live graph series.
  graph.plotter.push(seriesIdx, value)

proc push*(graph: var LiveGraph; seriesIdx: int;
           values: openArray[float64]) =
  ## Appends several samples to a live graph series.
  graph.plotter.push(seriesIdx, values)

proc setRange*(graph: var LiveGraph; minimum, maximum: float64) =
  ## Sets a fixed range on the underlying plotter.
  graph.plotter.setRange(minimum, maximum)

proc clearRange*(graph: var LiveGraph) =
  ## Restores automatic range calculation on the underlying plotter.
  graph.plotter.clearRange()

proc clear*(graph: var LiveGraph) =
  ## Clears samples from every series in the underlying plotter.
  graph.plotter.clear()

proc renderFrame*(graph: LiveGraph): string =
  ## Renders one frame without moving the cursor or writing to stdout.
  graph.plotter.render(
    width = graph.width,
    height = graph.height,
    useColor = graph.useColor,
    showStats = graph.showStats
  )

proc isActive*(graph: LiveGraph): bool =
  ## Returns whether ``startLive`` has been called without a matching stop.
  graph.active

proc startLive*(graph: var LiveGraph; clearScreen = true) =
  ## Hides the cursor and optionally clears the terminal before live drawing.
  ##
  ## Calling this procedure again while the graph is active has no effect.
  if graph.active:
    return
  hideCursor()
  if clearScreen:
    eraseScreen()
  graph.active = true

proc draw*(graph: LiveGraph) =
  ## Replaces the current terminal frame with the latest graph contents.
  ##
  ## Raises ``ValueError`` if ``startLive`` has not been called.
  if not graph.active:
    raise newException(ValueError, "call startLive before drawing a live graph")
  setCursorPos(0, 0)
  eraseScreen()
  stdout.write graph.renderFrame()
  stdout.flushFile()

proc stopLive*(graph: var LiveGraph) =
  ## Restores terminal attributes and cursor visibility.
  ##
  ## Calling this procedure for an inactive graph has no effect.
  if not graph.active:
    return
  resetAttributes()
  showCursor()
  graph.active = false

proc initLiveLineGraph*(seriesCount = 1; maxSamples = 80;
                        config = initAsciiGraphConfig()): LiveLineGraph =
  ## Creates a colored streaming line graph without touching terminal state.
  if seriesCount <= 0:
    raise newException(ValueError, "seriesCount must be greater than zero")
  if maxSamples <= 0:
    raise newException(ValueError, "maxSamples must be greater than zero")
  LiveLineGraph(
    config: config,
    sampleLimit: maxSamples,
    series: newSeqWith(seriesCount, initDeque[float64]()),
    active: false,
    previousFrameLines: 0
  )

proc requireSeries(graph: LiveLineGraph; seriesIdx: int) =
  if seriesIdx < 0 or seriesIdx >= graph.series.len:
    raise newException(IndexDefect,
      "live line graph series index is out of bounds")

proc push*(graph: var LiveLineGraph; seriesIdx: int; value: float64) =
  ## Appends one sample. NaN creates a visible gap; infinities are rejected.
  graph.requireSeries(seriesIdx)
  if value.classify in {fcInf, fcNegInf}:
    raise newException(ValueError,
      "live line graph values must be finite numbers or NaN gaps")
  graph.series[seriesIdx].addLast(value)
  while graph.series[seriesIdx].len > graph.sampleLimit:
    discard graph.series[seriesIdx].popFirst()

proc push*(graph: var LiveLineGraph; seriesIdx: int;
           values: openArray[float64]) =
  ## Appends several samples after validating the complete batch.
  graph.requireSeries(seriesIdx)
  for value in values:
    if value.classify in {fcInf, fcNegInf}:
      raise newException(ValueError,
        "live line graph values must be finite numbers or NaN gaps")
  for value in values:
    graph.push(seriesIdx, value)

proc sampleCount*(graph: LiveLineGraph; seriesIdx: int): int =
  ## Returns retained sample count for one live line series.
  graph.requireSeries(seriesIdx)
  graph.series[seriesIdx].len

proc clear*(graph: var LiveLineGraph) =
  ## Clears samples from every live line series.
  for series in graph.series.mitems:
    series.clear()

proc renderFrame*(graph: LiveLineGraph): string =
  ## Renders current streaming data without writing or moving the cursor.
  var
    values = newSeq[seq[float64]](graph.series.len)
    hasSamples = false
  for index, series in graph.series:
    if series.len == 0:
      values[index] = @[NaN]
    else:
      hasSamples = true
      values[index] = newSeqOfCap[float64](series.len)
      for value in series:
        values[index].add value
  if not hasSamples:
    return ""
  plotMany(values, graph.config)

proc isActive*(graph: LiveLineGraph): bool =
  ## Returns whether the streaming display is active.
  graph.active

proc startLive*(graph: var LiveLineGraph; clearScreen = true) =
  ## Starts a streaming line display and hides the terminal cursor.
  if graph.active:
    return
  hideCursor()
  if clearScreen:
    eraseScreen()
  graph.active = true
  graph.previousFrameLines = 0

proc draw*(graph: var LiveLineGraph) =
  ## Redraws the streaming line graph, preserving content above it.
  if not graph.active:
    raise newException(ValueError,
      "call startLive before drawing a live line graph")
  let frame = graph.renderFrame()
  if frame.len == 0:
    return
  if graph.previousFrameLines > 0:
    stdout.write clearLinesSequence(graph.previousFrameLines)
  stdout.write frame
  stdout.write '\n'
  stdout.flushFile()
  graph.previousFrameLines = frame.splitLines().len

proc stopLive*(graph: var LiveLineGraph) =
  ## Stops streaming and restores terminal attributes and cursor visibility.
  if not graph.active:
    return
  resetAttributes()
  showCursor()
  graph.active = false
  graph.previousFrameLines = 0
