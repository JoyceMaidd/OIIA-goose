// Grass background generator
module grass_bg(
  input wire [9:0] pix_x,
  input wire [9:0] pix_y,
  output wire [1:0] r,
  output wire [1:0] g,
  output wire [1:0] b,
  input wire frame
);

  // Draw the grass when the y-coordinate of the current pixel is in the grass region
  wire in_grass_blade_vert_region = pix_y[5] && pix_y[6] && pix_y[7];

  // Define grass blade location based on x-coordinate (and the frame so that the grass appears to be moving)
  wire inside_grass_shape_1 = ((!frame & pix_x[1]) || (frame & pix_x[2])) && in_grass_blade_vert_region && 
                              ((pix_x[4] && !pix_x[3]) || (pix_x[3] && !pix_x[4] && !pix_x[5]) || (pix_x[5] && pix_x[6]));

  // Define the area for the grass base
  wire in_grass_base = (pix_y[5] && pix_y[6] && pix_y[7] && pix_y[4]) || pix_y[8];

  // Combine all grass regions
  wire in_all_grass = inside_grass_shape_1 || in_grass_base;

  // Output colors as blue or green based on whether the current pixel is the grass region
  assign r = in_all_grass ? 2'b00 : 2'b00;
  assign g = in_all_grass ? 2'b11 : 2'b10;
  assign b = in_all_grass ? 2'b00 : 2'b11;
  
endmodule