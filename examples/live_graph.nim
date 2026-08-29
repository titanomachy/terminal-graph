## Continuously update a graph in place. Stop it with Ctrl+C.
# Run with: nim r --path:src examples/live_graph.nim

when isMainModule:
  import std/[atomics, math, os, random]

  import ../src/terminal_graph

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

  var graph = initLiveGraph("Live service metrics", unit = "req/s")
  let throughput = graph.addSeries(
    "throughput",
    style = psFill,
    color = ModernGraphSeriesColors[0],
    marker = "▄"
  )
  let errors = graph.addSeries(
    "errors",
    style = psLine,
    color = ModernGraphSeriesColors[1],
    marker = "•"
  )

  var
    step = 0.0
    renderedFrames = 0

  stopRequested.store(false, moRelaxed)
  setControlCHook(requestStop)
  try:
    graph.startLive()
    while not stopRequested.load(moRelaxed):
      step += 0.05
      graph.push(throughput,
        max(40.0 + sin(step) * 22.0 + rand(8.0) - 4.0, 0.0))
      graph.push(errors,
        max(8.0 + cos(step * 0.6) * 5.0 + rand(2.0), 0.0))

      graph.draw()
      inc renderedFrames
      sleep(33)
      if recordingMode and renderedFrames >= RecordingFrameLimit:
        break
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    try:
      graph.stopLive()
    except IOError:
      discard
    finally:
      when declared(unsetControlCHook):
        unsetControlCHook()
