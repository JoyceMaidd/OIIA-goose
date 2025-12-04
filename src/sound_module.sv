// Sound module
// - Creates a periodic square-wave "lead" voice whose frequency is
//   chosen from a small lookup controlled by `frame_counter` (timer).
// - Applies a coarse envelope and bounds the audible region by X
//   coordinate so that the sound can be tied to on-screen content.
`default_nettype none

module sound_module(
  input wire clk,
  input wire rst_n,
  input wire[6:0] frame_counter,
  input wire[9:0] x,
  input wire[9:0] y,
  output wire sound
);

  wire [6:0] timer = frame_counter;
  
  reg part1;

  // exponential decays in 4 frames
  wire [4:0] envelopeB = 5'd31 - ({3'b000, timer[1:0]} << 3);

  // lead wave counter
  reg [4:0] note_freq;
  reg [7:0] note_counter;
  reg       note;

  wire [1:0] note_freq_sel;

  // lead notes
  // 16 notes, 4 frames per note each. 64 frames total, ~2 seconds (if around 30 FPS)
  // Select the current note selected
  wire [3:0] note_in = timer[5:2];           
  assign note_freq_sel[0] = !(note_in[0] ^ note_in[1]) && note_in[2];
  assign note_freq_sel[1] = (!note_in[0] & note_in[1]) || (!note_in[2] & note_in[3]) || (!note_in[0] & !note_in[1]) || (note_in[1] & !note_in[2] & !note_in[3]);

  // Select the note frequency based on current note selected
  always @(*) begin
    case (note_freq_sel)
      2'd0: note_freq = 5'd0;  // Rest
      2'd1: note_freq = 5'd28; // Cs5
      2'd2: note_freq = 5'd25; // Ds5
      2'd3: note_freq = 5'd24; // E5
    endcase
  end

  // ROM square wave with envelope
  wire lead = note & (x >= 256 && x < 256 + (envelopeB<<3));

  assign sound = { lead && part1 };

  always @(posedge clk) begin
    if (~rst_n) begin
      note_counter <= 0;
      note <= 0;
      part1 <= 1;

    end else begin
      part1 <= timer[6];

      // Update the note counter and play the note by toggling the note on/off at the specified frequency
      if (x == 0) begin
        if (note_counter > {3'b000, note_freq} && note_freq != 0) begin
          note_counter <= 0;
          note <= ~note;
        end else begin
          note_counter <= note_counter + 1'b1;
        end
      end
    end
  end
endmodule
