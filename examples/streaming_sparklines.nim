## A compact streaming dashboard made from reusable sparkline renderings.
## Stop it with Ctrl+C.

when isMainModule:
  import std/[atomics, math, os, random]

  import ../src/terminal_graphs

  const HistoryLength = 36

  proc pushSample(history: var seq[float64]; value: float64) =
    history.add value
    if history.len > HistoryLength:
      history.delete(0)

  randomize()

  var stopRequested: Atomic[bool]

  proc requestStop() {.noconv.} =
    ## A signal handler may only perform signal-safe work.
    stopRequested.store(true)

  var
    cpuHistory: seq[float64]
    memoryHistory: seq[float64]
    step = 0.0
    dashboard = initLiveDashboard()

  dashboard.startLive()
  setControlCHook(requestStop)
  try:
    while not stopRequested.load():
      step += 0.06
      cpuHistory.pushSample(
        clamp(52.0 + sin(step) * 28.0 + rand(8.0) - 4.0, 0.0, 100.0)
      )
      memoryHistory.pushSample(
        clamp(64.0 + cos(step * 0.45) * 12.0 + rand(3.0), 0.0, 100.0)
      )

      # Keep one blank row above the dashboard for a clean video crop.
      let frame = "\n" & cyan("CPU     ", sparkline(cpuHistory),
          "  ", cpuHistory[^1].int, "%") & '\n' &
        yellow("Memory  ", sparkline(memoryHistory),
          "  ", memoryHistory[^1].int, "%")
      dashboard.draw(frame)

      sleep(33)
  except IOError:
    # A closed output pipe is a normal way for a terminal program to stop.
    discard
  finally:
    when declared(unsetControlCHook):
      unsetControlCHook()
    dashboard.stopLive()
