`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.05.2026 00:58:50
// Design Name: instruction cache
// Module Name: i_cache
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

`define tag 31:13   //position of tag in address (19 bits)
`define index 12:2  //position of set index in address (11 bits)
`define offset 1:0  //position of offset in address (2 bits)


module i_cache
    #(
    parameter size = 16*1024*8, /* desired cache size in Kilobytes x conversion factor from Kilobytes to bytes 
                                    x conversion factor from bytes to bits */
    parameter nways = 2,        // no of ways in each set
    parameter nsets = 2048,     // no of sets = 2^11 
    parameter block_size = 32,  // no of bits per block 
    parameter width = 32,       // width of the data bus between cpu and cache
    parameter mwidth = 32,      // width of the data bus between cache and main memory
    parameter index_width = 11,
    parameter tag_width = 19,
    parameter offset_width = 2
    )
    (
    input clk,
    input [width-1:0] address,      //address from cpu
    input rden,                     // 1 if load inst
    input [width-1:0] mq,           // data from memory to cache
    input mem_ready,
    output [width-1:0] q,           // data from cache to cpu
    output [width-1:0] mrdaddress,  // memory read address 
    output mrden,                    // 1 if reading from memory
    output stall
    );
    
    // way 1 flags and data
    reg valid1 [0:nsets-1];                 // 0 if garbage data, 1 if valid data 
    reg lru1 [0:nsets-1];                   // 0 if most recently accessed, else 1
    reg [tag_width-1:0] tag1 [0:nsets-1];   // tag associated with each cache line
    reg [mwidth-1:0] mem1 [0:nsets-1];      // the part of the cache that actually stores the 32-bit data blocks
    
    // way 2 flags and data
    reg valid2 [0:nsets-1];
    reg lru2 [0:nsets-1];
    reg [tag_width-1:0] tag2 [0:nsets-1];
    reg [mwidth-1:0] mem2 [0:nsets-1];
    
    // flag initialization
    integer k;
    initial begin
        for (k=0;k<nsets;k=k+1) begin
            valid1[k] <= 0;
            valid2[k] <= 0;
            lru1[k] <= 0;
            lru2[k] <= 0; 
        end
    end
    
    reg [width-1:0] _q = {width{1'b0}};
    reg [$clog2(nways)-1:0] alloc_way;
    reg _mrden = 1'b0;
    
    assign mrdaddress = {address[`tag],address[`index],{offset_width{1'b0}}};
    assign q = _q;
    assign mrden = _mrden;
    
    // state parameters
    localparam idle = 1'b0;
    localparam miss = 1'b1;
    
    reg current_state = idle;
    
    assign stall = current_state == miss;
    
    always@(posedge clk) begin
        case(current_state)
            idle : begin
                
                if(~rden) current_state <= idle;
                
                else if((valid1[address[`index]] && (tag1[address[`index]] == address[`tag]))) begin
                    _q <= mem1[address[`index]];
                    lru1[address[`index]] <= 0;
                    lru2[address[`index]] <= 1;
                end  
                
                else if((valid2[address[`index]] && (tag2[address[`index]] == address[`tag]))) begin
                    _q <= mem2[address[`index]];
                    lru2[address[`index]] <= 0;
                    lru1[address[`index]] <= 1;
                end 
                
                else begin
                    alloc_way <= ~valid1[address[`index]] ? 1'b0 :
                                 ~valid2[address[`index]] ? 1'b1 :
                                 lru1[address[`index]] ? 1'b0 : 1'b1;
                    _mrden <= 1;
                    current_state <= miss;   
                end           
            end
            
            miss: begin
                if(mem_ready) begin
                    case(alloc_way)
                        1'b0 : begin
                            mem1[address[`index]] <= mq;
                            _q <= mq;
                            tag1[address[`index]] <= address[`tag];
                            valid1[address[`index]] <= 1;
                            lru1[address[`index]] <= 0;
                            lru2[address[`index]] <= 1;
                        end
                        1'b1 : begin
                            mem2[address[`index]] <= mq;
                            _q <= mq;
                            tag2[address[`index]] <= address[`tag];
                            valid2[address[`index]] <= 1;
                            lru2[address[`index]] <= 0;
                            lru1[address[`index]] <= 1;
                        end
                    endcase
                    _mrden <= 0;
                    current_state <= idle;
                end
                
                else current_state <= miss;
            end
            
            default : current_state <= idle;
        endcase
    end
    
endmodule
