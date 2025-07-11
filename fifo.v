`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/07/2025 11:39:49 AM
// Design Name: 
// Module Name: fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo #(parameter DATA_WIDTH=32, DEPTH=16)(
    input clk, rst,
  input w_en, r_en,
  input [DATA_WIDTH-1:0] data_in,
  output reg [DATA_WIDTH-1:0] data_out,
  output full, empty
    
    );
    
    reg [DATA_WIDTH-1:0] fifo[DEPTH-1:0];
    reg [$clog2(DEPTH)-1:0] w_ptr,r_ptr;
    
    //RESET
//    always @(posedge clk)begin
//    if(!rst_n)begin
//        w_ptr<=0;
//        r_ptr<=0;
//        data_out<=0; 
//    end
//    end
    
    //fifo write

    always @(posedge clk)begin
	 if(rst)begin
        w_ptr<=0;
    end
        else if(w_en && !full)begin
            
            fifo[w_ptr]<=data_in;
            w_ptr<=w_ptr+1;
         
        end
        end
        
    //fifo read
            always @(posedge clk)begin
				if(rst)begin
					r_ptr<=0;
					data_out<=0; 
					end
               else if(r_en && !empty)begin
                
                
                    data_out<=fifo[r_ptr];
                     r_ptr<=r_ptr+1; 
         
                end
                end
                
                //full empty
                assign full = (w_ptr==DEPTH)?1:0;
                assign empty = (r_ptr==w_ptr);
endmodule
