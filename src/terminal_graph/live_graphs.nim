## Live terminal graph display helpers.
##
## ``LiveGraph`` streams the marker/fill renderer, ``LiveLineGraph`` streams the
## connected ASCII line renderer, and ``LiveCandleGraph`` retains bounded OHLC
## periods. ``LiveDashboard`` owns a full-screen lifecycle for arbitrary
## composed frames, including responsive multiplots. Constructing or importing
## these types never changes terminal state. Call ``startLive`` before ``draw``
## and ensure ``stopLive`` runs from a ``finally`` block.
##
## Most applications should access this API through ``import terminal_graph``.

import std/[deques, math, options, sequtils, strutils, terminal]

when defined(windows):
  import std/winlean

import ./[candle_graphs, line_graphs, static_graphs]

export candle_graphs, line_graphs, static_graphs

type LiveTerminalSession = object
  output: File
  active: bool
  usingAlternateScreen: bool
  usingVtSequences: bool
  when defined(windows):
    windowsConsoleHandle: Handle
    windowsOriginalMode: DWORD
    windowsModeChanged: bool

type LiveGraph* = object
  ## A plotter configured for repeated full-screen terminal rendering.
  plotter*: Plotter
  width*: int
  height*: int
  useColor*: bool
  showStats*: bool
  session: LiveTerminalSession

type LiveDashboard* = object
  ## Full-screen terminal lifecycle for an arbitrary rendered frame.
  ##
  ## Every draw clears the complete screen from its home position, so old
  ## physical rows cannot survive when a terminal resize rewraps the previous
  ## frame. On VT-capable terminals, ``alternateScreen`` keeps animation
  ## frames out of the application's normal screen and scrollback.
  alternateScreen*: bool
  session: LiveTerminalSession

type LiveLineGraph* = object
  ## A bounded collection of series rendered repeatedly by ``plotMany``.
  config*: AsciiGraphConfig
  sampleLimit*: int
  series: seq[Deque[float64]]
  session: LiveTerminalSession
  previousFrameLines: int

type LiveCandleGraph* = object
  ## A bounded OHLC history rendered repeatedly by ``plotCandles``.
  options*: CandlePlotOptions
  candleLimit*: int
  candles: Deque[Candle]
  labels: Deque[string]
  session: LiveTerminalSession
  previousFrameLines: int

when defined(windows):
  const
    enableProcessedOutput = DWORD(0x0001)
    enableVirtualTerminalProcessing = DWORD(0x0004)

  proc getConsoleMode(handle: Handle; mode: ptr DWORD): WINBOOL {.
      stdcall, dynlib: "kernel32", importc: "GetConsoleMode".}

  proc setConsoleMode(handle: Handle; mode: DWORD): WINBOOL {.
      stdcall, dynlib: "kernel32", importc: "SetConsoleMode".}

  proc enableWindowsVt(session: var LiveTerminalSession): bool =
    if not session.output.isatty or
        (session.output != stdout and session.output != stderr):
      return false
    let handle = getStdHandle(
      if session.output == stderr: STD_ERROR_HANDLE else: STD_OUTPUT_HANDLE)
    if handle == INVALID_HANDLE_VALUE:
      return false
    var originalMode: DWORD
    if getConsoleMode(handle, addr originalMode) == 0:
      return false
    let requestedMode = originalMode or enableProcessedOutput or
      enableVirtualTerminalProcessing
    if requestedMode != originalMode and
        setConsoleMode(handle, requestedMode) == 0:
      return false
    session.windowsConsoleHandle = handle
    session.windowsOriginalMode = originalMode
    session.windowsModeChanged = requestedMode != originalMode
    true

  proc restoreWindowsConsoleMode(session: var LiveTerminalSession) =
    if session.windowsModeChanged:
      discard setConsoleMode(session.windowsConsoleHandle,
        session.windowsOriginalMode)
    session.windowsModeChanged = false

proc initLiveTerminalSession(output: File): LiveTerminalSession =
  LiveTerminalSession(output: output)

proc fullScreenSequence(frame: string): string =
  ## Paints a frame before erasing unused line tails and obsolete lower rows.
  ## Synchronized output prevents supporting terminals from presenting the
  ## frame while they are still parsing this update.
  var update = "\e[H"
  if frame.len == 0:
    update.add "\e[J"
  else:
    let lines = frame.splitLines()
    for index, line in lines:
      update.add line
      if index == lines.high:
        update.add "\e[J"
      else:
        update.add "\e[K\r\n"
  result = update.synchronizedOutputSequence()

proc startSession(session: var LiveTerminalSession; clearScreen,
                  alternateScreen: bool) =
  if session.active:
    return
  if session.output == nil:
    session.output = stdout
  when defined(posix):
    session.usingVtSequences = true
  elif defined(windows):
    session.usingVtSequences = session.enableWindowsVt()

  if alternateScreen and session.output.isatty and
      session.usingVtSequences:
    session.output.write "\e[?1049h"
    session.usingAlternateScreen = true
  if clearScreen:
    if session.usingVtSequences:
      session.output.write "\e[2J\e[H"
    else:
      session.output.setCursorPos(0, 0)
      session.output.eraseScreen()
  if session.usingVtSequences:
    session.output.write "\e[?25l"
  else:
    session.output.hideCursor()
  session.output.flushFile()
  session.active = true

proc drawFullScreen(session: LiveTerminalSession; frame: string) =
  if session.usingVtSequences:
    session.output.write frame.fullScreenSequence()
  else:
    session.output.setCursorPos(0, 0)
    session.output.eraseScreen()
    session.output.write frame
  session.output.flushFile()

proc stopSession(session: var LiveTerminalSession) =
  if not session.active:
    return
  if session.usingVtSequences:
    # Cancel a possibly interrupted synchronized update before restoring the
    # rest of the terminal state.
    session.output.write "\e[?2026l\e[0m"
    if session.usingAlternateScreen:
      session.output.write "\e[?1049l"
    session.output.write "\e[?25h"
  else:
    session.output.resetAttributes()
    session.output.showCursor()
  session.output.flushFile()
  when defined(windows):
    session.restoreWindowsConsoleMode()
  session.active = false
  session.usingAlternateScreen = false
  session.usingVtSequences = false

proc initLiveDashboard*(alternateScreen = true;
                        output: File = stdout): LiveDashboard =
  ## Creates a side-effect-free full-screen dashboard controller.
  ##
  ## ``output`` defaults to standard output and is retained for the complete
  ## lifecycle. Alternate-screen mode is enabled only for a VT-capable TTY;
  ## other outputs still receive deterministic full-screen redraws.
  if output == nil:
    raise newException(ValueError, "live dashboard output cannot be nil")
  LiveDashboard(
    alternateScreen: alternateScreen,
    session: initLiveTerminalSession(output)
  )

proc isActive*(dashboard: LiveDashboard): bool =
  ## Returns whether the dashboard owns the configured terminal output.
  dashboard.session.active

proc startLive*(dashboard: var LiveDashboard) =
  ## Enters full-screen mode and hides the cursor.
  ##
  ## Calling this procedure again while active has no effect.
  dashboard.session.startSession(
    clearScreen = true,
    alternateScreen = dashboard.alternateScreen
  )

proc draw*(dashboard: LiveDashboard; frame: string) =
  ## Clears and replaces the complete dashboard frame.
  ##
  ## Full redraws deliberately avoid saved logical line counts: after a resize,
  ## a terminal may have rewrapped each old line into several physical rows.
  if not dashboard.session.active:
    raise newException(ValueError,
      "call startLive before drawing a live dashboard")
  dashboard.session.drawFullScreen(frame)

proc stopLive*(dashboard: var LiveDashboard) =
  ## Restores attributes, the normal screen, and cursor visibility.
  ##
  ## Calling this procedure for an inactive dashboard has no effect.
  dashboard.session.stopSession()

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
    session: initLiveTerminalSession(stdout)
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
  graph.session.active

proc startLive*(graph: var LiveGraph; clearScreen = true) =
  ## Hides the cursor and optionally clears the terminal before live drawing.
  ##
  ## Calling this procedure again while the graph is active has no effect.
  graph.session.startSession(
    clearScreen = clearScreen,
    alternateScreen = false
  )

proc draw*(graph: LiveGraph) =
  ## Replaces the current terminal frame with the latest graph contents.
  ##
  ## Raises ``ValueError`` if ``startLive`` has not been called.
  if not graph.session.active:
    raise newException(ValueError, "call startLive before drawing a live graph")
  graph.session.drawFullScreen(graph.renderFrame())

proc stopLive*(graph: var LiveGraph) =
  ## Restores terminal attributes and cursor visibility.
  ##
  ## Calling this procedure for an inactive graph has no effect.
  graph.session.stopSession()

proc initLiveLineGraph*(seriesCount = 1; maxSamples = 80;
                        config = initAsciiGraphConfig();
                        output: File = stdout): LiveLineGraph =
  ## Creates a colored streaming line graph without touching terminal state.
  if seriesCount <= 0:
    raise newException(ValueError, "seriesCount must be greater than zero")
  if maxSamples <= 0:
    raise newException(ValueError, "maxSamples must be greater than zero")
  if output == nil:
    raise newException(ValueError, "live line graph output cannot be nil")
  LiveLineGraph(
    config: config,
    sampleLimit: maxSamples,
    series: newSeqWith(seriesCount, initDeque[float64]()),
    session: initLiveTerminalSession(output),
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
  graph.session.active

proc startLive*(graph: var LiveLineGraph; clearScreen = true) =
  ## Starts a streaming line display and hides the terminal cursor.
  if graph.session.active:
    return
  graph.session.startSession(
    clearScreen = clearScreen,
    alternateScreen = false
  )
  graph.previousFrameLines = 0

proc draw*(graph: var LiveLineGraph) =
  ## Redraws the streaming line graph, preserving content above it.
  if not graph.session.active:
    raise newException(ValueError,
      "call startLive before drawing a live line graph")
  let frame = graph.renderFrame()
  if frame.len == 0:
    return
  let update = frame.replaceLinesSequence(graph.previousFrameLines)
  graph.session.output.write update
  graph.session.output.flushFile()
  graph.previousFrameLines = frame.splitLines().len

proc stopLive*(graph: var LiveLineGraph) =
  ## Stops streaming and restores terminal attributes and cursor visibility.
  graph.session.stopSession()
  graph.previousFrameLines = 0

proc initLiveCandleGraph*(maxCandles = 80;
                          options = initCandlePlotOptions();
                          output: File = stdout): LiveCandleGraph =
  ## Creates a bounded live candle chart without changing terminal state.
  if maxCandles <= 0:
    raise newException(ValueError,
      "maxCandles must be greater than zero")
  if output == nil:
    raise newException(ValueError,
      "live candle graph output cannot be nil")
  LiveCandleGraph(
    options: options,
    candleLimit: maxCandles,
    candles: initDeque[Candle](),
    labels: initDeque[string](),
    session: initLiveTerminalSession(output)
  )

proc validateLiveCandle(value: Candle) =
  for price in [value.open, value.high, value.low, value.close]:
    if price.classify in {fcNan, fcInf, fcNegInf}:
      raise newException(ValueError, "candle prices must be finite")
  if value.low > value.high or value.open < value.low or
      value.open > value.high or value.close < value.low or
      value.close > value.high:
    raise newException(ValueError,
      "candle prices must satisfy low <= open/close <= high")

proc validateCandleLabel(label: string) =
  if '\n' in label or '\r' in label:
    raise newException(ValueError,
      "candle labels cannot contain line breaks")

proc appendValidated(graph: var LiveCandleGraph; value: Candle;
                     label: string) =
  graph.candles.addLast(value)
  graph.labels.addLast(label)
  while graph.candles.len > graph.candleLimit:
    discard graph.candles.popFirst()
    discard graph.labels.popFirst()

proc push*(graph: var LiveCandleGraph; value: Candle) =
  ## Appends one completed candle without a period label.
  value.validateLiveCandle()
  graph.appendValidated(value, "")

proc push*(graph: var LiveCandleGraph; value: Candle; label: string) =
  ## Appends one completed candle and its period label.
  value.validateLiveCandle()
  label.validateCandleLabel()
  graph.appendValidated(value, label)

proc push*(graph: var LiveCandleGraph;
           values: openArray[Candle]) =
  ## Atomically validates and appends several unlabelled candles.
  for value in values:
    value.validateLiveCandle()
  for value in values:
    graph.appendValidated(value, "")

proc push*(graph: var LiveCandleGraph; labels: openArray[string];
           values: openArray[Candle]) =
  ## Atomically validates and appends labelled candles.
  if labels.len != values.len:
    raise newException(ValueError,
      "candle label count must match the candle count")
  for value in values:
    value.validateLiveCandle()
  for label in labels:
    label.validateCandleLabel()
  for index, value in values:
    graph.appendValidated(value, labels[index])

proc updateLatest*(graph: var LiveCandleGraph; value: Candle) =
  ## Replaces the newest in-progress candle while retaining its label.
  value.validateLiveCandle()
  if graph.candles.len == 0:
    raise newException(ValueError,
      "cannot update an empty live candle graph")
  discard graph.candles.popLast()
  graph.candles.addLast(value)

proc updateLatest*(graph: var LiveCandleGraph; value: Candle;
                   label: string) =
  ## Replaces the newest in-progress candle and its label.
  value.validateLiveCandle()
  label.validateCandleLabel()
  if graph.candles.len == 0:
    raise newException(ValueError,
      "cannot update an empty live candle graph")
  discard graph.candles.popLast()
  discard graph.labels.popLast()
  graph.candles.addLast(value)
  graph.labels.addLast(label)

proc candleCount*(graph: LiveCandleGraph): int =
  ## Returns the number of retained candles.
  graph.candles.len

proc latestCandle*(graph: LiveCandleGraph): Option[Candle] =
  ## Returns the newest retained candle, if any.
  if graph.candles.len == 0:
    none(Candle)
  else:
    some(graph.candles.peekLast())

proc clear*(graph: var LiveCandleGraph) =
  ## Clears all retained candles and labels.
  graph.candles.clear()
  graph.labels.clear()

proc setRange*(graph: var LiveCandleGraph;
               minimum, maximum: float64) =
  ## Sets a fixed price range on the candle renderer.
  graph.options.setCandleRange(minimum, maximum)

proc clearRange*(graph: var LiveCandleGraph) =
  ## Restores automatic price bounds on the candle renderer.
  graph.options.clearCandleRange()

proc renderFrame*(graph: LiveCandleGraph): string =
  ## Renders the newest width-limited candle window without terminal I/O.
  if graph.candles.len == 0:
    return ""
  var
    retained = newSeqOfCap[Candle](graph.candles.len)
    retainedLabels = newSeqOfCap[string](graph.labels.len)
  for value in graph.candles:
    retained.add value
  for label in graph.labels:
    retainedLabels.add label
  let capacity = if graph.options.width > 0:
    graph.options.width
  else:
    retained.len
  let firstVisible = max(retained.len - capacity, 0)
  plotCandles(
    retainedLabels[firstVisible .. retainedLabels.high],
    retained[firstVisible .. retained.high],
    graph.options
  )

proc isActive*(graph: LiveCandleGraph): bool =
  ## Returns whether the streaming candle display is active.
  graph.session.active

proc startLive*(graph: var LiveCandleGraph; clearScreen = true) =
  ## Starts the streaming display and hides the terminal cursor.
  if graph.session.active:
    return
  graph.session.startSession(
    clearScreen = clearScreen,
    alternateScreen = false
  )
  graph.previousFrameLines = 0

proc draw*(graph: var LiveCandleGraph) =
  ## Redraws the streaming candle chart while preserving content above it.
  if not graph.session.active:
    raise newException(ValueError,
      "call startLive before drawing a live candle graph")
  let frame = graph.renderFrame()
  if frame.len == 0:
    return
  let update = frame.replaceLinesSequence(graph.previousFrameLines)
  graph.session.output.write update
  graph.session.output.flushFile()
  graph.previousFrameLines = frame.splitLines().len

proc stopLive*(graph: var LiveCandleGraph) =
  ## Stops streaming and restores terminal attributes and cursor visibility.
  graph.session.stopSession()
  graph.previousFrameLines = 0
