`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2017 08:23:49 PM
// Design Name: 
// Module Name: I2C_TB
// Project Name: 
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


module top_TB;
  // Inputs
    reg           clk_in1_p;
    reg           clk_in1_n;
    reg           reset;
  // Output
    wire          led_reset;
    wire          led_0;
    wire          led_busy;
    wire          scl;
    wire          sda;
    
   
    wire          CLK_40M;
    wire          CLK_200M;
    wire          wr;
    wire          rd;
    wire [6:0]    adr;
    wire [31:0]   wr_data; 
    wire [2:0]    wr_bytes;  
    wire          rd_data_en;
    wire [31:0]   rd_data;
    wire [2:0]    rd_bytes;  
    wire [3:0]    rd_channels;
    wire          scl_drv;
    wire          sda_i;
    wire          sda_o;
    reg [31:0]   FIFO_RD_DELAY_CNT;
    
    wire [7:0]    tx_fifo_data;    //tx fifo data 8bit
    wire          tx_fifo_data_en; //tx fifo data enable 
    wire [7:0]    tx_data;
    
  // FIFO
    wire FIFO_VALID;
    wire FIFO_EMPTY;
    wire FIFO_WR_EN;
    reg FIFO_RD_EN;
    
  // SiTCP
    reg TCP_OPEN_ACK;
    reg TCP_TX_FULL; 
   
  // from here
    clk_wiz_v5_4 clk_gen   (
       // Clock out ports
           .clk_out1(CLK_40M),     // output clk_out1
           .clk_out2(CLK_200M),     // output clk_out2
       // Status and control signals
           .reset(reset),          // input reset
           .locked(),        // output locked
       // Clock in ports
           .clk_in1_p(clk_in1_p),  // input clk_in1_p
           .clk_in1_n(clk_in1_n)
    );
       
    assign sda = (sda_o == 1'b0) ? 1'b0 : 1'bz;
    assign sda_i = sda;
    assign scl = (scl_drv == 1'b0) ? 1'b0 : 1'bz;
   
  // I2C master 
    i2c_master_if i2c_master_if(
        .clk        (   CLK_40M),
        .reset      (  reset),
        .scl_o      (  scl_drv),
        .sda_o      (  sda_o),
        .sda_i      (  sda_i),
        .wr_flg     (    wr),
        .rd_flg     (    rd),
        .adr        (   adr),
        .wr_data    (wr_data),
        .wr_bytes   (wr_bytes),
        .rd_data    (rd_data),
        .rd_channels(rd_channels),
        .rd_data_en (rd_data_en),
        .rd_bytes   (rd_bytes),
        .busy       (led_busy) 
      );
   
  // MAX1238                   
    i2c_max1238_ctrl i2c_ctrl( 
        .clk            (   CLK_40M),
        .reset          (  reset),
        .led_ctrl       ( led_0),
        .wr_flg         (    wr),
        .rd_flg         (    rd),
        .adr            (   adr),
        .wr_data        (wr_data),
        .wr_bytes       (wr_bytes),
        .rd_data        (rd_data),
        .rd_data_en     (rd_data_en),
        .rd_bytes       (rd_bytes),
        .rd_channels    (rd_channels),
        .tx_fifo_data_en  (tx_fifo_data_en),   
        .tx_fifo_data   (tx_fifo_data)
    );  
    
    assign FIFO_WR_EN = tx_fifo_data_en;
    //assign FIFO_RD_EN = ~TCP_TX_FULL;

    fifo_generator_v13_2 fifo_8bit_data (
        .rst      (reset),         // input wire srst
        .wr_clk   (CLK_40M),            // input wire wr_clk
        .rd_clk   (CLK_200M),            // input wire rd_clk
        .din      (tx_fifo_data),      // input wire [7 : 0] din
        .wr_en    (FIFO_WR_EN),  // input wire wr_en
        .rd_en    (FIFO_RD_EN),  // input wire rd_en
        .dout     (tx_data),     // output wire [7 : 0] dout
        .full     (),            // output wire full
        .empty    (FIFO_EMPTY),           // output wire empty
        .valid    (FIFO_VALID),  // output wire valid
        .wr_rst_busy(),  // output wire wr_rst_busy
        .rd_rst_busy()  // output wire rd_rst_busy
    );
    
    reg [31:0] FIFO_DELAY;
    
  // FIFO_RD_EN Delay
      always @ (posedge CLK_200M or negedge reset ) begin
          if ( reset == 1 ) begin
              FIFO_RD_DELAY_CNT <= 32'd0;
              FIFO_RD_EN    <= 1'b0;
          end
          else if (FIFO_RD_DELAY_CNT == 32'd0) begin
              FIFO_RD_EN    <= 1'b0;
              if ( FIFO_WR_EN  == 1'b1)
                  FIFO_RD_DELAY_CNT <= 32'd1000000; // delay 5 ms
          end
          else if (FIFO_RD_DELAY_CNT > 32'd4*{24'd0,rd_channels}) // 4 bytes x rd channels
              FIFO_RD_DELAY_CNT <= FIFO_RD_DELAY_CNT - 32'd1;
          else if ( (32'd0 < FIFO_RD_DELAY_CNT) && (FIFO_RD_DELAY_CNT <= 32'd4*{24'd0,rd_channels}) ) begin
              FIFO_RD_DELAY_CNT <= FIFO_RD_DELAY_CNT - 32'd1;
              FIFO_RD_EN    <= 1'b1;
          end
      end
    
    // to here
   
    initial begin
        // Initialize Inputs
        reset = 0;
 
        #200;
        reset = 1;
        #100;
        reset = 0;
        
        #1000000; // 1 ms
        TCP_OPEN_ACK = 1;
        TCP_TX_FULL = 0;
    end
    
    always begin
        // 0 ns
        clk_in1_p = 0;
        clk_in1_n = 1;
        #2.5
        clk_in1_p = 1;
        clk_in1_n = 0;
        #2.5;
        // 5 ns = 0 ns
    end 

endmodule
