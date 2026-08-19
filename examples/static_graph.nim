## Render a deterministic graph once. This is suitable for reports, logs, and
## a quick first integration test.

when isMainModule:
  import std/terminal

  import ../src/terminal_graphs

  var graph = initStaticGraph("Weekly request volume", unit = "requests")
  let requests = graph.addSeries(
    "requests",
    style = psFill,
    color = fgGreen,
    marker = "▄"
  )

  graph.push(requests, [12.0, 18.0, 15.0, 27.0, 35.0, 31.0, 42.0])

  # Explicit dimensions and disabled color make redirected output predictable.
  echo graph.render(width = 64, height = 14, useColor = false)
