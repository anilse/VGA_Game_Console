/*
 * EE-566 Term Project: VGA Game Console
 * - This module is the top module which instantiates submodules.
 * - It is forked from my VGA_Adjust_Speed lab work.
 * - The ball with the handle bounces when it crashes into the borders of screen.
 * 
 * ANIL SEZGiN 
 */
module project_top_milestone_3(clk, rst, push, hsync, vsync, rgb);

input clk, rst;
input [2:0] push; 
output hsync, vsync;
output [2:0] rgb;

wire video_on;
wire [9:0] pixel_x, pixel_y;

// instantiate vgaSync and pixelGeneration circuit
vgaSync vgaSync(.clk(clk), .rst(rst), .hsync(hsync), .vsync(vsync), .video_on(video_on), .p_tick(), .pixel_x(pixel_x), .pixel_y(pixel_y));
pixelGeneration pixelGeneration(.clk(clk), .rst(rst), .push(push), .pixel_x(pixel_x), .pixel_y(pixel_y), .video_on(video_on), .rgb(rgb));

endmodule
