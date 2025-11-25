# Script for extracting goose gif
import os
import sys
import numpy as np
from PIL import Image

# Open the original GIF
goose_gif = Image.open("data/goose.gif")

# frame_count * sprite_width * sprite_height
# Produce 4 frames of 25x25 pixels each
FRAMES = 4
FRAME_W = 25
FRAME_H = 25
datasiz = FRAMES * FRAME_W * FRAME_H

frames = []

# Extract and process each frame and store as lists
for i in range(0, FRAMES):
    goose_gif.seek(i)
    frame = goose_gif.copy()

    # Ensure palette conversion; then resize to target FRAME_W x FRAME_H
    # Use nearest-neighbor so palette indices remain meaningful
    frame = frame.convert('P')
    frame = frame.resize((FRAME_W, FRAME_H), resample=Image.NEAREST)
    indexed_data = np.array(frame)

    frames.append(indexed_data.astype(int))

# Write SVH-format arrays (one `frameN` per block) into `data/goose.hex`
with open("data/goose.hex", "w") as f:
    for idx, frm in enumerate(frames):
        f.write(f"reg [2:0] frame{idx} [0:{FRAME_H-1}][0:{FRAME_W-1}] = '{{\n")
        for r_i, row in enumerate(frm):
            row_str = ','.join(str(int(x)) for x in row)
            f.write("    '{" + row_str + "}")
            if r_i != FRAME_H-1:
                f.write(',\n')
            else:
                f.write('\n')
        f.write('};\n\n')

# # Write SVH-format single-pixel assignments into "src/frame<#>.svh"
# for idx, frm in enumerate(frames):
#     with open(f"src/frame{idx}.svh", "w") as f:
#         f.write(f"reg [2:0] frame{idx} [0:{FRAME_H-1}][0:{FRAME_W-1}];\n")
#         f.write(f"initial begin\n")
#         for r_i in range(FRAME_H):
#             for c_i in range(FRAME_W):
#                 pixel_val = int(frm[r_i][c_i])
#                 f.write(f"    frame{idx}[{r_i}][{c_i}] = 3'd{pixel_val};\n")
#         f.write("end\n")