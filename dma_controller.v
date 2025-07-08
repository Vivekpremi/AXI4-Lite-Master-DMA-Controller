`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2025 02:11:25 PM
// Design Name: 
// Module Name: vw
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


module dma_controller(
input  wire        clk,
input  wire        rst,
input  wire        trigger,
input  wire [4:0]  length,  //byte length
input  wire [31:0] source_address,             //unaligned_src_addr,
input  wire [31:0] destination_address,                           //unaligned_dst_addr,

//AR channel
input wire ARREADY,
output wire ARVALID,
output wire [31:0] ARADDR,

// Read Channel
input wire [31:0] RDATA,
input wire RVALID,
output wire RREADY,
//AW channel
input wire AWREADY,
output wire AWVALID,
output wire [31:0] AWADDR,
//write data channel
input wire WREADY,
output wire WVALID,
output wire [31:0] WDATA,
output wire [3:0] WSTRB,
// Write Response Channel
input wire BVALID,
input wire [1:0] BRESP,
output wire BREADY,

output wire done
    );


wire aligner_valid_out;
wire aligner_done;
wire [31:0] aligned_data;
wire [31:0]aligned_rd_addr;
wire [31:0] aligned_rd_addr_end;
wire  rd_data_valid;
wire mem_rd_valid;
wire mem_rd_en;
wire [31:0] mem_rd_addr;
wire [31:0] mem_rd_data;



wire fifo_wr_en;
wire fifo_rd_en;
wire [31:0] fifo_wr_data;
wire [31:0] fifo_rd_data;
wire fifo_full;
wire fifo_empty;



wire [31:0] unaligned_dst_addr;
wire dealigner_valid_out;
wire [31:0]dealigned_data;
wire [3:0]dealigned_strb;
wire write_gen_done;
wire [31:0]aligned_dst_addr;
wire [4:0] bytes_written;




wire [31:0] mem_wr_addr;
wire  mem_wr_en;
wire  req_data;

wire write_done;
    aligner align_inst(clk,rst,trigger,mem_rd_valid,source_address,length,mem_rd_data,aligner_valid_out,aligner_done,aligned_data,aligned_rd_addr,aligned_rd_addr_end);
       assign RREADY = (ARVALID && ARREADY && rd_data_valid);
       assign mem_rd_data = (RVALID && RREADY)? mem_rd_data: 0;//R handshake
       
    read_block read_ctrl (clk,rst,trigger,aligned_rd_addr,aligned_rd_addr_end,mem_rd_addr,mem_rd_en,rd_data_valid);
    assign mem_rd_valid = rd_data_valid;
    assign ARVALID = mem_rd_en;
    assign ARADDR = (ARVALID && ARREADY)? mem_rd_addr: 0;//AR handshake
    
    fifo fifo_inst (clk,rst,fifo_wr_en,fifo_rd_en,fifo_wr_data,fifo_rd_data,fifo_full,fifo_empty);
    assign fifo_wr_data =    aligned_data;
    assign fifo_wr_en = (aligner_valid_out && !fifo_full);
    assign fifo_rd_en = !fifo_empty;
    
    dealigner dealign_inst (clk,rst,trigger,fifo_rd_en,unaligned_dst_addr,
        length,fifo_rd_data,dealigner_valid_out,write_gen_done,dealigned_data,dealigned_strb);
    assign unaligned_dst_addr = destination_address;
    
    assign WSTRB = (WVALID && WREADY)? dealigned_strb:0;
    assign WVALID = AWVALID && AWREADY &&  dealigner_valid_out;
    assign WDATA= (WVALID && WREADY)? dealigned_data:0 ;//W handshake
    assign done = write_gen_done;
    
    
    
    write_block write_ctrl(clk,rst,trigger,length,unaligned_dst_addr,write_done,mem_wr_addr, mem_wr_en, req_data);

assign AWVALID = mem_wr_en ;
assign AWADDR = (AWVALID && AWREADY)? mem_wr_addr: 0;    //AW handshake

    endmodule