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

    `include "palette.svh"

    // Output one 6-bit RGB value
    always @(*) begin
        {r, g, b} = palette[index][subpixel];
    end

endmodule
