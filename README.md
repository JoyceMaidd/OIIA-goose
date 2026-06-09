![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# OIIA Goose

OIIA Goose is A VGA demo inspired by the well-known "OIIA Cat" meme. It renders a rotating pixel-art Canada goose.

## Demo

https://github.com/user-attachments/assets/04561e0d-b1d1-407a-a500-8e53dc14e199

**3D viewer**: https://gds-viewer.tinytapeout.com/?model=https://joycemaidd.github.io/OIIA-goose/tinytapeout.oas&pdk=sky130A
## Features

- **Spinning goose** with four sprite orientations (forward, backward, left, right)
- **Four selectable backgrounds** controlled via `ui_in[1:0]`:
  - Grass/Sky procedural background
  - Bouncing University of Waterloo logo animation
  - Solid blue/purple gradient
  - Solid green/teal gradient
- **Four spin modes** controlled via `ui_in[3:2]`:
  - `00` — No spin
  - `01` — Slow spin
  - `10` — Fast spin
  - `11` — Default: spins quickly to the music, stops when silent
- **Chiptune audio** output via PWM

## Try It Out

You can run this project directly in your browser — no hardware required!

1. Go to [vga-playground.com](https://vga-playground.com)
2. Paste the contents of [`main/src/vga_playground.v`](https://github.com/JoyceMaidd/OIIA-goose/blob/main/src/vga_playground.v) into the editor
3. Watch the goose spin 🪿

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)
