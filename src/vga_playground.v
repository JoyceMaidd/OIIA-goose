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

    wire [1:0] bg_r;
    wire [1:0] bg_g;
    wire [1:0] bg_b;

    grass_bg grass_bg_inst (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .r(bg_r),
        .g(bg_g),
        .b(bg_b)
    );


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
    // assign R = video_active ? in_shape ? pal_r : (pix_x == frame_num * 100) ? 2'b11 : 2'b00 : 2'b00;
    // assign G = video_active ? in_shape ? pal_g : (pix_x == frame_num * 100) ? 2'b11 : 2'b00 : 2'b00;
    // assign B = video_active ? in_shape ? pal_b : (pix_x == frame_num * 100) ? 2'b11 : 2'b00 : 2'b00;

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

// frame0.svh — 25x25 goose sprite ROM
reg [3:0] frame0 [0:24][0:24] = '{
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
  always @(note_in) begin
    note_freq_sel[0] = !(note_in[0] ^ note_in[1]) && note_in[2];
    note_freq_sel[1] = (!note_in[0] & note_in[1]) || (!note_in[2] & note_in[3]) || (!note_in[0] & !note_in[1]) || (note_in[1] & !note_in[2] & !note_in[3]);
  end
  
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
