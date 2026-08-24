## TerminalGraph with one convenient import.
##
## This façade re-exports bar, candle, connected line, scatter/XY, multiplot,
## 2D surface, static, live, sparkline, and terminal-styling APIs. Importing it
## has no side effects; terminal state changes happen only through explicitly
## called helpers. Compiling this file directly runs a small graph demonstration
## because that code is guarded by ``when isMainModule``.
##
## .. code-block:: nim
##
##   import terminal_graph
##
##   echo plot([3, 4, 9, 6, 2, 4, 5, 8])
##   echo sparkline([1.0, 4.0, 2.0, 8.0])
##
##   var graph = initStaticGraph("Request latency", unit = "ms")
##   let latency = graph.addSeries("p95")
##   graph.push(latency, [18.0, 20.5, 19.0, 23.0])
##   echo graph.render(width = 60, height = 14, useColor = false)
##
##   let terrain = @[@[0.0, 0.5], @[0.75, 1.0]]
##   echo plotSurface(terrain)

import terminal_style
import terminal_graph/[bar_graphs, candle_graphs, line_graphs, live_graphs,
  multiplot_graphs, sparkline_graphs, static_graphs, surface_graphs, xy_graphs]

export bar_graphs, candle_graphs, line_graphs, live_graphs, multiplot_graphs,
  sparkline_graphs, static_graphs, surface_graphs, terminal_style, xy_graphs

when isMainModule:
  echo "Sparkline example:"
  echo sparkline([1.0, 5.0, 2.5, 8.0, 12.0, 7.0, 3.0, 9.0])

  echo "\nTerminal graph example:"
  var graph = initPlotter("Sample values")
  let values = graph.addSeries("values", marker = "x")
  graph.push(values, [1.0, 5.0, 2.5, 8.0, 12.0, 7.0, 3.0, 9.0])
  echo graph.render(width = 64, height = 12, useColor = false)
