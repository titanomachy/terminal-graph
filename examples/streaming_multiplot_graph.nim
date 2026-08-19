## Continuously update two independent line graphs as one multiplot dashboard.
## Stop it with Ctrl+C.

when isMainModule:
  import std/[atomics, math, os, random, terminal]

  import ../src/terminal_graphs

  randomize()

  var stopRequested: Atomic[bool]

  proc requestStop() {.noconv.} =
    ## A signal handler may only perform signal-safe work.
    stopRequested.store(true)

  var
    dashboard = initLiveDashboard()
    throughput = initLiveGraph(
      "Throughput", unit = "req/s", maxSamples = 60,
      width = 38, height = 10, showStats = false
    )
    latency = initLiveGraph(
      "Latency", unit = "ms", maxSamples = 60,
      width = 38, height = 10, showStats = false
    )
    step = 0.0
  let
    throughputSeries = throughput.addSeries(
      "throughput", color = fgCyan, marker = "•")
    latencySeries = latency.addSeries(
      "latency", color = fgYellow, marker = "•")
    renderThroughput: MultiplotRenderer = proc(width: int): string =
      var view = throughput
      view.width = width
      view.renderFrame()
    renderLatency: MultiplotRenderer = proc(width: int): string =
      var view = latency
      view.width = width
      view.renderFrame()

  var layout = initMultiplotOptions()
  layout.columns = autoColumns
  layout.minimumCellWidth = 32
  layout.horizontalGap = 4
  layout.verticalGap = 1
  layout.breakpoints = @[
    multiplotBreakpoint(0, 1),
    multiplotBreakpoint(70, 2)
  ]

  dashboard.startLive()
  setControlCHook(requestStop)
  try:
    while not stopRequested.load():
      step += 0.15
      throughput.push(throughputSeries,
        max(70.0 + sin(step) * 20.0 + rand(6.0) - 3.0, 0.0))
      latency.push(latencySeries,
        max(28.0 + cos(step * 0.7) * 9.0 + rand(3.0), 0.0))

      # Terminal width is detected on every call. The callbacks render each
      # graph at its newly assigned cell width before the grid is assembled.
      let frame = multiplotResponsive(
        [renderThroughput, renderLatency], layout
      )
      dashboard.draw(frame)
      sleep(80)
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    when declared(unsetControlCHook):
      unsetControlCHook()
    dashboard.stopLive()
