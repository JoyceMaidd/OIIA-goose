/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_oiia_goose (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire sound;
    reg [9:0] counter;

    // Goose RGB
    wire [1:0] goose_R;
    wire [1:0] goose_G;
    wire [1:0] goose_B;

    // // Background RGB
    // wire [1:0] moving_grass_R;
    // wire [1:0] moving_grass_G;
    // wire [1:0] moving_grass_B;
    // wire [1:0] uw_bouncing_R;
    // wire [1:0] uw_bouncing_G;
    // wire [1:0] uw_bouncing_B;

    wire in_goose;

    // wire moving_grass_bg_en, uw_bouncing_bg_en, blue_bg_en, green_bg_en;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = {7'b0, sound};

    // Unused outputs assigned to 0.
    assign uio_oe    = 0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, ui_in, uio_in};

    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // oiia_sound oiia_sound_inst(
    //     .x(pix_x),
    //     .y(pix_y),
    //     .clk(clk),      // clock
    //     .rst_n(rst_n),    // reset_n - low to reset
    //     .sound(sound)
    // );

    // moving_grass_bg moving_grass_bg_inst( 
    //     .clk(clk),                   // system clock
    //     .rst_n(rst_n),               // active-low reset
    //     .counter(counter),
    //     .video_active(video_active),
    //     .pix_x(pix_x),
    //     .pix_y(pix_y),
    //     .R(moving_grass_R),
    //     .G(moving_grass_G),
    //     .B(moving_grass_B)
    // );
    
    // uw_bouncing_bg uw_bouncing_bg_inst( 
    //     .clk(clk),                   // system clock
    //     .rst_n(rst_n),               // active-low reset
    //     .counter(counter),
    //     .video_active(video_active),
    //     .pix_x(pix_x),
    //     .pix_y(pix_y),
    //     .R(uw_bouncing_R),
    //     .G(uw_bouncing_G),
    //     .B(uw_bouncing_B)
    // );

    // Insert goose module
    goose_sprite goose_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .R(goose_R),
        .G(goose_G),
        .B(goose_B),
        .in_goose(in_goose)
    );

    reg [1:0] R_reg, G_reg, B_reg;
    assign R = R_reg;
    assign G = G_reg;
    assign B = B_reg;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            counter <= 0;
            R_reg <= 0;
            G_reg <= 0;
            B_reg <= 0;
        end else begin
            counter <= counter + 1;

            if (in_goose) begin
                R_reg <= goose_R;
                G_reg <= goose_G;
                B_reg <= goose_B;
            end 
            // else begin
            //     // Choose colors based on selected background
            //     case (ui_in[1:0])
            //         2'b00: begin
            //             R_reg <= moving_grass_R;
            //             G_reg <= moving_grass_G;
            //             B_reg <= moving_grass_B;
            //         end
            //         2'b01: begin
            //             R_reg <= uw_bouncing_R;
            //             G_reg <= uw_bouncing_G;
            //             B_reg <= uw_bouncing_B;
            //         end
            //         2'b10: begin
            //             R_reg <= 2'b00;
            //             G_reg <= 2'b01;
            //             B_reg <= 2'b11;
            //         end
            //         2'b11: begin
            //             R_reg <= 2'b00;
            //             G_reg <= 2'b11;
            //             B_reg <= 2'b01;
            //         end
            //     endcase
            // end
        end
    end  
endmodule
