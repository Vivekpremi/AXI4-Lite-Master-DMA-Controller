`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/11/2025 01:46:59 PM
// Design Name: 
// Module Name: read
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

`timescale 1ns / 1ps

module read_block (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,           // Start signal from top-level DMA
    input  wire [31:0] start_addr,      // Aligned starting address from aligner
    input  wire [31:0] end_addr,        // Aligned end address from aligner

    output reg  [31:0] mem_rd_addr,     // Output address to memory
    output reg         mem_rd_en,       // Trigger to memory
    output reg         data_valid       // Used by aligner to capture rd_data
);

    reg active;
    reg [31:0] current_addr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            active       <= 0;
            current_addr <= 32'b0;
            mem_rd_en    <= 0;
            mem_rd_addr  <= 32'b0;
            data_valid   <= 0;
        end else begin
            if (start) begin
                current_addr <= start_addr;
                active       <= 1;
                mem_rd_en    <= 1;
                mem_rd_addr  <= start_addr;
                data_valid   <= 0;
            end else if (active) begin
                mem_rd_en <= 1;
                mem_rd_addr <= current_addr;

                if (current_addr < end_addr) begin
                    current_addr <= current_addr + 4;
                    data_valid <= 1;
                end else begin
                    mem_rd_en  <= 0;
                    active     <= 0;
                    data_valid <= 1; // signal last word
                end
            end else begin
                mem_rd_en  <= 0;
                data_valid <= 0;
            end
        end
    end
endmodule

