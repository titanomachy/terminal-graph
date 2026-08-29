## A compact streaming dashboard made from reusable sparkline renderings.
## Stop it with Ctrl+C.
# Run with: nim r --path:src examples/streaming_sparklines.nim

when isMainModule:
  import std/[atomics, math, os, random]

  import ../src/terminal_graph

  const HistoryLength = 36

  proc pushSample(history: var seq[float64]; value: float64) =
    history.add value
    if history.len > HistoryLength:
      history.delete(0)

  const RecordingFrameLimit = 120
  let recordingMode = getEnv("TERMINAL_GRAPH_RECORDING") == "1"
  if recordingMode:
    randomize(42)
  else:
    randomize()

  var stopRequested: Atomic[bool]

  proc requestStop() {.noconv.} =
    ## A signal handler may only perform signal-safe work.
    stopRequested.store(true, moRelaxed)

  var
    cpuHistory: seq[float64]
    memoryHistory: seq[float64]
    step = 0.0
    renderedFrames = 0
    dashboard = initLiveDashboard()

  stopRequested.store(false, moRelaxed)
  setControlCHook(requestStop)
  try:
    dashboard.startLive()
    while not stopRequested.load(moRelaxed):
      step += 0.06
      cpuHistory.pushSample(
        clamp(52.0 + sin(step) * 28.0 + rand(8.0) - 4.0, 0.0, 100.0)
      )
      memoryHistory.pushSample(
        clamp(64.0 + cos(step * 0.45) * 12.0 + rand(3.0), 0.0, 100.0)
      )

      # Keep one blank row above the dashboard for a clean video crop.
      let frame = "\n" & foreground(ModernGraphSeriesColors[0],
          "CPU     ", sparkline(cpuHistory),
          "  ", cpuHistory[^1].int, "%") & '\n' & '\n' &
        foreground(ModernGraphSeriesColors[1],
          "Memory  ", sparkline(memoryHistory),
          "  ", memoryHistory[^1].int, "%")
      dashboard.draw(frame)

      inc renderedFrames
      sleep(33)
      if recordingMode and renderedFrames >= RecordingFrameLimit:
        break
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    try:
      dashboard.stopLive()
    except IOError:
      discard
    finally:
      when declared(unsetControlCHook):
        unsetControlCHook()
