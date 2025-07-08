`timescale 1ns / 1ps

module aligner (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        data_valid,       // '1' when rd_data is valid
    input  wire [31:0] address,          // unaligned starting address
    input  wire [4:0]  length,           // number of bytes to read
    input  wire [31:0] rd_data,          // 32-bit input from memory

    output reg         valid_out,        // '1' when aligned_data is valid
    output reg         done,             // '1' when final word is output
    output reg  [31:0] aligned_data,     // aligned output
    output wire [31:0] start_addr,      // aligned start address
    output wire [31:0] end_addr       // aligned end address
);
    wire [31:0] end_addr;
    wire [2:0] offset;
    wire [31:0] total_bytes;
    wire [31:0] total_bytes_rounded;
    wire [4:0]  word_count;

    assign start_addr = {address[31:2], 2'b00};
    assign offset     = address[1:0];
    assign total_bytes = offset + length;

    assign total_bytes_rounded = (total_bytes[1:0] == 2'b00) ?
                                  total_bytes :
                                  (total_bytes + (4 - total_bytes[1:0]));

    assign end_addr = start_addr + total_bytes_rounded - 4;
    assign word_count = total_bytes_rounded >> 2;

 
    reg [31:0] prev_buffer;
    reg [4:0]  count;
    reg [2:0]  offset_reg;
    reg [2:0]  last_bytes;

    reg active;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count         <= 0;
            aligned_data  <= 0;
            prev_buffer   <= 0;
            valid_out     <= 0;
            done          <= 0;
            offset_reg    <= 0;
            last_bytes    <= 0;
            active        <= 0;
        end else begin
            if (start) begin
                count      <= 0;
                valid_out  <= 0;
                done       <= 0;
                offset_reg <= 2'b11-offset[1:0]+2'b01;
                last_bytes <= total_bytes[2:0];
                active     <= 1;
            end 
           
              else if (active && data_valid && count< word_count) begin
                case (offset)
                    0: begin
                        aligned_data <= rd_data;
                        valid_out    <= 1;
                    end
                    3: begin
                        if (count == 0)
                            prev_buffer[7:0] <= rd_data[31:24];
                        else begin
                            aligned_data  <= {rd_data[23:0],prev_buffer[7:0]};
                            prev_buffer[7:0] <= rd_data[31:24];
                            valid_out     <= 1;
                        end
                    end
                    2: begin
                        if (count == 0)
                            prev_buffer[15:0] <= rd_data[31:16];
                        else begin
                           
                            aligned_data  <= {rd_data[15:0],prev_buffer[15:0]};
                            prev_buffer[15:0]  <= rd_data[31:16];
                            valid_out     <= 1;
                        end
                    end
                    1: begin
								
                        if (count == 0)
                           prev_buffer[23:0] <= rd_data[31:8];
                        else begin
                            aligned_data  <= {rd_data[7:0],prev_buffer[23:0]};
                            prev_buffer[23:0] <= rd_data[31:8];
                            valid_out     <= 1;
                        end
                    end
                endcase

                count <= count + 1;
                end
                // Final word handling
                else if (active && data_valid && count==word_count) begin
                    done <= 1;
                    active <= 0;

                    // Add don't cares (X) to upper bits of final word
                    
                    if(last_bytes>offset || word_count==1)begin
                         case(offset)
                         1:begin 
                         aligned_data <= {7'b0,prev_buffer[23:0]};
                         valid_out<=1;
                          end 
                         2:begin 
                         aligned_data <= {16'b0,prev_buffer[15:0]};
                         valid_out<=1;
                          end  
                         3:begin                       
                         aligned_data <= {24'b0,prev_buffer[7:0]};
                         valid_out<=1;
                          end
                         endcase 
                    end
                
                    else aligned_data <= rd_data;
               
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule
