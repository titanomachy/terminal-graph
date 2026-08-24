import std/[math, options, os, strutils, tempfiles, unittest]

import terminal_graph

suite "static candle charts":
  setup:
    var plain = initCandlePlotOptions()
    plain.width = 9
    plain.height = 7
    plain.useColor = false
    plain.showLabels = false
    plain.setCandleRange(8.0, 15.0)

  test "renders rising falling and unchanged candles":
    let rendered = plotCandles([
      candle(10, 14, 8, 13),
      candle(13, 15, 9, 10),
      candle(11, 12, 10, 11)
    ], plain)
    check rendered.splitLines.len == 8 # seven canvas rows and baseline
    check "█" in rendered
    check "│" in rendered
    check "┃" notin rendered
    check "━" notin rendered
    check '\e' notin rendered
    for line in rendered.splitLines:
      check line.displayWidth == 15

  test "spreads candles across unique columns":
    var options = plain
    options.height = 5
    options.showAxis = false
    options.setCandleRange(0.0, 10.0)
    let rendered = plotCandles([
      candle(5, 5, 5, 5), candle(5, 5, 5, 5), candle(5, 5, 5, 5)
    ], options)
    check rendered.splitLines[2] == "█   █   █"

  test "formats axis values units captions and custom line endings":
    plain.caption = "Daily OHLC"
    plain.unit = "USD"
    plain.lineEnding = "\r\n"
    plain.yAxisValueFormatter = proc(value: float64): string =
      $int(round(value))
    let rendered = plotCandles([candle(10, 14, 8, 13)], plain)
    check rendered.startsWith("Daily OHLC\r\n15 USD")
    check "8 USD" in rendered
    check rendered.count("\r\n") == 8

  test "uses visible automatic bounds and expands flat prices":
    var options = plain
    options.clearCandleRange()
    check plotCandles([candle(100, 105, 95, 102)], options).len > 0
    check plotCandles([candle(5, 5, 5, 5)], options).len > 0

  test "clips candles to a fixed viewport":
    var options = plain
    options.showAxis = false
    let rendered = plotCandles([candle(5, 20, 0, 15)], options)
    check rendered.splitLines.len == options.height
    check rendered.count("█") == options.height

  test "separates labels and prioritizes endpoints":
    var options = plain
    options.width = 17
    options.height = 5
    options.showAxis = false
    options.showLabels = true
    let rendered = plotCandles(
      ["first", "middle", "last"],
      [candle(10, 12, 9, 11), candle(11, 13, 10, 12),
       candle(12, 14, 11, 13)],
      options
    )
    check rendered.splitLines[^1] == "first        last"

    options.width = 5
    let crowded = plotCandles(
      ["first", "last"],
      [candle(10, 12, 9, 11), candle(11, 13, 10, 12)],
      options
    )
    check crowded.splitLines[^1] == "first"

    options.width = 24
    let streaming = plotCandles(
      ["09:30", "09:31", "09:32", "09:33", "09:34", "09:35"],
      [candle(10, 12, 9, 11), candle(11, 13, 10, 12),
       candle(12, 14, 11, 13), candle(13, 15, 12, 14),
       candle(14, 16, 13, 15), candle(15, 17, 14, 16)],
      options
    ).splitLines[^1]
    check streaming == "09:30  09:32       09:35"

  test "uses full-cell backgrounds for every direction color":
    var options = plain
    options.useColor = true
    options.showAxis = false
    let rendered = plotCandles([
      candle(10, 12, 9, 11),
      candle(12, 13, 9, 10),
      candle(10, 11, 9, 10)
    ], options)
    check ansiCode(colorBrightGreen) in rendered
    check ansiCode(colorBrightRed) in rendered
    check ansiCode(colorBrightGreen, cpBackground) in rendered
    check ansiCode(colorBrightRed, cpBackground) in rendered
    check ansiCode(colorBrightYellow) in rendered
    check ansiCode(colorBrightYellow, cpBackground) in rendered
    check rendered.endsWith(termClear) or termClear in rendered

  test "supports custom one-cell glyphs":
    plain.wickGlyph = "!"
    plain.risingGlyph = "+"
    plain.fallingGlyph = "#"
    plain.unchangedGlyph = "="
    let rendered = plotCandles([
      candle(10, 12, 9, 11), candle(12, 13, 9, 10),
      candle(10, 11, 9, 10)
    ], plain)
    check '+' in rendered
    check '#' in rendered
    check '=' in rendered
    check '!' in rendered

  test "validates candles labels dimensions ranges and glyphs":
    expect ValueError:
      discard plotCandles(newSeq[Candle](), plain)
    expect ValueError:
      discard plotCandles([candle(10, 9, 8, 9)], plain)
    expect ValueError:
      discard plotCandles([Candle(open: NaN, high: 2, low: 0, close: 1)], plain)
    expect ValueError:
      discard plotCandles(["one", "two"], [candle(1, 2, 0, 1)], plain)
    expect ValueError:
      discard plotCandles(["bad\nlabel"], [candle(1, 2, 0, 1)], plain)

    var invalid = plain
    invalid.width = 2
    expect ValueError:
      discard plotCandles([candle(1, 2, 0, 1)], invalid)
    invalid = plain
    invalid.width = 3
    expect ValueError:
      discard plotCandles([
        candle(1, 2, 0, 1), candle(1, 2, 0, 1),
        candle(1, 2, 0, 1), candle(1, 2, 0, 1)
      ], invalid)
    invalid = plain
    invalid.wickGlyph = "xx"
    expect ValueError:
      discard plotCandles([candle(1, 2, 0, 1)], invalid)
    invalid = plain
    invalid.minimum = some(0.0)
    invalid.maximum = none(float64)
    expect ValueError:
      discard plotCandles([candle(1, 2, 0, 1)], invalid)
    expect ValueError:
      invalid.setCandleRange(2.0, 1.0)

  test "rejects multiline formatter output":
    plain.yAxisValueFormatter = proc(value: float64): string = "bad\naxis"
    expect ValueError:
      discard plotCandles([candle(10, 12, 9, 11)], plain)

suite "live candle charts":
  proc liveOptions(): CandlePlotOptions =
    result = initCandlePlotOptions()
    result.width = 3
    result.height = 5
    result.useColor = false
    result.showAxis = false
    result.showLabels = false

  test "appends evicts and updates the newest candle":
    let first = candle(10, 12, 9, 11)
    let second = candle(11, 13, 10, 12)
    let third = candle(12, 14, 11, 13)
    let fourth = candle(13, 15, 12, 14)
    var graph = initLiveCandleGraph(
      maxCandles = 3, options = liveOptions())
    graph.push([first, second, third, fourth])
    check graph.candleCount == 3
    check graph.latestCandle.get() == fourth

    let changed = candle(13, 16, 12, 15)
    graph.updateLatest(changed)
    check graph.candleCount == 3
    check graph.latestCandle.get() == changed

  test "retains or replaces the latest label":
    var options = liveOptions()
    options.width = 8
    options.showLabels = true
    var graph = initLiveCandleGraph(options = options)
    graph.push(candle(10, 12, 9, 11), "09:30")
    graph.updateLatest(candle(10, 13, 9, 12))
    check "09:30" in graph.renderFrame()
    graph.updateLatest(candle(10, 14, 9, 13), "09:31")
    check "09:31" in graph.renderFrame()
    check "09:30" notin graph.renderFrame()

  test "validates complete batches before mutation":
    var graph = initLiveCandleGraph(options = liveOptions())
    graph.push(candle(10, 12, 9, 11))
    expect ValueError:
      graph.push([
        candle(11, 13, 10, 12),
        Candle(open: Inf, high: Inf, low: 0, close: 1)
      ])
    check graph.candleCount == 1

    expect ValueError:
      graph.push(["one"], [candle(10, 12, 9, 11),
        candle(11, 13, 10, 12)])
    check graph.candleCount == 1

  test "shows the newest width-limited window":
    var options = liveOptions()
    var graph = initLiveCandleGraph(maxCandles = 5, options = options)
    let values = [
      candle(1, 2, 0, 1), candle(2, 3, 1, 2),
      candle(100, 105, 95, 102), candle(102, 108, 100, 107),
      candle(107, 112, 104, 110)
    ]
    graph.push(values)
    check graph.renderFrame() == plotCandles(values[2 .. 4], options)

  test "supports ranges clearing and empty state":
    var graph = initLiveCandleGraph(options = liveOptions())
    check graph.renderFrame() == ""
    check graph.latestCandle.isNone
    expect ValueError:
      graph.updateLatest(candle(1, 2, 0, 1))
    graph.setRange(0.0, 20.0)
    check graph.options.minimum.get() == 0.0
    graph.clearRange()
    check graph.options.minimum.isNone
    graph.push(candle(10, 12, 9, 11))
    graph.clear()
    check graph.candleCount == 0

  test "composes side by side without terminal output":
    var graph = initLiveCandleGraph(options = liveOptions())
    graph.push(candle(10, 12, 9, 11))
    check not graph.isActive
    let combined = multiplot([graph.renderFrame(), graph.renderFrame()],
      columns = 2, horizontalGap = 2)
    check combined.splitLines.len == liveOptions().height
    expect ValueError:
      graph.draw()

  test "validates construction and streaming values":
    expect ValueError:
      discard initLiveCandleGraph(maxCandles = 0)
    expect ValueError:
      discard initLiveCandleGraph(output = nil)
    var graph = initLiveCandleGraph(options = liveOptions())
    expect ValueError:
      graph.push(Candle(open: NaN, high: 2, low: 0, close: 1))
    expect ValueError:
      graph.push(candle(1, 2, 0, 1), "bad\nlabel")

  when defined(posix):
    test "redraws and restores live terminal state":
      let (output, path) = createTempFile(
        "terminal_graph_candles_", ".txt")
      var outputOpen = true
      defer:
        if outputOpen:
          output.close()
        if path.fileExists:
          path.removeFile()

      var graph = initLiveCandleGraph(
        options = liveOptions(), output = output)
      graph.push(candle(10, 12, 9, 11))
      graph.startLive(clearScreen = false)
      graph.startLive(clearScreen = false)
      check graph.isActive
      graph.draw()
      graph.updateLatest(candle(10, 13, 9, 12))
      graph.draw()
      graph.stopLive()
      graph.stopLive()
      check not graph.isActive

      output.close()
      outputOpen = false
      let emitted = path.readFile()
      check emitted.startsWith("\e[?25l")
      check "\e[?2026h" in emitted
      check emitted.endsWith("\e[0m\e[?25h")
