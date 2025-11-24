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
    wire sound;

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = {sound, 7'b0};
    assign uio_oe  = 8'hff;

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
    wire [2:0] pixel_index0;
    wire [2:0] pixel_index1;
    wire [2:0] pixel_index2;
    wire [2:0] pixel_index3;

    wire in_shape = pix_x[8] && !pix_x[9] && !pix_y[8];

    reg [2:0] pixel_index;

    always @* begin
        case (frame_num)
            2'b00: pixel_index = pixel_index0;
            2'b01: pixel_index = pixel_index1;
            2'b10: pixel_index = pixel_index2;
            2'b11: pixel_index = pixel_index3;
            default: pixel_index = 0;
        endcase
    end

    wire [9:0] vert_pos = pix_y - 50;

    frame0_lut frame0 (
        .x(pix_x[7:3]),
        .y(vert_pos[7:3]),
        .pixel0(pixel_index0),
        .pixel1(pixel_index1),
        .pixel2(pixel_index2),
        .pixel3(pixel_index3)
    );

    // background
    wire in_bg = (!pixel_index[2] && !pixel_index[1] && !pixel_index[0]) || !in_shape;

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

    reg [1:0] bg_r;
    reg [1:0] bg_g;
    reg [1:0] bg_b;

    wire [1:0] bg_r_grass;
    wire [1:0] bg_g_grass;
    wire [1:0] bg_b_grass;

    wire [1:0] bg_r_uw;
    wire [1:0] bg_g_uw;
    wire [1:0] bg_b_uw;

    grass_bg grass_bg_inst (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .r(bg_r_grass),
        .g(bg_g_grass),
        .b(bg_b_grass)
    );

    uw_bouncing uw_bouncing_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .r(bg_r_uw),
        .g(bg_g_uw),
        .b(bg_b_uw)
    );

  always @(*) begin
      case (ui_in[1:0])
          2'b00: begin
              bg_r = bg_r_grass;
              bg_g = bg_g_grass;
              bg_b = bg_b_grass;
          end
          2'b01: begin
              bg_r = bg_r_uw;
              bg_g = bg_g_uw;
              bg_b = bg_b_uw;
          end
          2'b10: begin
              bg_r = 2'b00;
              bg_g = 2'b01;
              bg_b = 2'b11;
          end
          2'b11: begin
              bg_r = 2'b00;
              bg_g = 2'b11;
              bg_b = 2'b01;
          end
      endcase
  end

  sound_module sound_inst(
    .clk(clk),
    .rst_n(rst_n),
    .frame_counter(frame_counter),
    .x(pix_x),
    .y(pix_y),
    .sound(sound)
);

    //------------------------------------------------------------
    // Drive video
    //------------------------------------------------------------
    assign R = video_active ? in_bg ? bg_r : pal_r : 2'b00;
    assign G = video_active ? in_bg ? bg_g : pal_g : 2'b00;
    assign B = video_active ? in_bg ? bg_b : pal_b : 2'b00;

    reg [6:0] frame_counter;
    reg [1:0] frame_num;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_counter <= 0;
            frame_num <= 0;
        end else begin
            if (pix_x == 0 && pix_y == 0) begin
                frame_counter <= frame_counter + 1;
                
                if (frame_counter[2] & !frame_counter[1] & !frame_counter[0]) begin
                    frame_num <= frame_num + 1;
                end
            end
        end
    end
endmodule

module uw_bouncing(
    input wire clk,      // clock
    input wire rst_n,    // reset_n - low to reset
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    output wire [1:0] r,
    output wire [1:0] g,
    output wire [1:0] b
);

    reg uw_frame [0:11][0:36];
    initial begin
        uw_frame[0][0] = 1'b1;
        uw_frame[0][1] = 1'b1;
        uw_frame[0][2] = 1'b1;
        uw_frame[0][3] = 1'b1;
        uw_frame[0][4] = 1'b0;
        uw_frame[0][5] = 1'b0;
        uw_frame[0][6] = 1'b0;
        uw_frame[0][7] = 1'b0;
        uw_frame[0][8] = 1'b0;
        uw_frame[0][9] = 1'b0;
        uw_frame[0][10] = 1'b0;
        uw_frame[0][11] = 1'b1;
        uw_frame[0][12] = 1'b1;
        uw_frame[0][13] = 1'b1;
        uw_frame[0][14] = 1'b1;
        uw_frame[0][15] = 1'b0;
        uw_frame[0][16] = 1'b1;
        uw_frame[0][17] = 1'b1;
        uw_frame[0][18] = 1'b1;
        uw_frame[0][19] = 1'b1;
        uw_frame[0][20] = 1'b0;
        uw_frame[0][21] = 1'b0;
        uw_frame[0][22] = 1'b0;
        uw_frame[0][23] = 1'b0;
        uw_frame[0][24] = 1'b0;
        uw_frame[0][25] = 1'b0;
        uw_frame[0][26] = 1'b0;
        uw_frame[0][27] = 1'b0;
        uw_frame[0][28] = 1'b0;
        uw_frame[0][29] = 1'b0;
        uw_frame[0][30] = 1'b0;
        uw_frame[0][31] = 1'b0;
        uw_frame[0][32] = 1'b0;
        uw_frame[0][33] = 1'b1;
        uw_frame[0][34] = 1'b1;
        uw_frame[0][35] = 1'b1;
        uw_frame[0][36] = 1'b1;

        uw_frame[1][0] = 1'b1;
        uw_frame[1][1] = 1'b1;
        uw_frame[1][2] = 1'b1;
        uw_frame[1][3] = 1'b1;
        uw_frame[1][4] = 1'b0;
        uw_frame[1][5] = 1'b0;
        uw_frame[1][6] = 1'b0;
        uw_frame[1][7] = 1'b0;
        uw_frame[1][8] = 1'b0;
        uw_frame[1][9] = 1'b0;
        uw_frame[1][10] = 1'b0;
        uw_frame[1][11] = 1'b1;
        uw_frame[1][12] = 1'b1;
        uw_frame[1][13] = 1'b1;
        uw_frame[1][14] = 1'b1;
        uw_frame[1][15] = 1'b0;
        uw_frame[1][16] = 1'b1;
        uw_frame[1][17] = 1'b1;
        uw_frame[1][18] = 1'b1;
        uw_frame[1][19] = 1'b1;
        uw_frame[1][20] = 1'b0;
        uw_frame[1][21] = 1'b0;
        uw_frame[1][22] = 1'b0;
        uw_frame[1][23] = 1'b0;
        uw_frame[1][24] = 1'b0;
        uw_frame[1][25] = 1'b0;
        uw_frame[1][26] = 1'b0;
        uw_frame[1][27] = 1'b0;
        uw_frame[1][28] = 1'b0;
        uw_frame[1][29] = 1'b0;
        uw_frame[1][30] = 1'b0;
        uw_frame[1][31] = 1'b0;
        uw_frame[1][32] = 1'b0;
        uw_frame[1][33] = 1'b1;
        uw_frame[1][34] = 1'b1;
        uw_frame[1][35] = 1'b1;
        uw_frame[1][36] = 1'b1;
        
        uw_frame[2][0] = 1'b1;
        uw_frame[2][1] = 1'b1;
        uw_frame[2][2] = 1'b1;
        uw_frame[2][3] = 1'b1;
        uw_frame[2][4] = 1'b0;
        uw_frame[2][5] = 1'b0;
        uw_frame[2][6] = 1'b0;
        uw_frame[2][7] = 1'b0;
        uw_frame[2][8] = 1'b0;
        uw_frame[2][9] = 1'b0;
        uw_frame[2][10] = 1'b0;
        uw_frame[2][11] = 1'b1;
        uw_frame[2][12] = 1'b1;
        uw_frame[2][13] = 1'b1;
        uw_frame[2][14] = 1'b1;
        uw_frame[2][15] = 1'b0;
        uw_frame[2][16] = 1'b1;
        uw_frame[2][17] = 1'b1;
        uw_frame[2][18] = 1'b1;
        uw_frame[2][19] = 1'b1;
        uw_frame[2][20] = 1'b0;
        uw_frame[2][21] = 1'b0;
        uw_frame[2][22] = 1'b0;
        uw_frame[2][23] = 1'b0;
        uw_frame[2][24] = 1'b0;
        uw_frame[2][25] = 1'b1;
        uw_frame[2][26] = 1'b1;
        uw_frame[2][27] = 1'b1;
        uw_frame[2][28] = 1'b0;
        uw_frame[2][29] = 1'b0;
        uw_frame[2][30] = 1'b0;
        uw_frame[2][31] = 1'b0;
        uw_frame[2][32] = 1'b0;
        uw_frame[2][33] = 1'b1;
        uw_frame[2][34] = 1'b1;
        uw_frame[2][35] = 1'b1;
        uw_frame[2][36] = 1'b1;

        uw_frame[3][0] = 1'b1;
        uw_frame[3][1] = 1'b1;
        uw_frame[3][2] = 1'b1;
        uw_frame[3][3] = 1'b1;
        uw_frame[3][4] = 1'b0;
        uw_frame[3][5] = 1'b0;
        uw_frame[3][6] = 1'b0;
        uw_frame[3][7] = 1'b0;
        uw_frame[3][8] = 1'b0;
        uw_frame[3][9] = 1'b0;
        uw_frame[3][10] = 1'b0;
        uw_frame[3][11] = 1'b1;
        uw_frame[3][12] = 1'b1;
        uw_frame[3][13] = 1'b1;
        uw_frame[3][14] = 1'b1;
        uw_frame[3][15] = 1'b0;
        uw_frame[3][16] = 1'b1;
        uw_frame[3][17] = 1'b1;
        uw_frame[3][18] = 1'b1;
        uw_frame[3][19] = 1'b1;
        uw_frame[3][20] = 1'b1;
        uw_frame[3][21] = 1'b0;
        uw_frame[3][22] = 1'b0;
        uw_frame[3][23] = 1'b0;
        uw_frame[3][24] = 1'b1;
        uw_frame[3][25] = 1'b1;
        uw_frame[3][26] = 1'b1;
        uw_frame[3][27] = 1'b1;
        uw_frame[3][28] = 1'b1;
        uw_frame[3][29] = 1'b0;
        uw_frame[3][30] = 1'b0;
        uw_frame[3][31] = 1'b0;
        uw_frame[3][32] = 1'b1;
        uw_frame[3][33] = 1'b1;
        uw_frame[3][34] = 1'b1;
        uw_frame[3][35] = 1'b1;
        uw_frame[3][36] = 1'b1;

        uw_frame[4][0] = 1'b1;
        uw_frame[4][1] = 1'b1;
        uw_frame[4][2] = 1'b1;
        uw_frame[4][3] = 1'b1;
        uw_frame[4][4] = 1'b0;
        uw_frame[4][5] = 1'b0;
        uw_frame[4][6] = 1'b0;
        uw_frame[4][7] = 1'b0;
        uw_frame[4][8] = 1'b0;
        uw_frame[4][9] = 1'b0;
        uw_frame[4][10] = 1'b0;
        uw_frame[4][11] = 1'b1;
        uw_frame[4][12] = 1'b1;
        uw_frame[4][13] = 1'b1;
        uw_frame[4][14] = 1'b1;
        uw_frame[4][15] = 1'b0;
        uw_frame[4][16] = 1'b0;
        uw_frame[4][17] = 1'b1;
        uw_frame[4][18] = 1'b1;
        uw_frame[4][19] = 1'b1;
        uw_frame[4][20] = 1'b1;
        uw_frame[4][21] = 1'b0;
        uw_frame[4][22] = 1'b0;
        uw_frame[4][23] = 1'b0;
        uw_frame[4][24] = 1'b1;
        uw_frame[4][25] = 1'b1;
        uw_frame[4][26] = 1'b1;
        uw_frame[4][27] = 1'b1;
        uw_frame[4][28] = 1'b1;
        uw_frame[4][29] = 1'b0;
        uw_frame[4][30] = 1'b0;
        uw_frame[4][31] = 1'b0;
        uw_frame[4][32] = 1'b1;
        uw_frame[4][33] = 1'b1;
        uw_frame[4][34] = 1'b1;
        uw_frame[4][35] = 1'b1;
        uw_frame[4][36] = 1'b0;

        uw_frame[5][0] = 1'b0;
        uw_frame[5][1] = 1'b1;
        uw_frame[5][2] = 1'b1;
        uw_frame[5][3] = 1'b1;
        uw_frame[5][4] = 1'b1;
        uw_frame[5][5] = 1'b0;
        uw_frame[5][6] = 1'b0;
        uw_frame[5][7] = 1'b0;
        uw_frame[5][8] = 1'b0;
        uw_frame[5][9] = 1'b0;
        uw_frame[5][10] = 1'b1;
        uw_frame[5][11] = 1'b1;
        uw_frame[5][12] = 1'b1;
        uw_frame[5][13] = 1'b1;
        uw_frame[5][14] = 1'b0;
        uw_frame[5][15] = 1'b0;
        uw_frame[5][16] = 1'b0;
        uw_frame[5][17] = 1'b1;
        uw_frame[5][18] = 1'b1;
        uw_frame[5][19] = 1'b1;
        uw_frame[5][20] = 1'b1;
        uw_frame[5][21] = 1'b1;
        uw_frame[5][22] = 1'b0;
        uw_frame[5][23] = 1'b1;
        uw_frame[5][24] = 1'b1;
        uw_frame[5][25] = 1'b1;
        uw_frame[5][26] = 1'b1;
        uw_frame[5][27] = 1'b1;
        uw_frame[5][28] = 1'b1;
        uw_frame[5][29] = 1'b1;
        uw_frame[5][30] = 1'b0;
        uw_frame[5][31] = 1'b1;
        uw_frame[5][32] = 1'b1;
        uw_frame[5][33] = 1'b1;
        uw_frame[5][34] = 1'b1;
        uw_frame[5][35] = 1'b1;
        uw_frame[5][36] = 1'b0;

        uw_frame[6][0] = 1'b0;
        uw_frame[6][1] = 1'b1;
        uw_frame[6][2] = 1'b1;
        uw_frame[6][3] = 1'b1;
        uw_frame[6][4] = 1'b1;
        uw_frame[6][5] = 1'b0;
        uw_frame[6][6] = 1'b0;
        uw_frame[6][7] = 1'b0;
        uw_frame[6][8] = 1'b0;
        uw_frame[6][9] = 1'b0;
        uw_frame[6][10] = 1'b1;
        uw_frame[6][11] = 1'b1;
        uw_frame[6][12] = 1'b1;
        uw_frame[6][13] = 1'b1;
        uw_frame[6][14] = 1'b0;
        uw_frame[6][15] = 1'b0;
        uw_frame[6][16] = 1'b0;
        uw_frame[6][17] = 1'b0;
        uw_frame[6][18] = 1'b1;
        uw_frame[6][19] = 1'b1;
        uw_frame[6][20] = 1'b1;
        uw_frame[6][21] = 1'b1;
        uw_frame[6][22] = 1'b0;
        uw_frame[6][23] = 1'b1;
        uw_frame[6][24] = 1'b1;
        uw_frame[6][25] = 1'b1;
        uw_frame[6][26] = 1'b1;
        uw_frame[6][27] = 1'b1;
        uw_frame[6][28] = 1'b1;
        uw_frame[6][29] = 1'b1;
        uw_frame[6][30] = 1'b0;
        uw_frame[6][31] = 1'b1;
        uw_frame[6][32] = 1'b1;
        uw_frame[6][33] = 1'b1;
        uw_frame[6][34] = 1'b1;
        uw_frame[6][35] = 1'b0;
        uw_frame[6][36] = 1'b0;

        uw_frame[7][0] = 1'b0;
        uw_frame[7][1] = 1'b1;
        uw_frame[7][2] = 1'b1;
        uw_frame[7][3] = 1'b1;
        uw_frame[7][4] = 1'b1;
        uw_frame[7][5] = 1'b1;
        uw_frame[7][6] = 1'b0;
        uw_frame[7][7] = 1'b0;
        uw_frame[7][8] = 1'b0;
        uw_frame[7][9] = 1'b1;
        uw_frame[7][10] = 1'b1;
        uw_frame[7][11] = 1'b1;
        uw_frame[7][12] = 1'b1;
        uw_frame[7][13] = 1'b1;
        uw_frame[7][14] = 1'b0;
        uw_frame[7][15] = 1'b0;
        uw_frame[7][16] = 1'b0;
        uw_frame[7][17] = 1'b0;
        uw_frame[7][18] = 1'b1;
        uw_frame[7][19] = 1'b1;
        uw_frame[7][20] = 1'b1;
        uw_frame[7][21] = 1'b1;
        uw_frame[7][22] = 1'b1;
        uw_frame[7][23] = 1'b1;
        uw_frame[7][24] = 1'b1;
        uw_frame[7][25] = 1'b1;
        uw_frame[7][26] = 1'b0;
        uw_frame[7][27] = 1'b1;
        uw_frame[7][28] = 1'b1;
        uw_frame[7][29] = 1'b1;
        uw_frame[7][30] = 1'b1;
        uw_frame[7][31] = 1'b1;
        uw_frame[7][32] = 1'b1;
        uw_frame[7][33] = 1'b1;
        uw_frame[7][34] = 1'b1;
        uw_frame[7][35] = 1'b0;
        uw_frame[7][36] = 1'b0;

        uw_frame[8][0] = 1'b0;
        uw_frame[8][1] = 1'b0;
        uw_frame[8][2] = 1'b1;
        uw_frame[8][3] = 1'b1;
        uw_frame[8][4] = 1'b1;
        uw_frame[8][5] = 1'b1;
        uw_frame[8][6] = 1'b0;
        uw_frame[8][7] = 1'b0;
        uw_frame[8][8] = 1'b0;
        uw_frame[8][9] = 1'b1;
        uw_frame[8][10] = 1'b1;
        uw_frame[8][11] = 1'b1;
        uw_frame[8][12] = 1'b1;
        uw_frame[8][13] = 1'b0;
        uw_frame[8][14] = 1'b0;
        uw_frame[8][15] = 1'b0;
        uw_frame[8][16] = 1'b0;
        uw_frame[8][17] = 1'b0;
        uw_frame[8][18] = 1'b0;
        uw_frame[8][19] = 1'b1;
        uw_frame[8][20] = 1'b1;
        uw_frame[8][21] = 1'b1;
        uw_frame[8][22] = 1'b1;
        uw_frame[8][23] = 1'b1;
        uw_frame[8][24] = 1'b1;
        uw_frame[8][25] = 1'b0;
        uw_frame[8][26] = 1'b0;
        uw_frame[8][27] = 1'b0;
        uw_frame[8][28] = 1'b1;
        uw_frame[8][29] = 1'b1;
        uw_frame[8][30] = 1'b1;
        uw_frame[8][31] = 1'b1;
        uw_frame[8][32] = 1'b1;
        uw_frame[8][33] = 1'b1;
        uw_frame[8][34] = 1'b0;
        uw_frame[8][35] = 1'b0;
        uw_frame[8][36] = 1'b0;

        uw_frame[9][0] = 1'b0;
        uw_frame[9][1] = 1'b0;
        uw_frame[9][2] = 1'b1;
        uw_frame[9][3] = 1'b1;
        uw_frame[9][4] = 1'b1;
        uw_frame[9][5] = 1'b1;
        uw_frame[9][6] = 1'b1;
        uw_frame[9][7] = 1'b1;
        uw_frame[9][8] = 1'b1;
        uw_frame[9][9] = 1'b1;
        uw_frame[9][10] = 1'b1;
        uw_frame[9][11] = 1'b1;
        uw_frame[9][12] = 1'b1;
        uw_frame[9][13] = 1'b0;
        uw_frame[9][14] = 1'b0;
        uw_frame[9][15] = 1'b0;
        uw_frame[9][16] = 1'b0;
        uw_frame[9][17] = 1'b0;
        uw_frame[9][18] = 1'b0;
        uw_frame[9][19] = 1'b0;
        uw_frame[9][20] = 1'b1;
        uw_frame[9][21] = 1'b1;
        uw_frame[9][22] = 1'b1;
        uw_frame[9][23] = 1'b1;
        uw_frame[9][24] = 1'b1;
        uw_frame[9][25] = 1'b0;
        uw_frame[9][26] = 1'b0;
        uw_frame[9][27] = 1'b0;
        uw_frame[9][28] = 1'b1;
        uw_frame[9][29] = 1'b1;
        uw_frame[9][30] = 1'b1;
        uw_frame[9][31] = 1'b1;
        uw_frame[9][32] = 1'b1;
        uw_frame[9][33] = 1'b0;
        uw_frame[9][34] = 1'b0;
        uw_frame[9][35] = 1'b0;
        uw_frame[9][36] = 1'b0;

        uw_frame[10][0] = 1'b0;
        uw_frame[10][1] = 1'b0;
        uw_frame[10][2] = 1'b0;
        uw_frame[10][3] = 1'b1;
        uw_frame[10][4] = 1'b1;
        uw_frame[10][5] = 1'b1;
        uw_frame[10][6] = 1'b1;
        uw_frame[10][7] = 1'b1;
        uw_frame[10][8] = 1'b1;
        uw_frame[10][9] = 1'b1;
        uw_frame[10][10] = 1'b1;
        uw_frame[10][11] = 1'b1;
        uw_frame[10][12] = 1'b0;
        uw_frame[10][13] = 1'b0;
        uw_frame[10][14] = 1'b0;
        uw_frame[10][15] = 1'b0;
        uw_frame[10][16] = 1'b0;
        uw_frame[10][17] = 1'b0;
        uw_frame[10][18] = 1'b0;
        uw_frame[10][19] = 1'b0;
        uw_frame[10][20] = 1'b1;
        uw_frame[10][21] = 1'b1;
        uw_frame[10][22] = 1'b1;
        uw_frame[10][23] = 1'b1;
        uw_frame[10][24] = 1'b0;
        uw_frame[10][25] = 1'b0;
        uw_frame[10][26] = 1'b0;
        uw_frame[10][27] = 1'b0;
        uw_frame[10][28] = 1'b0;
        uw_frame[10][29] = 1'b1;
        uw_frame[10][30] = 1'b1;
        uw_frame[10][31] = 1'b1;
        uw_frame[10][32] = 1'b1;
        uw_frame[10][33] = 1'b0;
        uw_frame[10][34] = 1'b0;
        uw_frame[10][35] = 1'b0;
        uw_frame[10][36] = 1'b0;

        uw_frame[11][0] = 1'b0;
        uw_frame[11][1] = 1'b0;
        uw_frame[11][2] = 1'b0;
        uw_frame[11][3] = 1'b0;
        uw_frame[11][4] = 1'b1;
        uw_frame[11][5] = 1'b1;
        uw_frame[11][6] = 1'b1;
        uw_frame[11][7] = 1'b1;
        uw_frame[11][8] = 1'b1;
        uw_frame[11][9] = 1'b1;
        uw_frame[11][10] = 1'b1;
        uw_frame[11][11] = 1'b0;
        uw_frame[11][12] = 1'b0;
        uw_frame[11][13] = 1'b0;
        uw_frame[11][14] = 1'b0;
        uw_frame[11][15] = 1'b0;
        uw_frame[11][16] = 1'b0;
        uw_frame[11][17] = 1'b0;
        uw_frame[11][18] = 1'b0;
        uw_frame[11][19] = 1'b0;
        uw_frame[11][20] = 1'b0;
        uw_frame[11][21] = 1'b1;
        uw_frame[11][22] = 1'b1;
        uw_frame[11][23] = 1'b0;
        uw_frame[11][24] = 1'b0;
        uw_frame[11][25] = 1'b0;
        uw_frame[11][26] = 1'b0;
        uw_frame[11][27] = 1'b0;
        uw_frame[11][28] = 1'b0;
        uw_frame[11][29] = 1'b0;
        uw_frame[11][30] = 1'b1;
        uw_frame[11][31] = 1'b1;
        uw_frame[11][32] = 1'b0;
        uw_frame[11][33] = 1'b0;
        uw_frame[11][34] = 1'b0;
        uw_frame[11][35] = 1'b0;
        uw_frame[11][36] = 1'b0;
    end

    // Define square position and size
    localparam SCREEN_PADDING = 32;
    localparam UW_REC_WIDTH = 37;
    localparam UW_REC_HEIGHT = 12;
    
    reg uw_x_dir_right = 1;
    reg uw_y_dir_down = 1;

    reg [9:0] uw_x_pos;
    reg [9:0] uw_y_pos;
    
    wire [9:0] uw_right_edge;
    wire [9:0] uw_bot_edge;
    assign uw_right_edge = uw_x_pos + UW_REC_WIDTH;
    assign uw_bot_edge = uw_y_pos + UW_REC_HEIGHT;
    
    wire in_logo;
    assign in_logo = (pix_x >= uw_x_pos) && (pix_x < uw_x_pos + UW_REC_WIDTH) && 
        (pix_y >= uw_y_pos) && (pix_y < uw_y_pos + UW_REC_HEIGHT);

    wire [9:0] uw_x = pix_x - uw_x_pos;
    wire [9:0] uw_y = pix_y - uw_y_pos;
    wire colour = uw_frame[uw_y][uw_x];

    assign r = in_logo ? {!colour, !colour} : 2'b11;
    assign g = in_logo ? {!colour, !colour} : 2'b11;
    assign b = in_logo ? {2'b00} : 2'b00;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uw_x_pos <= SCREEN_PADDING;
            uw_y_pos <= SCREEN_PADDING;
            uw_x_dir_right <= 1'b1;
            uw_y_dir_down  <= 1'b1;
        end 
        else begin
          if (pix_x == 0 && pix_y == 0) begin
            // Move horizontally
            if (uw_x_dir_right) begin
                uw_x_pos <= uw_x_pos + 1;
            end else begin
                uw_x_pos <= uw_x_pos - 1;
            end

            // Move vertically
            if (uw_y_dir_down) begin
                uw_y_pos <= uw_y_pos + 1;
            end else begin
                uw_y_pos <= uw_y_pos - 1;
            end

            // Bounce off edges
            if (uw_right_edge[9] && uw_right_edge[6]) begin
                uw_x_dir_right <= 1'b0; // move left
            end else if (!uw_x_pos[9] & !uw_x_pos[8] & !uw_x_pos[7] & !uw_x_pos[6] & !uw_x_pos[5]) begin
                uw_x_dir_right <= 1'b1; // move right
            end

            if (uw_bot_edge[8] && uw_bot_edge[7] && uw_bot_edge[6]) begin
                uw_y_dir_down <= 1'b0;  // move up
            end else if (!uw_y_pos[9] & !uw_y_pos[8] & !uw_y_pos[7] & !uw_y_pos[6] & !uw_y_pos[5]) begin
                uw_y_dir_down <= 1'b1;  // move down
            end
          end
        end
    end
  
endmodule
//------------------------------------------------------------
// 32×32 FRAME — bitmap stored in frame0[y][x]
//     frame0[][] contains a 4-bit palette index
//------------------------------------------------------------
module frame0_lut(
    input  wire [4:0] x,    // 0–31
    input  wire [4:0] y,    // 0–31
    output wire [2:0] pixel0,
    output wire [2:0] pixel1,
    output wire [2:0] pixel2,
    output wire [2:0] pixel3
);

reg [2:0] frame0 [0:24][0:24];
initial begin
    frame0[0][0] = 3'd0;
    frame0[0][1] = 3'd0;
    frame0[0][2] = 3'd0;
    frame0[0][3] = 3'd0;
    frame0[0][4] = 3'd0;
    frame0[0][5] = 3'd0;
    frame0[0][6] = 3'd0;
    frame0[0][7] = 3'd0;
    frame0[0][8] = 3'd0;
    frame0[0][9] = 3'd0;
    frame0[0][10] = 3'd0;
    frame0[0][11] = 3'd0;
    frame0[0][12] = 3'd0;
    frame0[0][13] = 3'd0;
    frame0[0][14] = 3'd0;
    frame0[0][15] = 3'd0;
    frame0[0][16] = 3'd0;
    frame0[0][17] = 3'd0;
    frame0[0][18] = 3'd0;
    frame0[0][19] = 3'd0;
    frame0[0][20] = 3'd0;
    frame0[0][21] = 3'd0;
    frame0[0][22] = 3'd0;
    frame0[0][23] = 3'd0;
    frame0[0][24] = 3'd0;
    frame0[1][0] = 3'd0;
    frame0[1][1] = 3'd0;
    frame0[1][2] = 3'd0;
    frame0[1][3] = 3'd0;
    frame0[1][4] = 3'd0;
    frame0[1][5] = 3'd0;
    frame0[1][6] = 3'd0;
    frame0[1][7] = 3'd0;
    frame0[1][8] = 3'd0;
    frame0[1][9] = 3'd0;
    frame0[1][10] = 3'd1;
    frame0[1][11] = 3'd1;
    frame0[1][12] = 3'd1;
    frame0[1][13] = 3'd1;
    frame0[1][14] = 3'd1;
    frame0[1][15] = 3'd0;
    frame0[1][16] = 3'd0;
    frame0[1][17] = 3'd0;
    frame0[1][18] = 3'd0;
    frame0[1][19] = 3'd0;
    frame0[1][20] = 3'd0;
    frame0[1][21] = 3'd0;
    frame0[1][22] = 3'd0;
    frame0[1][23] = 3'd0;
    frame0[1][24] = 3'd0;
    frame0[2][0] = 3'd0;
    frame0[2][1] = 3'd0;
    frame0[2][2] = 3'd0;
    frame0[2][3] = 3'd0;
    frame0[2][4] = 3'd0;
    frame0[2][5] = 3'd0;
    frame0[2][6] = 3'd0;
    frame0[2][7] = 3'd0;
    frame0[2][8] = 3'd0;
    frame0[2][9] = 3'd2;
    frame0[2][10] = 3'd2;
    frame0[2][11] = 3'd2;
    frame0[2][12] = 3'd2;
    frame0[2][13] = 3'd2;
    frame0[2][14] = 3'd2;
    frame0[2][15] = 3'd2;
    frame0[2][16] = 3'd0;
    frame0[2][17] = 3'd0;
    frame0[2][18] = 3'd0;
    frame0[2][19] = 3'd0;
    frame0[2][20] = 3'd0;
    frame0[2][21] = 3'd0;
    frame0[2][22] = 3'd0;
    frame0[2][23] = 3'd0;
    frame0[2][24] = 3'd0;
    frame0[3][0] = 3'd0;
    frame0[3][1] = 3'd0;
    frame0[3][2] = 3'd0;
    frame0[3][3] = 3'd0;
    frame0[3][4] = 3'd0;
    frame0[3][5] = 3'd0;
    frame0[3][6] = 3'd0;
    frame0[3][7] = 3'd0;
    frame0[3][8] = 3'd0;
    frame0[3][9] = 3'd1;
    frame0[3][10] = 3'd1;
    frame0[3][11] = 3'd2;
    frame0[3][12] = 3'd2;
    frame0[3][13] = 3'd2;
    frame0[3][14] = 3'd1;
    frame0[3][15] = 3'd1;
    frame0[3][16] = 3'd0;
    frame0[3][17] = 3'd0;
    frame0[3][18] = 3'd0;
    frame0[3][19] = 3'd0;
    frame0[3][20] = 3'd0;
    frame0[3][21] = 3'd0;
    frame0[3][22] = 3'd0;
    frame0[3][23] = 3'd0;
    frame0[3][24] = 3'd0;
    frame0[4][0] = 3'd0;
    frame0[4][1] = 3'd0;
    frame0[4][2] = 3'd0;
    frame0[4][3] = 3'd0;
    frame0[4][4] = 3'd0;
    frame0[4][5] = 3'd0;
    frame0[4][6] = 3'd0;
    frame0[4][7] = 3'd0;
    frame0[4][8] = 3'd0;
    frame0[4][9] = 3'd3;
    frame0[4][10] = 3'd1;
    frame0[4][11] = 3'd2;
    frame0[4][12] = 3'd2;
    frame0[4][13] = 3'd2;
    frame0[4][14] = 3'd1;
    frame0[4][15] = 3'd3;
    frame0[4][16] = 3'd0;
    frame0[4][17] = 3'd0;
    frame0[4][18] = 3'd0;
    frame0[4][19] = 3'd0;
    frame0[4][20] = 3'd0;
    frame0[4][21] = 3'd0;
    frame0[4][22] = 3'd0;
    frame0[4][23] = 3'd0;
    frame0[4][24] = 3'd0;
    frame0[5][0] = 3'd0;
    frame0[5][1] = 3'd0;
    frame0[5][2] = 3'd0;
    frame0[5][3] = 3'd0;
    frame0[5][4] = 3'd0;
    frame0[5][5] = 3'd0;
    frame0[5][6] = 3'd0;
    frame0[5][7] = 3'd0;
    frame0[5][8] = 3'd0;
    frame0[5][9] = 3'd1;
    frame0[5][10] = 3'd1;
    frame0[5][11] = 3'd3;
    frame0[5][12] = 3'd1;
    frame0[5][13] = 3'd3;
    frame0[5][14] = 3'd1;
    frame0[5][15] = 3'd1;
    frame0[5][16] = 3'd0;
    frame0[5][17] = 3'd0;
    frame0[5][18] = 3'd0;
    frame0[5][19] = 3'd0;
    frame0[5][20] = 3'd0;
    frame0[5][21] = 3'd0;
    frame0[5][22] = 3'd0;
    frame0[5][23] = 3'd0;
    frame0[5][24] = 3'd0;
    frame0[6][0] = 3'd0;
    frame0[6][1] = 3'd0;
    frame0[6][2] = 3'd0;
    frame0[6][3] = 3'd0;
    frame0[6][4] = 3'd0;
    frame0[6][5] = 3'd0;
    frame0[6][6] = 3'd0;
    frame0[6][7] = 3'd0;
    frame0[6][8] = 3'd0;
    frame0[6][9] = 3'd0;
    frame0[6][10] = 3'd0;
    frame0[6][11] = 3'd1;
    frame0[6][12] = 3'd1;
    frame0[6][13] = 3'd1;
    frame0[6][14] = 3'd0;
    frame0[6][15] = 3'd0;
    frame0[6][16] = 3'd0;
    frame0[6][17] = 3'd0;
    frame0[6][18] = 3'd0;
    frame0[6][19] = 3'd0;
    frame0[6][20] = 3'd0;
    frame0[6][21] = 3'd0;
    frame0[6][22] = 3'd0;
    frame0[6][23] = 3'd0;
    frame0[6][24] = 3'd0;
    frame0[7][0] = 3'd0;
    frame0[7][1] = 3'd0;
    frame0[7][2] = 3'd0;
    frame0[7][3] = 3'd0;
    frame0[7][4] = 3'd0;
    frame0[7][5] = 3'd0;
    frame0[7][6] = 3'd0;
    frame0[7][7] = 3'd0;
    frame0[7][8] = 3'd0;
    frame0[7][9] = 3'd0;
    frame0[7][10] = 3'd0;
    frame0[7][11] = 3'd1;
    frame0[7][12] = 3'd2;
    frame0[7][13] = 3'd1;
    frame0[7][14] = 3'd0;
    frame0[7][15] = 3'd0;
    frame0[7][16] = 3'd0;
    frame0[7][17] = 3'd0;
    frame0[7][18] = 3'd0;
    frame0[7][19] = 3'd0;
    frame0[7][20] = 3'd0;
    frame0[7][21] = 3'd0;
    frame0[7][22] = 3'd0;
    frame0[7][23] = 3'd0;
    frame0[7][24] = 3'd0;
    frame0[8][0] = 3'd0;
    frame0[8][1] = 3'd0;
    frame0[8][2] = 3'd0;
    frame0[8][3] = 3'd0;
    frame0[8][4] = 3'd0;
    frame0[8][5] = 3'd0;
    frame0[8][6] = 3'd0;
    frame0[8][7] = 3'd0;
    frame0[8][8] = 3'd0;
    frame0[8][9] = 3'd0;
    frame0[8][10] = 3'd0;
    frame0[8][11] = 3'd1;
    frame0[8][12] = 3'd2;
    frame0[8][13] = 3'd1;
    frame0[8][14] = 3'd0;
    frame0[8][15] = 3'd0;
    frame0[8][16] = 3'd0;
    frame0[8][17] = 3'd0;
    frame0[8][18] = 3'd0;
    frame0[8][19] = 3'd0;
    frame0[8][20] = 3'd0;
    frame0[8][21] = 3'd0;
    frame0[8][22] = 3'd0;
    frame0[8][23] = 3'd0;
    frame0[8][24] = 3'd0;
    frame0[9][0] = 3'd0;
    frame0[9][1] = 3'd0;
    frame0[9][2] = 3'd0;
    frame0[9][3] = 3'd0;
    frame0[9][4] = 3'd0;
    frame0[9][5] = 3'd0;
    frame0[9][6] = 3'd0;
    frame0[9][7] = 3'd0;
    frame0[9][8] = 3'd0;
    frame0[9][9] = 3'd0;
    frame0[9][10] = 3'd0;
    frame0[9][11] = 3'd1;
    frame0[9][12] = 3'd2;
    frame0[9][13] = 3'd1;
    frame0[9][14] = 3'd0;
    frame0[9][15] = 3'd0;
    frame0[9][16] = 3'd0;
    frame0[9][17] = 3'd0;
    frame0[9][18] = 3'd0;
    frame0[9][19] = 3'd0;
    frame0[9][20] = 3'd0;
    frame0[9][21] = 3'd0;
    frame0[9][22] = 3'd0;
    frame0[9][23] = 3'd0;
    frame0[9][24] = 3'd0;
    frame0[10][0] = 3'd0;
    frame0[10][1] = 3'd0;
    frame0[10][2] = 3'd0;
    frame0[10][3] = 3'd0;
    frame0[10][4] = 3'd0;
    frame0[10][5] = 3'd0;
    frame0[10][6] = 3'd0;
    frame0[10][7] = 3'd0;
    frame0[10][8] = 3'd0;
    frame0[10][9] = 3'd0;
    frame0[10][10] = 3'd1;
    frame0[10][11] = 3'd1;
    frame0[10][12] = 3'd2;
    frame0[10][13] = 3'd1;
    frame0[10][14] = 3'd1;
    frame0[10][15] = 3'd0;
    frame0[10][16] = 3'd0;
    frame0[10][17] = 3'd0;
    frame0[10][18] = 3'd0;
    frame0[10][19] = 3'd0;
    frame0[10][20] = 3'd0;
    frame0[10][21] = 3'd0;
    frame0[10][22] = 3'd0;
    frame0[10][23] = 3'd0;
    frame0[10][24] = 3'd0;
    frame0[11][0] = 3'd0;
    frame0[11][1] = 3'd0;
    frame0[11][2] = 3'd0;
    frame0[11][3] = 3'd0;
    frame0[11][4] = 3'd0;
    frame0[11][5] = 3'd0;
    frame0[11][6] = 3'd0;
    frame0[11][7] = 3'd0;
    frame0[11][8] = 3'd0;
    frame0[11][9] = 3'd1;
    frame0[11][10] = 3'd2;
    frame0[11][11] = 3'd4;
    frame0[11][12] = 3'd4;
    frame0[11][13] = 3'd4;
    frame0[11][14] = 3'd2;
    frame0[11][15] = 3'd1;
    frame0[11][16] = 3'd0;
    frame0[11][17] = 3'd0;
    frame0[11][18] = 3'd0;
    frame0[11][19] = 3'd0;
    frame0[11][20] = 3'd0;
    frame0[11][21] = 3'd0;
    frame0[11][22] = 3'd0;
    frame0[11][23] = 3'd0;
    frame0[11][24] = 3'd0;
    frame0[12][0] = 3'd0;
    frame0[12][1] = 3'd0;
    frame0[12][2] = 3'd0;
    frame0[12][3] = 3'd0;
    frame0[12][4] = 3'd0;
    frame0[12][5] = 3'd0;
    frame0[12][6] = 3'd0;
    frame0[12][7] = 3'd0;
    frame0[12][8] = 3'd0;
    frame0[12][9] = 3'd2;
    frame0[12][10] = 3'd2;
    frame0[12][11] = 3'd4;
    frame0[12][12] = 3'd4;
    frame0[12][13] = 3'd4;
    frame0[12][14] = 3'd2;
    frame0[12][15] = 3'd2;
    frame0[12][16] = 3'd0;
    frame0[12][17] = 3'd0;
    frame0[12][18] = 3'd0;
    frame0[12][19] = 3'd0;
    frame0[12][20] = 3'd0;
    frame0[12][21] = 3'd0;
    frame0[12][22] = 3'd0;
    frame0[12][23] = 3'd0;
    frame0[12][24] = 3'd0;
    frame0[13][0] = 3'd0;
    frame0[13][1] = 3'd0;
    frame0[13][2] = 3'd0;
    frame0[13][3] = 3'd0;
    frame0[13][4] = 3'd0;
    frame0[13][5] = 3'd0;
    frame0[13][6] = 3'd1;
    frame0[13][7] = 3'd1;
    frame0[13][8] = 3'd2;
    frame0[13][9] = 3'd4;
    frame0[13][10] = 3'd4;
    frame0[13][11] = 3'd4;
    frame0[13][12] = 3'd4;
    frame0[13][13] = 3'd4;
    frame0[13][14] = 3'd4;
    frame0[13][15] = 3'd4;
    frame0[13][16] = 3'd2;
    frame0[13][17] = 3'd1;
    frame0[13][18] = 3'd1;
    frame0[13][19] = 3'd0;
    frame0[13][20] = 3'd0;
    frame0[13][21] = 3'd0;
    frame0[13][22] = 3'd0;
    frame0[13][23] = 3'd0;
    frame0[13][24] = 3'd0;
    frame0[14][0] = 3'd0;
    frame0[14][1] = 3'd0;
    frame0[14][2] = 3'd0;
    frame0[14][3] = 3'd0;
    frame0[14][4] = 3'd0;
    frame0[14][5] = 3'd1;
    frame0[14][6] = 3'd1;
    frame0[14][7] = 3'd2;
    frame0[14][8] = 3'd2;
    frame0[14][9] = 3'd4;
    frame0[14][10] = 3'd4;
    frame0[14][11] = 3'd4;
    frame0[14][12] = 3'd4;
    frame0[14][13] = 3'd4;
    frame0[14][14] = 3'd4;
    frame0[14][15] = 3'd4;
    frame0[14][16] = 3'd2;
    frame0[14][17] = 3'd2;
    frame0[14][18] = 3'd1;
    frame0[14][19] = 3'd1;
    frame0[14][20] = 3'd0;
    frame0[14][21] = 3'd0;
    frame0[14][22] = 3'd0;
    frame0[14][23] = 3'd0;
    frame0[14][24] = 3'd0;
    frame0[15][0] = 3'd0;
    frame0[15][1] = 3'd0;
    frame0[15][2] = 3'd0;
    frame0[15][3] = 3'd0;
    frame0[15][4] = 3'd0;
    frame0[15][5] = 3'd1;
    frame0[15][6] = 3'd2;
    frame0[15][7] = 3'd2;
    frame0[15][8] = 3'd2;
    frame0[15][9] = 3'd4;
    frame0[15][10] = 3'd4;
    frame0[15][11] = 3'd4;
    frame0[15][12] = 3'd4;
    frame0[15][13] = 3'd4;
    frame0[15][14] = 3'd4;
    frame0[15][15] = 3'd4;
    frame0[15][16] = 3'd2;
    frame0[15][17] = 3'd2;
    frame0[15][18] = 3'd2;
    frame0[15][19] = 3'd1;
    frame0[15][20] = 3'd0;
    frame0[15][21] = 3'd0;
    frame0[15][22] = 3'd0;
    frame0[15][23] = 3'd0;
    frame0[15][24] = 3'd0;
    frame0[16][0] = 3'd0;
    frame0[16][1] = 3'd0;
    frame0[16][2] = 3'd0;
    frame0[16][3] = 3'd0;
    frame0[16][4] = 3'd0;
    frame0[16][5] = 3'd1;
    frame0[16][6] = 3'd1;
    frame0[16][7] = 3'd2;
    frame0[16][8] = 3'd1;
    frame0[16][9] = 3'd5;
    frame0[16][10] = 3'd4;
    frame0[16][11] = 3'd4;
    frame0[16][12] = 3'd4;
    frame0[16][13] = 3'd4;
    frame0[16][14] = 3'd4;
    frame0[16][15] = 3'd5;
    frame0[16][16] = 3'd1;
    frame0[16][17] = 3'd2;
    frame0[16][18] = 3'd1;
    frame0[16][19] = 3'd1;
    frame0[16][20] = 3'd0;
    frame0[16][21] = 3'd0;
    frame0[16][22] = 3'd0;
    frame0[16][23] = 3'd0;
    frame0[16][24] = 3'd0;
    frame0[17][0] = 3'd0;
    frame0[17][1] = 3'd0;
    frame0[17][2] = 3'd0;
    frame0[17][3] = 3'd0;
    frame0[17][4] = 3'd0;
    frame0[17][5] = 3'd0;
    frame0[17][6] = 3'd1;
    frame0[17][7] = 3'd1;
    frame0[17][8] = 3'd1;
    frame0[17][9] = 3'd2;
    frame0[17][10] = 3'd5;
    frame0[17][11] = 3'd4;
    frame0[17][12] = 3'd4;
    frame0[17][13] = 3'd4;
    frame0[17][14] = 3'd5;
    frame0[17][15] = 3'd2;
    frame0[17][16] = 3'd1;
    frame0[17][17] = 3'd1;
    frame0[17][18] = 3'd1;
    frame0[17][19] = 3'd0;
    frame0[17][20] = 3'd0;
    frame0[17][21] = 3'd0;
    frame0[17][22] = 3'd0;
    frame0[17][23] = 3'd0;
    frame0[17][24] = 3'd0;
    frame0[18][0] = 3'd0;
    frame0[18][1] = 3'd0;
    frame0[18][2] = 3'd0;
    frame0[18][3] = 3'd0;
    frame0[18][4] = 3'd0;
    frame0[18][5] = 3'd0;
    frame0[18][6] = 3'd0;
    frame0[18][7] = 3'd1;
    frame0[18][8] = 3'd1;
    frame0[18][9] = 3'd2;
    frame0[18][10] = 3'd2;
    frame0[18][11] = 3'd5;
    frame0[18][12] = 3'd5;
    frame0[18][13] = 3'd5;
    frame0[18][14] = 3'd2;
    frame0[18][15] = 3'd2;
    frame0[18][16] = 3'd1;
    frame0[18][17] = 3'd1;
    frame0[18][18] = 3'd0;
    frame0[18][19] = 3'd0;
    frame0[18][20] = 3'd0;
    frame0[18][21] = 3'd0;
    frame0[18][22] = 3'd0;
    frame0[18][23] = 3'd0;
    frame0[18][24] = 3'd0;
    frame0[19][0] = 3'd0;
    frame0[19][1] = 3'd0;
    frame0[19][2] = 3'd0;
    frame0[19][3] = 3'd0;
    frame0[19][4] = 3'd0;
    frame0[19][5] = 3'd0;
    frame0[19][6] = 3'd0;
    frame0[19][7] = 3'd0;
    frame0[19][8] = 3'd0;
    frame0[19][9] = 3'd1;
    frame0[19][10] = 3'd2;
    frame0[19][11] = 3'd2;
    frame0[19][12] = 3'd5;
    frame0[19][13] = 3'd2;
    frame0[19][14] = 3'd2;
    frame0[19][15] = 3'd1;
    frame0[19][16] = 3'd0;
    frame0[19][17] = 3'd0;
    frame0[19][18] = 3'd0;
    frame0[19][19] = 3'd0;
    frame0[19][20] = 3'd0;
    frame0[19][21] = 3'd0;
    frame0[19][22] = 3'd0;
    frame0[19][23] = 3'd0;
    frame0[19][24] = 3'd0;
    frame0[20][0] = 3'd0;
    frame0[20][1] = 3'd0;
    frame0[20][2] = 3'd0;
    frame0[20][3] = 3'd0;
    frame0[20][4] = 3'd0;
    frame0[20][5] = 3'd0;
    frame0[20][6] = 3'd0;
    frame0[20][7] = 3'd0;
    frame0[20][8] = 3'd0;
    frame0[20][9] = 3'd1;
    frame0[20][10] = 3'd0;
    frame0[20][11] = 3'd1;
    frame0[20][12] = 3'd2;
    frame0[20][13] = 3'd1;
    frame0[20][14] = 3'd0;
    frame0[20][15] = 3'd1;
    frame0[20][16] = 3'd0;
    frame0[20][17] = 3'd0;
    frame0[20][18] = 3'd0;
    frame0[20][19] = 3'd0;
    frame0[20][20] = 3'd0;
    frame0[20][21] = 3'd0;
    frame0[20][22] = 3'd0;
    frame0[20][23] = 3'd0;
    frame0[20][24] = 3'd0;
    frame0[21][0] = 3'd0;
    frame0[21][1] = 3'd0;
    frame0[21][2] = 3'd0;
    frame0[21][3] = 3'd0;
    frame0[21][4] = 3'd0;
    frame0[21][5] = 3'd0;
    frame0[21][6] = 3'd0;
    frame0[21][7] = 3'd0;
    frame0[21][8] = 3'd0;
    frame0[21][9] = 3'd1;
    frame0[21][10] = 3'd0;
    frame0[21][11] = 3'd0;
    frame0[21][12] = 3'd1;
    frame0[21][13] = 3'd0;
    frame0[21][14] = 3'd0;
    frame0[21][15] = 3'd1;
    frame0[21][16] = 3'd0;
    frame0[21][17] = 3'd0;
    frame0[21][18] = 3'd0;
    frame0[21][19] = 3'd0;
    frame0[21][20] = 3'd0;
    frame0[21][21] = 3'd0;
    frame0[21][22] = 3'd0;
    frame0[21][23] = 3'd0;
    frame0[21][24] = 3'd0;
    frame0[22][0] = 3'd0;
    frame0[22][1] = 3'd0;
    frame0[22][2] = 3'd0;
    frame0[22][3] = 3'd0;
    frame0[22][4] = 3'd0;
    frame0[22][5] = 3'd0;
    frame0[22][6] = 3'd0;
    frame0[22][7] = 3'd0;
    frame0[22][8] = 3'd0;
    frame0[22][9] = 3'd1;
    frame0[22][10] = 3'd0;
    frame0[22][11] = 3'd0;
    frame0[22][12] = 3'd0;
    frame0[22][13] = 3'd0;
    frame0[22][14] = 3'd0;
    frame0[22][15] = 3'd1;
    frame0[22][16] = 3'd0;
    frame0[22][17] = 3'd0;
    frame0[22][18] = 3'd0;
    frame0[22][19] = 3'd0;
    frame0[22][20] = 3'd0;
    frame0[22][21] = 3'd0;
    frame0[22][22] = 3'd0;
    frame0[22][23] = 3'd0;
    frame0[22][24] = 3'd0;
    frame0[23][0] = 3'd0;
    frame0[23][1] = 3'd0;
    frame0[23][2] = 3'd0;
    frame0[23][3] = 3'd0;
    frame0[23][4] = 3'd0;
    frame0[23][5] = 3'd0;
    frame0[23][6] = 3'd0;
    frame0[23][7] = 3'd0;
    frame0[23][8] = 3'd0;
    frame0[23][9] = 3'd1;
    frame0[23][10] = 3'd1;
    frame0[23][11] = 3'd0;
    frame0[23][12] = 3'd0;
    frame0[23][13] = 3'd0;
    frame0[23][14] = 3'd1;
    frame0[23][15] = 3'd1;
    frame0[23][16] = 3'd0;
    frame0[23][17] = 3'd0;
    frame0[23][18] = 3'd0;
    frame0[23][19] = 3'd0;
    frame0[23][20] = 3'd0;
    frame0[23][21] = 3'd0;
    frame0[23][22] = 3'd0;
    frame0[23][23] = 3'd0;
    frame0[23][24] = 3'd0;
    frame0[24][0] = 3'd0;
    frame0[24][1] = 3'd0;
    frame0[24][2] = 3'd0;
    frame0[24][3] = 3'd0;
    frame0[24][4] = 3'd0;
    frame0[24][5] = 3'd0;
    frame0[24][6] = 3'd0;
    frame0[24][7] = 3'd0;
    frame0[24][8] = 3'd1;
    frame0[24][9] = 3'd1;
    frame0[24][10] = 3'd0;
    frame0[24][11] = 3'd1;
    frame0[24][12] = 3'd0;
    frame0[24][13] = 3'd1;
    frame0[24][14] = 3'd0;
    frame0[24][15] = 3'd1;
    frame0[24][16] = 3'd1;
    frame0[24][17] = 3'd0;
    frame0[24][18] = 3'd0;
    frame0[24][19] = 3'd0;
    frame0[24][20] = 3'd0;
    frame0[24][21] = 3'd0;
    frame0[24][22] = 3'd0;
    frame0[24][23] = 3'd0;
    frame0[24][24] = 3'd0;
end

// 25×25 FRAME — bitmap stored in frame1[y][x]
// frame1[][] contains a 3-bit palette index
reg [2:0] frame1 [0:24][0:24] = '{
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,1,1,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,1,2,1,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,1,2,1,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,1,1,1,1,2,2,2,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,1,1,3,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,1,3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,1,1,2,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,1,4,4,4,2,1,1,1,1,1,1,0,0,0,0,0,0,1,1,0},
    '{0,0,0,1,1,4,4,5,5,5,5,5,5,5,5,5,5,5,1,1,1,5,5,1,0},
    '{0,0,0,1,4,4,5,5,5,5,2,2,5,5,5,5,5,5,5,5,5,5,5,1,0},
    '{0,0,0,1,4,4,5,5,5,5,1,2,2,5,5,5,5,5,5,5,5,5,5,1,0},
    '{0,0,0,1,4,4,4,5,5,5,5,5,5,2,2,2,2,2,2,2,3,1,1,0,0},
    '{0,0,0,1,1,4,4,4,5,5,5,5,5,1,1,1,1,1,1,1,1,1,0,0,0},
    '{0,0,0,0,0,1,4,4,4,5,5,5,5,3,3,3,3,3,3,3,1,0,0,0,0},
    '{0,0,0,0,0,1,1,4,4,4,4,4,4,4,3,3,3,4,4,1,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,1,1,1,5,5,1,1,1,1,1,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,1,1,1,0,1,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0}
};

reg [2:0] frame2 [0:24][0:24] = '{
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,4,2,2,2,4,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,1,1,2,1,1,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,1,2,1,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,1,2,1,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,1,2,1,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,1,2,1,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,1,1,2,1,1,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,5,5,5,5,5,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,1,5,5,5,5,5,5,5,1,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,1,1,5,5,5,5,5,5,5,5,5,1,1,0,0,0,0,0,0},
    '{0,0,0,0,0,1,1,2,5,5,5,5,5,5,5,5,5,2,1,1,0,0,0,0,0},
    '{0,0,0,0,0,1,2,2,5,5,5,5,5,5,5,5,5,2,2,1,0,0,0,0,0},
    '{0,0,0,0,0,1,1,1,1,2,5,5,5,5,5,2,1,1,1,1,0,0,0,0,0},
    '{0,0,0,0,0,0,1,3,4,1,2,2,5,2,2,1,4,3,1,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,1,3,1,1,1,2,1,1,1,3,1,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,1,4,4,1,1,1,4,4,1,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,1,3,4,3,1,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,1,1,0,1,0,1,0,1,1,0,0,0,0,0,0,0,0}
};

reg [2:0] frame3 [0:24][0:24] = '{
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,2,2,1,1,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,1,1,2,1,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,2,1,2,1,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,2,2,2,1,1,1,1,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,3,1,1,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,3,1,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,2,2,1,1,0,0,0,0,0},
    '{0,1,1,0,0,0,0,0,0,1,1,1,1,1,1,2,4,4,4,1,0,0,0,0,0},
    '{0,1,5,5,1,1,1,5,5,5,5,5,5,5,5,5,5,5,4,4,1,1,0,0,0},
    '{0,1,5,5,5,5,5,5,5,5,5,5,5,2,2,5,5,5,5,4,4,1,0,0,0},
    '{0,1,5,5,5,5,5,5,5,5,5,5,5,2,1,5,5,5,5,4,4,1,0,0,0},
    '{0,0,1,1,3,2,2,2,2,2,2,2,1,5,5,5,5,5,4,4,4,1,0,0,0},
    '{0,0,0,1,1,1,1,1,1,1,1,1,5,5,5,5,5,4,4,4,1,1,0,0,0},
    '{0,0,0,0,1,3,3,3,3,3,3,3,5,5,5,5,4,4,4,1,0,0,0,0,0},
    '{0,0,0,0,0,1,4,4,3,3,3,4,4,4,4,4,4,4,1,1,0,0,0,0,0},
    '{0,0,0,0,0,0,0,1,1,1,1,1,5,5,1,1,1,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
    '{0,0,0,0,0,0,0,0,0,1,1,1,0,1,1,1,0,0,0,0,0,0,0,0,0}
};

    assign pixel0 = frame0[y][x];
    assign pixel1 = frame1[y][x];
    assign pixel2 = frame2[y][x];
    assign pixel3 = frame3[y][x];

endmodule

module grass_bg(
  input wire [9:0] pix_x,
  input wire [9:0] pix_y,
  output wire [1:0] r,
  output wire [1:0] g,
  output wire [1:0] b
);

  // Local coordinates for each "grass cell"
  wire in_grass_blade_vert_region = pix_y[5] && pix_y[6] && pix_y[7];

  // Define curved grass shape (using quadratic approximation)
  wire inside_grass_shape_1 = pix_x[1] && in_grass_blade_vert_region;

  // Draw the base layer of grass (flat bottom)
  wire in_grass_base = (pix_y[5] && pix_y[6] && pix_y[7] && pix_y[4]) || pix_y[8];

  // Combine all grass regions
  // wire in_all_grass = (inside_grass_shape_5) || in_grass_base;
  wire in_all_grass = inside_grass_shape_1 || in_grass_base;

  // Output colors
  assign r = in_all_grass ? 2'b00 : 2'b00;
  assign g = in_all_grass ? 2'b11 : 2'b10;
  assign b = in_all_grass ? 2'b00 : 2'b11;
  
endmodule

module sound_module(
  input wire clk,
  input wire rst_n,
  input wire[6:0] frame_counter,
  input wire[9:0] x,
  input wire[9:0]y,
  output wire sound
);

  wire [6:0] timer = frame_counter;
  
  reg part1;

  wire [4:0] envelopeB = 5'd31 - timer[1:0] << 3;// exp(t*-20) decays to 0 approximately in 16 frames  [255 181 129  92  65  46  33  23  16  12   8   6   4   3]

  // lead wave counter
  reg [4:0] note_freq;
  reg [7:0] note_counter;
  reg       note;

  wire [1:0] note_freq_sel;

  // lead notes
  wire [3:0] note_in = timer[5:2];           // 16 notes, 4 frames per note each. 64 frames total, ~2 seconds
    assign note_freq_sel[0] = !(note_in[0] ^ note_in[1]) && note_in[2];
    assign note_freq_sel[1] = (!note_in[0] & note_in[1]) || (!note_in[2] & note_in[3]) || (!note_in[0] & !note_in[1]) || (note_in[1] & !note_in[2] & !note_in[3]);
  
  always @(*) begin
    case (note_freq_sel)
      2'd0: note_freq = 5'd0;
      2'd1: note_freq = 5'd28;
      2'd2: note_freq = 5'd25;
      2'd3: note_freq = 5'd24;
    endcase
  end

  wire lead = note & (x >= 256 && x < 256 + (envelopeB<<3));   // ROM square wave with quarter second envelope

  assign sound = { lead && part1 };

  always @(posedge clk) begin
    if (~rst_n) begin
      note_counter <= 0;
      note <= 0;
      part1 <= 1;

    end else begin
      part1 <= timer[6];

      // square wave
      if (x == 0) begin
        if (note_counter > note_freq && note_freq != 0) begin
          note_counter <= 0;
          note <= ~note;
        end else begin
          note_counter <= note_counter + 1'b1;
        end
      end
    end
  end
endmodule

//------------------------------------------------------------
// 8-color PALETTE (each has 4 subpixel RGB entries)
// palette[index][subpixel] → 6-bit {r,g,b}
//------------------------------------------------------------
module palette_lut(
    input  wire [2:0] index,      // 0–8
    input  wire [1:0] subpixel,   // 0–2 (8 pixel pattern)
    output reg  [1:0] r,
    output reg  [1:0] g,
    output reg  [1:0] b
);

// palette[index][subpixel] = 6-bit  {r,g,b}
// 16 palette entries, each with 4 subpixels
reg [5:0] palette [0:7][0:3];

initial begin
    // Example palette — same values you had
    palette[3'h0][0] = {2'b00, 2'b11, 2'b00}; // background green
    palette[3'h0][1] = {2'b00, 2'b11, 2'b00};
    palette[3'h0][2] = {2'b00, 2'b11, 2'b00};
    palette[3'h0][3] = {2'b00, 2'b11, 2'b00};

    palette[3'h1][0] = {2'b00, 2'b00, 2'b00}; // black
    palette[3'h1][1] = {2'b00, 2'b00, 2'b00};
    palette[3'h1][2] = {2'b00, 2'b00, 2'b00};
    palette[3'h1][3] = {2'b00, 2'b00, 2'b00};

    palette[3'h2][0] = {2'b00, 2'b00, 2'b00}; // Brown
    palette[3'h2][1] = {2'b01, 2'b00, 2'b00};
    palette[3'h2][2] = {2'b00, 2'b00, 2'b00};
    palette[3'h2][3] = {2'b01, 2'b00, 2'b00};

    palette[3'h3][0] = {2'b11, 2'b11, 2'b11}; // white
    palette[3'h3][1] = {2'b11, 2'b11, 2'b11};
    palette[3'h3][2] = {2'b11, 2'b11, 2'b11};
    palette[3'h3][3] = {2'b11, 2'b11, 2'b11};

    // Very light cream ( #ebdcb5 ) in 2-bit RGB w/4-pixel dither
    palette[3'h4][0] = {2'b11, 2'b11, 2'b11}; // Tone A: very light cream (R=3,G=3,B=3)
    palette[3'h4][1] = {2'b11, 2'b11, 2'b10}; // Tone B: light cream (R=3,G=3,B=2)
    palette[3'h4][2] = {2'b11, 2'b11, 2'b10}; // Tone B
    palette[3'h4][3] = {2'b11, 2'b11, 2'b11}; // Tone A

    // Muted brown (#806d55) in 2-bit RGB w/4-pixel dither
    palette[3'h5][0] = {2'b10, 2'b01, 2'b00}; // Tone A: base muted brown (R=2,G=1,B=1)
    palette[3'h5][1] = {2'b10, 2'b01, 2'b01}; // Tone B: slightly darker (R=2,G=1,B=0)
    palette[3'h5][2] = {2'b01, 2'b01, 2'b00}; // Tone B
    palette[3'h5][3] = {2'b00, 2'b01, 2'b01}; // Tone A
    
    // ... keep adding colors 3-F here (up to 8 colours total) ...
end

    // Output one 6-bit RGB value
    always @(*) begin
        {r, g, b} = palette[index][subpixel];
    end

endmodule
