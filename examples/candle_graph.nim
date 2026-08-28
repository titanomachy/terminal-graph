## Static OHLC candlesticks with ordered period labels.
# Run with: nim r --path:src examples/candle_graph.nim

when isMainModule:
  import ../src/terminal_graph

  let
    periods = ["Mon", "Tue", "Wed", "Thu", "Fri", "Mon", "Tue", "Wed"]
    prices = [
      candle(101.0, 106.0, 99.0, 104.0),
      candle(104.0, 108.0, 102.0, 103.0),
      candle(103.0, 107.0, 101.0, 106.0),
      candle(106.0, 110.0, 105.0, 108.0),
      candle(108.0, 111.0, 103.0, 104.0),
      candle(104.0, 109.0, 102.0, 107.0),
      candle(107.0, 112.0, 106.0, 107.0),
      candle(107.0, 113.0, 105.0, 111.0)
    ]
  var options = initCandlePlotOptions()
  options.width = 52
  options.height = 14
  options.caption = "Daily OHLC"
  options.unit = "USD"
  options.risingColor = ModernGraphPalette.green
  options.fallingColor = ModernGraphPalette.red
  options.unchangedColor = ModernGraphPalette.yellow
  options.axisColor = ModernGraphPalette.brightBlack
  options.labelColor = ModernGraphPalette.white

  echo plotCandles(periods, prices, options)
