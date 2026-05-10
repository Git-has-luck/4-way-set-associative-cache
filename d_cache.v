`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.05.2026 19:35:50
// Design Name: data cache
// Module Name: d_cache
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
`define index 12:3  //position of set index in address (10 bits)
`define offset 2:0  //position of offset in address (3 bits)


module d_cache
    #(
    parameter size = 32*1024*8, /* desired cache size in Kilobytes x conversion factor from Kilobytes to bytes 
                                    x conversion factor from bytes to bits */
    parameter nways = 4,        // no of ways in each set
    parameter nsets = 1024,     // no of sets = 2^10 
    parameter block_size = 64,  // no of bits per block 
    parameter width = 32,       // width of the data bus between cpu and cache
    parameter mwidth = 64,      // width of the data bus between cache and main memory
    parameter index_width = 10,
    parameter tag_width = 19,
    parameter offset_width = 3,
    parameter word1 = 3,
    parameter word2 = 7
    )
    (
    input clk,
    input [width-1:0] address,      //address from cpu
    input [width-1:0] din,          //data from cpu to cache (if store inst)
    input rden,                     // 1 if load inst
    input wren,                     // 1 if store inst
    input [mwidth-1:0] mq,          // data from memory to cache
    input mem_write_ready,          // 1 if data from cache has been written to memory
    input mem_read_ready,           // 1 if data has been successfully read from main memory
    output [width-1:0] q,           // data from cache to cpu
    output [mwidth-1:0] mdout,      // data from cache to memory
    output [width-1:0] mrdaddress,  // memory read address
    output mrden,                   // 1 if reading from memory
    output [width-1:0] mwraddress,  // memory write addr
    output mwren,                   // 1 if writing to memory
    output stall                    // stall cpu during miss
    );
    
    // way 1 flags and data
    reg valid1 [0:nsets-1];                 // 0 if garbage data, 1 if valid data 
    reg dirty1 [0:nsets-1];                 // 1 if cache data is newer than main memory and needs to be updated in memory
    reg [1:0] lru1 [0:nsets-1];             // lower the value, the more recently the line was accessed
    reg [tag_width-1:0] tag1 [0:nsets-1];   // tag associated with each cache line
    reg [block_size-1:0] mem1 [0:nsets-1];  // the part of the cache that actually stores the 32-bit data blocks
    
    // way 2 flags and data
    reg valid2 [0:nsets-1];
    reg dirty2 [0:nsets-1];
    reg [1:0] lru2 [0:nsets-1];
    reg [tag_width-1:0] tag2 [0:nsets-1];
    reg [block_size-1:0] mem2 [0:nsets-1];
    
    // way 3 flags and data
    reg valid3 [0:nsets-1];
    reg dirty3 [0:nsets-1];
    reg [1:0] lru3 [0:nsets-1];
    reg [tag_width-1:0] tag3 [0:nsets-1];
    reg [block_size-1:0] mem3 [0:nsets-1];
    
    // way 4 flags and data
    reg valid4 [0:nsets-1];
    reg dirty4 [0:nsets-1];
    reg [1:0] lru4 [0:nsets-1];
    reg [tag_width-1:0] tag4 [0:nsets-1];
    reg [block_size-1:0] mem4 [0:nsets-1];
    
    // flag initialization
    integer k;
    initial begin
        for (k=0;k<nsets;k=k+1) begin
            valid1[k] <= 0;
            valid2[k] <= 0;
            valid3[k] <= 0;
            valid4[k] <= 0;
            dirty1[k] <= 0;
            dirty2[k] <= 0;
            dirty3[k] <= 0;
            dirty4[k] <= 0;
            lru1[k] <= 2'b00;
            lru2[k] <= 2'b00;
            lru3[k] <= 2'b00;
            lru4[k] <= 2'b00;
        end
    end
    
    // internal registers
    reg [width-1:0] _q = {width{1'b0}};
    reg _mrden = 1'b0;
    reg [width-1:0] wb_address;
    reg [mwidth-1:0] wb_data;
    reg [(nways/2)-1:0] alloc_way;
    
    assign mwraddress = wb_address;
    assign mdout = wb_data;
    assign mrden = _mrden;
    assign mrdaddress = {address[`tag],address[`index],{offset_width{1'b0}}}; // block address = tag + index
    assign q = _q;
    
    // state parameters 
    localparam idle = 2'b00;        // receive requests from cpu
    localparam write_back = 2'b01;  // write back dirty block to main memory
    localparam allocate = 2'b10;    // read new data to cache line
    
    // state register
    reg [1:0] current_state = idle;
    
    // freeze the cpu when cache is handling a miss (blocking cache)
    assign stall = current_state != idle ;
    
    // cache follows write-back policy where memory write occurs only during dirty line eviction
    assign mwren = current_state == write_back;
    
    always@(posedge clk) begin
        case(current_state)
            idle : begin
            
                // do nothing on null request            
                if(~rden && ~wren) current_state <= idle;
                
                // check way 1 
                else if((valid1[address[`index]] && (tag1[address[`index]] == address[`tag]))) begin
                    // valid1[address['index']] checks whether data in way1 in the set pointed to by `index is valid
                    /* tag1[address[`index]] == address[`tag] compares tag bits of address to tag of
                        way1 of set pointed to by `index */
                    if(rden) _q <= (address[`offset] <= word1) ? mem1[address[`index]][width-1:0] 
                                    : mem1[address[`index]][2*width-1:width];
                    else if (wren) begin
                        _q <= {width{1'b0}};
                        dirty1[address[`index]] <= 1;
                        if (address[`offset] <= word1) mem1[address[`index]][width-1:0] <= din;
                        else mem1[address[`index]][2*width-1:width] <= din;
                    end
                    if (lru2[address[`index]] <= lru1[address[`index]]) lru2[address[`index]] <= lru2[address[`index]] + 1;
                    if (lru3[address[`index]] <= lru1[address[`index]]) lru3[address[`index]] <= lru3[address[`index]] + 1;
                    if (lru4[address[`index]] <= lru1[address[`index]]) lru4[address[`index]] <= lru4[address[`index]] + 1;
                    lru1[address[`index]] <= 0;                          
                end
                
                // check way 2 
                else if((valid2[address[`index]] && (tag2[address[`index]] == address[`tag]))) begin
                    if(rden) _q <= (address[`offset] <= word1) ? mem2[address[`index]][width-1:0] 
                                    : mem2[address[`index]][2*width-1:width];
                    else if (wren) begin
                        _q <= {width{1'b0}};
                        dirty2[address[`index]] <= 1;
                        if (address[`offset] <= word1) mem2[address[`index]][width-1:0] <= din;
                        else mem2[address[`index]][2*width-1:width] <= din;
                    end
                    if (lru1[address[`index]] <= lru2[address[`index]]) lru1[address[`index]] <= lru1[address[`index]] + 1;
                    if (lru3[address[`index]] <= lru2[address[`index]]) lru3[address[`index]] <= lru3[address[`index]] + 1;
                    if (lru4[address[`index]] <= lru2[address[`index]]) lru4[address[`index]] <= lru4[address[`index]] + 1;
                    lru2[address[`index]] <= 0;                          
                end    
                
                // check way 3 
                else if((valid3[address[`index]] && (tag3[address[`index]] == address[`tag]))) begin
                    if(rden) _q <= (address[`offset] <= word1) ? mem3[address[`index]][width-1:0] 
                                    : mem3[address[`index]][2*width-1:width];
                    else if (wren) begin
                        _q <= {width{1'b0}};
                        dirty3[address[`index]] <= 1;
                        if (address[`offset] <= word1) mem3[address[`index]][width-1:0] <= din;
                        else mem3[address[`index]][2*width-1:width] <= din;
                    end
                    if (lru1[address[`index]] <= lru3[address[`index]]) lru1[address[`index]] <= lru1[address[`index]] + 1;
                    if (lru2[address[`index]] <= lru3[address[`index]]) lru2[address[`index]] <= lru2[address[`index]] + 1;
                    if (lru4[address[`index]] <= lru3[address[`index]]) lru4[address[`index]] <= lru4[address[`index]] + 1;
                    lru3[address[`index]] <= 0;                          
                end
                
                // check way 4 
                else if((valid4[address[`index]] && (tag4[address[`index]] == address[`tag]))) begin
                    if(rden) _q <= (address[`offset] <= word1) ? mem4[address[`index]][width-1:0] 
                                    : mem4[address[`index]][2*width-1:width];
                    else if (wren) begin
                        _q <= {width{1'b0}};
                        dirty4[address[`index]] <= 1;
                        if (address[`offset] <= word1) mem4[address[`index]][width-1:0] <= din;
                        else mem4[address[`index]][2*width-1:width] <= din;
                    end
                    if (lru1[address[`index]] <= lru4[address[`index]]) lru1[address[`index]] <= lru1[address[`index]] + 1;
                    if (lru2[address[`index]] <= lru4[address[`index]]) lru2[address[`index]] <= lru2[address[`index]] + 1;
                    if (lru3[address[`index]] <= lru4[address[`index]]) lru3[address[`index]] <= lru3[address[`index]] + 1;
                    lru4[address[`index]] <= 0;                          
                end
                
                else begin
                    
                    // way that is chosen during allocate state. Used to reduce code size
                    alloc_way <= ~valid1[address[`index]] ? 2'd0:
                                ~valid2[address[`index]] ? 2'd1: 
                                ~valid3[address[`index]] ? 2'd2:
                                ~valid4[address[`index]] ? 2'd3:
                                (lru1[address[`index]]==3) ? 2'd0:
                                (lru2[address[`index]]==3) ? 2'd1:
                                (lru3[address[`index]]==3) ? 2'd2:2'd3;
                    
                    // if any cache line is invalid, we can directly allocate data to it
                    if (!(valid1[address[`index]] && valid2[address[`index]] && valid3[address[`index]] 
                          && valid4[address[`index]])) begin
                          _mrden <= 1;
                          current_state <= allocate;
                    end
                    
                    // least recently used cache line has data newer than main memory, needs to be written back
                    else if ((lru1[address[`index]] == 3 && dirty1[address[`index]])
                            || (lru2[address[`index]] == 3 && dirty2[address[`index]])
                            || (lru3[address[`index]] == 3 && dirty3[address[`index]])
                            || (lru4[address[`index]] == 3 && dirty4[address[`index]])) begin
                        
                        current_state <= write_back;
                        
                        /* assign memory write address and data combinationally to avoid latency due to 
                        synchronous assignments inside writeback state */
                        wb_address <=(lru1[address[`index]]==3)?{tag1[address[`index]],address[`index],{offset_width{1'b0}}}:
                                     (lru2[address[`index]]==3)?{tag2[address[`index]],address[`index],{offset_width{1'b0}}}:       
                                     (lru3[address[`index]]==3)?{tag3[address[`index]],address[`index],{offset_width{1'b0}}}:
                                                                {tag4[address[`index]],address[`index],{offset_width{1'b0}}};
                                                                
                        wb_data <= (lru1[address[`index]]==3)? mem1[address[`index]]:
                                   (lru2[address[`index]]==3)? mem2[address[`index]]:
                                   (lru3[address[`index]]==3)? mem3[address[`index]]:
                                                               mem4[address[`index]];                                         
                    end  
                    
                    // no invalid cache lines but no dirty lines either
                    else begin
                        _mrden <= 1;
                        current_state <= allocate;  
                    end
                end   
            end
            
            write_back: begin
                
                if(mem_write_ready) begin
                    _mrden <= 1;
                    current_state <= allocate;
                end
                
                else current_state <= write_back;
                
            end
            
            allocate: begin
            
                if(mem_read_ready) begin
                    case(alloc_way)
                        2'd0:   begin
                            tag1[address[`index]] <= address[`tag];
                            valid1[address[`index]] <= 1;
                            if(wren) begin
                                dirty1[address[`index]] <= 1;
                                if(address[`offset] <= word1) mem1[address[`index]] <= {mq[2*width-1:width],din};
                                else mem1[address[`index]] <= {din,mq[width-1:0]};
                            end
                            else if(rden) begin
                                mem1[address[`index]] <= mq;
                                dirty1[address[`index]] <= 0;
                                _q <= (address[`offset] <= word1) ? mq[width-1:0] : mq[2*width-1:width];
                            end
                            if (lru2[address[`index]] <= lru1[address[`index]]) 
                                lru2[address[`index]] <= lru2[address[`index]] + 1;
                            if (lru3[address[`index]] <= lru1[address[`index]]) 
                                lru3[address[`index]] <= lru3[address[`index]] + 1;
                            if (lru4[address[`index]] <= lru1[address[`index]]) 
                                lru4[address[`index]] <= lru4[address[`index]] + 1;
                            lru1[address[`index]] <= 0;
                        end
                        
                        2'd1: begin
                            tag2[address[`index]] <= address[`tag];
                            valid2[address[`index]] <= 1;
                            if(wren) begin
                                dirty2[address[`index]] <= 1;
                                if(address[`offset] <= word1) mem2[address[`index]] <= {mq[2*width-1:width],din};
                                else mem2[address[`index]] <= {din,mq[width-1:0]};
                            end
                            else if(rden) begin
                                mem2[address[`index]] <= mq;
                                dirty2[address[`index]] <= 0;
                                _q <= (address[`offset] <= word1) ? mq[width-1:0] : mq[2*width-1:width];
                            end
                            if (lru1[address[`index]] <= lru2[address[`index]]) 
                                lru1[address[`index]] <= lru1[address[`index]] + 1;
                            if (lru3[address[`index]] <= lru2[address[`index]]) 
                                lru3[address[`index]] <= lru3[address[`index]] + 1;
                            if (lru4[address[`index]] <= lru2[address[`index]]) 
                                lru4[address[`index]] <= lru4[address[`index]] + 1;
                            lru2[address[`index]] <= 0;
                        end
                        
                        2'd2: begin
                            tag3[address[`index]] <= address[`tag];
                            valid3[address[`index]] <= 1;
                            if(wren) begin
                                dirty3[address[`index]] <= 1;
                                if(address[`offset] <= word1) mem3[address[`index]] <= {mq[2*width-1:width],din};
                                else mem3[address[`index]] <= {din,mq[width-1:0]};
                            end
                            else if(rden) begin
                                mem3[address[`index]] <= mq;
                                dirty3[address[`index]] <= 0;
                                _q <= (address[`offset] <= word1) ? mq[width-1:0] : mq[2*width-1:width];
                            end
                            if (lru1[address[`index]] <= lru3[address[`index]]) 
                                lru1[address[`index]] <= lru1[address[`index]] + 1;
                            if (lru2[address[`index]] <= lru3[address[`index]]) 
                                lru2[address[`index]] <= lru2[address[`index]] + 1;
                            if (lru4[address[`index]] <= lru3[address[`index]]) 
                                lru4[address[`index]] <= lru4[address[`index]] + 1;
                            lru3[address[`index]] <= 0;
                        end
                        
                        2'd3: begin
                            tag4[address[`index]] <= address[`tag];
                            valid4[address[`index]] <= 1;
                            if(wren) begin
                                dirty4[address[`index]] <= 1;
                                if(address[`offset] <= word1) mem4[address[`index]] <= {mq[2*width-1:width],din};
                                else mem4[address[`index]] <= {din,mq[width-1:0]};
                            end
                            else if(rden) begin
                                mem4[address[`index]] <= mq;
                                dirty4[address[`index]] <= 0;
                                _q <= (address[`offset] <= word1) ? mq[width-1:0] : mq[2*width-1:width];
                            end
                            if (lru1[address[`index]] <= lru4[address[`index]]) 
                                lru1[address[`index]] <= lru1[address[`index]] + 1;
                            if (lru2[address[`index]] <= lru4[address[`index]]) 
                                lru2[address[`index]] <= lru2[address[`index]] + 1;
                            if (lru3[address[`index]] <= lru4[address[`index]]) 
                                lru3[address[`index]] <= lru3[address[`index]] + 1;
                            lru4[address[`index]] <= 0;
                        end
                    endcase
                    _mrden <= 0;
                    current_state <= idle;
                end
                
                else current_state <= allocate;
            end
                       
            default : current_state <= idle;
            
        endcase
    end
endmodule
