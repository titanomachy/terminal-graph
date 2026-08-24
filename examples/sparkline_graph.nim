## Compact sparklines embedded in ordinary terminal output.

when isMainModule:
  import std/math

  import ../src/terminal_graph

  let
    responseTimes = [18, 21, 19, 26, 34, 31, 45, 38, 29, 24]
    temperatures = [-2.0, -0.5, 1.0, 4.5, 7.0, 5.5, 3.0, 0.0]
    steadyState = [5.0, 5.0, 5.0, 5.0]
    interrupted = [0.0, 2.0, NaN, 6.0, 8.0]

  echo "Response time  ", sparkline(responseTimes), "  ms"
  echo "Temperature    ", sparkline(temperatures), "  °C"
  echo "Steady state   ", sparkline(steadyState)
  echo "With a gap     ", sparkline(interrupted)

  var sharedScale = initSparklineOptions()
  sharedScale.setSparklineRange(0.0, 100.0)
  echo "Shared 0–100   ", sparkline([10, 25, 40, 75, 100], sharedScale)

  var fire = sharedScale
  fire.useColor = true
  echo "Fire gradient  ", sparkline([10, 25, 40, 75, 100], fire)
