`timescale 1ns / 1ps
module pixelGeneration(clk, rst, push, pixel_x, pixel_y, video_on, rgb);

input clk, rst;
input [2:0] push;
input [9:0] pixel_x, pixel_y;
input video_on;
output reg [2:0] rgb;

wire ball_on, border_circle, handle_on ,refr_tick;
reg handle_pixel;
// define screen size max values.
localparam MAX_X = 640;
localparam MAX_Y = 480;
// define handle size
localparam ROD_L = 16;
// define ball size and its velocity
localparam BALL_RADIUS = 16;
localparam BIG_BALL_RADIUS = 27;
localparam BALL_VEL = 5;
// angle control state
reg [1:0] state, stateNext;
// multiplication result
wire [17:0] expanded_x, expanded_y;
// define registers and wires for controlling the coordinates of the ball with a handle
wire [9:0] ball_x_left, ball_x_right, ball_y_top, ball_y_bottom;
reg [9:0] ball_y_cent, ball_y_cent_next, diffX, diffY;
reg [9:0] ball_x_cent, ball_x_cent_next;
// define registers for direction info
reg direction_y, direction_x, direction_yNext, direction_xNext;
// handle quadrant
reg [1:0] quadrant, quadrant_next;

reg [7:0] angle, angle_next;
wire [7:0] tan;
LUT_TAN lut(angle, tan);
/* 
 * Register behaviour for keeping the information of the x-y coordinates of the ball.
 */
always @(posedge clk) begin
	if(rst) begin
		// Initial values
		ball_y_cent <= 240;
		ball_x_cent <= 320;
		direction_y <= 0; // down
		direction_x <= 0; // right
		quadrant <= 0;
		angle <= 0;
		state <= 0;
	end
	else begin
      // Register the next value at posedge clk and ~rst.
		ball_y_cent <= #1 ball_y_cent_next;
		ball_x_cent <= #1 ball_x_cent_next;
		direction_y <= #1 direction_yNext;
		direction_x <= #1 direction_xNext;
		quadrant <= quadrant_next;
		angle <= angle_next;
		state <= stateNext;
	end
end

// Circuit for checking screen refresh when pixel_x and pixel_y scan starts.
assign refr_tick = (pixel_y == 481) && (pixel_x == 0);

/* Define boundaries of the ball movement by adding and
 * substracting the BALL_RADIUS.
**/
assign ball_y_top = ball_y_cent - BALL_RADIUS + 1;
assign ball_x_left = ball_x_cent - BALL_RADIUS + 1;
assign ball_y_bottom = ball_y_cent + BALL_RADIUS - 1;
assign ball_x_right = ball_x_cent + BALL_RADIUS - 1;

/*
 * RGB CIRCUIT
 */
always @(*) begin
	rgb = 3'b000;
	if(video_on) begin
		if(handle_on)
			rgb = 3'b000;
		else begin 
			if(ball_on)
				rgb = 3'b011;
			else	
				rgb = 3'b110;
		end
	end
end

/* BALL DRAWING CIRCUIT
 * Let's assume the center of the ball is (xc,yc):
 * A simple equation is enough to draw the ball: [BALL_RADIUS^2 > (x-xc)^2*(y-yc)^2]
 */
assign ball_on = ((BALL_RADIUS * BALL_RADIUS) > ((pixel_x - ball_x_cent)*(pixel_x - ball_x_cent))
									+ ((pixel_y - ball_y_cent)*(pixel_y - ball_y_cent)));
assign border_circle = ((BIG_BALL_RADIUS * BIG_BALL_RADIUS) > ((pixel_x - ball_x_cent)*(pixel_x - ball_x_cent))
									+ ((pixel_y - ball_y_cent)*(pixel_y - ball_y_cent))); 									
assign handle_on = handle_pixel && border_circle;

/* 
 * Why expanded? Because, e.g. it's impossible to show 0.369 pixels.
 * I multiplied my (pixel_x - ball_cent_x) with tan.
 * Which means (y-yc) = tan(x-xc).
 */
assign expanded_x = diffX*tan; // 0 - 45
assign expanded_y = diffY*tan; // 45 - 90, trick for showing this angle span. 
					
//object animation circuit
always @(*) begin
	ball_y_cent_next = ball_y_cent;
	ball_x_cent_next = ball_x_cent;
	direction_xNext = direction_x;
	direction_yNext = direction_y;
	quadrant_next = quadrant;
	angle_next = angle;
	stateNext = state;
	/*
	 * BALL DIRECTION BEHAVIOR, bounce back 
	 * if it's at the border.
	 */
	// determine direction for x
	if(ball_x_right >= (MAX_X-8))
		direction_xNext = 1; // go to left
	else if (0 >= ball_x_left)
		direction_xNext = 0; // go to right
	// determine direction for y
	if (ball_y_bottom >= MAX_Y)
		direction_yNext = 0; // go up
	else if (5 >= ball_y_top)
		direction_yNext = 1; // go down
	
	/*
	 * HANDLE BEHAVIOUR.
	 * push button 2 changes the degree.
	 */
	if(refr_tick) begin		
		 // The following is done in order to keep the ball on the screen.
		if (push[0] && (~direction_x)) begin
			ball_x_cent_next = ball_x_cent + BALL_VEL; // right
		end 
		else if (push[0] && (direction_x)) begin
			if(ball_x_left < BALL_VEL) begin
				ball_x_cent_next = BALL_RADIUS - 1 ; // left
			end
			else begin // protection algorithm to keep the ball on the screen on the left move.
				ball_x_cent_next = ball_x_cent - BALL_VEL; 
			end
		end
		else if (push[1] && (direction_y)) begin
			ball_y_cent_next = ball_y_cent + BALL_VEL; // down
		end
		else if (push[1] && (~direction_y)) begin
			ball_y_cent_next = ball_y_cent - BALL_VEL; // up
		end
		/* Angle control by LUT, in refr_tick. */
		if(push[2]) begin
			if(state == 0)begin
				if(angle < 23)
					angle_next = angle + 1;
				else
					stateNext = state + 1;
			end
			else if(state == 1) begin		
				if(angle > 0)
					angle_next = angle - 1;
				else begin
					stateNext = state + 1;
					quadrant_next = quadrant + 1;
				end
			end
			else if(state == 2)begin
				if(angle < 23)
					angle_next = angle + 1;
				else
					stateNext = state + 1;
			end
			else if(state == 3) begin		
				if(angle > 0)
					angle_next = angle - 1;
				else begin
					stateNext = state + 1;
					quadrant_next = quadrant + 1;
				end
			end
		end
	end	 
	case(quadrant)
		0:begin 
			diffX = pixel_x-ball_x_cent;
			diffY = ball_y_cent-pixel_y;
			if ((state == 0) || (state == 3)) begin	
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_x[17:7]-1 == diffY)
				|| (expanded_x[17:7] == diffY)
				|| (expanded_x[17:7]+1 == diffY);
			end
			else if ((state == 1) || (state == 2))begin
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_y[17:7]-1 == diffX)
				|| (expanded_y[17:7] == diffX)
				|| (expanded_y[17:7]+1 == diffX);
			end
		end
		1:begin
			diffX = ball_x_cent-pixel_x;
			diffY = ball_y_cent-pixel_y;
			if ((state == 0) || (state == 3)) begin	
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_x[17:7]-1 == diffY)
				|| (expanded_x[17:7] == diffY)
				|| (expanded_x[17:7]+1 == diffY);
			end
			else if ((state == 1) || (state == 2))begin
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_y[17:7]-1 == diffX)
				|| (expanded_y[17:7] == diffX)
				|| (expanded_y[17:7]+1 == diffX);
			end
		end
		2:begin
			diffX = ball_x_cent-pixel_x;
			diffY = pixel_y-ball_y_cent;
			if ((state == 0) || (state == 3)) begin	
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_x[17:7]-1 == diffY)
				|| (expanded_x[17:7] == diffY)
				|| (expanded_x[17:7]+1 == diffY);
			end
			else if ((state == 1) || (state == 2))begin
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_y[17:7]-1 == diffX)
				|| (expanded_y[17:7] == diffX)
				|| (expanded_y[17:7]+1 == diffX);
			end	
		end
		3:begin
			diffX = pixel_x-ball_x_cent;
			diffY = pixel_y-ball_y_cent;
			if ((state == 0) || (state == 3)) begin	
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_x[17:7]-1 == diffY)
				|| (expanded_x[17:7] == diffY)
				|| (expanded_x[17:7]+1 == diffY);
			end
			else if ((state == 1) || (state == 2))begin
				handle_pixel =
					// Three thin rods make one thick rod.
					(expanded_y[17:7]-1 == diffX)
				|| (expanded_y[17:7] == diffX)
				|| (expanded_y[17:7]+1 == diffX);
			end	
		end
	endcase
	if(refr_tick) begin		
		 // The following is done in order to keep the ball on the screen.
		if (push[0] && (~direction_x)) begin
			ball_x_cent_next = ball_x_cent + BALL_VEL; // right
		end 
		else if (push[0] && (direction_x)) begin
			if(ball_x_left < BALL_VEL) begin
				ball_x_cent_next = BALL_RADIUS - 1 ; // left
			end
			else begin // protection algorithm to keep the ball on the screen on the left move.
				ball_x_cent_next = ball_x_cent - BALL_VEL; 
			end
		end
		else if (push[1] && (direction_y)) begin
			ball_y_cent_next = ball_y_cent + BALL_VEL; // down
		end
		else if (push[1] && (~direction_y)) begin
			ball_y_cent_next = ball_y_cent - BALL_VEL; // up
		end
	end
end

endmodule

/*
 * LUT_TAN:
 *	ROM - LUT for tangent values to set the gradient. I had to use 45/2 steps,
 * because I was losing some pixels with a bigger tan_scale for the ball size above.
 * Tangent lookup table is derived from: http://www.science-projects.com/TangentTable.htm 
 */

module LUT_TAN (angle, tan_scale);
input [7:0] angle;
output reg [7:0] tan_scale;
always @(*)
   case(angle)
       0: tan_scale = 4;   
       1: tan_scale = 7;   
       2: tan_scale = 11;   
       3: tan_scale = 14;  
       4: tan_scale = 18;  
       5: tan_scale = 21;  
       6: tan_scale = 25;  
       7: tan_scale = 29;  
       8: tan_scale = 33;   
       9: tan_scale = 36;   
       10: tan_scale = 40;   
       11: tan_scale = 45;   
       12: tan_scale = 49;   
       13: tan_scale = 53;   
       14: tan_scale = 58;   
       15: tan_scale = 63;   
       16: tan_scale = 67;   
       17: tan_scale = 73;   
       18: tan_scale = 78;   
       19: tan_scale = 84;   
       20: tan_scale = 90;   
       21: tan_scale = 97;   
       22: tan_scale = 100; // 45 degrees		 
       default: tan_scale = 100; 
    endcase
endmodule
