## A compact streaming dashboard made from reusable sparkline renderings.
## Stop it with Ctrl+C.

when isMainModule:
  import std/[math, os, random, strutils, terminal]

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
    previousFrameLines = 0

  echo ""
  hideCursor()
  try:
    while true:
      step += 0.06
      cpuHistory.pushSample(
        clamp(52.0 + sin(step) * 28.0 + rand(8.0) - 4.0, 0.0, 100.0)
      )
      memoryHistory.pushSample(
        clamp(64.0 + cos(step * 0.45) * 12.0 + rand(3.0), 0.0, 100.0)
      )

      let frame = cyan("CPU     ", sparkline(cpuHistory),
          "  ", cpuHistory[^1].int, "%") & '\n' &
        yellow("Memory  ", sparkline(memoryHistory),
          "  ", memoryHistory[^1].int, "%")
      stdout.write frame.replaceLinesSequence(previousFrameLines)
      stdout.flushFile()

      previousFrameLines = frame.splitLines().len
      sleep(33)
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    resetAttributes()
    showCursor()
