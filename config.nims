## Locate the sibling package while this workspace is split into repositories.
## Installed packages resolve ``terminal_style`` through Nimble instead.
import std/os

let siblingStyles = thisDir() / ".." / "terminal-style" / "src"
if dirExists(siblingStyles):
  switch("path", siblingStyles)
