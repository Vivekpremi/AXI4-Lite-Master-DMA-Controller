`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2025 01:41:34 PM
// Design Name: 
// Module Name: write_block
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


module write_block(
        input clk,
        input rst,
        input trigger,
        input [4:0] length,  // no. of bytes to write
        input [31:0]address,   // unaligned destination addr
        
        output reg done,
        output reg [31:0] mem_wr_addr,
        output reg  mem_wr_en,
        output reg req_data // tells dealigner to send strobe and data
        
    );
    reg active;
    reg [31:0] curr_addr;
    
    wire [31:0] aligned_start_addr;
    
    wire [31:0] end_addr_un,aligned_end_addr;
    reg [31:0] count;
    assign end_addr_un = address + length;
    assign aligned_end_addr = {end_addr_un[31:2],2'b00};
    assign aligned_start_addr = {address[31:2],2'b00};
    
    
    always @(posedge clk or posedge rst)begin
            if(rst)begin
            mem_wr_addr<=0;
            req_data<=0;
            mem_wr_en<=0;
            active<=0;
         
            end
            else begin
            if(trigger)begin
                active<=1;
                mem_wr_en<=1;
                req_data<=0;
                curr_addr<=aligned_start_addr;
                mem_wr_addr<=aligned_start_addr;
                
                end
             else if(active)begin
                  mem_wr_en<=1;
                  mem_wr_addr<=curr_addr;
                  
                  if(curr_addr < aligned_end_addr) begin
                        curr_addr <= curr_addr + 4;
                        req_data<=1;
                  end
                  else begin
                        mem_wr_en<=0;
                        active<=0;
                        done<=1;
                        req_data<=0;
                  end
                  
             end
             else begin
                mem_wr_en<=0;
                req_data<=0;
             end
                
            end
    
    end
    
endmodule
