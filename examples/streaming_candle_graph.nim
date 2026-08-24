## Stream completed candles and update the newest forming candle. Stop with Ctrl+C.

when isMainModule:
  import std/[os, random, strformat]

  import ../src/terminal_graph

  randomize()

  var options = initCandlePlotOptions()
  options.width = 60
  options.height = 14
  options.caption = "Live OHLC"
  options.unit = "USD"

  var graph = initLiveCandleGraph(maxCandles = 80, options = options)
  graph.push(
    ["09:30", "09:31", "09:32"],
    [
      candle(100.0, 102.0, 99.0, 101.0),
      candle(101.0, 103.0, 100.0, 102.0),
      candle(102.0, 104.0, 101.0, 103.0)
    ]
  )

  var
    minute = 33
    ticksInPeriod = 0
    current = candle(103.0, 103.0, 103.0, 103.0)
  graph.push(current, &"09:{minute:02}")

  graph.startLive()
  try:
    while true:
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
        let nextOpen = current.close
        current = candle(nextOpen, nextOpen, nextOpen, nextOpen)
        graph.push(current, &"09:{minute:02}")
  except IOError:
    discard
  finally:
    graph.stopLive()
