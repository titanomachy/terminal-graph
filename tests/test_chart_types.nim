import std/[math, options, strutils, unittest]

import terminal_graphs

suite "horizontal bar graphs":
  test "draws positive and negative values around zero":
    const BarWidth = 9
    var options = initBarGraphOptions()
    options.width = BarWidth
    options.useColor = false
    options.showValues = false

    let lines = plotBars(["loss", "gain"], [-5.0, 5.0], options).splitLines()
    check lines.len == 2
    check lines[0].find("█") < lines[0].find("│")
    check lines[1].find("█") > lines[1].find("│")
    check lines[0].displayWidth == 4 + 1 + BarWidth
    check lines[1].displayWidth == 4 + 1 + BarWidth

  test "supports grouped and stacked colored series":
    let values = @[
      @[4.0, -2.0],
      @[2.0, 3.0]
    ]
    var options = initBarGraphOptions()
    options.width = 15
    options.seriesLegends = @["actual", "forecast"]
    options.seriesColors = @[colorBrightCyan, colorBrightYellow]

    let grouped = plotBars(["A", "B"], values, options)
    check grouped.splitLines.len == 5 # four bars and one legend
    check "A / actual" in grouped
    check ansiCode(colorBrightCyan) in grouped
    check ansiCode(colorBrightYellow) in grouped

    options.mode = bmStacked
    let stacked = plotBars(["A", "B"], values, options)
    check stacked.splitLines.len == 3 # two bars and one legend
    check "actual=4.00" in stacked
    check "forecast=2.00" in stacked

  test "supports fixed zero-containing ranges and integer data":
    var options = initBarGraphOptions()
    options.useColor = false
    options.showValues = false
    options.width = 11
    options.setBarRange(-10.0, 10.0)
    let rendered = plotBars(["low", "high"], [-10, 10], options)
    check rendered.splitLines.len == 2
    options.clearBarRange()
    check options.minimum.isNone
    check options.maximum.isNone

  test "validates dimensions, shapes, values, legends, and glyphs":
    var options = initBarGraphOptions()
    options.width = 2
    expect ValueError:
      discard plotBars(["A"], [1.0], options)

    options = initBarGraphOptions()
    expect ValueError:
      discard plotBars(["A", "B"], @[@[1.0]], options)
    expect ValueError:
      discard plotBars(["A"], [Inf], options)
    options.seriesLegends = @["one", "two"]
    expect ValueError:
      discard plotBars(["A"], [1.0], options)
    options = initBarGraphOptions()
    options.glyph = "xx"
    expect ValueError:
      discard plotBars(["A"], [1.0], options)
    expect ValueError:
      options.setBarRange(1.0, 2.0)

suite "scatter and irregular XY graphs":
  setup:
    var plain = initXYPlotOptions()
    plain.width = 9
    plain.height = 5
    plain.useColor = false
    plain.showRanges = false

  test "draws zero-crossing axes and unconnected scatter points":
    let rendered = plotScatter([
      xyPoint(-1.0, -1.0),
      xyPoint(1.0, 1.0)
    ], plain)
    let lines = rendered.splitLines()
    check lines.len == 5
    check lines[2] == "────┼────"
    check rendered.count("●") == 2
    check "╱" notin rendered
    check "╲" notin rendered

  test "uses explicit irregular X coordinates and connects supplied order":
    plain.width = 11
    plain.showAxes = false
    plain.includeZero = false
    let points = [
      xyPoint(-10.0, 0.0),
      xyPoint(-8.0, 1.0),
      xyPoint(10.0, 0.0)
    ]
    let scatter = plotScatter(points, plain)
    check scatter.splitLines()[0].startsWith(" ●")

    let connected = plotXY(points, plain)
    check "╱" in connected or "╲" in connected

  test "clips connected lines to fixed viewports":
    plain.setXRange(-1.0, 1.0)
    plain.setYRange(-1.0, 1.0)
    let rendered = plotXY([
      xyPoint(-2.0, 0.5),
      xyPoint(2.0, 0.5)
    ], plain)
    check "─" in rendered
    check "●" notin rendered # both original points are outside the viewport
    plain.clearXRange()
    plain.clearYRange()
    check plain.minimumX.isNone
    check plain.minimumY.isNone

  test "supports multiple colored series and legends":
    var options = initXYPlotOptions()
    options.width = 12
    options.height = 6
    options.showRanges = false
    let rendered = plotScatterMany([
      initXYSeries("alpha", [xyPoint(-1, -1)], colorBrightCyan, marker = "x"),
      initXYSeries("beta", [xyPoint(1, 1)], colorBrightYellow, marker = "o")
    ], options)
    check ansiCode(colorBrightCyan) in rendered
    check ansiCode(colorBrightYellow) in rendered
    check "x alpha" in stripAnsi(rendered)
    check "o beta" in stripAnsi(rendered)

  test "treats NaN as a path break":
    let rendered = plotXY([
      xyPoint(-1.0, -1.0),
      XYPoint(x: NaN, y: NaN),
      xyPoint(1.0, 1.0)
    ], plain)
    check rendered.count("●") == 2
    check "╱" notin rendered
    check "╲" notin rendered

  test "pairs arrays and validates malformed XY input":
    check xyPoints([0, 2, 9], [1.0, 3.0, 4.0]).len == 3
    check plotScatter([0, 2], [1.0, 3.0], plain).len > 0
    expect ValueError:
      discard xyPoints([0, 1], [1.0])
    expect ValueError:
      discard plotScatter([XYPoint(x: Inf, y: 0.0)], plain)
    expect ValueError:
      discard plotScatter([XYPoint(x: NaN, y: NaN)], plain)
    expect ValueError:
      discard plotScatterMany([
        initXYSeries("bad", [xyPoint(0, 0)], marker = "xx")
      ], plain)
    plain.width = 2
    expect ValueError:
      discard plotScatter([xyPoint(0, 0)], plain)
