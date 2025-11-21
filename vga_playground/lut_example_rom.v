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

    wire in_shape = pix_x[8] && !pix_x[9] && !pix_y[8];

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
        .subpixel(pix_x[3:0] ^ pix_y[3:0]), // Dithering (blending colours using subpixels)
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

//------------------------------------------------------------
// 64×64 FRAME — bitmap stored in frame0[y][x]
//     frame0[][] contains a 4-bit palette index
//------------------------------------------------------------
module frame0_lut(
    input  wire [5:0] x,    // 0–63
    input  wire [5:0] y,    // 0–63
    output wire [3:0] pixel
);

    // 64×64 pixels, each 4 bits
    reg [3:0] frame0 [0:63][0:63];

    initial begin
        // YOU fill your bitmap here:
        // frame0[row][col] = palette index
        frame0[0][0] = 4'h1;
        frame0[0][1] = 4'h1;
        frame0[0][2] = 4'h1;
        frame0[0][3] = 4'h1;
        frame0[0][4] = 4'h1;
        frame0[0][5] = 4'h1;
        frame0[0][6] = 4'h1;
        frame0[0][7] = 4'h1;
        frame0[0][8] = 4'h1;
        frame0[0][9] = 4'h1;
        frame0[0][10] = 4'h2;
        frame0[0][11] = 4'h2;
        frame0[0][12] = 4'h2;
        frame0[0][13] = 4'h2;
        frame0[0][14] = 4'h2;
        frame0[0][15] = 4'h2;
        frame0[0][16] = 4'h2;
        frame0[0][17] = 4'h2;
        frame0[0][18] = 4'h2;
        frame0[0][19] = 4'h2;
        frame0[0][20] = 4'h0;
        frame0[0][21] = 4'h1;
        frame0[0][22] = 4'h2;
        frame0[0][23] = 4'h3;
        frame0[0][24] = 4'h0;
        frame0[0][25] = 4'h1;
        frame0[0][26] = 4'h2;
        frame0[0][27] = 4'h3;
        frame0[0][28] = 4'h0;
        frame0[0][29] = 4'h1;
        frame0[0][30] = 4'h0;
        frame0[0][31] = 4'h1;
        frame0[0][32] = 4'h2;
        frame0[0][33] = 4'h3;
        frame0[0][34] = 4'h0;
        frame0[0][35] = 4'h1;
        frame0[0][36] = 4'h2;
        frame0[0][37] = 4'h3;
        frame0[0][38] = 4'h0;
        frame0[0][39] = 4'h1;
        frame0[0][40] = 4'h0;
        frame0[0][41] = 4'h1;
        frame0[0][42] = 4'h2;
        frame0[0][43] = 4'h3;
        frame0[0][44] = 4'h0;
        frame0[0][45] = 4'h1;
        frame0[0][46] = 4'h2;
        frame0[0][47] = 4'h3;
        frame0[0][48] = 4'h0;
        frame0[0][49] = 4'h1;
        frame0[0][50] = 4'h0;
        frame0[0][51] = 4'h1;
        frame0[0][52] = 4'h2;
        frame0[0][53] = 4'h3;
        frame0[0][54] = 4'h0;
        frame0[0][55] = 4'h1;
        frame0[0][56] = 4'h2;
        frame0[0][57] = 4'h3;
        frame0[0][58] = 4'h0;
        frame0[0][59] = 4'h1;
        frame0[0][60] = 4'h0;
        frame0[0][61] = 4'h1;
        frame0[0][62] = 4'h2;
        frame0[0][63] = 4'h3;

        frame0[1] [0]= 4'h1;
        frame0[2] [0]= 4'h1;
        frame0[3] [0]= 4'h1;
        frame0[4] [0]= 4'h1;
        frame0[5] [0]= 4'h1;
        frame0[6] [0]= 4'h1;
        frame0[7] [0]= 4'h1;
        frame0[8] [0]= 4'h1;
        frame0[9] [0]= 4'h1;
        frame0[10][0] = 4'h2;
        frame0[11][0] = 4'h2;
        frame0[12][0] = 4'h2;
        frame0[13][0] = 4'h2;
        frame0[14][0] = 4'h2;
        frame0[15][0] = 4'h2;
        frame0[16][0] = 4'h2;
        frame0[17][0] = 4'h2;
        frame0[18][0] = 4'h2;
        frame0[19][0] = 4'h2;
        frame0[20][0] = 4'h0;
        frame0[21][0] = 4'h1;
        frame0[22][0] = 4'h2;
        frame0[23][0] = 4'h3;
        frame0[24][0] = 4'h0;
        frame0[25][0] = 4'h1;
        frame0[26][0] = 4'h2;
        frame0[27][0] = 4'h3;
        frame0[28][0] = 4'h0;
        frame0[29][0] = 4'h1;
        frame0[30][0] = 4'h0;
        frame0[31][0] = 4'h1;
        frame0[32][0] = 4'h2;
        frame0[33][0] = 4'h3;
        frame0[34][0] = 4'h0;
        frame0[35][0] = 4'h1;
        frame0[36][0] = 4'h2;
        frame0[37][0] = 4'h3;
        frame0[38][0] = 4'h0;
        frame0[39][0] = 4'h1;
        frame0[40][0] = 4'h0;
        frame0[41][0] = 4'h1;
        frame0[42][0] = 4'h2;
        frame0[43][0] = 4'h3;
        frame0[44][0] = 4'h0;
        frame0[45][0] = 4'h1;
        frame0[46][0] = 4'h2;
        frame0[47][0] = 4'h3;
        frame0[48][0] = 4'h0;
        frame0[49][0] = 4'h1;
        frame0[50][0] = 4'h0;
        frame0[51][0] = 4'h1;
        frame0[52][0] = 4'h2;
        frame0[53][0] = 4'h3;
        frame0[54][0] = 4'h0;
        frame0[55][0] = 4'h1;
        frame0[56][0] = 4'h2;
        frame0[57][0] = 4'h3;
        frame0[58][0] = 4'h0;
        frame0[59][0] = 4'h1;
        frame0[60][0] = 4'h0;
        frame0[61][0] = 4'h1;
        frame0[62][0] = 4'h2;
        frame0[63][0] = 4'h3;


        frame0[1] [63]= 4'h1;
        frame0[2] [63]= 4'h1;
        frame0[3] [63]= 4'h1;
        frame0[4] [63]= 4'h1;
        frame0[5] [63]= 4'h1;
        frame0[6] [63]= 4'h1;
        frame0[7] [63]= 4'h1;
        frame0[8] [63]= 4'h1;
        frame0[9] [63]= 4'h1;
        frame0[10][63] = 4'h2;
        frame0[11][63] = 4'h2;
        frame0[12][63] = 4'h2;
        frame0[13][63] = 4'h2;
        frame0[14][63] = 4'h2;
        frame0[15][63] = 4'h2;
        frame0[16][63] = 4'h2;
        frame0[17][63] = 4'h2;
        frame0[18][63] = 4'h2;
        frame0[19][63] = 4'h2;
        frame0[20][63] = 4'h0;
        frame0[21][63] = 4'h1;
        frame0[22][63] = 4'h2;
        frame0[23][63] = 4'h3;
        frame0[24][63] = 4'h0;
        frame0[25][63] = 4'h1;
        frame0[26][63] = 4'h2;
        frame0[27][63] = 4'h3;
        frame0[28][63] = 4'h0;
        frame0[29][63] = 4'h1;
        frame0[30][63] = 4'h0;
        frame0[31][63] = 4'h1;
        frame0[32][63] = 4'h2;
        frame0[33][63] = 4'h3;
        frame0[34][63] = 4'h0;
        frame0[35][63] = 4'h1;
        frame0[36][63] = 4'h2;
        frame0[37][63] = 4'h3;
        frame0[38][63] = 4'h0;
        frame0[39][63] = 4'h1;
        frame0[40][63] = 4'h0;
        frame0[41][63] = 4'h1;
        frame0[42][63] = 4'h2;
        frame0[43][63] = 4'h3;
        frame0[44][63] = 4'h0;
        frame0[45][63] = 4'h1;
        frame0[46][63] = 4'h2;
        frame0[47][63] = 4'h3;
        frame0[48][63] = 4'h0;
        frame0[49][63] = 4'h1;
        frame0[50][63] = 4'h0;
        frame0[51][63] = 4'h1;
        frame0[52][63] = 4'h2;
        frame0[53][63] = 4'h3;
        frame0[54][63] = 4'h0;
        frame0[55][63] = 4'h1;
        frame0[56][63] = 4'h2;
        frame0[57][63] = 4'h3;
        frame0[58][63] = 4'h0;
        frame0[59][63] = 4'h1;
        frame0[60][63] = 4'h0;
        frame0[61][63] = 4'h1;
        frame0[62][63] = 4'h2;
        frame0[63][63] = 4'h3;

        // Small example of using dithering for a blended blue
        frame0[2][0] = 4'h6;
        frame0[2][1] = 4'h6;
        frame0[2][2] = 4'h6;
        frame0[2][3] = 4'h6;
        frame0[2][4] = 4'h6;
        frame0[2][5] = 4'h6;
        frame0[2][6] = 4'h6;
        frame0[2][7] = 4'h6;
        frame0[3][0] = 4'h6;
        frame0[3][1] = 4'h6;
        frame0[3][2] = 4'h6;
        frame0[3][3] = 4'h6;
        frame0[3][4] = 4'h6;
        frame0[3][5] = 4'h6;
        frame0[3][6] = 4'h6;
        frame0[3][7] = 4'h6;
        frame0[4][0] = 4'h6;
        frame0[4][1] = 4'h6;
        frame0[4][2] = 4'h6;
        frame0[4][3] = 4'h6;
        frame0[4][4] = 4'h6;
        frame0[4][5] = 4'h6;
        frame0[4][6] = 4'h6;
        frame0[4][7] = 4'h6;

        frame0[63][1] = 4'h6;
        frame0[63][2] = 4'h6;
        frame0[63][3] = 4'h6;
        frame0[63][4] = 4'h6;
        frame0[63][5] = 4'h6;
        frame0[63][6] = 4'h6;
        frame0[63][7] = 4'h6;
        frame0[63][8] = 4'h6;
        frame0[63][9] = 4'h6;
        frame0[63][10] = 4'h6;
        frame0[63][11] = 4'h6;
        frame0[63][12] = 4'h6;
        frame0[63][13] = 4'h6;
        frame0[63][14] = 4'h6;
        frame0[63][15] = 4'h6;
        frame0[63][16] = 4'h6;
        frame0[63][17] = 4'h6;
        frame0[63][18] = 4'h6;
        frame0[63][19] = 4'h6;
        frame0[63][20] = 4'h6;
        frame0[63][21] = 4'h6;
        frame0[63][22] = 4'h6;
        frame0[63][23] = 4'h6;
        frame0[63][24] = 4'h6;
        frame0[63][25] = 4'h6;
        frame0[63][26] = 4'h6;
        frame0[63][27] = 4'h6;
        frame0[63][28] = 4'h6;
        frame0[63][29] = 4'h6;
        frame0[63][30] = 4'h6;
        frame0[63][31] = 4'h6;
        frame0[63][32] = 4'h6;
        frame0[63][33] = 4'h6;
        frame0[63][34] = 4'h6;
        frame0[63][35] = 4'h6;
        frame0[63][36] = 4'h6;
        frame0[63][37] = 4'h6;
        frame0[63][38] = 4'h6;
        frame0[63][39] = 4'h6;
        frame0[63][40] = 4'h6;
        frame0[63][41] = 4'h6;
        frame0[63][42] = 4'h6;
        frame0[63][43] = 4'h6;
        frame0[63][44] = 4'h6;
        frame0[63][45] = 4'h6;
        frame0[63][46] = 4'h6;
        frame0[63][47] = 4'h6;
        frame0[63][48] = 4'h6;
        frame0[63][49] = 4'h6;
        frame0[63][50] = 4'h6;
        frame0[63][51] = 4'h6;
        frame0[63][52] = 4'h6;
        frame0[63][53] = 4'h6;
        frame0[63][54] = 4'h6;
        frame0[63][55] = 4'h6;
        frame0[63][56] = 4'h6;
        frame0[63][57] = 4'h6;
        frame0[63][58] = 4'h6;
        frame0[63][59] = 4'h6;
        frame0[63][60] = 4'h6;
        frame0[63][61] = 4'h6;
        frame0[63][62] = 4'h6;

        // etc...
    end

    assign pixel = frame0[y][x];

endmodule


//------------------------------------------------------------
// 16-color PALETTE (each has 4 subpixel RGB entries)
// palette[index][subpixel] → 6-bit {r,g,b}
//------------------------------------------------------------
module palette_lut(
    input  wire [3:0] index,      // 0–15
    input  wire [3:0] subpixel,   // 0–3 (2×2 upscale)
    output reg  [1:0] r,
    output reg  [1:0] g,
    output reg  [1:0] b
);

    // palette[index][subpixel] = 6-bit  {r,g,b}
    // 16 palette entries, each with 4 subpixels
    reg [5:0] palette [0:15][0:3];

    initial begin
        // Example palette — same values you had
        palette[4'h0][0] = {2'b00, 2'b00, 2'b00}; // black
        palette[4'h0][1] = {2'b00, 2'b00, 2'b00};
        palette[4'h0][2] = {2'b00, 2'b00, 2'b00};
        palette[4'h0][3] = {2'b00, 2'b00, 2'b00};

        palette[4'h1][0] = {2'b11, 2'b00, 2'b00}; // red
        palette[4'h1][1] = {2'b11, 2'b00, 2'b00};
        palette[4'h1][2] = {2'b11, 2'b00, 2'b00};
        palette[4'h1][3] = {2'b11, 2'b00, 2'b00};

        palette[4'h2][0] = {2'b00, 2'b11, 2'b00}; // green
        palette[4'h2][1] = {2'b00, 2'b11, 2'b00};
        palette[4'h2][2] = {2'b00, 2'b11, 2'b00};
        palette[4'h2][3] = {2'b00, 2'b11, 2'b00};

        palette[4'h3][0] = {2'b01, 2'b00, 2'b00}; // brown
        palette[4'h3][1] = {2'b01, 2'b00, 2'b00};
        palette[4'h3][2] = {2'b01, 2'b00, 2'b00};
        palette[4'h3][3] = {2'b01, 2'b00, 2'b00};

        palette[4'h4][0] = {2'b11, 2'b10, 2'b00}; // orange
        palette[4'h4][1] = {2'b11, 2'b10, 2'b00};
        palette[4'h4][2] = {2'b11, 2'b10, 2'b00};
        palette[4'h4][3] = {2'b11, 2'b10, 2'b00};

        palette[4'h5][0] = {2'b00, 2'b11, 2'b11}; // blue
        palette[4'h5][1] = {2'b00, 2'b11, 2'b11};
        palette[4'h5][2] = {2'b00, 2'b11, 2'b11};
        palette[4'h5][3] = {2'b00, 2'b11, 2'b11};

        palette[4'h6][0] = {2'b00, 2'b01, 2'b11}; // Blended blue
        palette[4'h6][1] = {2'b00, 2'b01, 2'b11};
        palette[4'h6][2] = {2'b00, 2'b01, 2'b01};
        palette[4'h6][3] = {2'b00, 2'b01, 2'b10};
        palette[4'h6][4] = {2'b00, 2'b01, 2'b01};
        palette[4'h6][5] = {2'b00, 2'b01, 2'b11};
        palette[4'h6][6] = {2'b01, 2'b01, 2'b01};
        palette[4'h6][7] = {2'b00, 2'b01, 2'b01};
        // ... keep adding colors 3-F here ...
    end

    // Output one 6-bit RGB value
    always @(*) begin
        {r, g, b} = palette[index][subpixel];
    end

endmodule
