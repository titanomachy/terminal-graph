## Locate the sibling package while this workspace is split into repositories.
## Installed packages resolve ``terminal_style`` through Nimble instead.
import std/os

let siblingStyles = thisDir() / ".." / "terminal-style" / "src"
if dirExists(siblingStyles):
  switch("path", siblingStyles)
# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
