## Compact sparklines embedded in ordinary terminal output.
# Run with: nim r --path:src examples/sparkline_graph.nim

when isMainModule:
  import std/math

  import ../src/terminal_graph

  let
    responseTimes = [18, 21, 19, 26, 34, 31, 45, 38, 29, 24]
    temperatures = [-2.0, -0.5, 1.0, 4.5, 7.0, 5.5, 3.0, 0.0]
    steadyState = [5.0, 5.0, 5.0, 5.0]
    interrupted = [0.0, 2.0, NaN, 6.0, 8.0]

  var colors = initSparklineOptions()
  colors.useColor = true
  colors.palette = @ModernGraphGradient

  echo ""
  echo "Response time    ", sparkline(responseTimes, colors), "  ms"
  echo ""
  echo "Temperature      ", sparkline(temperatures, colors), "  °C"
  echo ""
  echo "Steady state     ", sparkline(steadyState)
  echo ""
  echo "With a gap       ", sparkline(interrupted)
  echo ""

  var sharedScale = initSparklineOptions()
  sharedScale.setSparklineRange(0.0, 100.0)
  echo "Shared 0–100     ", sparkline([10, 25, 40, 75, 100], sharedScale)
  echo ""

  var modernGradient = sharedScale
  modernGradient.useColor = true
  modernGradient.palette = @[
    hexColor("#22D3EE"), hexColor("#39C8F0"), hexColor("#4FBCF2"),
    hexColor("#66B1F4"), hexColor("#7CA6F6"), hexColor("#939BF8"),
    hexColor("#A98FFA"), hexColor("#C084FC")
  ]
  echo "Modern gradient  ", sparkline(
    [10, 25, 40, 75, 100], modernGradient)
