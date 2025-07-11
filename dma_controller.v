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
`include "fifo.v"

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

output wire DONE
    );


localparam IDLE = 3'b000,
           R_ADDR = 3'b001,
           Wait_ARREADY = 3'b010,
           Wait_RDATA  = 3'b011,
           Read_Done = 3'b100;

localparam W_ADDR = 3'b001,
           Wait_AWREADY = 3'b010,
           Wait_WREADY  = 3'b011,
           Wait_BRESP  = 3'b100,
           Write_Done = 3'b101;


reg [2:0] rstate,wstate;

reg arvalid;
reg [31:0] araddr;

reg rready;

reg awvalid;
reg [31:0] awaddr;

// reg wvalid;
reg [31:0] wdata;
reg [3:0]  wstrb;

reg bready;
reg done;


reg [31:0]aligned_data;
reg [31:0] r_prev_buffer;
reg [31:0] read_data;


wire [31:0] next_addr;
wire [31:0] aligned_start_raddr,aligned_end_raddr,unaligned_end_raddr;
wire [1:0] roffset;
assign aligned_start_raddr = {source_address[31:2], 2'b00};
assign unaligned_end_raddr = source_address + {27'b0,length};
assign aligned_end_raddr   = {unaligned_end_raddr[31:2],2'b0};
assign roffset       = source_address[1:0];
assign next_addr = araddr + 4;

always@(posedge clk or posedge rst)begin

        if(rst) begin rstate <= IDLE;

            aligned_data  <= 0;
            r_prev_buffer   <= 0;
            araddr   <= 0 ;
            arvalid      <= 0;

        end 
        else begin

            case(rstate)

            IDLE : begin
                if(trigger) begin
                    rstate <= R_ADDR;
                    araddr <= aligned_start_raddr-4;
                end
            end

            R_ADDR : begin
                if($signed(araddr) < $signed(aligned_end_raddr))begin
                    araddr <= next_addr;
                    
                end
                arvalid <= 1'b1;
                rstate <= Wait_ARREADY;
            end

            Wait_ARREADY : begin
                if(ARREADY && arvalid) begin
                    arvalid <= 1'b0;
                    rstate <= Wait_RDATA;
                end

            end

            Wait_RDATA : begin
                if(RVALID) begin
                    case (roffset)
                    0: begin
                        aligned_data <= RDATA;
                        
                    end
                    3: begin
                        if (araddr == aligned_start_raddr)
                            r_prev_buffer[7:0] <= RDATA[31:24];
                        else begin
                            aligned_data  <= {RDATA[23:0],r_prev_buffer[7:0]};
                            r_prev_buffer[7:0] <= RDATA[31:24];
                           
                        end
                    end
                    2: begin
                        if (araddr == aligned_start_raddr)
                            r_prev_buffer[15:0] <= RDATA[31:16];
                        else begin
                            aligned_data  <= {RDATA[15:0],r_prev_buffer[15:0]};
                            r_prev_buffer[15:0]  <= RDATA[31:16];
                          
                        end
                    end
                    1: begin
                        if (araddr == aligned_start_raddr)
                           r_prev_buffer[23:0] <= RDATA[31:8];
                        else begin
                            aligned_data  <= {RDATA[7:0],r_prev_buffer[23:0]};
                            r_prev_buffer[23:0] <= RDATA[31:8];
                        end
                    end
                endcase
                    if(araddr==aligned_end_raddr)begin
                            rstate <= Read_Done;
                        end
                    else begin
                    if(!fifo_full)begin
                        rstate <= R_ADDR;
                    end
                end
                
                end

            end

            Read_Done : begin
                if(wstate == Write_Done) rstate<= IDLE;
                
                 
            end


            endcase

        end



end

wire [31:0] fifo_data_in;

assign fifo_data_in = (rstate == Wait_RDATA && RVALID) ? 
                      (roffset == 3) ? {RDATA[23:0], r_prev_buffer[7:0]} :
                      (roffset == 2) ? {RDATA[15:0], r_prev_buffer[15:0]} :
                      (roffset == 1) ? {RDATA[7:0],  r_prev_buffer[23:0]} :
                      RDATA :
                      32'b0;
fifo fifo(
    .clk(clk),
    .rst(rst),
    .w_en((rstate == Wait_RDATA)&& ~(((roffset!=0)&&(araddr == aligned_start_raddr)))),
    .r_en((wstate == Wait_WREADY) && !fifo_empty),
    .data_in(fifo_data_in),
    .data_out(fifo_data_out),
    .full(fifo_full),
    .empty(fifo_empty)
);
//assert rready for one cycle.
always@(posedge clk or posedge rst)begin
    if(rst) rready <= 1'b0;
    else if(rstate == Wait_RDATA && RVALID) rready<=1'b1;
    else rready <= 1'b0;
end

//write
wire [31:0] aligned_start_waddr;
wire [31:0] aligned_end_waddr,unaligned_end_waddr;
wire [1:0] last_bytes,woffset;
wire [31:0] fifo_data_out;

wire wvalid;
assign wvalid = (wstate == Wait_WREADY ) && ~fifo_empty;

reg [31:0] w_prev_buffer;


assign  aligned_start_waddr = {destination_address[31:2],2'b0};
assign  unaligned_end_waddr =   destination_address + {27'b0,length};
assign  aligned_end_waddr  = {unaligned_end_waddr[31:2],2'b0};
assign  woffset = destination_address[1:0];
assign  last_bytes = unaligned_end_waddr[1:0];

always@(posedge clk or posedge rst)begin
    if(rst) begin wstate <= IDLE;

            awaddr   <= aligned_start_waddr-4 ;
            awvalid        <=0;
            //wvalid        <=0;
            wdata       <= 0;
            wstrb       <= 0;
            w_prev_buffer  <=  0;
            

        end 
    else begin

        case(wstate)

        IDLE:begin
            if(trigger)begin wstate <= W_ADDR;

            awaddr   <= aligned_start_waddr-4 ;
            awvalid        <=0;
            //wvalid        <=0;
            wdata       <= 0;
            wstrb       <= 0;
            w_prev_buffer  <=  0;


            end
        end

        W_ADDR: begin
            awvalid <= 1'b1;
                if(awaddr<aligned_end_waddr)begin
                    awaddr <= awaddr + 4;
                    awvalid <= 1'b1;

                 //wvalid <=~fifo_empty;
                   
                end
                wstate <= Wait_AWREADY;
        end

        Wait_AWREADY: begin
            if(AWREADY & awvalid) begin
                awvalid <= 1'b0;
                wstate <=  Wait_WREADY;
                //wvalid<=~fifo_empty;
            end
            //  else if(~fifo_empty) begin wvalid<=~fifo_empty;
            //          wstate <=  Wait_WREADY;
            // end
        end

        Wait_WREADY:begin
            if(WREADY && wvalid)begin
                //wvalid<=0;
                wstate <= Wait_BRESP;
                //wstrobe logic
                if(awaddr==aligned_start_waddr)begin
                    case(woffset)
                        2'd0: wstrb <= (length >= 4) ? 4'b1111 : (4'b1111 >>(4- length));
                        2'd1: wstrb <= (length >= 3) ? 4'b1110 : {3'b111 >> (3-length),1'b0};
                        2'd2: wstrb <= (length >= 2) ? 4'b1100 : {2'b11 >> (2-length),2'b00} ;
                        2'd3: wstrb <= (length >= 1) ? 4'b1000 : {1'b1 >> (1-length),3'b000};
                    endcase
                    
                end
                else begin
                    if(awaddr == aligned_end_waddr - 4) begin

                            if(last_bytes>=woffset) wstrb<=4'b1111;

                            else wstrb<= 4'b1111 >> (woffset-last_bytes);

                     end
                     else if (awaddr != aligned_end_waddr)  wstrb <= 4'b1111;

                     else  wstrb <= (last_bytes>woffset)?(4'b1111 >> (4-(last_bytes - woffset))):4'b0000;
						
                    end
            
            //wdata logic
            case (woffset)
                2'd0:begin  
                         
                         wdata <= fifo_data_out;
                        
                 end
                2'd1:begin
                  //here we do not check for curr_addr == start_addr bec we are generating strobe already
                         wdata <= {fifo_data_out[23:0],w_prev_buffer[7:0]};
                         w_prev_buffer[7:0]<=fifo_data_out[31:24]; 
                        
                      
                end
                2'd2:begin
                   
                     wdata <= {fifo_data_out[15:0],w_prev_buffer[15:0]};
                     w_prev_buffer[15:0]<=fifo_data_out[31:16];
                    
                     
                
                end
                2'd3:begin
                
                     wdata <= {fifo_data_out[7:0],w_prev_buffer[23:0]};
                     w_prev_buffer[23:0] <= fifo_data_out[31:8];
                    
                     
                end
                endcase 
                end  
            //else wstate <= Wait_AWREADY;

        end

        Wait_BRESP: begin
            if(BVALID)begin
                if(awaddr==aligned_end_waddr)begin
                    wstate <= Write_Done;

                end
                else begin
                   
                        wstate <= W_ADDR;
                  
                end
            end

        end

        Write_Done:begin
            if(rstate == Read_Done) wstate <= IDLE;
            

        end


    endcase

    end
end

//
wire [31:0] w_data;
assign w_data= (wstate == Wait_WREADY &&  WREADY && wvalid) ? 
                      (woffset == 3) ? {fifo_data_out[7:0],w_prev_buffer[23:0]} :
                      (woffset == 2) ? {fifo_data_out[15:0],w_prev_buffer[15:0]} :
                      (woffset == 1) ? {fifo_data_out[23:0],w_prev_buffer[7:0]} :
                      fifo_data_out :
                      32'b0;

//assert bready for one cycle.
always@(posedge clk or posedge rst)begin
    if(rst) bready <= 1'b0;
    else if(wstate == Wait_BRESP && BVALID) bready<=1'b1;
    else bready <= 1'b0;
end

always@(posedge clk or posedge rst)begin
    if(rst) done <= 1'b0;
    else if((rstate == Read_Done) && (wstate == Write_Done)) done<=1'b1;
    else if(trigger)done <= 1'b0;
end

assign DONE = done;
assign ARVALID = arvalid;
assign ARADDR = araddr;
assign RREADY = rready;
assign AWVALID = awvalid;
assign WDATA  = w_data;
assign WVALID = wvalid;
assign WSTRB  = wstrb;
assign BREADY = bready;
assign AWADDR = awaddr;
endmodule 


























// wire aligner_valid_out;
// wire aligner_done;
// wire [31:0] aligned_data;
// wire [31:0]aligned_rd_addr;
// wire [31:0] aligned_rd_addr_end;
// wire  rd_data_valid;
// wire mem_rd_valid;
// wire mem_rd_en;
// wire [31:0] mem_rd_addr;
// wire [31:0] mem_rd_data;



// wire fifo_wr_en;
// wire fifo_rd_en;
// wire [31:0] fifo_wr_data;
// wire [31:0] fifo_rd_data;
// wire fifo_full;
// wire fifo_empty;



// wire [31:0] unaligned_dst_addr;
// wire dealigner_valid_out;
// wire [31:0]dealigned_data;
// wire [3:0]dealigned_strb;
// wire write_gen_done;
// wire [31:0]aligned_dst_addr;
// wire [4:0] bytes_written;




// wire [31:0] mem_wr_addr;
// wire  mem_wr_en;
// wire  req_data;

// wire write_done;
//     aligner align_inst(clk,rst,trigger,mem_rd_valid,source_address,length,mem_rd_data,aligner_valid_out,aligner_done,aligned_data,aligned_rd_addr,aligned_rd_addr_end);
//        assign RREADY = (ARVALID && ARREADY && rd_data_valid);
//        assign mem_rd_data = (RVALID && RREADY)? mem_rd_data: 0;//R handshake
       
//     read_block read_ctrl (clk,rst,trigger,aligned_rd_addr,aligned_rd_addr_end,mem_rd_addr,mem_rd_en,rd_data_valid);
//     assign mem_rd_valid = rd_data_valid;
//     assign ARVALID = mem_rd_en;
//     assign ARADDR = (ARVALID && ARREADY)? mem_rd_addr: 0;//AR handshake
    
//     fifo fifo_inst (clk,rst,fifo_wr_en,fifo_rd_en,fifo_wr_data,fifo_rd_data,fifo_full,fifo_empty);
//     assign fifo_wr_data =    aligned_data;
//     assign fifo_wr_en = (aligner_valid_out && !fifo_full);
//     assign fifo_rd_en = !fifo_empty;
    
//     dealigner dealign_inst (clk,rst,trigger,fifo_rd_en,unaligned_dst_addr,
//         length,fifo_rd_data,dealigner_valid_out,write_gen_done,dealigned_data,dealigned_strb);
//     assign unaligned_dst_addr = destination_address;
    
//     assign WSTRB = (WVALID && WREADY)? dealigned_strb:0;
//     assign WVALID = AWVALID && AWREADY &&  dealigner_valid_out;
//     assign WDATA= (WVALID && WREADY)? dealigned_data:0 ;//W handshake
//     assign done = write_gen_done;
    
    
    
//     write_block write_ctrl(clk,rst,trigger,length,unaligned_dst_addr,write_done,mem_wr_addr, mem_wr_en, req_data);

// assign AWVALID = mem_wr_en ;
// assign AWADDR = (AWVALID && AWREADY)? mem_wr_addr: 0;    //AW handshake

//     endmodule