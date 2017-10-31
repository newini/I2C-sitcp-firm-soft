`timescale 1ns / 1ps
/******************************************************************************
// File Name            : top.v
//------------------------------------------------------------------------------
// Function             : top module for ADC readout application on Verilog-HDL
//                        use I2C and SiTCP                     
//                        
//------------------------------------------------------------------------------
// Designer             : Eunchong Kim 
//------------------------------------------------------------------------------
// Last Modified        : 10/25/2017 by Eunchong Kim
//******************************************************************************/
module top ( 
  // CLock
    input         clk_in1_p,
    input         clk_in1_n,
  // Swich
    input         reset,
  // LED
    output        led_ctrl,
    output        led_busy,
    output        led_reset,
    output        LED_GMII_OK,
    output        LED_TCP_open,
  // I2C IO
    inout         scl_io, //I2C SCL inout
    inout         sda_io, //I2C SDA inout
  // SiTCP
    output        GMII_RSTn,
    input         GMII_TX_CLK,
    output        GMII_GTXCLK,
    output        GMII_TX_EN,
    output        GMII_TX_ER,
    output [7:0]  GMII_TXD,
    input         GMII_RX_CLK,
    input         GMII_RX_DV,
    input         GMII_RX_ER,
    input  [7:0]  GMII_RXD,
    input         GMII_CRS,
    input         GMII_COL,
  // Management IF
    output        GMII_MDC,    // out  : Clock for MDIO
    inout         GMII_MDIO,    //
  //connect EEPROM
    inout         I2C_SDA,
    output        I2C_SCL,
    input         GPIO_SWITCH_0  // ForceDefault Switch
    );
  
  // wires & regs
    wire          CLK_40M;
    wire          CLK_200M;
    wire          wr_flg;
    wire          rd_flg;
    wire [6:0]    adr;
    wire [31:0]   wr_data; 
    wire [2:0]    wr_bytes; 
    wire          rd_data_en;
    wire [31:0]   rd_data;
    wire [2:0]    rd_bytes; 
    wire [3:0]    rd_channels;
    wire          scl_o;
    wire          scl_i;
    (* mark_debug *) wire          sda_i;
    wire          sda_o;
        
    (* mark_debug *) wire [7:0]  tx_fifo_data;    //tx fifo data 8bit
    (* mark_debug *) wire        tx_fifo_data_en; //tx fifo data enable 
    (* mark_debug *) wire [7:0]  tx_data;         //tx data 8bit
  
  // FIFO
    (* mark_debug *) wire FIFO_VALID;
    wire FIFO_EMPTY;
    (* mark_debug *) wire FIFO_WR_EN;
    (* mark_debug *) reg FIFO_RD_EN;
    
    reg [31:0]    FIFO_RD_DELAY_CNT;
  
  //SiTCP
    wire          PLL_CLKFB;
    wire          CLK125M;
    wire          LOCKD;
    reg    [10:0] CNT0;
    reg           SYS_RESET;
    reg    [ 5:0] CNT125M;
    reg    [ 3:0] ALTREQ;
  // GMII
    wire          GMII_MDIO_OUT;
    wire          GMII_MDIO_OE;
    reg           GMII_1000M;
    reg    [ 4:0] CNTRXC;
    wire          SiTCP_RST;        // out: reset for SiTCP and related circuits
    wire          TCP_CLOSE_REQ;      // out: Connection close request
    wire   [ 7:0] TCP_RX_DATA;
    wire   [ 7:0] TCP_TX_DATA;
    wire          TCP_RX_WR;
    wire          TCP_TX_FULL;
    wire          TCP_OPEN_ACK;
    wire  [14:0]  FIFO_DATA_COUNT;
    //wire          FIFO_RD_VALID;
    wire          TCP_TX_WR_EN;
    reg    [31:0] OFFSET_TEST;
  // RBCP
    wire   [31:0] RBCP_ADDR;
    wire   [ 7:0] RBCP_WD;
    wire          RBCP_WE;
    wire          RBCP_RE;
    reg           RBCP_ACK;
    reg    [ 7:0] RBCP_RD;
    
    wire          BUF_TX_CLK;
    
    wire          CS;
    wire          SK;
    wire          DI;
    wire          DO;
    wire          SiTCP_RESET;
    
    assign led_reset = reset; 
  
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

  // IO driver      
    assign sda_io = (sda_o == 1'b0) ? 1'b0 : 1'bz;
    assign sda_i = sda_io;
    assign scl_io = (scl_o == 1'b0) ? 1'b0 : 1'bz;
    assign scl_i = scl_io;
   
  // I2C Master IO 
    i2c_master_if i2c_master_if(
        .clk          (   CLK_40M),
        .reset        (  reset),
        .scl_o        (  scl_o),
        .scl_i        ( scl_i),
        .sda_o        (  sda_o),
        .sda_i        (  sda_i),
        .wr_flg       (    wr_flg),
        .rd_flg       (    rd_flg),
        .adr          (   adr),
        .wr_data      (wr_data),
        .wr_bytes     (wr_bytes),
        .rd_data      (rd_data),
        .rd_bytes     (rd_bytes),
        .rd_channels  (rd_channels),
        .rd_data_en   (rd_data_en),
        .busy         (led_busy) 
      );

  // MAX1238 Controller                   
    i2c_max1238_ctrl i2c_ctrl( 
        .clk              (   CLK_40M),
        .reset            (  reset),
        .led_ctrl         ( led_ctrl),
        .wr_flg           (    wr_flg),
        .rd_flg           (    rd_flg),
        .adr              (   adr),
        .wr_data          (wr_data),
        .wr_bytes         (wr_bytes),
        .rd_data          (rd_data),
        .rd_channels      (rd_channels),
        .rd_data_en       (rd_data_en),
        .rd_bytes         (rd_bytes),
        .tx_fifo_data_en  (tx_fifo_data_en),   
        .tx_fifo_data     (tx_fifo_data)
    );
    
    assign FIFO_WR_EN = tx_fifo_data_en;

    fifo_generator_v13_2 fifo_8bit_data (
        .rst          (~TCP_OPEN_ACK),         // input wire srst
        .wr_clk       (CLK_40M),            // input wire wr_clk
        .rd_clk       (CLK_200M),            // input wire rd_clk
        .din          (tx_fifo_data),      // input wire [7 : 0] din
        .wr_en        (FIFO_WR_EN),  // input wire wr_en
        .rd_en        (FIFO_RD_EN),  // input wire rd_en
        .dout         (tx_data),     // output wire [7 : 0] dout
        .full         (),            // output wire full
        .empty        (FIFO_EMPTY),           // output wire empty
        .valid        (FIFO_VALID),  // output wire valid
        .wr_rst_busy  (),  // output wire wr_rst_busy
        .rd_rst_busy  ()  // output wire rd_rst_busy
    );
    
    
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
    ////
    //SiTCP
    ////
    assign      LED_GMII_OK  = GMII_1000M;
    assign      LED_TCP_open  = TCP_OPEN_ACK;
    assign      TCP_TX_DATA = tx_data;
    assign      TCP_TX_WR_EN = FIFO_VALID;
 
    PLLE2_BASE #(
      .CLKFBOUT_MULT      (5),
      .CLKIN1_PERIOD      (5.000),
      .CLKOUT0_DIVIDE     (8),
      .CLKOUT0_DUTY_CYCLE (0.500),
      .DIVCLK_DIVIDE      (1)
    ) 
    PLLE2_BASE(
      .CLKFBOUT       (PLL_CLKFB),
      .CLKOUT0        (CLK125M),
      .CLKOUT1        (),
      .CLKOUT2        (),
      .CLKOUT3        (),
      .CLKOUT4        (),
      .CLKOUT5        (),
      .LOCKED         (LOCKD),
      .CLKFBIN        (PLL_CLKFB),
      .CLKIN1         (CLK_200M),
      .PWRDWN         (1'b0),
      .RST            (reset)
    );
    
    always@(posedge CLK_200M or negedge LOCKD)begin
      if (~LOCKD) begin
        CNT0[10:0]    <=  {1'b1,10'b0};
        SYS_RESET    <=  1'b0;
      end else begin
        CNT0[10:0]    <=  CNT0[10]?  (CNT0[10:0]+11'd1):    11'd0;
        SYS_RESET    <=  CNT0[10];
      end
    end
    
    always@(posedge CLK125M)begin
      CNT125M[5]    <= CNT125M[4];
      CNT125M[4:0]  <= CNT125M[4]?  5'd0:  (CNT125M[4:0] + 5'd1);
      if (CNT125M[4]) begin
        ALTREQ[3:0]  <= ((GMII_1000M ^ CNTRXC[4]) & ~ALTREQ[3])?    (ALTREQ[3:0] + 4'd1):  4'd0;
        GMII_1000M  <= ALTREQ[3]?  CNTRXC[4]:    GMII_1000M;
      end
    end
    
    always@(posedge GMII_RX_CLK or posedge CNT125M[5])begin
      if (CNT125M[5]) begin
        CNTRXC[4:0]  <= 5'd4;
      end else begin
        CNTRXC[4:0]  <= CNTRXC[4]?  CNTRXC[4:0]:  (CNTRXC[4:0] + 5'd1);
      end
    end
    
    BUFGMUX GMIIMUX(.O(BUF_TX_CLK), .I0(GMII_TX_CLK), .I1(CLK125M), .S(GMII_1000M));
    
    ODDR  IOB_GTX    (.C(BUF_TX_CLK), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0), .Q(GMII_GTXCLK));
    
    //------------------------------------------------------------------------------
    //     PCA9548A(8ch_I2C_switch) This device switch to EEPROM.
    //
    //     System sequence
    //     Phase1:            Phase2:
    //     Switcher    ->    EEPROM  & SiTCP
    //
    //------------------------------------------------------------------------------   
    wire      SDI;
    wire      SDO;
    wire      SDT;
    wire      SCLK;
    wire      MUX_SDO;
    wire      MUX_SDT;
    wire      MUX_SCLK;
    wire      ROM_SDO;
    wire      ROM_SDT;
    wire      ROM_SCLK;
    wire      RST_I2Cselector;
   
  // bug exist here
    IOBUF  sda_buf( .O(SDI), .I(SDO), .T(SDT), .IO(I2C_SDA) );
    OBUF  obufiic( .O(I2C_SCL), .I(SCLK));
  
  // switch from PCA9548A to EEPROM
    assign SCLK    =    (RST_I2Cselector == 1) ? ROM_SCLK : MUX_SCLK;
    assign SDO    =    (RST_I2Cselector == 1) ? ROM_SDO : MUX_SDO;
    assign SDT    =    (RST_I2Cselector == 1) ? ROM_SDT : MUX_SDT;
  
  // PCA9548A channel select
    PCA9548A #(
      .SYSCLK_FREQ_IN_MHz    (200),
      .ADDR           (7'd116),
      .CHANNEL        (8'b0000_1000)
    ) PCA9548A (
      .SYSCLK_IN      (CLK_200M),       //in : system clock
      .I2C_SCLK       (MUX_SCLK),        //out
      .SDO_I2CS       (MUX_SDO),        //out
      .SDI_I2CS       (SDI),          //in
      .SDT_I2CS       (MUX_SDT),        //out
      .RESET_IN       (SYS_RESET),      //in
      .RESET_OUT      (RST_I2Cselector)    //out
    );
 
    AT93C46_M24C08 #(
      .SYSCLK_FREQ_IN_MHz(200)
    ) AT93C46_M24C08 (
      .AT93C46_CS_IN    (CS),
      .AT93C46_SK_IN    (SK),
      .AT93C46_DI_IN    (DI),
      .AT93C46_DO_OUT   (DO),
      .M24C08_SCL_OUT   (ROM_SCLK),
      .M24C08_SDA_OUT   (ROM_SDO),
      .M24C08_SDA_IN    (SDI),
      .M24C08_SDAT_OUT  (ROM_SDT),
      .RESET_IN         (~RST_I2Cselector),
      .SiTCP_RESET_OUT  (SiTCP_RESET),
      .SYSCLK_IN        (CLK_200M)
    );
    
    assign GMII_MDIO    = GMII_MDIO_OE  ? GMII_MDIO_OUT : 1'bz;
    
    WRAP_SiTCP_GMII_XC7K_32K  #(
      .TIM_PERIOD       (200)                  // 200MHz
    ) SiTCP(
      .CLK              (CLK_200M),                // in  : System Clock >129MHz
      .RST              (SiTCP_RESET),              // in  : System reset
    // Configuration parameters
      .FORCE_DEFAULTn   (GPIO_SWITCH_0),            // in  : Load default parameters
      .EXT_IP_ADDR      (32'd0),                // in  : IP address[31:0]
      .EXT_TCP_PORT     (16'd0),                // in  : TCP port #[15:0]
      .EXT_RBCP_PORT    (16'd0),                // in  : RBCP port #[15:0]
      .PHY_ADDR         (5'b0_0111),              // in  : PHY-device MIF address[4:0]
    // EEPROM
      .EEPROM_CS        (CS),                  // out  : Chip select
      .EEPROM_SK        (SK),                  // out  : Serial data clock
      .EEPROM_DI        (DI),                  // out  : Serial write data
      .EEPROM_DO        (DO),                  // in  : Serial read data
    // user data, intialial values are stored in the EEPROM, 0xFFFF_FC3C-3F
      .USR_REG_X3C      (),                    // out  : Stored at 0xFFFF_FF3C
      .USR_REG_X3D      (),                    // out  : Stored at 0xFFFF_FF3D
      .USR_REG_X3E      (),                    // out  : Stored at 0xFFFF_FF3E
      .USR_REG_X3F      (),                    // out  : Stored at 0xFFFF_FF3F
    // MII interface
      .GMII_RSTn        (GMII_RSTn),              // out  : PHY reset Active low
      .GMII_1000M       (GMII_1000M),              // in  : GMII mode (0:MII, 1:GMII)
    // TX
      .GMII_TX_CLK      (BUF_TX_CLK),              // in  : Tx clock
      .GMII_TX_EN       (GMII_TX_EN),              // out  : Tx enable
      .GMII_TXD         (GMII_TXD[7:0]),            // out  : Tx data[7:0]
      .GMII_TX_ER       (GMII_TX_ER),              // out  : TX error
    // RX
      .GMII_RX_CLK      (GMII_RX_CLK),              // in  : Rx clock
      .GMII_RX_DV       (GMII_RX_DV),              // in  : Rx data valid
      .GMII_RXD         (GMII_RXD[7:0]),            // in  : Rx data[7:0]
      .GMII_RX_ER       (GMII_RX_ER),              // in  : Rx error
      .GMII_CRS         (GMII_CRS),                // in  : Carrier sense
      .GMII_COL         (GMII_COL),                // in  : Collision detected
    // Management IF
      .GMII_MDC         (GMII_MDC),                // out  : Clock for MDIO
      .GMII_MDIO_IN     (GMII_MDIO),              // in  : Data
      .GMII_MDIO_OUT    (GMII_MDIO_OUT),            // out  : Data
      .GMII_MDIO_OE     (GMII_MDIO_OE),              // out  : MDIO output enable
    // User I/F
      .SiTCP_RST        (SiTCP_RST),              // out  : reset for SiTCP and related circuits
    // TCP connection control
      .TCP_OPEN_REQ     (1'b0),                  // in  : Reserved input, shoud be 0
      .TCP_OPEN_ACK     (TCP_OPEN_ACK),              // out  : Acknowledge for open (=Socket busy)
      .TCP_ERROR        (),                    // out  : TCP error, its active period is equal to MSL
      .TCP_CLOSE_REQ    (TCP_CLOSE_REQ),            // out  : Connection close request
      .TCP_CLOSE_ACK    (TCP_CLOSE_REQ),            // in  : Acknowledge for closing
    // FIFO I/F
      .TCP_RX_WC        (16'd0),// disable TCP receive //({1'b1,FIFO_DATA_COUNT[14:0]}),      // in  : Rx FIFO write count[15:0] (Unused bits should be set 1)
      .TCP_RX_WR        (TCP_RX_WR),              // out  : Write enable
      .TCP_RX_DATA      (TCP_RX_DATA[7:0]),            // out  : Write data[7:0]
      .TCP_TX_FULL      (TCP_TX_FULL),              // out  : Almost full flag
      .TCP_TX_WR        (TCP_TX_WR_EN),            // in    : Write enable
      .TCP_TX_DATA      (TCP_TX_DATA[7:0]),            // in  : Write data[7:0]
    // RBCP
      .RBCP_ACT         (),                    // out  : RBCP active
      .RBCP_ADDR        (RBCP_ADDR[31:0]),            // out  : Address[31:0]
      .RBCP_WD          (RBCP_WD[7:0]),              // out  : Data[7:0]
      .RBCP_WE          (RBCP_WE),                // out  : Write enable
      .RBCP_RE          (RBCP_RE),                // out  : Read enable
      .RBCP_ACK         (RBCP_ACK),                // in  : Access acknowledge
      .RBCP_RD          (RBCP_RD[7:0])              // in  : Read data[7:0]
    );  
  
  /*
    fifo_generator_v9_3 RX_FIFO(
      .clk          (CLK_200M),          //in  :
      .rst          (~TCP_OPEN_ACK),      //in  :
      .din          (TCP_RX_DATA[7:0]),      //in  :
      .wr_en        (TCP_RX_WR),        //in  :
      .full         (),              //out  :
      .dout         (TCP_TX_DATA[7:0]),      //out  :
      .valid        (FIFO_RD_VALID),      //out  :active hi
      .rd_en        (~TCP_TX_FULL),        //in  :
      .empty        (),              //out  :
      .data_count   (FIFO_DATA_COUNT[14:0])    //out  :
    );
  */
  
    always@(posedge CLK_200M )begin
      if (RBCP_WE) begin
        OFFSET_TEST[31:0]  <= {RBCP_ADDR[31:2],2'b00}+{RBCP_WD[7:0],RBCP_WD[7:0],RBCP_WD[7:0],RBCP_WD[7:0]};
      end
      RBCP_RD[7:0]  <= (
        ((RBCP_ADDR[1:0]==8'h0) ? OFFSET_TEST[ 7: 0]:  8'h0)|
        ((RBCP_ADDR[1:0]==8'h1) ? OFFSET_TEST[15: 8]:   8'h0)|
        ((RBCP_ADDR[1:0]==8'h2) ? OFFSET_TEST[23:16]:  8'h0)|
        ((RBCP_ADDR[1:0]==8'h3) ? OFFSET_TEST[31:24]:   8'h0)
      );
      RBCP_ACK  <= RBCP_RE|RBCP_WE;
    end
   
endmodule
