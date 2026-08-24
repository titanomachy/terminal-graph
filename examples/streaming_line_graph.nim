## Connected, colored streaming lines. Stop with Ctrl+C.

when isMainModule:
  import std/[math, os, random]

  import ../src/terminal_graph

  randomize()

  var config = initAsciiGraphConfig()
  config.width = 60
  config.height = 12
  config.caption = "Live API latency"
  config.seriesColors = @[colorBrightCyan, colorBrightYellow]
  config.seriesLegends = @["p50", "p95"]

  var graph = initLiveLineGraph(
    seriesCount = 2,
    maxSamples = 60,
    config = config
  )

  var step = 0.0
  graph.startLive()
  try:
    while true:
      step += 0.06
      graph.push(0, 20.0 + sin(step) * 5.0 + rand(2.0))
      graph.push(1, 40.0 + cos(step * 0.7) * 12.0 + rand(5.0))
      graph.draw()
      sleep(33)
  except IOError:
    discard
  finally:
    graph.stopLive()
