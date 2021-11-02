# Package
version       = "0.1.1"
author        = "Hendrik Albers"
description   = "Show or modify the hak list of a Neverwinter Nights module"
license       = "MIT"
srcDir        = "src"
bin           = @["nwhaklist"]


# Dependencies
requires "nim >= 1.6.0"
requires "neverwinter == 1.4.5"
