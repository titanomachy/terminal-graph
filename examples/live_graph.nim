## Continuously update a graph in place. Stop it with Ctrl+C.

when isMainModule:
  import std/[math, os, random, terminal]

  import ../src/terminal_graph

  randomize()

  var graph = initLiveGraph("Live service metrics", unit = "req/s")
  let throughput = graph.addSeries(
    "throughput",
    style = psFill,
    color = fgCyan,
    marker = "▄"
  )
  let errors = graph.addSeries(
    "errors",
    style = psLine,
    color = fgYellow,
    marker = "•"
  )

  var step = 0.0

  graph.startLive()
  try:
    while true:
      step += 0.05
      graph.push(throughput,
        max(40.0 + sin(step) * 22.0 + rand(8.0) - 4.0, 0.0))
      graph.push(errors,
        max(8.0 + cos(step * 0.6) * 5.0 + rand(2.0), 0.0))

      graph.draw()
      sleep(33)
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    graph.stopLive()
