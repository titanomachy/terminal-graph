import std/[math, options, os, strutils, tempfiles, unittest]

import terminal_graph

suite "terminal_graph data management":
  test "creates plotters and series":
    var plotter = initPlotter("CPU", unit = "%", maxSamples = 20)

    check plotter.title == "CPU"
    check plotter.unit == "%"
    check plotter.maxSamples == 20
    check plotter.seriesCount == 0

    let cpu = plotter.addSeries("usage")
    check cpu == 0
    check plotter.seriesCount == 1
    check plotter.sampleCount(cpu) == 0
    check plotter.latest(cpu).isNone

  test "rejects invalid construction and series input":
    expect ValueError:
      discard initPlotter("bad", maxSamples = 0)

    var plotter = initPlotter("markers")
    expect ValueError:
      discard plotter.addSeries("empty", marker = "")
    expect ValueError:
      discard plotter.addSeries("wide", marker = "ab")
    expect IndexDefect:
      plotter.push(0, 1.0)

  test "retains only the newest configured samples":
    var plotter = initPlotter("bounded", maxSamples = 3)
    let series = plotter.addSeries("values")

    plotter.push(series, [1.0, 2.0, 3.0, 4.0])

    check plotter.sampleCount(series) == 3
    check plotter.samples(series) == @[2.0, 3.0, 4.0]
    check plotter.latest(series).get() == 4.0

    plotter.setMaxSamples(2)
    check plotter.maxSamples == 2
    check plotter.samples(series) == @[3.0, 4.0]

  test "validates a batch before appending any of it":
    var plotter = initPlotter("finite values")
    let series = plotter.addSeries("values")
    plotter.push(series, 1.0)

    expect ValueError:
      plotter.push(series, [2.0, NaN])

    check plotter.samples(series) == @[1.0]

  test "computes statistics and clears samples":
    var plotter = initPlotter("stats")
    let series = plotter.addSeries("values")
    plotter.push(series, [2.0, 4.0, 9.0])

    let summary = plotter.statistics(series).get()
    check summary.current == 9.0
    check summary.minimum == 2.0
    check summary.maximum == 9.0
    check summary.average == 5.0
    check summary.sampleCount == 3

    plotter.clear(series)
    check plotter.statistics(series).isNone

suite "terminal_graph ranges":
  test "uses sensible automatic bounds":
    var emptyPlotter = initPlotter("empty")
    check emptyPlotter.valueRange == (minimum: 0.0, maximum: 1.0)

    let series = emptyPlotter.addSeries("flat")
    emptyPlotter.push(series, 5.0)
    check emptyPlotter.valueRange == (minimum: 4.0, maximum: 6.0)

    emptyPlotter.push(series, -2.0)
    check emptyPlotter.valueRange == (minimum: -2.0, maximum: 5.0)

  test "supports validated fixed bounds":
    var plotter = initPlotter("fixed")
    plotter.setRange(-10.0, 10.0)
    check plotter.valueRange == (minimum: -10.0, maximum: 10.0)

    plotter.clearRange()
    check plotter.valueRange == (minimum: 0.0, maximum: 1.0)

    expect ValueError:
      plotter.setRange(1.0, 1.0)
    expect ValueError:
      plotter.setRange(Inf, 2.0)

suite "terminal_graph rendering":
  test "renders deterministic plain-text frames":
    var plotter = initStaticGraph("Latency", unit = "ms")
    let line = plotter.addSeries("p95", marker = "x")
    plotter.setRange(0.0, 10.0)
    plotter.push(line, [0.0, 5.0, 10.0])

    let frame = plotter.render(width = 40, height = 10, useColor = false)

    check frame.startsWith("Latency (ms)\n")
    check "p95 [x] cur 10.00" in frame
    check '\e' notin frame
    check frame.count("┤") == 6
    check frame.splitLines.len == 10
    check 'x' in frame

  test "covers colored full-block cell seams with matching backgrounds":
    var plotter = initStaticGraph("Filled")
    let fill = plotter.addSeries(
      "values", style = psFill, marker = "▄")
    plotter.setRange(0.0, 10.0)
    plotter.push(fill, [5.0, 8.0])

    let frame = plotter.render(width = 30, height = 10, useColor = true)

    check "\e[36m" in frame
    check "\e[46m" in frame
    check "█" in stripAnsi(frame)

  test "can omit statistics and preserves off-screen history":
    var plotter = initPlotter("History", maxSamples = 100)
    let line = plotter.addSeries("values", marker = "+")
    for value in 0 ..< 50:
      plotter.push(line, float64(value))

    let frame = plotter.render(
      width = MinimumRenderWidth,
      height = MinimumRenderHeight,
      useColor = false,
      showStats = false
    )

    check frame.splitLines.len == MinimumRenderHeight
    check "cur " notin frame
    check plotter.sampleCount(line) == 50

  test "validates explicit dimensions":
    let plotter = initPlotter("small")
    expect ValueError:
      discard plotter.render(width = MinimumRenderWidth - 1)
    expect ValueError:
      discard plotter.render(height = MinimumRenderHeight - 1)

suite "terminal_graph sparklines":
  test "renders integer and floating-point sequences":
    check sparkline([0, 1, 2, 3, 4, 5, 6, 7]) == "▁▂▃▄▅▆▇█"
    check sparkline([2.5, 2.5, 2.5]) == "▅▅▅"
    check sparkline([0.0, 0.0, 0.0]) == "▁▁▁"

  test "renders NaN gaps and rejects infinity":
    check sparkline(newSeq[float64]()) == ""
    check sparkline([0.0, NaN, 10.0]) == "▁ █"
    check sparkline([NaN, NaN]) == "  "
    expect ValueError:
      discard sparkline([1.0, Inf])

  test "supports fixed and independent scale bounds":
    var options = initSparklineOptions()
    options.setSparklineRange(0.0, 10.0)
    check sparkline([-5.0, 0.0, 5.0, 10.0, 15.0], options) == "▁▁▅██"

    options.clearSparklineRange()
    options.setSparklineMinimum(0.0)
    check sparkline([5.0, 10.0], options) == "▅█"
    options.clearSparklineMinimum()
    check options.minimum.isNone

    options = initSparklineOptions()
    options.setSparklineMaximum(10.0)
    check sparkline([0.0, 5.0], options) == "▁▅"
    options.clearSparklineMaximum()
    check options.maximum.isNone

  test "supports fire and custom palettes without changing display width":
    var options = initSparklineOptions()
    options.useColor = true
    let fire = sparkline([0, 1, 2, 3, 4, 5, 6, 7], options)
    check stripAnsi(fire) == "▁▂▃▄▅▆▇█"
    check ansiCode(FireSparklinePalette[0]) in fire
    check ansiCode(FireSparklinePalette[^1]) in fire
    check fire.endsWith(termClear)

    options.palette = @[colorBrightCyan, colorBrightRed]
    let custom = sparkline([0, 1], options)
    check ansiCode(colorBrightCyan) in custom
    check ansiCode(colorBrightRed) in custom

  test "supports custom ticks, gaps, and constant behavior":
    var options = initSparklineOptions()
    options.ticks = @[".", "o", "O"]
    options.gapGlyph = "?"
    options.setSparklineRange(0.0, 10.0)
    check sparkline([0.0, NaN, 5.0, 10.0], options) == ".?oO"

    options = initSparklineOptions()
    options.constantMode = scmLowest
    check sparkline([5.0, 5.0], options) == "▁▁"

  test "validates sparkline options":
    var options = initSparklineOptions()
    options.ticks = @["x"]
    expect ValueError:
      discard sparkline([1.0], options)
    options = initSparklineOptions()
    options.gapGlyph = "gap"
    expect ValueError:
      discard sparkline([1.0], options)
    expect ValueError:
      options.setSparklineRange(2.0, 1.0)

suite "terminal_graph live display":
  test "builds deterministic frames without changing terminal state":
    var graph = initLiveGraph(
      "Live requests",
      unit = "req/s",
      width = 40,
      height = 10,
      useColor = false
    )
    let requests = graph.addSeries("requests", marker = "x")
    graph.push(requests, [3.0, 7.0, 5.0])

    check not graph.isActive
    check graph.plotter.sampleCount(requests) == 3
    check graph.renderFrame().startsWith("Live requests (req/s)\n")

    expect ValueError:
      graph.draw()

  when defined(posix):
    test "full-screen dashboards redraw and restore terminal state":
      let (output, path) = createTempFile(
        "terminal_graph_dashboard_", ".txt")
      var outputOpen = true
      defer:
        if outputOpen:
          output.close()
        if path.fileExists:
          path.removeFile()

      var dashboard = initLiveDashboard(
        alternateScreen = false, output = output)
      check not dashboard.isActive
      expect ValueError:
        dashboard.draw("not started")

      dashboard.startLive()
      dashboard.startLive() # Starting twice is intentionally idempotent.
      check dashboard.isActive
      dashboard.draw("first row\nsecond row")
      dashboard.draw("responsive frame")
      dashboard.draw("")
      dashboard.stopLive()
      dashboard.stopLive() # Stopping twice is intentionally idempotent.
      check not dashboard.isActive
      expect ValueError:
        dashboard.draw("already stopped")

      output.close()
      outputOpen = false
      let emitted = path.readFile()
      check emitted.startsWith("\e[2J\e[H\e[?25l")
      check "\e[?2026h\e[Hfirst row\e[K\r\nsecond row\e[J\e[?2026l" in
        emitted
      check "\e[Hresponsive frame\e[J" in emitted
      check "\e[?2026h\e[H\e[J\e[?2026l" in emitted
      check emitted.count("\e[?2026h") == 3
      check emitted.count("\e[?2026l") == 4
      check "\e[2K" notin emitted
      check emitted.endsWith("\e[0m\e[?25h")

  test "rejects a missing dashboard output":
    expect ValueError:
      discard initLiveDashboard(output = nil)
