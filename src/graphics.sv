`default_nettype none

module graphics
    #(
        parameter H_PIXELS = 640,
        parameter V_PIXELS = 480,

        parameter H_FRONT_PORCH = 16,
        parameter H_SYNC_PULSE = 96,
        parameter H_BACK_PORCH = 48,

        parameter V_FRONT_PORCH = 10,
        parameter V_SYNC_PULSE = 2,
        parameter V_BACK_PORCH = 33
    )
    (
        input wire clk,
        input wire rst_n,

        output wire [7:0] vga_pmod
    );

    localparam PIXEL_X_BITS = $clog2(H_PIXELS + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH);
    localparam PIXEL_Y_BITS = $clog2(V_PIXELS + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH);

    localparam SCALE_BITS = 3;
    localparam SCALE = 2 ** SCALE_BITS;

    localparam DOWNSCALED_PIXEL_Y_BITS = PIXEL_Y_BITS - SCALE_BITS;

    localparam BITMAP_WIDTH = 32;
    localparam BITMAP_HEIGHT = 32;
    localparam BITMAP_TOP = 16;
    localparam BITMAP_BOTTOM = BITMAP_TOP + BITMAP_HEIGHT;

    localparam SCALED_BITMAP_TOP = BITMAP_TOP * SCALE;
    localparam SCALED_BITMAP_BOTTOM = BITMAP_BOTTOM * SCALE;

    localparam BITMAP_PIXEL_X_BITS = $clog2(BITMAP_WIDTH);
    localparam BITMAP_PIXEL_Y_BITS = $clog2(BITMAP_HEIGHT);

    reg hsync;
    reg vsync;
    reg [1:0] red;
    reg [1:0] green;
    reg [1:0] blue;

    reg [PIXEL_X_BITS - 1 : 0] pixel_x;
    reg [PIXEL_Y_BITS - 1 : 0] pixel_y;

    reg [4:0] frame_counter;
    reg render_x;
    reg render_y;

    wire [BITMAP_PIXEL_X_BITS - 1 : 0] bitmap_x;
    wire [BITMAP_PIXEL_Y_BITS - 1 : 0] bitmap_y;

    assign vga_pmod = {hsync, blue[0], green[0], red[0], vsync, blue[1], green[1], red[1]};

    assign bitmap_x = pixel_x[BITMAP_PIXEL_X_BITS + SCALE_BITS - 1 : SCALE_BITS];
    assign bitmap_y = BITMAP_PIXEL_Y_BITS'(DOWNSCALED_PIXEL_Y_BITS'(pixel_y >> SCALE_BITS) - DOWNSCALED_PIXEL_Y_BITS'(BITMAP_TOP));
 
    `include "palette.svh"
    `include "frame0.svh"
    `include "frame1.svh"
    `include "frame2.svh"
    `include "frame3.svh"

    // Select which of the four frames to display.  We derive a 2-bit
    // index from `frame_counter`. Adjust the bit selection below to
    // change how long each frame is shown (see notes below).
    wire [1:0] frame_index = frame_counter[4:3];

    // Combinationally pick the palette index from the active frame
    // RAM for the current bitmap group and row. This keeps the lookup
    // simple in the sequential block below.
    wire [5:0] selected_palette_index = (frame_index == 2'd0) ?
        frame0[bitmap_x[BITMAP_PIXEL_X_BITS - 1 : 2]][bitmap_y] :
        (frame_index == 2'd1) ?
            frame1[bitmap_x[BITMAP_PIXEL_X_BITS - 1 : 2]][bitmap_y] :
        (frame_index == 2'd2) ?
            frame2[bitmap_x[BITMAP_PIXEL_X_BITS - 1 : 2]][bitmap_y] :
            frame3[bitmap_x[BITMAP_PIXEL_X_BITS - 1 : 2]][bitmap_y];

    always @ (posedge clk) begin
        if (!rst_n) begin
            hsync <= 1'b1;
            vsync <= 1'b1;

            red <= 2'd0;
            green <= 2'd0;
            blue <= 2'd0;
            pixel_x <= PIXEL_X_BITS'(0);
            pixel_y <= PIXEL_Y_BITS'(0);
            frame_counter <= 5'd0;
            render_x <= 1'b1;
            render_y <= 1'b0;
        end else begin
            if (pixel_x == H_PIXELS + H_FRONT_PORCH) begin
                hsync <= 1'b0;
            end
            if (pixel_x == H_PIXELS + H_FRONT_PORCH + H_SYNC_PULSE) begin
                hsync <= 1'b1;
            end

            if (pixel_y == V_PIXELS + V_FRONT_PORCH) begin
                vsync <= 1'b0;
            end
            if (pixel_y == V_PIXELS + V_FRONT_PORCH + V_SYNC_PULSE) begin
                vsync <= 1'b1;
            end

            if (pixel_x == H_PIXELS + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH - 1) begin
                pixel_x <= PIXEL_X_BITS'(0);
                render_x <= 1'b1;
                if (pixel_y == V_PIXELS + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH - 1) begin
                    pixel_y <= PIXEL_Y_BITS'(0);
                    frame_counter <= frame_counter + 5'd1;
                end else begin
                    pixel_y <= pixel_y + PIXEL_Y_BITS'(1);
                end
            end else begin
                pixel_x <= pixel_x + PIXEL_X_BITS'(1);
            end

            if (pixel_y == SCALED_BITMAP_TOP - 1) begin
                render_y <= 1'b1;
            end

            if (pixel_y == SCALED_BITMAP_BOTTOM - 1) begin
                render_y <= 1'b0;
            end

            if (bitmap_x == BITMAP_PIXEL_X_BITS'(BITMAP_WIDTH - 1)) begin
                render_x <= 1'b0;
            end

            if (render_x && render_y) begin
                {red, green, blue} <= palette[selected_palette_index][bitmap_x[1:0]];
            end else begin
                {red, green, blue} <= 6'b000111;
            end
        end
    end
endmodule