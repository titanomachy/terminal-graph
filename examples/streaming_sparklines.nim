## A compact streaming dashboard made from reusable sparkline renderings.
## Stop it with Ctrl+C.

when isMainModule:
  import std/[math, os, random, terminal]

  import ../src/terminal_graphs

  const HistoryLength = 36

  proc pushSample(history: var seq[float64]; value: float64) =
    history.add value
    if history.len > HistoryLength:
      history.delete(0)

  randomize()

  var
    cpuHistory: seq[float64]
    memoryHistory: seq[float64]
    step = 0.0
    hasPreviousFrame = false

  hideCursor()
  try:
    while true:
      step += 0.18
      cpuHistory.pushSample(
        clamp(52.0 + sin(step) * 28.0 + rand(8.0) - 4.0, 0.0, 100.0)
      )
      memoryHistory.pushSample(
        clamp(64.0 + cos(step * 0.45) * 12.0 + rand(3.0), 0.0, 100.0)
      )

      if hasPreviousFrame:
        stdout.write clearLinesSequence(2)

      stdout.write cyan("CPU     ", sparkline(cpuHistory),
        "  ", cpuHistory[^1].int, "%")
      stdout.write '\n'
      stdout.write yellow("Memory  ", sparkline(memoryHistory),
        "  ", memoryHistory[^1].int, "%")
      stdout.write '\n'
      stdout.flushFile()

      hasPreviousFrame = true
      sleep(100)
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    resetAttributes()
    showCursor()
