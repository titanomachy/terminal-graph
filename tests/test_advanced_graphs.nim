import std/[math, sequtils, strutils, unittest]

import terminal_graphs

suite "multiplot layouts":
  test "aligns plots side by side and in grids":
    check multiplot(["a\nbb", "xxx\ny"], horizontalGap = 2) ==
      "a   xxx\nbb  y"
    check multiplot(["one", "two", "three"], columns = 2,
      verticalGap = 1) == "one     two\n\nthree"

  test "uses shared widths for logical columns across every row":
    check multiplot(["a", "x", "long", "y"], columns = 2,
      horizontalGap = 1, verticalGap = 0) == "a    x\nlong y"

  test "auto-fits rendered plots to an explicit width":
    var options = initMultiplotOptions()
    options.availableWidth = 12
    options.minimumCellWidth = 1
    options.horizontalGap = 2
    options.verticalGap = 0
    options.expandColumns = false
    check multiplot(["aaaaaa", "bbbb", "cc"], options) ==
      "aaaaaa  bbbb\ncc"

    options.availableWidth = 11
    check multiplot(["aaaaaa", "bbbb", "cc"], options) ==
      "aaaaaa\nbbbb\ncc"

  test "supports order-independent CSS-style breakpoints":
    var options = initMultiplotOptions()
    options.availableWidth = 90
    options.minimumCellWidth = 1
    options.horizontalGap = 1
    options.verticalGap = 0
    options.expandColumns = false
    options.breakpoints = @[
      multiplotBreakpoint(120, 3),
      multiplotBreakpoint(0, 1),
      multiplotBreakpoint(80, 2)
    ]
    check multiplot(["a", "b", "c"], options) == "a b\nc"
    options.availableWidth = 70
    check multiplot(["a", "b", "c"], options) == "a\nb\nc"

  test "supports horizontal and vertical cell alignment":
    var horizontal = initMultiplotOptions()
    horizontal.columns = fixedColumns(2)
    horizontal.availableWidth = 12
    horizontal.minimumCellWidth = 1
    horizontal.horizontalGap = 2
    horizontal.verticalGap = 0
    horizontal.horizontalAlignment = mhaCenter
    check multiplot(["a", "b"], horizontal) == "  a      b"
    horizontal.horizontalAlignment = mhaRight
    check multiplot(["a", "b"], horizontal) == "    a      b"

    var vertical = initMultiplotOptions()
    vertical.columns = fixedColumns(2)
    vertical.availableWidth = 2
    vertical.minimumCellWidth = 1
    vertical.horizontalGap = 1
    vertical.verticalGap = 0
    vertical.verticalAlignment = mvaBottom
    vertical.expandColumns = false
    check multiplot(["a", "b\nc"], vertical) == "a\nb\nc"
    vertical.constrainToAvailableWidth = false
    check multiplot(["a", "b\nc"], vertical) == "  b\na c"

  test "aligns ragged plots as blocks instead of shifting each line":
    var centered = initMultiplotOptions()
    centered.columns = fixedColumns(1)
    centered.availableWidth = 5
    centered.minimumCellWidth = 1
    centered.horizontalAlignment = mhaCenter
    check multiplot(["xx\nx"], centered) == " xx\n x"

    centered.horizontalAlignment = mhaRight
    check multiplot(["xx\nx"], centered) == "   xx\n   x"

  test "never emits over-wide lines from a constrained responsive grid":
    var options = initMultiplotOptions()
    options.columns = fixedColumns(3)
    options.availableWidth = 9
    options.minimumCellWidth = 6
    options.horizontalGap = 2
    options.verticalGap = 0
    options.expandColumns = false

    let rendered = multiplot([
      "first plot", "second plot", "third plot"
    ], options)
    check rendered.splitLines().allIt(it.displayWidth <= 9)
    check stripAnsi(rendered) == "first plo\nsecond pl\nthird plo"

  test "closes multiline ANSI styles at grid cell boundaries":
    let styledPlot = ansiCode(colorBrightRed) & "a\nb" & termClear
    var options = initMultiplotOptions()
    options.columns = fixedColumns(2)
    options.availableWidth = 5
    options.minimumCellWidth = 1
    options.horizontalGap = 1
    options.expandColumns = false

    let lines = multiplot([styledPlot, "x\ny"], options).splitLines()
    check lines.len == 2
    check lines[0].endsWith(termClear & " x")
    check lines[1].startsWith(ansiCode(colorBrightRed) & "b")
    check lines[1].contains(termClear & " y")

  test "assigns widths before deferred responsive rendering":
    var assignedWidths: seq[int]
    let
      renderA: MultiplotRenderer = proc(width: int): string =
        assignedWidths.add width
        repeat('a', width)
      renderB: MultiplotRenderer = proc(width: int): string =
        assignedWidths.add width
        repeat('b', width)
      renderC: MultiplotRenderer = proc(width: int): string =
        assignedWidths.add width
        repeat('c', width)
      renderers = @[renderA, renderB, renderC]
    var options = initMultiplotOptions()
    options.availableWidth = 21
    options.minimumCellWidth = 10
    options.horizontalGap = 1
    options.verticalGap = 0
    let rendered = multiplotResponsive(renderers, options)
    check assignedWidths == @[10, 10, 10]
    check rendered.splitLines.len == 2
    check rendered.splitLines[0].displayWidth == 21
    check rendered.splitLines[1].displayWidth == 10

  test "reduces deferred fixed columns before violating minimum widths":
    var assignedWidths: seq[int]
    let renderer: MultiplotRenderer = proc(width: int): string =
      assignedWidths.add width
      repeat('x', width)
    var options = initMultiplotOptions()
    options.columns = fixedColumns(3)
    options.availableWidth = 12
    options.minimumCellWidth = 8
    options.horizontalGap = 2
    options.verticalGap = 0

    let rendered = multiplotResponsive(
      [renderer, renderer, renderer], options)
    check assignedWidths == @[12, 12, 12]
    check rendered.splitLines.len == 3
    check rendered.splitLines.allIt(it.displayWidth <= 12)

  test "ignores ANSI sequences when measuring colored plots":
    let colored = ansiCode(colorBrightRed) & "x" & termClear
    let combined = multiplot([colored, "yy"], horizontalGap = 2)
    check stripAnsi(combined) == "x  yy"
    check ansiCode(colorBrightRed) in combined

  test "validates layout dimensions":
    expect ValueError:
      discard multiplot(["x"], columns = -1)
    expect ValueError:
      discard multiplot(["x"], horizontalGap = -1)
    expect ValueError:
      discard fixedColumns(0)
    expect ValueError:
      discard multiplotBreakpoint(-1, 1)
    expect ValueError:
      discard multiplotBreakpoint(0, 0)

    var options = initMultiplotOptions()
    options.minimumCellWidth = 0
    expect ValueError:
      discard multiplot(["x"], options)
    options = initMultiplotOptions()
    options.availableWidth = -1
    expect ValueError:
      discard multiplot(["x"], options)
    options = initMultiplotOptions()
    options.availableWidth = 40
    let missing: MultiplotRenderer = nil
    expect ValueError:
      discard multiplotResponsive([missing], options)
    options.breakpoints = @[
      multiplotBreakpoint(0, 1),
      multiplotBreakpoint(0, 2)
    ]
    expect ValueError:
      discard multiplot(["x"], options)

suite "2D surface and contour plots":
  setup:
    var plain = initSurfacePlotOptions()
    plain.useColor = false
    plain.showScale = false

  test "renders matrices and flat row-major data":
    let matrix = @[
      @[0.0, 1.0, 2.0],
      @[1.0, 2.0, 3.0],
      @[2.0, 3.0, 4.0],
      @[3.0, 4.0, 5.0]
    ]
    let surface = plotSurface(matrix, plain)
    check surface.splitLines.len == 2
    check surface.splitLines[0].displayWidth == 3

    let contour = plotContour(
      @[0.0, 1.0, 2.0, 1.0, 2.0, 3.0],
      columns = 3,
      options = plain
    )
    check contour.splitLines.len == 2
    check contour.splitLines[0].displayWidth == 3

  test "uses foreground and background ANSI colors for high resolution":
    var colored = initSurfacePlotOptions()
    colored.showScale = false
    colored.caption = "surface"
    let surface = plotSurface(@[
      @[0.0, 1.0],
      @[2.0, 3.0]
    ], colored)
    check surface.startsWith("surface\n")
    check "\e[38;5;" in surface
    check "\e[48;5;" in surface
    check "▀" in surface

    let contour = plotContour(@[
      @[0.0, 1.0],
      @[2.0, 3.0]
    ], colored)
    check "\e[48;5;" in contour
    check "█" in stripAnsi(contour)

  test "resamples and shows a scale":
    var options = initSurfacePlotOptions()
    options.useColor = false
    options.width = 6
    options.height = 4
    options.caption = "field"
    options.setSurfaceRange(-1.0, 4.0)
    let contour = plotContour(@[
      @[0.0, 1.0],
      @[2.0, 3.0]
    ], options)
    check contour.startsWith("field\n")
    check contour.splitLines.len == 6 # caption + 4 rows + scale
    check "-1" in contour
    check "4" in contour

  test "supports NaN holes and validates malformed surfaces":
    check plotSurface(@[
      @[0.0, NaN],
      @[1.0, 2.0]
    ], plain).len > 0
    expect ValueError:
      discard plotSurface(@[@[1.0], @[1.0, 2.0]], plain)
    expect ValueError:
      discard plotContour(@[@[NaN]], plain)
    expect ValueError:
      discard plot2D([1.0, 2.0, 3.0], columns = 2, options = plain)

suite "colored live line graphs":
  test "retains bounded samples and renders through plotMany":
    var config = initAsciiGraphConfig()
    config.height = 4
    config.width = 8
    config.caption = "live latency"
    config.seriesColors = @[colorBrightCyan, colorBrightYellow]
    config.seriesLegends = @["API", "worker"]

    var graph = initLiveLineGraph(
      seriesCount = 2,
      maxSamples = 3,
      config = config
    )
    graph.push(0, [1.0, 2.0, 3.0, 4.0])
    graph.push(1, [4.0, 3.0, 2.0])

    check graph.sampleCount(0) == 3
    check graph.sampleCount(1) == 3
    check not graph.isActive
    let frame = graph.renderFrame()
    check "live latency" in frame
    check ansiCode(colorBrightCyan) in frame
    check ansiCode(colorBrightYellow) in frame
    check "■" in frame

    expect ValueError:
      graph.draw()

  test "supports empty and partially populated streaming state":
    var graph = initLiveLineGraph(seriesCount = 2)
    check graph.renderFrame() == ""
    graph.push(1, 2.0)
    check graph.renderFrame().len > 0
    graph.clear()
    check graph.renderFrame() == ""

suite "terminal styling façade":
  test "exports styling helpers from terminal_graphs":
    check red("alert").startsWith(termRed)
    check red("alert").endsWith(termClear)
