`timescale 1ns / 1ps
/******************************************************************************
* File Name           : i2c_max1238_ctrl.v
*------------------------------------------------------------------------------
* Function            : i2c MAX1238 controler on Verilog-HDL
*                       Source based on Himawari (http://www.hmwr-lsi.co.jp/fpga/fpga_6.htm)
*                        
*------------------------------------------------------------------------------
* Designer            : Eunchong Kim
*------------------------------------------------------------------------------
* Created             : 11/7/2017 
/******************************************************************************/
module i2c_max1238_ctrl ( 
    input               clk,
    input               reset,
    output              led_ctrl,
    output reg          wr_flg,
    output reg          rd_flg,
    output reg [6:0]    adr,
    output reg [31:0]   wr_data,
    output reg [2:0]    wr_bytes,
    input       [31:0]  rd_data,
    output reg [2:0]    rd_bytes,
    output reg [3:0]    rd_channels, // max 16 channels
    input               rd_data_en,
    output reg [7:0]    tx_fifo_data,    //tx fifo data 8bit
    output reg          tx_fifo_data_en  //tx fifo data enable 
  );
 
    reg  [25:0] main_cnt; // Main Count
    reg       init_cnt;
    reg [3:0] output_cnt;  
    reg [3:0] rd_channel_cnt; 
    reg [7:0] WR_SETUP; 
    reg [7:0] WR_CONFIGURATION;


// Main Count
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) begin 
            main_cnt <= 26'b0;
            init_cnt <= 1'b1;   // initilize MAX1238
        end
        else if (main_cnt == 26'd39999999) begin   // every 1 s
            main_cnt <= 26'b0;
            init_cnt <= 1'b0;   // initilize for once
        end
        else
            main_cnt <= main_cnt + 26'd1;
    end
   
    assign led_ctrl = main_cnt[25];
 
   
  // for MAX1238 ADC
  // Setup
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1)
            WR_SETUP <= 8'b1000_0000;
        else
            WR_SETUP <= 8'b1010_0010;
    end

  // Configuration
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1)
            WR_CONFIGURATION <= 8'b0000_0000;
        else
 //          WR_CONFIGURATION <= 8'b0000_0001; // single conversion
            WR_CONFIGURATION <= 8'b0001_0111; // scan mode conversion
    end

  // Write for Setup, Configuration
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) begin
            wr_flg <= 1'b0;
            wr_data <= 32'h00000000;
            wr_bytes <= 4'd0; 
            adr <= 7'b0110101;    //MAX1238
        end
        else if ( (main_cnt==26'd500) && (init_cnt==1'b1) ) begin // for the first time
            wr_flg <= 1'b1;
            adr <= adr ;
            wr_bytes <= 3'd2; // 2 bytes Setup and Configuration data
            wr_data <= {WR_SETUP,WR_CONFIGURATION,16'h00};
        end
        else begin
            wr_flg <= 1'b0;
            wr_data <= wr_data;
            adr <= adr;
            wr_bytes <= wr_bytes; 
        end
    end
  
  // Read, 2 bytes per channels
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) begin
            rd_flg <= 1'b0; 
            rd_bytes <= 3'd0; 
        end   
        else if ( main_cnt == 26'd40000 ) begin // 1 ms after setup and configure 
            rd_flg <= 1'b1;
            rd_bytes <= 3'd2; // read 2 bytes (8bit x 2)
        end
        else begin   
            rd_flg <= 1'b0;
            rd_bytes <= rd_bytes; 
        end   
    end
  
  // channels
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) 
            rd_channels <= 4'd0;
        else 
            rd_channels <= 4'd11; // 11 channels
    end
    
  // read channel count
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) 
            rd_channel_cnt <= 4'd15;
        else if (rd_channel_cnt == 4'd15 && rd_flg == 1'b1)
            rd_channel_cnt <= 4'd0;
        else if (rd_channel_cnt < 4'd15 && output_cnt == 4'd1)
            rd_channel_cnt <= rd_channel_cnt + 4'd1;
        else if (rd_channel_cnt == rd_channels)
            rd_channel_cnt <= 4'd15;
        else
            rd_channel_cnt <= rd_channel_cnt;
    end

  // output data count per channel
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) 
            output_cnt <= 4'd0;
        else if (rd_data_en == 1'b1)
            output_cnt <= {1'd0,rd_bytes} + 4'd2; // + Header
        else if (output_cnt > 4'd0)
            output_cnt <= output_cnt - 4'd1;
        else
            output_cnt <= output_cnt;
    end

  // output data 
    always @ (posedge clk or negedge reset ) begin
        if (reset == 1'b1) begin
            tx_fifo_data <= 8'h00;
            tx_fifo_data_en <= 1'b0;
        end
        else if (output_cnt == 4'd4) begin
            tx_fifo_data <= 8'h52;    // "R"
            tx_fifo_data_en <= 1'b1;
        end
        else if (output_cnt == 4'd3) begin
            tx_fifo_data <= {4'd0,rd_channel_cnt};    // channel #
            tx_fifo_data_en <= 1'b1;
        end
        else if (output_cnt == 4'd2) begin
            tx_fifo_data <= {4'd0,rd_data[27:24]};
            tx_fifo_data_en <= 1'b1;
        end
        else if (output_cnt == 4'd1) begin
            tx_fifo_data <= rd_data[23:16];
            tx_fifo_data_en <= 1'b1;
        end
        else begin
            tx_fifo_data <= 8'h00;
            tx_fifo_data_en <= 1'b0;
        end     
    end

/*
//Hex to ASCII
function [7:0] hex2ascii;
  input [3:0] hex_data;
  begin
    if (hex_data < 4'ha)  // 0 to 9
      hex2ascii = 8'h30 + hex_data;
    else                  // a to f
      hex2ascii = 8'h57 + hex_data; 
  end
endfunction
   
// Hex to Binary Code (digital converter integral 2 digit)
function [11:0] hex2bcd;
  input [7:0] hex_data;
  reg   [7:0] tmp_data;   
  begin
    if (hex_data >= 8'hc8) begin
      hex2bcd[11:8] = 4'h2;
      tmp_data = hex_data -8'hc8;       
    end
    else if (hex_data >= 8'h64) begin
      hex2bcd[11:8] = 4'h1;
      tmp_data = hex_data -8'h64;      
    end
    else begin
      hex2bcd[11:8] = 4'h0;
      tmp_data = hex_data; 
    end
    // 
    if (tmp_data >= 8'h5A) begin
      hex2bcd[7:4] = 4'h9;
      tmp_data = tmp_data -8'h5a;       
    end
    else if (tmp_data >= 8'h50) begin
      hex2bcd[7:4] = 4'h8;
      tmp_data = tmp_data -8'h50;       
    end
    else if (tmp_data >= 8'h46) begin
      hex2bcd[7:4] = 4'h7;
      tmp_data = tmp_data -8'h46;       
    end
    else if (tmp_data >= 8'h3c) begin
      hex2bcd[7:4] = 4'h6;
      tmp_data = tmp_data -8'h3c;       
    end
    else if (tmp_data >= 8'h32) begin
      hex2bcd[7:4] = 4'h5;
      tmp_data = tmp_data -8'h32;       
    end
    else if (tmp_data >= 8'h28) begin
      hex2bcd[7:4] = 4'h4;
      tmp_data = tmp_data -8'h28;       
    end
    else if (tmp_data >= 8'h1e) begin
      hex2bcd[7:4] = 4'h3;
      tmp_data = tmp_data -8'h1e;       
    end
    else if (tmp_data >= 8'h14) begin
      hex2bcd[7:4] = 4'h2;
      tmp_data = tmp_data -8'h14;      
    end
    else if (tmp_data >= 8'ha) begin
      hex2bcd[7:4] = 4'h1;
      tmp_data = tmp_data -8'ha;        
    end
    else begin
      hex2bcd[7:4] = 4'h0;
      tmp_data = tmp_data ;    
    end
    //
    hex2bcd[3:0] = tmp_data[3:0];
  end
endfunction

// Hex to Binary code (digital converter, point 1 digit)
function [3:0] hex2point1;
  input [3:0] hex_data;
  begin
    if (hex_data==4'hf)
      hex2point1 = 4'd9;
    else if (hex_data>=4'hd)
      hex2point1 = 4'd8;
    else if (hex_data>=4'hc)
      hex2point1 = 4'd7;
    else if (hex_data>=4'ha)
      hex2point1 = 4'd6;
    else if (hex_data>=4'h8)
      hex2point1 = 4'd5;
    else if (hex_data>=4'h7)
      hex2point1 = 4'd4;
    else if (hex_data>=4'h5)
      hex2point1 = 4'd3;
    else if (hex_data>=4'h4)
      hex2point1 = 4'd2;
    else if (hex_data>=4'h2)
      hex2point1 = 4'd1;
    else
      hex2point1 = 4'd0;
  end
endfunction
*/
   
endmodule