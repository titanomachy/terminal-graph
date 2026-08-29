## Cohesive TerminalStyle colors for terminal graphs and surrounding UI.
##
## ``ModernGraphPalette`` targets dark terminal backgrounds. The named color
## slots can be used for semantic roles, while ``ModernGraphSeriesColors`` and
## ``ModernGraphGradient`` provide ready-to-use categorical and continuous
## graph palettes.

import terminal_style/palettes

export palettes

const
  ModernGraphPalette* = initTerminalPalette(
    black = hexColor("#111827"),
    red = hexColor("#FB7185"),
    green = hexColor("#22C55E"),
    yellow = hexColor("#FBBF24"),
    blue = hexColor("#60A5FA"),
    magenta = hexColor("#C084FC"),
    cyan = hexColor("#22D3EE"),
    white = hexColor("#CBD5E1"),
    brightBlack = hexColor("#64748B"),
    brightRed = hexColor("#FDA4AF"),
    brightGreen = hexColor("#4ADE80"),
    brightYellow = hexColor("#FCD34D"),
    brightBlue = hexColor("#93C5FD"),
    brightMagenta = hexColor("#D8B4FE"),
    brightCyan = hexColor("#67E8F9"),
    brightWhite = hexColor("#F8FAFC")
  )
    ## Modern true-color palette designed against a ``#111827`` background.

  ModernGraphSeriesColors*: array[8, TerminalColor] = [
    ModernGraphPalette.cyan,
    ModernGraphPalette.yellow,
    ModernGraphPalette.magenta,
    ModernGraphPalette.green,
    ModernGraphPalette.blue,
    ModernGraphPalette.red,
    ModernGraphPalette.brightCyan,
    ModernGraphPalette.brightYellow
  ]
    ## Categorical colors ordered to keep neighboring series distinct.

  ModernGraphGradient*: array[7, TerminalColor] = [
    hexColor("#6366F1"),
    hexColor("#3B82F6"),
    hexColor("#06B6D4"),
    hexColor("#10B981"),
    hexColor("#84CC16"),
    hexColor("#F59E0B"),
    hexColor("#F43F5E")
  ]
    ## Perceptually ordered cool-to-warm gradient for values and surfaces.

  ModernGraphHeadingStyle* = initTerminalStyle(
    foreground = ModernGraphPalette.brightCyan,
    attributes = {taBold}
  )
    ## Reusable style for headings around a group of graphs.

  ModernGraphMutedStyle* = initTerminalStyle(
    foreground = ModernGraphPalette.brightBlack
  )
    ## Reusable style for secondary labels and supporting text.
