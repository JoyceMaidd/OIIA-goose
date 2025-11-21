/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    //------------------------------------------------------------
    // VGA signals
    //------------------------------------------------------------
    wire hsync, vsync;
    wire [1:0] R, G, B;
    wire video_active;
    wire [9:0] pix_x, pix_y;

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    assign uio_out = 0;
    assign uio_oe  = 0;

    wire _unused_ok = &{ena, ui_in, uio_in};

    //------------------------------------------------------------
    // VGA timing generator
    //------------------------------------------------------------

    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    //------------------------------------------------------------
    // FRAMEBUFFER LOOKUP (frame0)
    //
    // You can store 2-bit or 4-bit indices per pixel.
    // Here: 6-bit address, 4-bit output = 16-color palette
    //------------------------------------------------------------
    wire [2:0] pixel_index;

    wire in_shape = pix_x[8] && !pix_x[9] && !pix_y[8];

    frame0_lut frame0 (
        .x(pix_x[7:3]),   // downsample to 64 pixels horizontally
        .y(pix_y[7:3]),   // downsample to 64 pixels vertically
        .pixel(pixel_index)
    );

    //------------------------------------------------------------
    // PALETTE LOOKUP
    //
    // Converts logical color index into R,G,B
    //------------------------------------------------------------
    wire [1:0] pal_r, pal_g, pal_b;

    palette_lut palette (
        .index(pixel_index),
        .subpixel(pix_x[1:0] ^ pix_y[1:0]), // Dithering (blending colours using subpixels)
        .r(pal_r),
        .g(pal_g),
        .b(pal_b)
    );

    //------------------------------------------------------------
    // Drive video
    //------------------------------------------------------------
    assign R = video_active ? in_shape ? pal_r : 2'b00 : 2'b00;
    assign G = video_active ? in_shape ? pal_g : 2'b00 : 2'b00;
    assign B = video_active ? in_shape ? pal_b : 2'b00 : 2'b00;

endmodule