`timescale 1ns / 1ps
//******************************************************************************
// File Name            : i2c_max1238_ctrl.v
//------------------------------------------------------------------------------
// Function             : i2c MAX1238 controler on Verilog-HDL
//                        Source based on Himawari (http://www.hmwr-lsi.co.jp/fpga/fpga_6.htm)
//                        
//------------------------------------------------------------------------------
// Designer             : Eunchong Kim
//------------------------------------------------------------------------------
// Last Modified        : 10/25/2017 by Eunchong Kim
//******************************************************************************
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
  
  wire [3:0] wr_be;  // Write Byte Enable
  wire [3:0] rd_be;  // Read Byte Enable
   
  reg       init_cnt;
  reg [3:0] output_cnt;
  
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
          WR_CONFIGURATION <= 8'b0000_0001;
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
          rd_channels <= 4'd12; // 12 channels
  end

// wr_flg,rd_flg byte enable
assign wr_be = (wr_bytes == 3'd1) ? 4'b1000 :    
               (wr_bytes == 3'd2) ? 4'b1100 : 
               (wr_bytes == 3'd3) ? 4'b1110 :
               (wr_bytes == 3'd4) ? 4'b1111 : 4'b0000;
   
assign rd_be = (rd_bytes == 3'd1) ? 4'b1000 :    
               (rd_bytes == 3'd2) ? 4'b1100 : 
               (rd_bytes == 3'd3) ? 4'b1110 :
               (rd_bytes == 3'd4) ? 4'b1111 : 4'b0000;

// output data count
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
          tx_fifo_data <= 8'h00;    // "0"
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
  reg [3:0] msg_cnt;  // tx fifo data 8bit
  reg [1:0] msg_type;
  wire [31:0]msg_data;
  wire [3:0]msg_be;
  reg        temp;
  reg [31:0] temp_data;
  reg [31:0] temp_be;
  wire [11:0] seisuu;
  wire [3:0]  point1;
 Hex to ASCII

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
   
// Convert Hex data to Decimal 
assign seisuu = hex2bcd(rd_data[30:23]); // 8 bit
assign point1 = hex2point1(rd_data[22:19]); // 4 bit
   
// Temperature
always @ (posedge clk or negedge reset ) begin
    if (reset == 1'b1) begin
        temp <= 1'b0; 
        temp_be <= 4'b0000; 
        temp_data<= 32'h00000000; 
    end   
    else begin   
        if (main_cnt ==26'd3500000) begin
            temp <= 1'b1;
            temp_be <= 4'b1110;
            temp_data<= {seisuu,4'h0,point1,12'h0000}; 
        end
        else begin   
            temp <= 1'b0;
            temp_be <= temp_be; 
            temp_data<= temp_data; 
        end 
    end
end

// Message
always @ ( posedge clk or negedge reset ) begin
    if (reset == 1'b1)
        msg_type <= 2'b0;
    else begin
        if (wr_flg == 1'b1)
            msg_type <= 2'b00;
        else if (rd_data_en == 1'b1)
            msg_type <= 2'b01;
        else if (temp == 1'b1)
            msg_type <= 2'b10;
        else
            msg_type <= msg_type;
    end
end

assign msg_data = (msg_type == 2'b00) ? wr_data :
                  (msg_type == 2'b01) ? rd_data :
                  (msg_type == 2'b10) ? temp_data :32'h00000000;
   
assign msg_be = ( msg_type == 2'b00) ? wr_be :
                ( msg_type == 2'b01) ? rd_be :
                ( msg_type == 2'b10) ? temp_be :4'b0000;

// Message Count
always @ (posedge clk or negedge reset ) begin
    if (reset == 1'b1)
        msg_cnt <= 4'd0;
    else begin
        if ( (wr_flg == 1'b1) || (rd_data_en == 1'b1) || (temp == 1'b1) )
            msg_cnt <= 4'd1;
        else begin
            if (msg_cnt == 4'd0)
                msg_cnt <= 4'd0;
            else
                msg_cnt <= msg_cnt + 4'd1;
        end
    end
end

// fifo wr_flg data
always @ (posedge clk or negedge reset ) begin
    if (reset == 1'b1) begin
        tx_fifo_data <= 8'h00;
        tx_fifo_data_en <= 1'b0;
    end
    else begin
        case(msg_cnt)
            4'd0:begin
                tx_fifo_data <= 8'h00;
                tx_fifo_data_en <= 1'b0;
            end
            4'd1:begin
                if (msg_type==2'b00) begin
                    tx_fifo_data <= 8'h57; //"W"
                    tx_fifo_data_en <= 1'b1;
                end
                else if (msg_type==2'b01) begin
                    tx_fifo_data <= 8'h52; //"R"
                    tx_fifo_data_en <= 1'b1;
                end
                else if (msg_type==2'b10) begin
                    tx_fifo_data <= 8'h54; //"T"
                    tx_fifo_data_en <= 1'b1;
                end
                else begin
                    tx_fifo_data <= 8'h44; //"E"
                    tx_fifo_data_en <= 1'b1;
                end
            end
            4'd2:begin
                tx_fifo_data <= 8'h5f; //"_"
                tx_fifo_data_en <= 1'b1;
            end
            4'd3:begin
                if (msg_type[1]==1'b0) begin 
                    tx_fifo_data <= hex2ascii(adr[6:3]);
                    tx_fifo_data_en <= 1'b1;
                end
                else begin
                    tx_fifo_data <= 8'h5f; // "-"
                    tx_fifo_data_en <= 1'b1;
                end
             end
            4'd4:begin
                if (msg_type[1]==1'b0) begin
                    tx_fifo_data <= hex2ascii({adr[2:0],msg_type[0]});
                    tx_fifo_data_en <= 1'b1;
                end
                else begin
                    tx_fifo_data <= 8'h5f; // "-"
                    tx_fifo_data_en <= 1'b1;
                end
            end        
            4'd5:begin
                tx_fifo_data <= 8'h5f; // "-"
                tx_fifo_data_en <= 1'b1;
            end
            4'd6:begin
                tx_fifo_data <=  hex2ascii(msg_data[31:28]);
                tx_fifo_data_en <= msg_be[3];
            end
            4'd7:begin
                tx_fifo_data <=  hex2ascii(msg_data[27:24]);
                tx_fifo_data_en <= msg_be[3];
            end
            4'd8:begin
                tx_fifo_data <=  hex2ascii(msg_data[23:20]);
                tx_fifo_data_en <= msg_be[2];
            end
            4'd9:begin
                if (msg_type[1]==1'b0) begin
                    tx_fifo_data <=  hex2ascii(msg_data[19:16]);
                    tx_fifo_data_en <= msg_be[2];
                end
                else begin
                    tx_fifo_data <= 8'h2e; // "."
                    tx_fifo_data_en <= 1'b1;
                end
            end
            4'd10:begin
                tx_fifo_data <=  hex2ascii(msg_data[15:12]);
                tx_fifo_data_en <= msg_be[1];
            end
            4'd11:begin
                if (msg_type[1]==1'b0) begin
                    tx_fifo_data <=  hex2ascii(msg_data[11:8]);
                    tx_fifo_data_en <= msg_be[1];
                end
                else begin
                    tx_fifo_data <= 8'h20; // " "
                    tx_fifo_data_en <= 1'b1;
                end
             end
            4'd12:begin
                tx_fifo_data <=  hex2ascii(msg_data[7:4]);
                tx_fifo_data_en <= msg_be[0];
            end
            4'd13:begin
                tx_fifo_data <=  hex2ascii(msg_data[3:0]);
                tx_fifo_data_en <= msg_be[0];
            end
            4'd14:begin
                tx_fifo_data <= 8'h0a; // LF
                tx_fifo_data_en <= 1'b1;
            end
            default begin
                tx_fifo_data <= 8'h00;
                tx_fifo_data_en <= 1'b0;
            end
        endcase
    end
end
*/
   
endmodule