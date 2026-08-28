## Stream completed candles and update the newest forming candle. Stop with Ctrl+C.
# Run with: nim r --path:src examples/streaming_candle_graph.nim

when isMainModule:
  import std/[atomics, os, random, strformat]

  import ../src/terminal_graph

  randomize()

  var stopRequested: Atomic[bool]

  proc requestStop() {.noconv.} =
    ## A signal handler may only perform signal-safe work.
    stopRequested.store(true, moRelaxed)

  var options = initCandlePlotOptions()
  options.width = 60
  options.height = 14
  options.caption = "Live OHLC"
  options.unit = "USD"
  options.risingColor = ModernGraphPalette.green
  options.fallingColor = ModernGraphPalette.red
  options.unchangedColor = ModernGraphPalette.yellow
  options.axisColor = ModernGraphPalette.brightBlack
  options.labelColor = ModernGraphPalette.white

  # Keep one blank column on either side of each candle so the streaming
  # history remains visually distinct instead of becoming a solid ribbon.
  var graph = initLiveCandleGraph(
    maxCandles = options.width div 3,
    options = options
  )
  graph.push(
    ["09:30", "09:31", "09:32"],
    [
      candle(100.0, 102.0, 99.0, 101.0),
      candle(101.0, 103.0, 100.0, 102.0),
      candle(102.0, 104.0, 101.0, 103.0)
    ]
  )

  var
    hour = 9
    minute = 33
    ticksInPeriod = 0
    current = candle(103.0, 103.0, 103.0, 103.0)
  graph.push(current, &"{hour:02}:{minute:02}")

  stopRequested.store(false, moRelaxed)
  setControlCHook(requestStop)
  try:
    graph.startLive()
    while not stopRequested.load(moRelaxed):
      let nextClose = max(current.close + rand(1.2) - 0.6, 0.01)
      current.high = max(current.high, nextClose)
      current.low = min(current.low, nextClose)
      current.close = nextClose
      graph.updateLatest(current)
      graph.draw()
      sleep(100)

      inc ticksInPeriod
      if ticksInPeriod == 10:
        ticksInPeriod = 0
        inc minute
        if minute == 60:
          minute = 0
          hour = (hour + 1) mod 24
        let nextOpen = current.close
        current = candle(nextOpen, nextOpen, nextOpen, nextOpen)
        graph.push(current, &"{hour:02}:{minute:02}")
  except IOError:
    discard
  finally:
    try:
      graph.stopLive()
    except IOError:
      discard
    finally:
      when declared(unsetControlCHook):
        unsetControlCHook()
