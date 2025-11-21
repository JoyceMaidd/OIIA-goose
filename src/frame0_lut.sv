
//------------------------------------------------------------
// 32×32 FRAME — bitmap stored in frame0[y][x]
//     frame0[][] contains a 4-bit palette index
//------------------------------------------------------------
module frame0_lut(
    input  wire [4:0] x,    // 0–31
    input  wire [4:0] y,    // 0–31
    output wire [2:0] pixel
);
    `include "frame0.svh"
    pixel = frame0[y][x];
endmodule