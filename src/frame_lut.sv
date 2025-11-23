
//------------------------------------------------------------
// 32×32 FRAME — bitmap stored in frame0[y][x]
//     frame0[][] contains a 3-bit palette index
//------------------------------------------------------------
module frame_lut(
    input  wire [4:0] x,    // 0–31
    input  wire [4:0] y,    // 0–31
    output wire [2:0] pixel0,
    output wire [2:0] pixel1,
    output wire [2:0] pixel2,
    output wire [2:0] pixel3
);

    `include "frame0.svh"
    `include "frame1.svh"
    `include "frame2.svh"
    `include "frame3.svh"

    assign pixel0 = frame0[y][x];
    assign pixel1 = frame1[y][x];
    assign pixel2 = frame2[y][x];
    assign pixel3 = frame3[y][x];
endmodule