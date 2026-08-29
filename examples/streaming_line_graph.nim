## Connected, colored streaming lines. Stop with Ctrl+C.
# Run with: nim r --path:src examples/streaming_line_graph.nim

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

  var config = initAsciiGraphConfig()
  config.width = 60
  config.height = 12
  config.caption = "Live API latency"
  config.seriesColors = @ModernGraphSeriesColors
  config.seriesLegends = @["p50", "p95"]
  config.captionColor = ModernGraphPalette.brightWhite
  config.axisColor = ModernGraphPalette.brightBlack
  config.labelColor = ModernGraphPalette.white

  var graph = initLiveLineGraph(
    seriesCount = 2,
    maxSamples = 60,
    config = config
  )

  var
    step = 0.0
    renderedFrames = 0
  stopRequested.store(false, moRelaxed)
  setControlCHook(requestStop)
  try:
    graph.startLive()
    while not stopRequested.load(moRelaxed):
      step += 0.06
      graph.push(0, 20.0 + sin(step) * 5.0 + rand(2.0))
      graph.push(1, 40.0 + cos(step * 0.7) * 12.0 + rand(5.0))
      graph.draw()
      inc renderedFrames
      sleep(33)
      if recordingMode and renderedFrames >= RecordingFrameLimit:
        break
  except IOError:
    discard
  finally:
    try:
      graph.stopLive()
    except IOError:
      discard
    finally:
      when declared(unsetControlCHook):
        unsetControlCHook()
