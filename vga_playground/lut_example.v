/*  * VGA Example with LUT Frame + Palette  */

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
    wire [3:0] pixel_index;

    frame0_lut frame0 (
        .x(pix_x[7:2]),   // downsample to 64 pixels horizontally
        .y(pix_y[7:2]),   // downsample to 64 pixels vertically
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
        .r(pal_r),
        .g(pal_g),
        .b(pal_b)
    );

    //------------------------------------------------------------
    // Drive video
    //------------------------------------------------------------
    assign R = video_active ? pal_r : 2'b00;
    assign G = video_active ? pal_g : 2'b00;
    assign B = video_active ? pal_b : 2'b00;

endmodule


//------------------------------------------------------------
// 64×64 FRAME  (4-bit palette index)
//------------------------------------------------------------
module frame0_lut(
    input  wire [5:0] x,   // 0–63
    input  wire [5:0] y,   // 0–63
    output reg  [3:0] pixel
);

    wire [11:0] addr = {y, x}; // 6+6 = 12-bit address (4096 pixels)

    always @(*) begin
        case (addr)

            // Example: simple gradient pattern
            12'h000: pixel = 4'h1;
            12'h001: pixel = 4'h2;
            12'h002: pixel = 4'h3;
            12'h003: pixel = 4'h4;

            // TODO: fill entire 4096-entry frame here

            default: pixel = (x ^ y) & 4'hF;  // fallback pattern
        endcase
    end

endmodule


//------------------------------------------------------------
// 16-color PALETTE
//------------------------------------------------------------
module palette_lut(
    input  wire [3:0] index,
    output reg  [1:0] r,
    output reg  [1:0] g,
    output reg  [1:0] b
);

    always @(*) begin
        case (index)

            4'h0: {r,g,b} = {2'b00, 2'b00, 2'b00}; // black
            4'h1: {r,g,b} = {2'b11, 2'b00, 2'b00}; // red
            4'h2: {r,g,b} = {2'b00, 2'b11, 2'b00}; // green
            4'h3: {r,g,b} = {2'b00, 2'b00, 2'b11}; // blue
            4'h4: {r,g,b} = {2'b11, 2'b11, 2'b00}; // yellow
            4'h5: {r,g,b} = {2'b11, 2'b00, 2'b11}; // magenta
            4'h6: {r,g,b} = {2'b00, 2'b11, 2'b11}; // cyan
            4'h7: {r,g,b} = {2'b11, 2'b11, 2'b11}; // white

            // Additional palette entries…
            4'h8: {r,g,b} = {2'b10,2'b01,2'b00};
            4'h9: {r,g,b} = {2'b01,2'b10,2'b00};
            4'hA: {r,g,b} = {2'b01,2'b01,2'b01};
            4'hB: {r,g,b} = {2'b10,2'b10,2'b10};
            4'hC: {r,g,b} = {2'b01,2'b00,2'b01};
            4'hD: {r,g,b} = {2'b00,2'b01,2'b01};
            4'hE: {r,g,b} = {2'b10,2'b01,2'b10};
            4'hF: {r,g,b} = {2'b11,2'b10,2'b01};

            default: {r,g,b} = 6'b0;
        endcase
    end

endmodule
