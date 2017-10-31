`timescale 1ns / 1ps
//******************************************************************************
// File Name            : i2c_master_interface.v
//------------------------------------------------------------------------------
// Function             : i2c interface for master on Verilog-HDL
//                        Source based on Himawari (http://www.hmwr-lsi.co.jp/fpga/fpga_6.htm)
//                        
//------------------------------------------------------------------------------
// Designer             : Eunchong Kim
//------------------------------------------------------------------------------
// Last Modified        : 10/25/2017
//******************************************************************************
module i2c_master_if ( 
    input               clk,
    input               reset,  
    output reg          scl_o,
    input               scl_i,
    output reg          sda_o,
    input               sda_i,
    input [6:0]         adr,
    input               wr_flg,
    input               rd_flg,
    input [31:0]        wr_data,
    input [2:0]         wr_bytes,
    output reg [31:0]   rd_data,
    input [2:0]         rd_bytes,
    input [3:0]         rd_channels,
    output reg          rd_data_en,
    output              busy
);

  wire [3:0] wr_be;
  wire [3:0] rd_be;
  wire [7:0] wr_bits;
  wire [7:0] rd_bits;
  reg        wr_d1;
  reg        rd_d1;
  wire      wr_start;
  wire      rd_start;  
  wire       start_sig;
  wire       end_sig;
  
  reg      scl_pull_down;
 
  reg [6:0] adr_reg;
  reg        rd_reg;
  reg [35:0] tx_data;
  reg       count_en;
  reg [11:0] time_cnt;
  reg [7:0] bit_cnt;
  reg       sda_i_d1;
  reg [35:0]      sda_i_reg;
  reg [7:0] end_bit;
  reg [3:0] rd_channels_cnt;
  reg rd_bytes_en;

  parameter p_1bit_cnt = 12'd400; // 40 MHz -> 40M/400 = 100 kHz
  parameter p_sda_chg = 12'd10;
   


// wr_flg,rd_flg 1clk delay   
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1) begin 
       wr_d1 <= 1'b0;
       rd_d1 <= 1'b0;
    end
    else begin
       wr_d1 <= wr_flg;
       rd_d1 <= rd_flg;
    end
    
// wr, rd, byte to bit
   assign wr_bits = (wr_bytes == 3'd1) ? 8'd9:    
                    (wr_bytes == 3'd2) ? 8'd18: 
                    (wr_bytes == 3'd3) ? 8'd27:
                    (wr_bytes == 3'd4) ? 8'd36: 4'd0;
   assign rd_bits = (rd_bytes == 3'd1) ? 8'd9:    
                    (rd_bytes == 3'd2) ? 8'd18: 
                    (rd_bytes == 3'd3) ? 8'd27:
                    (rd_bytes == 3'd4) ? 8'd36: 4'd0;
                                  
// wr_flg,rd_flg byte enable
  assign wr_be = (wr_bytes == 3'd1) ? 4'b1000:    
                 (wr_bytes == 3'd2) ? 4'b1100: 
                 (wr_bytes == 3'd3) ? 4'b1110:
                 (wr_bytes == 3'd4) ? 4'b1111: 4'b0000;
     
  assign rd_be = (rd_bytes == 3'd1) ? 4'b1000:    
                 (rd_bytes == 3'd2) ? 4'b1100: 
                 (rd_bytes == 3'd3) ? 4'b1110:
                 (rd_bytes == 3'd4) ? 4'b1111: 4'b0000;

// Strat signal        
  assign wr_start = ( (wr_flg==1'b1) && (wr_d1==1'b0) ) ? 1'b1 : 1'b0;
  assign rd_start = ( (rd_flg==1'b1) && (rd_d1==1'b0) ) ? 1'b1 : 1'b0;
  
  assign start_sig = ( (wr_start==1'b1) || (rd_start==1'b1) ) ? 1'b1 : 1'b0;
  assign end_sig =   ( (time_cnt==p_1bit_cnt) && (bit_cnt==(end_bit+8'd1)) ) ? 1'b1 : 1'b0;

// Hold adr data
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1 )
      adr_reg <= 7'h00;
    else
      if (start_sig == 1'b1)
        adr_reg <= adr;
      else if ( (time_cnt==p_sda_chg) && (bit_cnt>=8'd1) && (bit_cnt<=8'd7) )
        adr_reg <= {adr_reg[5:0],1'b0};
      else
        adr_reg <= adr_reg;

// Hold Read flg
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1 )
      rd_reg <= 1'b0;
    else
      if (start_sig == 1'b1)
        if (rd_flg == 1'b1)
          rd_reg <= 1'b1;
        else
          rd_reg <= 1'b0;
      else
        rd_reg <= rd_reg;

// SDA of Master
  always @ (posedge clk or negedge reset ) begin
      if (reset == 1'b1 )
          tx_data <= 36'hffffffff;
      else if (rd_flg == 1'b1)
          tx_data <= 36'hff7fbfdfe; // {1111 1111 0} x 4
      else if (wr_flg == 1'b1)
          tx_data <= {wr_data[31:24],1'b1,wr_data[23:16],1'b1,wr_data[15:8],1'b1,wr_data[7:0],1'b1};
      else if ( (time_cnt == p_sda_chg) && (bit_cnt>=8'd10) && (bit_cnt<=end_bit) && (scl_pull_down == 1'b0) )
          tx_data <= {tx_data[34:0],tx_data[35]};    // bit move
      else
          tx_data <= tx_data;
  end
 
// End bit
  always @ (posedge clk or negedge reset ) begin
      if (reset == 1'b1 ) 
          end_bit <= 8'd255;
      else if (rd_flg == 1'b1) 
          end_bit <= 8'd9 + rd_bits*{4'd0,rd_channels}; // (for address, write or read, and ACK) + rd byte x channels
      else if (wr_flg == 1'b1) 
          end_bit <= 8'd9 + wr_bits*8'd1;
      else
          end_bit <= end_bit;
  end

// count_en
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1) 
      count_en <= 1'b0;
    else
      if (start_sig == 1'b1)
        count_en <= 1'b1;
      else if (end_sig == 1'b1)
        count_en <= 1'b0;
      else
        count_en <= count_en;
   
// Time Count (40M to 100k)
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1) 
      time_cnt <= 12'h00;
    else
      if ( count_en==1'b1)
        if (time_cnt == p_1bit_cnt)
          time_cnt <= 12'h000;
        else
          time_cnt <= time_cnt + 12'h001;
      else
        time_cnt <= 12'h000;
   
// Bit Count (1 bit for 100k)
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1) 
      bit_cnt <= 8'h00;
    else
      if ( count_en == 1'b1 )
        if ( (time_cnt == p_1bit_cnt) && (scl_pull_down == 1'b0) )
          bit_cnt <= bit_cnt + 8'h01;
        else 
          bit_cnt <= bit_cnt ;
      else
        bit_cnt <= 8'h00;
  
// Read channels counter
  always @ (posedge clk or negedge reset ) begin
      if (reset == 1'b1) begin
          rd_channels_cnt <=4'd0;
          rd_bytes_en <= 1'b0;
      end
      else if (rd_reg == 1'b1) begin
          if (bit_cnt == (8'd27 + (rd_bits*{4'd0,rd_channels_cnt}))) begin
              rd_channels_cnt <= rd_channels_cnt + 4'd1;
              rd_bytes_en <= 1'b1;
          end
          else if (rd_channels_cnt == rd_channels) begin
              rd_channels_cnt <=4'd0;
              rd_bytes_en <= 1'b0;
          end
          else begin
              rd_channels_cnt <= rd_channels_cnt;
              rd_bytes_en <= 1'b0;     
          end        
      end
      else begin
          rd_channels_cnt <= rd_channels_cnt;
          rd_bytes_en <= rd_bytes_en;
      end
  end

// SCL
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1) begin
      scl_o <= 1'b1;
      scl_pull_down <= 1'b0;
    end
    else
      if (count_en == 1'b1)
        if (time_cnt == 12'h00)
          if (bit_cnt == 8'd0)
            scl_o <= 1'b1;
          else if (scl_i == 1'b0) begin
            scl_o <= 1'b1;
            scl_pull_down <= 1'b1;
          end
          else begin
            scl_o <= 1'b0;
            scl_pull_down <= 1'b0;  
          end
        else if (time_cnt == {1'b0,p_1bit_cnt[11:1]})
          scl_o <= 1'b1;
        else
          scl_o <= scl_o;
      else      
        scl_o <= 1'b1; 

//SDA output
/*
always @ (posedge clk or negedge reset )
  if (reset == 1'b1)  
    sda_o <= 1'b1;
  else
    if (count_en==1'b1)
      if (time_cnt == 8'h00)
        if (bit_cnt==8'd0)        
          sda_o <= 1'b0;        //start
        else if ((bit_cnt>=8'd1)&&(bit_cnt<=8'd7))
          sda_o <= adr_reg[6];
        else if (bit_cnt==8'd8)
          sda_o <= rd_reg ;     //rw
        else if (bit_cnt==8'd9)
          sda_o <= 1'b1;        //ack
        else if ((bit_cnt>=8'd10)&&(bit_cnt<=end_bit))
          sda_o <= tx_data[35];  //data
        else if (bit_cnt==(end_bit+8'd1))
          sda_o <= 1'b0;         //stop
        else if (bit_cnt==(end_bit+8'd2))
          sda_o <= 1'b1;         //stop
        else
          sda_o <= sda_o;       
      else
        sda_o <= sda_o;       
    else
      sda_o <= 1'b1;
*/

  always @ (posedge clk or negedge reset )
    if (reset == 1'b1)  
      sda_o <= 1'b1;
    else
      if ( start_sig == 1'b1)
         sda_o <= 1'b0;         // Start
      else if (count_en == 1'b1)
        if (time_cnt == p_sda_chg)
          if ( (bit_cnt>=8'd1) && (bit_cnt<=8'd7) ) // 7 bit
            sda_o <= adr_reg[6];
          else if (bit_cnt==8'd8)
            sda_o <= rd_reg ;     // Read or Write (1 for read, 0 for write)
          else if (bit_cnt==8'd9)
            sda_o <= 1'b1;        // ACK for slave
          else if ( (bit_cnt>=8'd10) && (bit_cnt<=end_bit) ) // (8 bit data + 1 bit ACK) x 2 = 18 bit when read 2byte
            sda_o <= tx_data[35];  // SDA data Master
          else if (bit_cnt == (end_bit+8'd1))
            sda_o <= 1'b0;         //stop
            //sda_o <= 1'b1;         //stop
          else if (bit_cnt==(end_bit+8'd2))
            sda_o <= 1'b1;         //stop
          else
            sda_o <= sda_o;       
        else
          sda_o <= sda_o;       
      else
        sda_o <= 1'b1;
   
// SDA input
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1)
      sda_i_d1 <= 1'b1;
    else
      sda_i_d1 <= sda_i;

// Pull SDA data to sda_i_reg @ 100k
  always @ (posedge clk or negedge reset )
    if (reset == 1'b1)
      sda_i_reg <= 36'h00000000;
    else
      if ( (count_en==1'b1) && (time_cnt == {1'b0,p_1bit_cnt[11:1]}) )
        sda_i_reg <= {sda_i_reg[34:0],sda_i_d1};    // Pull sda_i_d1 data to sda_i_reg from LSB
      else
        sda_i_reg <= sda_i_reg;

  always @ (posedge clk or negedge reset ) begin
      if (reset == 1'b1) begin
          rd_data <= 32'h00000000;
          rd_data_en <= 1'b0; 
      end
//      else if ( (rd_reg == 1'b1) && (time_cnt=={1'b0,p_1bit_cnt[11:1]}) && (rd_bytes_en == 1'b1) ) begin
        else if ( (rd_bytes_en == 1'b1) ) begin
          rd_data <= {sda_i_reg[16:9],sda_i_reg[7:0],16'h0000};
          rd_data_en <= 1'b1;
//          if (rd_be == 4'b1000)
//              rd_data <= {sda_i_reg[7:0],24'h000000};
//          else if (rd_be == 4'b1100)      // When  Read 2 byte
//              rd_data <= {sda_i_reg[16:9],sda_i_reg[7:0],16'h0000}; // 2 bytes exclude ACK, from [16:0]
//          else if (rd_be == 4'b1110)
//              rd_data <= {sda_i_reg[25:18],sda_i_reg[16:9],sda_i_reg[7:0],8'h00};
//          else 
//              rd_data <= {sda_i_reg[34:27],sda_i_reg[25:18],sda_i_reg[16:9],sda_i_reg[7:0]};
//          rd_data_en <= 1'b1;
      end
      else begin
          rd_data <= rd_data;
          rd_data_en <= 1'b0;
      end
  end
  
// busy
  assign busy = count_en;
         
endmodule