# four-tris
This is the source code for four-tris, an open source training tool for block-stacking games, built to allow you to quickly explore different situations and test different options and freely train in a Tetris-like environment.

## Creating custom Skins

You can add your own custom skins inside the `textures` folder.
All custom skins must follow these requirements:
-   Must be a .png file.
-   Must have a resolution of 300 x 30 or higher as long as it keeps the same aspect ratio.
-   Must have a bit depth of 32 (transparency)

You can follow this template for the placement of each different 'piece' (ZLOSIJT) and 'ghost piece'
The last black square represents the color of an empty cell.

<img src="https://i.imgur.com/8GRRW6f.png" alt="template skin" width="300">


## Reporting issues, suggestions, feedback, bugs

1. Ask in `#bug-reports` / `#feature-requests` / `#questions` on the [Official Discord](https://discord.gg/UhbnyAzWfw) if you are not entirely sure if it's a bug etc.
2. Check if it's already reported or requested in the appropriate text channels.
3. If not, try to be descriptive and show how the bug occourred.

## Building
-   You will need the latest version of [AutoIt3](https://www.autoitscript.com/site/)
-   Run `git clone https://github.com/fiorescarlatto/four-tris.git`
-   Run `Tetris.au3` with the script interpreter.

If you want to build the script into an executable file (.exe) you can do so by running the the AutoIt 'Compiler'.
A standalone up-to-date compiled version can be obtained from my discord server in `#current-version` as well as a showcase of some of the features coming with four-tris.

### Code

The application runs on a very simple loop using WinAPI calls to draw elements and textures to the screen.
The code is quite messy and hacky, but it has some logical structure to it.

If you want to add a new feature or in generally contribute I recommend to get in touch with me on [Discord](https://discord.gg/UhbnyAzWfw):

<a href="https://discord.gg/UhbnyAzWfw" target="_blank">
<img src="https://i.imgur.com/SoawBhW.png" alt="discord logo" width="50">
</a>


## License
    Copyright (C) 2020  github.com/fiorescarlatto

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/gpl.html>.
