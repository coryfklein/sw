# sw - <b>S</b>top<b>W</b>atch
Terminal stopwatch

![sw](https://user-images.githubusercontent.com/3503322/27500360-820c3b8e-5825-11e7-88fe-27bd8976c5c5.gif)

# Install

To install `sw` using [Sinister](https://github.com/jamesqo/sinister), run

    wget -q -O - http://git.io/sinister | sh -s -- -u https://raw.githubusercontent.com/coryfklein/sw/master/sw

Or just [download sw directly](https://raw.githubusercontent.com/coryfklein/sw/master/sw) and place it on your PATH somewhere.

# Usage

    sw
     - start a stopwatch from 0, save start time in ~/.sw
    sw [-r|--resume]
     - start a stopwatch from the last saved start time (or current time if no last saved start time exists)
     - "-r" stands for --resume

# Centiseconds

macOS comes bundled with BSD's `date` which does not print sub-second dates and thus `sw` will not print centiseconds. I recommend installing GNU `date` to enable this improved functionality:

    brew install coreutils
