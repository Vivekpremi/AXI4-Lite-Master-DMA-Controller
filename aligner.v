`timescale 1ns / 1ps

module aligner (
    input  wire        clk,
    input  wire        rst,
    input  wire        trigger,
    input  wire        fifo_full,       // '1' when rd_data is valid
    input  wire [31:0] source_address,          // unaligned starting address
    input  wire [4:0]  length,           // number of bytes to read
    input  wire [31:0] rd_data,          // 32-bit input from memory
        // '1' when aligned_data is valid
    output reg         done,             // '1' when final word is output
    output [31:0] fifo_aligned_data,  
    output aligner_ar_valid,aligner_r_ready,   // aligned output
    output wire [31:0] curr_araddr,   
    output wire fifo_wr_en;
   // aligned start address
       // aligned end address
);
   

    wire [2:0] offset;
    wire [31:0] total_bytes;
    wire [31:0] total_bytes_rounded;
    wire [4:0]  word_count;
    wire [31:0] last_bytes ;

    assign aligned_start_addr = {address[31:2], 2'b00};
    assign aligned_end_addr   = {{source_address + {27'b0,length}}[31:2],2'b0};
    assign offset     = source_address[1:0];
    

 
    reg [31:0] prev_buffer;
    reg [31:0] curr_addr;
    reg  [31:0] aligned_data, 
    reg ar_valid;
    reg valid_out;
    // reg [2:0]  offset_reg;
    // reg [2:0]  last_bytes;
    reg active;

    wire [31:0] next_addr;
    
      assign next_addr = curr_araddr + 4;

    initial begin
            aligned_data  <= 0;
            prev_buffer   <= 0;
            done          <= 0;
            ar_valid      <= 0;
            valid_out     <=0;
            curr_addr   <= aligned_start_addr-4 ;

    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            aligned_data  <= 0;
            prev_buffer   <= 0;
            done          <= 0;
            curr_addr   <= 0 ;
            ar_valid      <= 0;
            valid_out   <=0;
            curr_addr   <= aligned_start_addr-4 ;
            active        <= 0;
        end else begin
            if (start) begin
                done       <= 0;
                prev_buffer   <= 0;
                curr_addr   <= aligned_start_addr-4 ;
                active<=1;
            end
                // offset_reg <= 2'b11-offset[1:0]+2'b01;
              if(active && (curr_addr<aligned_end_addr && aligner_r_ready)) begin
                case (offset)
                    0: begin
                        aligned_data <= rd_data;
                        valid_out     <=1;
                    end
                    3: begin
                        if (curr_addr == aligned_start_addr)
                            prev_buffer[7:0] <= rd_data[31:24];
                        else begin
                            aligned_data  <= {rd_data[23:0],prev_buffer[7:0]};
                            prev_buffer[7:0] <= rd_data[31:24];
                            valid_out     <=1;
                           
                        end
                    end
                    2: begin
                        if (curr_addr == aligned_start_addr)
                            prev_buffer[15:0] <= rd_data[31:16];
                        else begin
                            aligned_data  <= {rd_data[15:0],prev_buffer[15:0]};
                            prev_buffer[15:0]  <= rd_data[31:16];
                            valid_out     <=1;
                           
                        end
                    end
                    1: begin
                        if (curr_addr == aligned_start_addr)
                           prev_buffer[23:0] <= rd_data[31:8];
                        else begin
                            aligned_data  <= {rd_data[7:0],prev_buffer[23:0]};
                            prev_buffer[23:0] <= rd_data[31:8];
                            valid_out     <=1;
                        end
                    end
                endcase

                curr_addr <= next_addr;
                ar_valid<=1;
                end
                // Final word handling
                if (curr_addr == aligned_end_addr) begin
                    done <= 1;
                    valid_out     <=0;
                    ar_valid<=0;
                    active<=0;
                end
               
            end else begin
                valid_out <= 0;
            end
        end

        assign fifo_aligned_data = aligned_data;
        assign aligner_ar_valid = ar_valid;
        assign aligner_r_ready = ~fifo_full;
        assign curr_araddr = (ar_valid)?curr_araddr : 32'b0;
        assign fifo_wr_en = valid_out;
endmodule
