# Package

version       = "0.0.1"
author        = "fabricio-p"
description   = "Small BEAM replica"
license       = "Apache 2.0"
srcDir        = "src"
bin           = @["nanobeam"]
# backend       = "cpp"

# Dependencies

requires "nim >= 2.0.6",
         "https://github.com/fabricio-p/yarolin.git",
         "fusion"
