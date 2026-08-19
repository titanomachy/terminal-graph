# Terminal graphs

This pure-Nim package provides the reusable `terminal_graphs` library. One
façade import provides horizontal bars, asciigraph-style and irregular XY lines, 
scatter plots, static and live displays, multiplot layouts, 2D surfaces and filled contours, 
compact sparklines, and the shared `terminal_styles` API. The implementation is pure Nim: it
does not require Python or an external plotting backend. Importing it does not
print, loop, hide the cursor, or otherwise change terminal state.

## Requirements

- Nim 2.0.0 or newer
- `terminal_styles` 0.1.0 or newer

From this directory, install dependencies and run the checks:

```sh
nimble test
nimble examples
```

The public façade can also be compiled as a small finite demo. Its executable
code is guarded by `when isMainModule`, so importing it remains side-effect
free and the Nimble package does not install an application binary:

```sh
nim c -r src/terminal_graphs.nim
```

## Importing the graph module

Code compiled through this Nimble package can import the module directly:

```nim
import terminal_graphs

echo plot([3, 4, 9, 6, 2, 4, 5, 8])
echo sparkline([1.0, 4.0, 2.0, 8.0])

var graph = initStaticGraph("Request latency", unit = "ms")
let latency = graph.addSeries("p95", marker = "x")

graph.push(latency, [18.0, 20.5, 19.0, 23.0])
echo graph.render(width = 60, height = 14, useColor = false)
```

For an application elsewhere on disk, install both packages with Nimble. When
working from this split workspace without installing them, add both `src`
directories to the compiler path:

```sh
nim c --path:/path/to/terminal_styles/src \
  --path:/path/to/terminal_graphs/src your_main.nim
```

## Module layout

`src/terminal_graphs.nim` is both the public façade and the optional demo entry
point. It imports and re-exports the focused implementations:

```text
src/
├── terminal_graphs.nim                  public façade and demo entry point
└── terminal_graphs/
    ├── bar_graphs.nim                   grouped and stacked horizontal bars
    ├── line_graphs.nim                  sample-indexed ASCII line graphs
    ├── live_graphs.nim                  in-place terminal updates
    ├── multiplot_graphs.nim             responsive ANSI-aware graph grids
    ├── sparkline_graphs.nim             compact single-line graphs
    ├── static_graphs.nim                plot data and frame rendering
    ├── surface_graphs.nim               2D surfaces and filled contours
    └── xy_graphs.nim                    scatter and irregular XY graphs
```

This keeps the common import stable as more graph types are added. Advanced
users can import a submodule directly—for example,
`import terminal_graphs/sparkline_graphs`—when they intentionally want only
that API.

To add another graph family, place its implementation under
`src/terminal_graphs/`, then import and export that module from
`src/terminal_graphs.nim`. Existing application imports remain unchanged.
The former `src/modules` directory is no longer needed. Shared colors, ANSI
parsing, and terminal-cell layout live in the independent `terminal_styles`
package. The graph façade re-exports that dependency, so applications using
graphs still need only `import terminal_graphs`.

## API overview

### ASCII line graphs

`plot` and `plotMany` provide a Nim implementation of the feature set from
[`guptarohit/asciigraph`](https://github.com/guptarohit/asciigraph). Integer and
floating-point inputs are accepted:

```nim
import terminal_graphs

let data = [3, 4, 9, 6, 2, 4, 5, 8, 5, 10, 2, 7, 2, 5, 6]

echo plot(
  data,
  graphHeight(8),
  graphWidth(40),
  graphCaption("Requests"),
  graphXAxisRange(0.0, 14.0),
  graphXAxisTickCount(3)
)
```

The line renderer supports:

- `plot` for one series and `plotMany` for overlapping series.
- `graphWidth` interpolation and explicit or automatically calculated
  `graphHeight`.
- Soft `lowerBound` and `upperBound` values. Data outside them still remains
  visible.
- `labelPrecision`, `axisOffset`, captions, and configurable `graphLineEnding`.
- `graphYAxisFormatter` and `graphXAxisFormatter` callbacks for units and
  domain-specific labels.
- Labeled X axes through `graphXAxisRange` and `graphXAxisTickCount`.
- NaN values as gaps, with start and end caps around disconnected segments.
- Per-series drawing symbols through `LineCharSet`, `createLineCharSet`, and
  `graphSeriesChars`.
- Standard, bright, ANSI-256, and RGB series, axis, label, and caption colors.
  Use named values such as `colorBrightRed`, `indexedColor(index)`, or
  `rgbColor(red, green, blue)`.
- Centered colored legends with `graphSeriesLegends`.
- Value-based gradients with `graphColorGradient`; `HeatmapSpectrum` is the
  built-in cool-to-warm palette.
- Strict `graphColorAbove` and `graphColorBelow` thresholds. Threshold colors
  override gradients, which override ordinary series colors. Above wins if
  both thresholds match.
- `clearTerminal` and `clearLines` helpers for repeated/realtime rendering.

The option-builder API is composable. For frequently reused settings, create
an `AsciiGraphConfig` with `initAsciiGraphConfig`, change its public fields, and
pass it to `plot` or `plotMany`.

Color option names have an `ansi` or `graph` prefix because Nim identifiers are
case-insensitive; this prevents collisions with common procedures such as
`red` and fields such as `width`.

### Horizontal bar graphs

`plotBars` accepts category labels and either one numeric sequence or several
series. Positive and negative bars share a visible zero baseline. Multiple
series can be rendered as separate grouped rows or accumulated into positive
and negative stacks:

```nim
import terminal_graphs

let labels = ["North", "South", "East"]
let values = @[
  @[18.0, 24.0, -7.0],
  @[12.0, -5.0, 11.0]
]

var options = initBarGraphOptions()
options.width = 32             # Width of the bar field, excluding labels.
options.caption = "Change by region"
options.unit = "%"
options.seriesLegends = @["current", "previous"]
options.seriesColors = @[colorBrightCyan, colorBrightYellow]

echo plotBars(labels, values, options)

options.mode = bmStacked
echo plotBars(labels, values, options)
```

Automatic ranges always contain zero. `setBarRange` fixes a shared range and
requires that it contain zero; `clearBarRange` restores automatic scaling.
`useColor`, `showValues`, `glyph`, `axisGlyph`, and `lineEnding` control output.
Labels and glyphs are Unicode-aware, while non-finite values, inconsistent
series lengths, and invalid options raise `ValueError`.

### Scatter and irregular XY graphs

The ordinary line renderer treats values as evenly spaced samples. The XY
renderer instead maps explicit coordinates, making it suitable for irregular
time intervals, mathematical paths, and scatter data:

```nim
import terminal_graphs

let signal = @[
  xyPoint(-5.0, -1.0),
  xyPoint(-3.8, 2.5),
  xyPoint(-0.4, 0.5),
  xyPoint(0.2, 4.0),
  xyPoint(5.0, 1.0)
]

var options = initXYPlotOptions()
options.width = 50
options.height = 16
options.caption = "Irregular signal"
options.xLabel = "time"
options.yLabel = "value"

echo plotXY(signal, options)
echo plotScatter(signal, options)
```

`plotXY` connects points in their supplied order; `plotScatter` draws only
markers. `plotXYMany` and `plotScatterMany` accept colored, named `XYSeries`
values. Paired numeric arrays are also accepted, for example
`plotScatter(xValues, yValues)`.

Automatic ranges include zero, so the axes cross at `(0, 0)` whenever both
dimensions contain it. Fixed viewports set with `setXRange` and `setYRange`
clip connected segments correctly; axes move to the nearest canvas edge if
zero lies outside a fixed range. NaN coordinates break a connected path and
infinite coordinates raise `ValueError`.

### Static graphs

- `initStaticGraph(title, unit, maxSamples)` creates a graph and sets a bounded
  per-series history. The default is 1,000 samples. `initPlotter` remains as an
  equivalent general-purpose constructor.
- `addSeries(...)` adds a line or filled series and returns its numeric handle.
- `push(handle, value)` and `push(handle, values)` append finite samples.
- `samples`, `latest`, `sampleCount`, and `statistics` inspect retained data.
- `setMaxSamples` changes retention and trims old samples immediately.
- `setRange(minimum, maximum)` fixes the y-axis; `clearRange` restores automatic
  scaling.
- `render(...)` returns a string and never modifies the plot. Width and height
  default to the current terminal. Explicit dimensions are useful for tests,
  logs, and snapshots. `useColor = false` removes ANSI escape sequences, while
  `showStats = false` leaves out the summary line.

Markers must contain exactly one Unicode code point. Many terminal symbols are
one code point but occupy two display columns (for example some emoji), so
single-column symbols such as `x`, `•`, and `▄` produce the most reliable
alignment.

Series drawn later take precedence if multiple values occupy the same cell.
Filled series extend from the graph's lower y-axis bound to their sample value.

### Sparklines

`sparkline(values)` accepts integer or floating-point data and returns a
single-line graph scaled across `▁▂▃▄▅▆▇█`. Empty input returns an empty string,
NaN creates a one-column gap, and infinity raises `ValueError`. An all-zero
series uses `▁`; constant nonzero data uses the more informative middle tick
`▅` by default.

Use `SparklineOptions` when several sparklines need a shared scale or styled
output:

```nim
import terminal_graphs

var options = initSparklineOptions()
options.setSparklineRange(0.0, 100.0)
options.useColor = true

echo sparkline([10, 25, 40, 75, 100], options)
```

`minimum` and `maximum` are independent optional bounds, and values beyond the
effective range are safely clamped. `FireSparklinePalette` is the default
yellow-to-red ANSI-256 gradient when coloring is enabled; assign any
`seq[TerminalColor]` to `palette` for a custom gradient. `ticks` and `gapGlyph` are
also configurable. Set `constantMode = scmLowest` to retain the old behavior
for constant nonzero sequences. `setSparklineRange` and
`clearSparklineRange` manage both bounds together; `setSparklineMinimum`,
`setSparklineMaximum`, and their corresponding clear procedures manage each
bound independently.

Sparklines deliberately remain a small, non-streaming renderer. Keeping live
terminal lifecycle code in `live_graphs.nim` makes it possible to reuse the
same sparkline output in logs, tables, dashboards, or a live application
without coupling the two APIs.

### Multiplot layouts

`multiplot` arranges any already-rendered graphs in an ANSI-aware grid. Logical
columns share one width across every row, so panels line up even when the
individual graph sizes differ. The concise overload remains useful for fixed,
deterministic reports:

```nim
import terminal_graphs

let left = plot([1, 4, 2, 6], graphCaption("Latency"),
  graphSeriesColors([colorBrightCyan]))
let right = plot([2, 3, 7, 4], graphCaption("Throughput"),
  graphSeriesColors([colorBrightYellow]))

echo multiplot([left, right], horizontalGap = 4)
```

Use `columns` to wrap plots into multiple rows. `columns = 0`, the default,
places all plots on one row. `horizontalGap` controls spaces between plots and
`verticalGap` controls blank lines between grid rows.

For a responsive grid, use `MultiplotOptions`. `autoColumns` selects the
largest number of columns that fits the available width; setting
`availableWidth = 0` detects the terminal width each time the layout is
rendered. An explicit width makes tests, snapshots, and redirected output
deterministic:

```nim
var layout = initMultiplotOptions()
layout.columns = autoColumns
layout.availableWidth = 100
layout.minimumCellWidth = 32
layout.horizontalGap = 4
layout.horizontalAlignment = mhaCenter
layout.verticalAlignment = mvaMiddle

echo multiplot([left, right], layout)
```

Use `fixedColumns(2)` to request two columns. Responsive layouts reduce that
count when the tracks would exceed `availableWidth`, preventing the terminal
from wrapping graph rows. Set `constrainToAvailableWidth = false` only when a
strict column count and potentially over-wide output are intentional.
`expandColumns` controls whether spare width is distributed across the shared
column tracks. Horizontal alignment may be `mhaLeft`, `mhaCenter`, or
`mhaRight`; vertical alignment may be `mvaTop`, `mvaMiddle`, or `mvaBottom`.
Applications that prefer framework-style thresholds can override content-based
auto-fit with order-independent breakpoints; the matching rule with the
greatest minimum width wins:

```nim
layout.breakpoints = @[
  multiplotBreakpoint(0, 1),
  multiplotBreakpoint(80, 2),
  multiplotBreakpoint(120, 3)
]
```

Already-rendered strings can reflow into new rows but cannot resize themselves.
If one is wider than the entire available width, the responsive grid clips its
lines at ANSI- and Unicode-safe cell boundaries so the terminal never wraps a
partial graph row. Deferred renderers avoid clipping by drawing at the assigned
width in the first place.

`multiplotResponsive` accepts deferred `MultiplotRenderer` callbacks and gives
each callback its complete cell-width budget before assembling the grid:

```nim
var graph = initStaticGraph("Requests")
let series = graph.addSeries("requests")
graph.push(series, [12.0, 18.0, 15.0, 27.0])

let renderGraph: MultiplotRenderer = proc(width: int): string =
  graph.render(width = width, height = 10, showStats = false)

echo multiplotResponsive([renderGraph], layout)
```

Auto-fit is recalculated on every call, so streaming dashboards can respond to
terminal resizing without reconstructing their graph data. Renderers should
honor the supplied budget. Content wider than its track is clipped by default;
disable `constrainToAvailableWidth` to retain overflow.

### 2D surfaces and contours

`plotSurface` displays two matrix samples in each terminal cell using the
foreground and background colors of a Unicode half block. `plotContour`
renders quantized filled contour bands. Both accept rectangular matrices or
flat row-major arrays and support resampling, captions, fixed or automatic
ranges, custom ANSI-256 palettes, plain-text rendering, and scale legends:

```nim
import terminal_graphs

let field = @[
  @[0.0, 0.2, 0.5, 0.2],
  @[0.1, 0.8, 1.0, 0.4],
  @[0.0, 0.3, 0.6, 0.1]
]

var options = initSurfacePlotOptions()
options.caption = "Temperature"
options.width = 32
options.height = 16
options.contourLevels = 6

echo plotSurface(field, options)
echo plotContour(field, options)
```

Set `options.useColor = false` for logs or terminals without ANSI support.
NaN values produce holes, while infinite values and malformed matrices raise
`ValueError`. `plot2D` is a convenience alias for flat surface data.

### Live graphs

`LiveGraph` wraps a regular plotter with explicit terminal lifecycle methods.
Always stop a live graph in a `finally` block so the cursor is restored:

```nim
import terminal_graphs

var graph = initLiveGraph("Requests", unit = "req/s")
let requests = graph.addSeries("requests", style = psFill, marker = "▄")

graph.startLive()
try:
  graph.push(requests, 42.0)
  graph.draw()
finally:
  graph.stopLive()
```

Use `renderFrame()` when you want the live graph's rendered string without
moving the cursor or writing to standard output.

Use `LiveDashboard` for a full-screen application composed from arbitrary
frames, including `multiplotResponsive` output. It clears and replaces the
complete terminal frame on every draw, so resized physical rows from the prior
frame cannot remain on screen. On POSIX terminals its alternate screen also
keeps animation out of normal scrollback:

```nim
var dashboard = initLiveDashboard()
dashboard.startLive()
try:
  let frame = multiplotResponsive(renderers, layout)
  dashboard.draw(frame)
finally:
  dashboard.stopLive()
```

`LiveDashboard` deliberately does not install a process-wide signal handler;
applications that handle Ctrl+C should request a normal loop exit so the
`finally` block runs. The streaming multiplot example demonstrates this with a
signal-safe atomic flag.

For connected, colored streaming lines, use `LiveLineGraph`. It delegates each
frame to the line renderer, so series colors, gradients, captions, legends,
threshold colors, axes, and custom characters all remain available:

```nim
import terminal_graphs

var config = initAsciiGraphConfig()
config.height = 10
config.caption = "Live sensors"
config.seriesColors = @[colorCyan, colorBrightYellow]
config.seriesLegends = @["temperature", "load"]

var graph = initLiveLineGraph(
  seriesCount = 2,
  maxSamples = 60,
  config = config
)

graph.startLive()
try:
  graph.push(0, 21.5)
  graph.push(1, 48.0)
  graph.draw()
finally:
  graph.stopLive()
```

Each series retains at most `maxSamples` values. `renderFrame()` is also
available for testing or integration with `LiveDashboard` or another
application-managed screen. Its direct `draw()` method preserves terminal
content above the graph; use `LiveDashboard` when resize-safe full-screen
replacement is preferred.

### Terminal styles and colors

Colors and ANSI-aware text layout are provided by the independent
[`terminal_styles`](../terminal_styles/README.md) package and re-exported by
the graph façade. It performs pure string transformation and never changes
global terminal state. Concise color and attribute helpers accept mixed values
like `echo` does:

```nim
import terminal_graphs

echo bold(cyan("connected ", 42))
echo bgBrightBlue(brightWhite(" healthy "))
```

For reusable styles, `TerminalStyle` combines a foreground, background, and a
set of attributes into one escape sequence. Colors may come from the standard
16-color palette, any ANSI-256 index, an RGB triplet, or a three/six-digit hex
value:

```nim
let heading = initTerminalStyle(
  foreground = hexColor("#78c8ff"),
  background = indexedColor(17),
  attributes = {taBold, taUnderline}
)

echo styled(heading, "Terminal graphs")
echo rgb(255, 120, 40, "true color")
echo onIndexed(235, brightYellow(" warning "))
```

Nested helpers restore their outer style after an inner reset. For redirected
output, `applyStyle(text, heading, enabled = false)` removes both the requested
style and ANSI sequences already present in `text`. `stripAnsi`,
`displayWidth`, `sliceAnsi`, `truncateAnsi`, `padAnsi`, and `wrapAnsi` are
available for ANSI-aware, Unicode-cell-aware layout. Graph color options use
`TerminalColor`, so the same standard, indexed, RGB, and hexadecimal colors
work throughout the library.

The styling package has its own finite example and complete API guide:

```sh
cd ../terminal_styles
nim c -r examples/terminal_styles.nim
```

## Examples

[`examples/all_graphs.nim`](examples/all_graphs.nim) is a finite tour of every
graph family. Live and streaming graphs are rendered as snapshots, allowing
the program to show the complete collection and then exit normally:

```sh
nim c -r examples/all_graphs.nim
```

The [`examples/multiplot_graph.nim`](examples/multiplot_graph.nim) program
arranges line, bar, scatter, and contour renderings into a finite auto-fitting
dashboard with aligned grid tracks:

```sh
nim r examples/multiplot_graph.nim
```

The [`examples/streaming_multiplot_graph.nim`](examples/streaming_multiplot_graph.nim)
program updates two independently buffered line graphs and redraws their
combined multiplot frame. Its deferred renderers resize and reflow after a
terminal-width change. It uses a fully redrawn alternate screen on supported
terminals, preventing resized copies of older frames from cluttering the
display or normal scrollback. Stop it with Ctrl+C:

```sh
nim r examples/streaming_multiplot_graph.nim
```

The [`examples/bar_graph.nim`](examples/bar_graph.nim) program demonstrates
colored grouped and stacked bars with positive and negative values:

```sh
nim r examples/bar_graph.nim
```

The [`examples/xy_graph.nim`](examples/xy_graph.nim) program places an
irregular line and scatter plot side by side:

```sh
nim r examples/xy_graph.nim
```

The [`examples/sparkline_graph.nim`](examples/sparkline_graph.nim) program
embeds integer and floating-point sparklines in ordinary output:

```sh
nim r examples/sparkline_graph.nim
```

The [`examples/streaming_sparklines.nim`](examples/streaming_sparklines.nim) program
combines bounded sample histories with colored sparklines to build a compact
live dashboard. Stop it with Ctrl+C:

```sh
nim r examples/streaming_sparklines.nim
```

The [`examples/static_graph.nim`](examples/static_graph.nim) program renders one
plain-text frame. Run it with:

```sh
nim r examples/static_graph.nim
```

The [`examples/live_graph.nim`](examples/live_graph.nim) program redraws a
color graph using generated streaming data. Stop it with Ctrl+C:

```sh
nim r examples/live_graph.nim
```

[`examples/line_graph.nim`](examples/line_graph.nim) demonstrates axis
formatters, interpolation, multiple colored series, legends, gradients, and
threshold alerts:

```sh
nim r examples/line_graph.nim
```

[`examples/advanced_graphs.nim`](examples/advanced_graphs.nim) renders a
colored surface and filled-contour plot side by side:

```sh
nim r examples/advanced_graphs.nim
```

[`examples/streaming_line_graph.nim`](examples/streaming_line_graph.nim) shows two
connected colored series in a bounded streaming window. Stop it with Ctrl+C:

```sh
nim r examples/streaming_line_graph.nim
```

All examples can be compile-checked together with `nimble examples`.

## Tests and generated API documentation

Run the unit tests:

```sh
nimble test
```

Generate browsable API documentation from the module's doc comments:

```sh
nimble docs
```

The task runs Nim's project documentation generator and places the façade and
submodule HTML under `htmldocs/`.

## Attribution

The connected ASCII line renderer is a Nim port inspired by the BSD-licensed
Go project `guptarohit/asciigraph`. The required copyright and license text is
included in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

The multiplot, surface, contour, and live-display direction was also inspired
by the feature set demonstrated by [`OFThomas/drawIt`](https://gitlab.com/OFThomas/drawIt).
This package's implementation is independent and uses only Nim terminal output.

The bar and explicit-coordinate XY APIs were inspired by the visualization
ideas in [`Luteva-ssh/nivot`](https://github.com/Luteva-ssh/nivot). Their
implementations were written independently for this package's typed, validated,
color-capable rendering model.

Sparkline ranges, gaps, and fire-gradient styling were inspired by
[`sindresorhus/sparkly`](https://github.com/sindresorhus/sparkly). The Nim API
and renderer are independent and add typed options, custom palettes and ticks,
validated bounds, safe clamping, and explicit constant-series behavior.

The example coverage audit is in [`docs/public-api.md`](docs/public-api.md).
Release history, contribution rules, third-party declarations, and the release
procedure live in `CHANGELOG.md`, `CONTRIBUTING.md`, and `RELEASING.md`.
