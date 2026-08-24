## Render a deterministic graph once. This is suitable for reports, logs, and
## a quick first integration test.

when isMainModule:
  import std/terminal

  import ../src/terminal_graph

  var graph = initStaticGraph("Weekly request volume", unit = "requests")
  let requests = graph.addSeries(
    "requests",
    style = psFill,
    color = fgGreen,
    marker = "▄"
  )

  graph.push(requests, [12.0, 18.0, 15.0, 27.0, 35.0, 31.0, 42.0])

  # Explicit dimensions keep the layout deterministic. Color also paints the
  # background of solid cells, hiding font-cell seams in affected terminals.
  echo graph.render(width = 64, height = 14, useColor = true)
