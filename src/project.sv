`default_nettype none
// Top-level module
// - Exposes video & sound signals on 8-bit I/O ports
// - Instantiates VGA timing, frame lookup, palette lookup,
//   background generators, and a sound generator
// - Maintains a small frame counter and optional multi-frame selection

module tt_um_goose(
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
    // The design produces separate 2-bit R,G,B signals that are
    // later packed and driven out to the `uo_out` port. `video_active`
    // indicates whether the current pixel is inside the visible area.
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
    // Produces `hsync`/`vsync` and the current pixel coordinates `pix_x`/`pix_y`
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
    // FRAMEBUFFER LOOKUP
    // The `frame_lut` converts a block X/Y into per-pixel
    // color indices. This design exposes four separate frame outputs
    // (`pixel_index0`..`3`) and selects one of them using `frame_num`.
    // Each pixel index is a small logical color index used by the
    // `palette_lut` to produce actual R/G/B values.
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

    frame_lut frame_inst (
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

    //------------------------------------------------------------
    // `ui_in[1:0]` selects which background to use:
    // - 00: grass background generator
    // - 01: bouncing uw generator
    // - 10/11: fixed hardcoded colour sets
    //------------------------------------------------------------

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
                
                if (frame_counter[1] & !frame_counter[0]) begin
                    frame_num <= frame_num + 1;
                end
            end
        end
    end
endmodule