`default_nettype none

module sound_module_mod(
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
