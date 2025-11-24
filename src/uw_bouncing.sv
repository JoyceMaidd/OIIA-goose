module uw_bouncing(
    input wire clk,      // clock
    input wire rst_n,    // reset_n - low to reset
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    output wire [1:0] r,
    output wire [1:0] g,
    output wire [1:0] b
);
    
    `include "uw.svh"

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