# TerminalGraphs

Pure-Nim terminal charts: connected lines, horizontal bars, irregular XY and
scatter plots, static and live graphs, responsive multiplot dashboards, 2D
surfaces, filled contours, and sparklines.

The package renders strings with Unicode and ANSI styling—there is no Python
runtime or external plotting backend. Importing `terminal_graphs` has no side
effects and does not change terminal state.

<p align="center">
  <a href="examples/live_graph.nim"><img src="examples/images/live_graph2.gif" alt="Animated live service metrics graph" width="45%"></a>
  <a href="examples/streaming_line_graph.nim"><img src="examples/images/streaming_line_graph2.gif" alt="Animated streaming API latency graph" width="51.45%"></a>
</p>
<p align="center"><a href="#examples">More examples</a></p>

## Platform support

TerminalGraphs has been tested on Linux and Windows. **On Windows this library still has some serious issue which I am working on currently.** It should also work on
macOS through its standard POSIX terminal and ANSI/VT support, but macOS has not
yet been tested directly.

## Requirements

- Nim 2.0.0 or newer
- [`terminal_styles`](https://github.com/titanomachy/terminal-styles) 0.1.0 or newer, installed from GitHub
- No runtime dependencies beyond `terminal_styles`

Until the first release, install from a checkout:

```sh
git clone https://github.com/titanomachy/terminal-graphs.git
cd terminal-graphs
nimble install
```

The repository also detects `../terminal_styles/src`, which is convenient when
both packages are sibling workspaces.

## Quick start

One façade import exposes every graph family and the shared styling API:

```nim
import terminal_graphs

echo sparkline([1, 4, 2, 8, 5])

echo plot(
  [3, 4, 9, 6, 2, 4, 5, 8],
  graphWidth(40),
  graphHeight(8),
  graphCaption("Request latency"),
  graphSeriesColors([colorBrightCyan])
)

var graph = initStaticGraph("Weekly requests", unit = "requests")
let requests = graph.addSeries(
  "requests", style = psFill, marker = "▄"
)
graph.push(requests, [12.0, 18.0, 15.0, 27.0, 35.0, 31.0, 42.0])

echo graph.render(width = 64, height = 14, useColor = false)
```

## API overview

| Graph family | Main API | Highlights |
| --- | --- | --- |
| Connected lines | `plot`, `plotMany`, `AsciiGraphConfig` | Interpolation, labeled axes, formatters, legends, custom glyphs, gradients, thresholds, and NaN gaps |
| Horizontal bars | `plotBars`, `BarGraphOptions` | Single-series, grouped, and stacked positive/negative bars around a shared zero axis |
| XY and scatter | `plotXY`, `plotXYMany`, `plotScatter`, `plotScatterMany` | Explicit coordinates, fixed or automatic viewports, clipping, labels, markers, and legends |
| Static graphs | `StaticGraph`, `initStaticGraph`, `render` | Bounded histories, line/fill series, statistics, automatic or fixed ranges, and deterministic dimensions |
| Sparklines | `sparkline`, `SparklineOptions` | Shared or automatic ranges, gaps, custom ticks, and ANSI-256 palettes |
| Surfaces and contours | `plotSurface`, `plotContour`, `plot2D` | Matrix or flat data, resampling, fixed ranges, palettes, scales, and plain-text output |
| Multiplot layouts | `multiplot`, `multiplotResponsive` | ANSI/Unicode-aware grids, auto-fit columns, breakpoints, alignment, and deferred width-aware renderers |
| Live displays | `LiveGraph`, `LiveLineGraph`, `LiveDashboard` | Bounded streaming data, frame rendering, in-place redraws, alternate-screen dashboards, and resize-safe composition |
| Terminal styling | Re-exported `terminal_styles` API | Standard, bright, ANSI-256, RGB, and hex colors plus ANSI-aware measuring, slicing, padding, and wrapping |

Line charts accept either composable option builders such as `graphWidth(40)`
or a reusable `AsciiGraphConfig`; the other graph families use their focused
options objects. Explicit dimensions make snapshots and logs deterministic,
while zero dimensions detect the current terminal. Color-capable renderers
also provide `useColor = false` for plain output.

Focused imports such as `import terminal_graphs/sparkline_graphs` are
supported, but most applications should use `import terminal_graphs`.

### Live lifecycle

Always restore terminal state in a `finally` block:

```nim
var graph = initLiveGraph("Requests", unit = "req/s")
let requests = graph.addSeries("requests", style = psFill, marker = "▄")

graph.startLive()
try:
  graph.push(requests, 42.0)
  graph.draw()
finally:
  graph.stopLive()
```

`renderFrame()` returns a frame without writing to the terminal. Use
`LiveDashboard` to redraw an arbitrary full-screen frame, including responsive
multiplot output, without leaving resized frames in scrollback.

On supported Windows consoles, live sessions enable virtual-terminal
processing and restore the original console mode when they stop.

## Examples

Run any example with `nim r examples/<name>.nim`. The four live examples run
until Ctrl+C; their animations below show them in action.

<details>
<summary><a href="examples/all_graphs.nim"><code>all_graphs.nim</code></a> — finite tour of every graph family</summary>
<p><a href="examples/images/all_graphs.png"><img src="examples/images/all_graphs.png" alt="Complete output of the all graphs example"></a></p>
</details>

<table>
  <tr>
    <td width="50%">
      <a href="examples/line_graph.nim"><img src="examples/images/line_graph.png" alt="Connected line graph example output"></a><br>
      <strong><a href="examples/line_graph.nim"><code>line_graph.nim</code></a></strong><br>
      Axes, multiple series, legends, gradients, and thresholds.
    </td>
    <td width="50%">
      <a href="examples/bar_graph.nim"><img src="examples/images/bar_graph.png" alt="Grouped and stacked horizontal bar graph example output"></a><br>
      <strong><a href="examples/bar_graph.nim"><code>bar_graph.nim</code></a></strong><br>
      Grouped and stacked bars with positive and negative values.
    </td>
  </tr>
  <tr>
    <td width="50%">
      <a href="examples/xy_graph.nim"><img src="examples/images/xy_graph.png" alt="Irregular XY line and scatter graph example output"></a><br>
      <strong><a href="examples/xy_graph.nim"><code>xy_graph.nim</code></a></strong><br>
      An irregular connected line and a scatter plot.
    </td>
    <td width="50%">
      <a href="examples/sparkline_graph.nim"><img src="examples/images/sparkline_graph.png" alt="Sparkline example output"></a><br>
      <strong><a href="examples/sparkline_graph.nim"><code>sparkline_graph.nim</code></a></strong><br>
      Compact graphs, gaps, shared scales, and a color gradient.
    </td>
  </tr>
  <tr>
    <td width="50%">
      <a href="examples/static_graph.nim"><img src="examples/images/static_graph.png" alt="Static filled terminal graph example output"></a><br>
      <strong><a href="examples/static_graph.nim"><code>static_graph.nim</code></a></strong><br>
      A deterministic, plain-text frame for logs and reports.
    </td>
    <td width="50%">
      <a href="examples/multiplot_graph.nim"><img src="examples/images/multiplot_graph.png" alt="Responsive multiplot terminal dashboard example output"></a><br>
      <strong><a href="examples/multiplot_graph.nim"><code>multiplot_graph.nim</code></a></strong><br>
      A responsive dashboard of independently rendered graph types.
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <a href="examples/advanced_graphs.nim"><img src="examples/images/advanced_graphs.png" alt="Two-dimensional surface and filled contour example output"></a><br>
      <strong><a href="examples/advanced_graphs.nim"><code>advanced_graphs.nim</code></a></strong><br>
      A high-resolution 2D surface and filled contours.
    </td>
  </tr>
</table>

### Live and streaming examples

<table>
  <tr>
    <td width="50%">
      <a href="examples/live_graph.nim"><img src="examples/images/live_graph2.gif" alt="Animated live service metrics graph" height="240"></a><br>
      <strong><a href="examples/live_graph.nim"><code>live_graph.nim</code></a></strong><br>
      Generated service metrics redrawn fluidly as a full terminal frame.
    </td>
    <td width="50%">
      <a href="examples/streaming_line_graph.nim"><img src="examples/images/streaming_line_graph2.gif" alt="Animated streaming connected line graph" height="240"></a><br>
      <strong><a href="examples/streaming_line_graph.nim"><code>streaming_line_graph.nim</code></a></strong><br>
      Two connected series in bounded streaming windows.
    </td>
  </tr>
  <tr>
    <td width="50%">
      <a href="examples/streaming_multiplot_graph.nim"><img src="examples/images/streaming_multiplot_graph2.gif" alt="Animated responsive streaming multiplot dashboard"></a><br>
      <strong><a href="examples/streaming_multiplot_graph.nim"><code>streaming_multiplot_graph.nim</code></a></strong><br>
      Two live graphs in a resize-aware full-screen dashboard.
    </td>
    <td width="50%">
      <a href="examples/streaming_sparklines.nim"><img src="examples/images/streaming_sparklines.gif" alt="Animated streaming CPU and memory sparklines"></a><br>
      <strong><a href="examples/streaming_sparklines.nim"><code>streaming_sparklines.nim</code></a></strong><br>
      A compact CPU and memory dashboard from reusable sparklines.
    </td>
  </tr>
</table>

Compile-check every example at once with:

```sh
nimble examples
```

## Development and documentation

```sh
nimble test       # run all test suites
nimble examples   # compile-check all examples
nimble docs       # generate htmldocs/ from public API comments
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules and
[docs/public-api.md](docs/public-api.md) for the example coverage map.

## Attribution and license

The connected line renderer is a Nim port inspired by
[`guptarohit/asciigraph`](https://github.com/guptarohit/asciigraph). Other API
and visualization ideas were inspired by
[`OFThomas/drawIt`](https://gitlab.com/OFThomas/drawIt),
[`Luteva-ssh/nivot`](https://github.com/Luteva-ssh/nivot), and
[`sindresorhus/sparkly`](https://github.com/sindresorhus/sparkly). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the required notice.

`terminal_graphs` is released under the [MIT License](LICENSE).
