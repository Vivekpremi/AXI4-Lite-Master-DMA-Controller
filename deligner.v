`timescale 1ns / 1ps

module dealigner (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        fifo_valid,         // Valid signal for fifo_data
    input  wire [31:0] address,          // Unaligned start address
    input  wire [4:0]  length,           // Total number of bytes to write
    input  wire [31:0] fifo_data,       // Full aligned word input

    output reg         valid_out,        // Valid when wr_data/addr/wstrb are valid
    output reg         done,             // Asserted when last word goes out
   
    output reg  [31:0] wr_data,          // Data to write
    output reg  [3:0]  wr_strb      // Bytes written
);

    // Internal variables
      reg [4:0] bytes_written ;
    wire [1:0] offset = address[1:0];
    reg  [4:0] count;
    reg  [31:0] base_addr;
    reg  [31:0]  total_bytes;
    reg  active;
	
    reg [31:0] prev_buff;
        always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out     <= 0;
            done          <= 0;
            count         <= 0;
            bytes_written <= 0;
            wr_data       <= 0;
            wr_strb       <= 0;
            prev_buff  <=  0;
         
            base_addr     <= 0;
            total_bytes   <= 0;
            active        <= 0;
        end else begin
            if (start) begin
                base_addr     <= {address[31:2], 2'b00};  // Word-aligned base address
                count         <= 0;
                valid_out     <= 0;
                done          <= 0;
                bytes_written <= 0;
                prev_buff <=0;
                total_bytes   <= length;
                active        <= 1;
            end else if (active && fifo_valid) begin
                //wr_data   <= fifo_data;
             
                valid_out <= 1;

                // First word case
                if(bytes_written==0)begin
                    case(offset)
                        2'd0: wr_strb <= (length >= 4) ? 4'b1111 : (4'b1111 >>(4- length));
                        2'd1: wr_strb <= (length >= 3) ? 4'b1110 : {3'b111 >> (3-length),1'b0};
                        2'd2: wr_strb <= (length >= 2) ? 4'b1100 : {2'b11 >> (2-length),2'b00} ;
                        2'd3: wr_strb <= (length >= 1) ? 4'b1000 : {1'b1 >> (1-length),3'b000};
                    endcase
                    bytes_written <= (length >= 4-offset) ? 4-offset : length ;
                end
                else begin
                     if ((total_bytes - bytes_written) >= 4)  wr_strb <= 4'b1111;
                     else  wr_strb <= (4'b1111 >> (4-(total_bytes - bytes_written)));
							
                         bytes_written <= bytes_written + (((total_bytes - bytes_written) >= 4) ? 4 : (total_bytes - bytes_written));
                    end
                if(active && fifo_valid && bytes_written<length)begin
                                
                               case (offset)
                                   2'd0:begin  
                                            
                                            wr_data <= fifo_data;
                                            valid_out<=1;
                                           
                                    end
                                   2'd1:begin
                                     
                                            wr_data <= {fifo_data[23:0],prev_buff[7:0]};
                                            prev_buff[7:0]<=fifo_data[31:24]; 
                                            valid_out<=1;
                                         
                                   end
                                   2'd2:begin
                                      
                                        wr_data <= {fifo_data[15:0],prev_buff[15:0]};
                                        prev_buff[15:0]<=fifo_data[31:16];
                                        valid_out<=1;
                                        
                                   
                                   end
                                   2'd3:begin
                                   
                                        wr_data <= {fifo_data[7:0],prev_buff[23:0]};
                                        prev_buff[23:0] <= fifo_data[31:8];
                                        valid_out<=1;
                                        
                                   end
                                   endcase   
                                    end
               
                                   
                // Check for done
                if (bytes_written >= total_bytes - ((total_bytes - bytes_written >= 4) ? 4 : (total_bytes - bytes_written))) begin
                    done      <= 1;
                    active    <= 0;
                end
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule
