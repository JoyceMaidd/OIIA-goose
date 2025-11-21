// palette[index][subpixel] = 6-bit  {r,g,b}
// 16 palette entries, each with 4 subpixels
reg [5:0] palette [7:0][3:0];

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

    // #b3925d warm brown/golden (2-bit RGB, 4-pixel dither)
    palette[3'h5][0] = {2'b11, 2'b10, 2'b01}; // Tone A: R=3,G=2,B=1 (lighter warm brown)
    palette[3'h5][1] = {2'b10, 2'b10, 2'b01}; // Tone B: R=2,G=2,B=1 (base brown)
    palette[3'h5][2] = {2'b10, 2'b10, 2'b01}; // Tone B
    palette[3'h5][3] = {2'b11, 2'b10, 2'b01}; // Tone A

    // ... keep adding colors 3-F here (up to 8 colours total) ...
end