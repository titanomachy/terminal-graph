import std/[math, strformat, strutils, unittest]

import terminal_graphs

suite "ASCII line graphs":
  test "plots one series with asciigraph-compatible connectors":
    let graph = plot([3, 4, 9, 6, 2, 4, 5, 8, 5, 10, 2, 7, 2, 5, 6])
    check graph == """ 10.00 ┤        ╭╮
  9.00 ┤ ╭╮     ││
  8.00 ┤ ││   ╭╮││
  7.00 ┤ ││   ││││╭╮
  6.00 ┤ │╰╮  ││││││ ╭
  5.00 ┤ │ │ ╭╯╰╯│││╭╯
  4.00 ┤╭╯ │╭╯   ││││
  3.00 ┼╯  ││    ││││
  2.00 ┤   ╰╯    ╰╯╰╯"""

  test "plots multiple series":
    let graph = plotMany(@[
      @[0.0, 1.0, 2.0, 3.0, 3.0, 3.0, 2.0, 0.0],
      @[5.0, 4.0, 2.0, 1.0, 4.0, 6.0, 6.0]
    ])
    check graph == """ 6.00 ┤    ╭─
 5.00 ┼╮   │
 4.00 ┤╰╮ ╭╯
 3.00 ┤ │╭│─╮
 2.00 ┤ ╰╮│ ╰╮
 1.00 ┤╭╯╰╯  │
 0.00 ┼╯     ╰"""

  test "interpolates width and applies height and caption":
    let graph = plot(
      [0.3189989805, 0.149949026, 0.30142492354, 0.195129182935,
       0.3142492354, 0.1674974513, 0.3142492354, 0.1474974513,
       0.3047974513],
      graphWidth(30),
      graphHeight(5),
      graphCaption("Plot with custom height & width.")
    )
    check graph.splitLines.len == 7
    check "0.32 ┼╮" in graph
    check graph.endsWith("Plot with custom height & width.")

  test "supports soft bounds, precision, and axis offset":
    let graph = plot(
      [1.0, 2.0, 3.0],
      lowerBound(0.0),
      upperBound(4.0),
      labelPrecision(1),
      axisOffset(6)
    )
    check graph.startsWith("   4.0  ┤")
    check "   0.0  ┤" in graph

  test "uses NaN values as visible gaps":
    check plot([1.0, 1.0, NaN, 1.0, 1.0]) == " 1.00 ┼─╴╶─"
    expect ValueError:
      discard plot([NaN, NaN])

  test "supports custom and partial character sets":
    check plot(
      [1, 2, 3, 2, 1],
      graphSeriesChars([createLineCharSet("*")])
    ) == """ 3.00 ┤ **
 2.00 ┤****
 1.00 ┼*  *"""

    let partial = LineCharSet(horizontal: "=", verticalLine: "|")
    check plot([1, 2, 2, 2, 3], graphSeriesChars([partial])) == """ 3.00 ┤   ╭
 2.00 ┤╭==╯
 1.00 ┼╯"""

  test "formats Y-axis values with application units":
    let graph = plot(
      [30.0, 70.0, 2.0],
      graphHeight(5),
      graphWidth(45),
      graphYAxisFormatter(proc(value: float64): string =
        &"{value:.2f} GiB")
    )
    check graph.startsWith(" 70.00 GiB ┤")
    check "  2.00 GiB ┤" in graph

  test "adds labeled and custom-formatted X axes":
    let graph = plot(
      [1, 1, 1, 1, 1],
      graphXAxisRange(0.0, 100.0),
      graphXAxisTickCount(2)
    )
    check graph == """ 1.00 ┼────
      └┬───┬
       0  100"""

    let custom = plot(
      [1, 1, 1, 1, 1],
      graphXAxisRange(0.0, 100.0),
      graphXAxisTickCount(2),
      graphXAxisFormatter(proc(value: float64): string =
        $int(round(value)) & "ms")
    )
    check "0ms" in custom

  test "supports configurable line endings":
    let graph = plot(
      [1, 2, 3],
      graphXAxisRange(0.0, 2.0),
      graphLineEnding("\r\n")
    )
    check "\r\n" in graph
    check graph.replace("\r\n", "").find('\n') < 0

  test "colors series, axes, labels, captions, and legends":
    let graph = plotMany(
      @[@[0.0, 1.0, 0.0], @[2.0, 3.0, 4.0, 3.0, 2.0]],
      graphSeriesColors([colorBrightRed, colorBrightBlue]),
      graphSeriesLegends(["Red", "Blue"]),
      graphCaption("colored"),
      graphCaptionColor(colorBrightYellow),
      graphAxisColor(colorGreen),
      graphLabelColor(colorBrightCyan)
    )
    check ansiCode(colorBrightRed) in graph
    check ansiCode(colorBrightBlue) in graph
    check ansiCode(colorGreen) in graph
    check ansiCode(colorBrightCyan) in graph
    check ansiCode(colorBrightYellow) & "colored" in graph
    check "■" in graph

  test "colors values along a true-color gradient":
    let graph = plot(
      [1, 2, 3],
      graphColorGradient([colorBrightBlue, colorBrightRed])
    )
    check graph == " 3.00 ┤ \e[91m╭\e[0m\n" &
      " 2.00 ┤\e[38;2;128;0;128m╭╯\e[0m\n" &
      " 1.00 ┼\e[94m╯\e[0m"

    let heatmap = plot([1, 2, 3], graphColorGradient(HeatmapSpectrum))
    check "\e[38;5;" in heatmap

  test "threshold colors override gradients and series colors":
    let graph = plot(
      [1, 2, 3],
      graphSeriesColors([colorGreen]),
      graphColorGradient([colorBrightBlue, colorGreen]),
      graphColorAbove(colorBrightRed, 2.0),
      graphColorBelow(colorBrightBlue, 2.0)
    )
    check ansiCode(colorBrightRed) in graph
    check ansiCode(colorBrightBlue) in graph
    let gradientOnly = plot(
      [1, 2, 3],
      graphColorGradient([colorBrightBlue, colorGreen])
    )
    check graph != gradientOnly

  test "supports reusable configuration objects":
    var config = initAsciiGraphConfig()
    config.height = 2
    config.caption = "reused"
    check plot([1, 2, 3], config).endsWith("reused")

  test "validates unusable datasets":
    expect ValueError:
      discard plot(newSeq[float64]())
    expect ValueError:
      discard plot([1.0, Inf])
    expect ValueError:
      discard plotMany(newSeq[seq[float64]]())

  test "builds terminal clearing sequences":
    check clearLinesSequence(0) == ""
    check clearLinesSequence(5) == "\e[5A\e[J"

  test "replaces lines before erasing stale content":
    check replaceLinesSequence("new\nframe", 2) ==
      "\e[2A\rnew\e[K\nframe\e[J\n"
    check replaceLinesSequence("first", 0) == "\rfirst\e[J\n"
    check replaceLinesSequence("", 1) == "\e[1A\r\e[J\n"
    expect ValueError:
      discard replaceLinesSequence("frame", -1)
