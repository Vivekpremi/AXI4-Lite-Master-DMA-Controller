// Code your testbench here
// or browse Examples
// Code your testbench here
// or browse Examples
`timescale 1ns/1ns

module tb();

logic clk;
logic reset_n;

logic trigger;
logic[31:0] length;
logic[31:0] destination_address;
logic[31:0] source_address;

logic[31:0] awaddr;
logic awready;
logic awvalid;

logic wready;
logic[31:0] wdata;
logic wvalid;
  logic[3:0] wstrb;

logic arready;
logic[31:0] araddr;
logic arvalid;

logic rvalid;
logic[31:0] rdata;
logic rready;

logic bresp;
logic bvalid;
logic bready;

logic done;

reg[31:0] read_address;
reg[31:0] write_address;

dma_controller top_module_inst(
    .clk(clk),
    .rst(reset_n),
    .trigger(trigger),
    .length(length),
    .destination_address(destination_address),
    .source_address(source_address),
    .AWADDR(awaddr),
    .AWREADY(awready),
    .AWVALID(awvalid),
    .WREADY(wready),
    .WDATA(wdata),
    .WVALID(wvalid),
  	.WSTRB(wstrb),
    .ARREADY(arready),
    .ARADDR(araddr),
    .ARVALID(arvalid),
    .RVALID(rvalid),
    .RDATA(rdata),
    .RREADY(rready),
    .BRESP(bresp),
    .BVALID(bvalid),
    .BREADY(bready),
    .done(done)
);


initial begin
    clk = 1'b0;
end

always #10 clk = ~clk;
integer i;
  
logic[31:0] mem[0:255];
logic busy_ar;
logic busy_r;

  

//task automatic axi_write();
//begin @(posedge clk);
//    awready = 1'b1;
//    wready = 1'b1;
//    fork
//    begin
//        wait(awvalid && awready);
//        @(posedge clk);
//        awready = 1'b0;
//        write_address = awaddr;
//    end
//    begin
//        wait(wvalid && wready);
//        @(posedge clk);
//        wready = 1'b0;
//        mem[write_address] = wdata;
//    end
//    join
//    #40
//    @(posedge clk);
//    bvalid = 1'b1;
//    bresp = 1'b1;
//    wait(bvalid && bready);
//    @(posedge clk);
//    bvalid = 1'b0;
//end
//endtask

task automatic axi_read();
    arready = 1'b1;

    wait( arvalid && arready);
    read_address = araddr;
    #20;
    arready = 1'b0;
    rvalid = 1'b1;
    wait ( rready && rvalid);
    rdata = mem[read_address/4];
    #20;
    rvalid = 1'b0;
endtask


task automatic axi_write();
    awready = 1'b1;
    wready = 1'b1;
    
    fork
    begin
        wait(awvalid && awready);
      	write_address = awaddr/4;
        #20;
        awready = 1'b0;
    end
    begin
      	wait(wvalid && wready);
      	#20
        mem[write_address] = wdata;
      $display("writing in memory ");
        #40;
        wready = 1'b0;
    end
    join

    bvalid = 1'b1;
    wait(bvalid && bready);
    bresp = 1;
    #20;
    bvalid = 1'b0;
    bresp = 0;
	#20;

endtask



always @(posedge trigger)
begin
    #100
  repeat(2)
    begin
        axi_read();
    end
end

always @(posedge trigger)
begin
    #1000
  repeat(2)
    begin
        axi_write();
    end
end

initial begin
    $dumpfile("top_module_tb.vcd");
    $dumpvars;
end

// always @(posedge clk)
//   begin
//     for( i = 0; i < 20; i= i + 1)
//       begin $display(" The Memory is %h", mem[i]); 
//         $display("---------------------");
//       end
//   end
  //always @(posedge clk)
    //$display(" The memory is ", mem);
    //$display("FIFO is ", top_module_inst.fifo_inst.mem);

initial begin
    #3000
    $finish;
end

initial begin
    length = 5;
  for(int i = 0; i < 255; i++)
    begin
        mem[i] = {$random};
    end
    reset_n = 1'b1;
    #50
    reset_n = 1'b0;
    source_address = 32'b1;
    destination_address =32'd13;
    @ (posedge clk) trigger = 1'b1;
    @ (posedge clk) trigger = 1'b0;
    //wait(done);
    #1500
//   for(int i = 0; i < (length/4); i++)
//       if(mem[source_address + i] == mem[destination_address + i])
//             $display("Success");
//         else
//           $display("Error %d != %d	", mem[i+source_address], mem[i+destination_address]);
    #2000
    $finish;
end



endmodule
