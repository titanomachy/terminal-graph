## Locate the sibling package while this workspace is split into repositories.
## Installed packages resolve ``terminal_styles`` through Nimble instead.
import std/os

let siblingStyles = thisDir() / ".." / "terminal_styles" / "src"
if dirExists(siblingStyles):
  switch("path", siblingStyles)
