<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Displays the OIIA goose demoscene

## How to test

Build the project and generate the SVH files used by `src/graphics.sv`.

1. Create a build directory and build the helper tools:

```sh
mkdir -p build && cd build
cmake ..
cmake --build .
```

2. Convert your BMP files to SVH files used by the Verilog sources. Run the `make_bitmaps` tool from the `build` directory and point the first argument at the `src` directory (this will write `palette.svh` and `frameN.svh` files into `src`):

```sh
./make_bitmaps ../src ../data/frame0.bmp ../data/frame1.bmp ../data/frame2.bmp ../data/frame3.bmp
```

- This writes `../src/palette.svh` and `../src/frame0.svh` .. `../src/frame3.svh` which are included by `src/graphics.sv`.

Notes:

The project currently uses 32×32 BMPs.
- To change frame timing or number of frames, edit `src/graphics.sv` and the included `frameN.svh` files accordingly.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
