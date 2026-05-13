`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.05.2026 13:15:17
// Design Name: main memory
// Module Name: mem
// Project Name: 4-way set-associative cache
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


module mem
    #(
    parameter depth = 16*1024, // desired memory size in Kilobytes x  conversion factor from Kilobytes to bytes
    parameter block_size = 64,
    parameter cpu_width = 32,
    parameter file = "",
    parameter init = 0,
    parameter latency = 3
    )
    (
    input clk,
    input [block_size-1:0] din,
    input [cpu_width-1:0] rdaddress,
    input rden,
    input [cpu_width-1:0] wraddress,
    input wren,
    output reg [block_size-1:0] dout,
    output reg mem_read_ready,
    output reg mem_write_ready
    );
    
    reg [7:0] mem [0:depth-1];
    
    integer _file;
    integer scan;
    integer i;
    
    initial begin
        if(init) begin
            for(i=0;i<depth;i=i+1)
                mem[i] = 8'd0;
        end
    end
    
    reg delay_read = 0;
    reg delay_write = 0;
    
    reg [block_size-1:0] _din;
    reg [$clog2(depth)-1:0] in_rdaddress;
    reg [$clog2(depth)-1:0] in_wraddress;
    
    integer counter = 0;
    
    always @(posedge clk) begin
        mem_read_ready <= 0;
        mem_write_ready <= 0;
        
        if(!delay_read && !delay_write && counter == 0) begin
            if(rden) begin
                delay_read <= 1;
                in_rdaddress <= rdaddress[$clog2(depth)-1:0];
                counter <= latency;
            end
            
            else if(wren) begin
                delay_write <= 1;
                in_wraddress <= wraddress[$clog2(depth)-1:0];
                _din <= din;
                counter <= latency;
            end
        end
        
        else begin
            if(counter >1) counter <= counter - 1;
            
            else begin
                
                counter <= 0;
                
                if(delay_read) begin
                    for(i=0;i<block_size/8;i=i+1)
                        dout[i*8 +:8] <= mem[in_rdaddress+i];
                    mem_read_ready <= 1;
                    delay_read <= 0;
                end
                
                else if(delay_write) begin
                    for(i=0;i<block_size/8;i=i+1)
                        mem[in_wraddress+i] <= _din[i*8 +:8];
                    mem_write_ready <= 1;
                    delay_write <= 0;
                end
            end
        end
    end
endmodule
