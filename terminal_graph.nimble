# Package

version       = "0.1.0"
author        = "titanomachy"
description   = "Pure-Nim terminal bar, candle, line, XY, live, surface, and sparkline graphs"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
requires "terminal_style >= 0.1.1"

task test, "Run the terminal graph test suite":
  exec "nim r --path:src tests/test_terminal_graph.nim"
  exec "nim r --path:src tests/test_line_graphs.nim"
  exec "nim r --path:src tests/test_advanced_graphs.nim"
  exec "nim r --path:src tests/test_chart_types.nim"
  exec "nim r --path:src tests/test_candle_graphs.nim"

task examples, "Check that all examples compile":
  exec "nim check examples/all_graphs.nim"
  exec "nim check examples/candle_graph.nim"
  exec "nim check examples/streaming_candle_graph.nim"
  exec "nim check examples/multiplot_graph.nim"
  exec "nim check examples/streaming_multiplot_graph.nim"
  exec "nim check examples/bar_graph.nim"
  exec "nim check examples/xy_graph.nim"
  exec "nim check examples/sparkline_graph.nim"
  exec "nim check examples/streaming_sparklines.nim"
  exec "nim check examples/static_graph.nim"
  exec "nim check examples/live_graph.nim"
  exec "nim check examples/line_graph.nim"
  exec "nim check examples/advanced_graphs.nim"
  exec "nim check examples/streaming_line_graph.nim"

task docs, "Generate API documentation":
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/bar_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/candle_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/line_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/live_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/multiplot_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/sparkline_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/static_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/surface_graphs.nim"
  exec "nim doc --outdir:htmldocs --path:src src/terminal_graph/xy_graphs.nim"
