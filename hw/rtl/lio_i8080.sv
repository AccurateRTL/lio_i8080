// Copyright AccurateRTL contributors.
// Licensed under the MIT License, see LICENSE for details.
// SPDX-License-Identifier: MIT

module lio_i8080 #(
  parameter A_WIDTH = 32,
  parameter CFG_A_WIDTH = 32,
  // Width of data bus in bits
  parameter DATA_WIDTH = 32,
  // Width of address bus in bits
  parameter ADDR_WIDTH = 32,
  // Width of wstrb (width of data bus in words)
  parameter STRB_WIDTH = (DATA_WIDTH/8),
  parameter IF_DATA_SIZE = 16
  // Timeout delay (cycles)  
)
( 
   input                       aclk,
   input                       arstn,
  
   input        [A_WIDTH-1:0]  awaddr,
   input        [2:0]          awprot,
   input                       awvalid,
   output logic                awready,
   input        [32-1:0]       wdata,
   input        [32/8-1:0]     wstrb,
   input                       wvalid,
   output logic                wready,
   output logic [1:0]          bresp,
   output logic                bvalid,
   input                       bready,
  
   input [A_WIDTH-1:0]         araddr,
   input        [2:0]          arprot,
   input                       arvalid,
   output logic                arready,
   output logic [32-1:0]       rdata,
   output logic                rvalid,
   input                       rready,
   output logic [1:0]          rresp,
   
   output logic                data_fifo_ready,

   output logic                    RSTn,
   output logic                    DC,
   output logic                    CSn,
   output logic                    WR, 
   output logic                    RD,
   output logic                    OE,
   output logic [IF_DATA_SIZE-1:0] DO,
   input  [IF_DATA_SIZE-1:0]       DI,
   
   input               TE,
   
   output logic        int_strb
);


logic [CFG_A_WIDTH-1:0]  reg_wr_addr;
logic [DATA_WIDTH-1:0]   reg_wr_data;
logic [STRB_WIDTH-1:0]   reg_wr_strb;
logic                    reg_wr_en;
//logic                    reg_wr_wait;
logic                    reg_wr_ack;
logic [CFG_A_WIDTH-1:0]  reg_rd_addr;
logic                    reg_rd_en;
logic [DATA_WIDTH-1:0]   reg_rd_data;
//logic                    reg_rd_wait;
logic                    reg_rd_ack;
logic        cmd_fifo_full;
logic        data_fifo_full;

typedef enum {
    IDLE,
    WR_0,
    WR_1,
    RD_0,
    RD_1,
    WAITING_DATA,
    SYNC,
    WAITING_TE,
    WAITING_TE_DELAY
} sm_states;

sm_states stt;

logic [7:0] cfg_wr_0_len;               // Длина интервала в тактах (задавать на 1 меньше), на котором сигнал WR равен 0
logic [7:0] cfg_wr_1_len;               // Длина интервала в тактах (задавать на 1 меньше), на котором сигнал WR равен 1
logic [7:0] cfg_rd_0_len;               // Длина интервала в тактах (задавать на 1 меньше), на котором сигнал RD равен 0
logic [7:0] cfg_rd_1_len;               // Длина интервала в тактах (задавать на 1 меньше), на котором сигнал RD равен 1
logic [1:0] cfg_if_sz_in_bytes;         // Ширина интерфейса в байтах
logic cfg_te_mode;                      // Режим синхронизации выдачи данных с получением сигнала TE
logic [15:0] cfg_te_delay;              // Задержка выполнения задания относительно TE
logic if_read_ack;
logic if_write_ack;
logic [IF_DATA_SIZE-1:0]     DI_d;
logic cmd_en;
logic TE_d1, TE_d2;  
logic [15:0] te_delay_cnt;

parameter logic [7:0] I8080_VERSION_REG_OFS         = 8'h00;
parameter logic [7:0] I8080_GONFIG_REG_0_OFS        = 8'h04;
parameter logic [7:0] I8080_GONFIG_REG_1_OFS        = 8'h08;
parameter logic [7:0] I8080_WINDOW_REG_OFS          = 8'h0C;
parameter logic [7:0] I8080_CMD_FIFO_OFS            = 8'h10;
parameter logic [7:0] I8080_DATA_FIFO_OFS           = 8'h14;
parameter logic [7:0] I8080_CSN_REG_OFS             = 8'h18;

// 
lio_axil_regs_if  #(.AWIDTH(8)) lio_axil_regs_if_i(
  .aclk(aclk),                                          // in
  .arstn(arstn),                                        // in
  .awaddr(awaddr),                                      // in
  .awprot(awprot),                                      // in
  .awvalid(awvalid),                                    // in
  .awready(awready),                                    // out
  .wdata(wdata),                                        // in
  .wstrb(wstrb),                                        // in
  .wvalid(wvalid),                                      // in
  .wready(wready),                                      // out
  .bresp(bresp),                                        // out
  .bvalid(bvalid),                                      // out
  .bready(bready),                                      // in
  .araddr(araddr),                                      // in
  .arprot(arprot),                                      // in
  .arvalid(arvalid),                                    // in
  .arready(arready),                                    // out
  .rdata(rdata),                                        // out
  .rvalid(rvalid),                                      // out
  .rready(rready),                                      // in
  .rresp(rresp),                                        // out

  .reg_wr_addr(reg_wr_addr),                            // out
  .reg_wr_data(reg_wr_data),                            // out
  .reg_wr_strb(reg_wr_strb),                            // out
  .reg_wr_en(reg_wr_en),                                // out
  .reg_wr_ack(reg_wr_ack),                              // in
  .reg_rd_addr(reg_rd_addr),                            // out
  .reg_rd_en(reg_rd_en),                                // out
  .reg_rd_data(reg_rd_data),                            // in
  .reg_rd_ack(reg_rd_ack)                               // in
);

always_comb begin
  if (reg_wr_en) begin 
    case (reg_wr_addr[7:0]) 
      I8080_WINDOW_REG_OFS:
        reg_wr_ack = if_write_ack;
      I8080_CMD_FIFO_OFS:
        reg_wr_ack = ~cmd_fifo_full;  
      I8080_DATA_FIFO_OFS:
        reg_wr_ack = ~data_fifo_full;
      default:
        reg_wr_ack = 1'b1;
    endcase
  end  
  else
    reg_wr_ack = 1'b0;          
  
  
  if (read_cmd)  
    reg_rd_ack = if_read_ack;
  else
    reg_rd_ack = reg_rd_en;
end

/*
always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn)
    reg_rd_ack <= 1'b0;
  else  
    if (reg_rd_en & (!reg_rd_ack))
      reg_rd_ack <= 1'b1;
    else
      reg_rd_ack <= 1'b0;
end
*/

// always_ff @(posedge aclk or negedge arstn) begin
//   TE_d1 <= TE;
//   TE_d2 <= TE_d1;
//   
//   if (cfg_te_mode)
//     if (TE) begin
//       te_delay_cnt <= cfg_te_delay;
//       cmd_en       <= 1'b0;      
//     end
//     else
//       if (te_delay_cnt>0) 
//         te_delay_cnt <= te_delay_cnt - 1;
//       else
//         cmd_en <= 1'b1;      
//   else
//    cmd_en <= 1'b1; 
// end

always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    cfg_wr_0_len        <= '0;
    cfg_wr_1_len        <= '0;
    cfg_rd_0_len        <= '0;
    cfg_rd_1_len        <= '0;
    cfg_if_sz_in_bytes  <= 2'b01;
    CSn                 <= 1'b1; 
    RSTn                <= 1'b0; 
    cfg_te_mode         <= 1'b0;
  end
  else begin
    if ((reg_wr_en))
      case ({reg_wr_addr[7:2], 2'b0})
        I8080_GONFIG_REG_0_OFS: begin
          cfg_wr_0_len   <=  reg_wr_data[7:0];
          cfg_wr_1_len   <=  reg_wr_data[15:8];
          cfg_rd_0_len   <=  reg_wr_data[23:16];
          cfg_rd_1_len   <=  reg_wr_data[31:24];
        end      
        
        I8080_GONFIG_REG_1_OFS: begin
          cfg_te_delay         <= reg_wr_data[31:16];
          cfg_te_mode          <= reg_wr_data[5];
          RSTn                 <= reg_wr_data[4];
          cfg_if_sz_in_bytes   <= reg_wr_data[1:0];
        end      
        
        I8080_CSN_REG_OFS: begin
          CSn                  <=  reg_wr_data[0];
        end    
        
        default: begin
        end
      endcase  
  end    
end 

always_ff @(posedge aclk) begin
  DI_d <= DI;
  TE_d1 <= TE;
  TE_d2 <= TE_d1;
end

always_comb begin
  reg_rd_data = '0;
  if ((reg_rd_en)) begin
    case ({reg_rd_addr[7:2],2'b00})
      I8080_VERSION_REG_OFS: begin    
        reg_rd_data[31:0] = 32'h80230125;
      end
      
      I8080_GONFIG_REG_0_OFS: begin
        reg_rd_data[7:0]   = cfg_wr_0_len; 
        reg_rd_data[15:8]  = cfg_wr_1_len;
        reg_rd_data[23:16] = cfg_rd_0_len; 
        reg_rd_data[31:24] = cfg_rd_1_len;
      end           

      I8080_GONFIG_REG_1_OFS: begin
        reg_rd_data[31:16] = cfg_te_delay;
        reg_rd_data[5]     = cfg_te_mode;
        reg_rd_data[4]     = RSTn; 
        reg_rd_data[1:0]   = cfg_if_sz_in_bytes; 
      end           
      
      I8080_WINDOW_REG_OFS: begin
        reg_rd_data[IF_DATA_SIZE-1:0]  = DI_d;
      end           

      default: begin
        reg_rd_data[31:0] = '0;        
      end
    endcase  
  end 
  else begin
    reg_rd_data[31:0]     = '0;        
  end
  
end 

logic [31:0] cmd_fifo_dout;
logic        cmd_fifo_rd_en;
logic        cmd_fifo_wr_en;
logic        cmd_fifo_empty;

assign cmd_fifo_wr_en = (reg_wr_en) & (reg_wr_addr[7:0] == I8080_CMD_FIFO_OFS) & (~cmd_fifo_full);

lio_sfifo #(.AW(2),.DW(32)) cmd_fifo (
  .clk(aclk),
  .rstn(arstn),
  
  .din(reg_wr_data),
  .wr_en(cmd_fifo_wr_en),
  .full(cmd_fifo_full),
  
  .dout(cmd_fifo_dout),
  .rd_en(cmd_fifo_rd_en),
  .empty(cmd_fifo_empty),

  .rd_err(),
  .wr_err(),
  
  .fifo_cnt()  
);

logic [31:0] data_fifo_dout;
logic        data_fifo_rd_en;
logic        data_fifo_wr_en;
logic        data_fifo_empty;

logic [IF_DATA_SIZE-1:0]  wr_data;
logic [31:0] wr_word;
logic write_cmd;
logic read_cmd;

logic [23:0]  if_rd_data;
logic [7:0]   trans_cnt;        // Счетчик числа тактов в транзакции
logic [23:0]  data_cnt_max;     // Максимальное значение счетчика отправленных байтов
logic [23:0]  data_cnt_cur;     // Счетчик отправленных байтов

assign data_fifo_wr_en = (reg_wr_en) & (reg_wr_addr[7:0] == I8080_DATA_FIFO_OFS) & (~data_fifo_full);

lio_sfifo #(.AW(2),.DW(32)) data_fifo (
  .clk(aclk),
  .rstn(arstn),
  
  .din(reg_wr_data),
  .wr_en(data_fifo_wr_en),
  .full(data_fifo_full),
  
  .dout(data_fifo_dout),
  .rd_en(data_fifo_rd_en),
  .empty(data_fifo_empty),

  .rd_err(),
  .wr_err(),
  
  .fifo_cnt()  
);

assign data_fifo_ready = ~data_fifo_full;

//always_ff @(posedge aclk) begin

//if (IF_DATA_SIZE==16) 
always_comb begin
  if ((cfg_if_sz_in_bytes==2'b10)) begin
    if (data_cnt_cur[1])
      wr_data = wr_word[31:16];
//    else  
//      wr_data = wr_word[15:0];
  end
  else begin
    wr_data[15:8] = '0;
    case(data_cnt_cur[1:0])
//      0: wr_data[7:0] = wr_word[7:0];
      1: wr_data[7:0] = wr_word[15:8];
      2: wr_data[7:0] = wr_word[23:16];
      3: wr_data[7:0] = wr_word[31:24];
      default: begin
      end
    endcase;
  end
end


always_comb begin
  if ((reg_wr_en) && (reg_wr_addr[7:0] == I8080_WINDOW_REG_OFS))
    write_cmd = 1'b1;
  else
    write_cmd = 1'b0;    
    
  if ((reg_rd_en) && (reg_rd_addr[7:0] == I8080_WINDOW_REG_OFS))
    read_cmd = 1'b1;
  else
    read_cmd = 1'b0; 
    
  if ((stt==RD_1) && (trans_cnt == cfg_rd_1_len)) 
    if_read_ack = 1'b1;
  else
    if_read_ack = 1'b0;
  
  if ((stt==WR_1) && (trans_cnt == cfg_wr_1_len)) 
    if_write_ack = 1'b1;
  else
    if_write_ack = 1'b0;  
    
end

localparam WRITE_CMD     = 0;
localparam WRITE_PARAM   = 1;
localparam WRITE_N_PARAM = 2;
localparam SYNC_CMD       = 3;

logic end_of_word;

assign end_of_word = (data_cnt_cur[1:0]==0);
/*
always_comb
  if (((cfg_if_sz_in_bytes==2'b10) && (data_cnt_cur[1:0]==2'b10)) || ((cfg_if_sz_in_bytes==2'b01) && (data_cnt_cur[1:0]==2'b11)))  
    end_of_word = 1'b1;
  else
    end_of_word = 1'b0;
*/    

always_ff @(posedge aclk or negedge arstn) begin
  if (!arstn) begin
    stt               <= IDLE;
    trans_cnt         <= '0;
    WR                <= 1'b1;
    OE                <= 1'b0;
    DC                <= 1'b1; 
    RD                <= 1'b1;
    cmd_fifo_rd_en    <= 1'b0;
    data_cnt_max      <= '0;
    data_cnt_cur      <= '0;
    int_strb          <= 1'b0;
  end
  else
    case (stt)
      IDLE: begin
        int_strb      <= 1'b0;
        trans_cnt     <= '0;
        data_cnt_cur  <= '0;
        if (!cfg_te_mode)
          if (write_cmd) begin
            stt           <= WR_0;
            OE            <= 1'b1;
            DO            <= reg_wr_data[IF_DATA_SIZE-1:0];
            DC            <= reg_wr_data[31];
            WR            <= 1'b0;
            data_cnt_max  <= '0;
          end  
          else begin
            if (read_cmd) begin
              stt           <= RD_0;
              OE            <= 1'b0;
              DC            <= 1'b1;
              RD            <= 1'b0;
            end
            else
              if (~cmd_fifo_empty) begin
                cmd_fifo_rd_en <= 1'b1;
                case(cmd_fifo_dout[31:30])
                  WRITE_CMD: begin
                    stt           <= WR_0;
                    OE            <= 1'b1;
                    DO            <= cmd_fifo_dout[IF_DATA_SIZE-1:0];
                    DC            <= 1'b0;
                    WR            <= 1'b0;
                    data_cnt_max  <= '0;
                  end
                  WRITE_PARAM: begin
                    stt           <= WR_0;
                    OE            <= 1'b1;
                    DO            <= cmd_fifo_dout[IF_DATA_SIZE-1:0];
                    DC            <= 1'b1;
                    WR            <= 1'b0;
                    data_cnt_max      <= '0;
                  end
                  WRITE_N_PARAM: begin
                    stt           <= WAITING_DATA;
                    data_cnt_max  <= cmd_fifo_dout[23:0];
                  end
                  SYNC_CMD: begin
                    stt         <= SYNC;
                    int_strb    <= cmd_fifo_dout[0];
                  end
                  default: begin
                  end
                endcase;
              end   
          end
        else begin
          stt <= WAITING_TE;
        end
      end
      
      WAITING_TE: begin
        int_strb          <= 1'b0;
        trans_cnt         <= '0;
        data_cnt_cur      <= '0;
        if (cfg_te_mode)
          if (TE_d2) begin
            te_delay_cnt <= cfg_te_delay;
            stt          <= WAITING_TE_DELAY;
          end
        else
          stt <= IDLE;
      end
   
      WAITING_TE_DELAY: begin
        if (te_delay_cnt>0) 
          te_delay_cnt <= te_delay_cnt - 1;
        else begin
          if (~cmd_fifo_empty) begin
            cmd_fifo_rd_en <= 1'b1;
            case(cmd_fifo_dout[31:30])
              WRITE_CMD: begin
                stt           <= WR_0;
                OE            <= 1'b1;
                DO            <= cmd_fifo_dout[IF_DATA_SIZE-1:0];
                DC            <= 1'b0;
                WR            <= 1'b0;
                data_cnt_max  <= '0;
              end
              WRITE_PARAM: begin
                stt           <= WR_0;
                OE            <= 1'b1;
                DO            <= cmd_fifo_dout[IF_DATA_SIZE-1:0];
                DC            <= 1'b1;
                WR            <= 1'b0;
                data_cnt_max      <= '0;
              end
              WRITE_N_PARAM: begin
                stt           <= WAITING_DATA;
                data_cnt_max  <= cmd_fifo_dout[23:0];
              end
              SYNC_CMD: begin
                int_strb          <= cmd_fifo_dout[0];
                stt               <= WAITING_TE;
              end
              default: begin
              end
            endcase;
          end   
          else begin
            stt <= WAITING_TE;
          end
        end
      end
      
      WR_0: begin
        cmd_fifo_rd_en  <= 1'b0;
        data_fifo_rd_en <= 1'b0;
        trans_cnt   <= trans_cnt  + 1;
        if (trans_cnt == cfg_wr_0_len) begin
          stt           <= WR_1;
          OE            <= 1'b1;
          WR            <= 1'b1;
          data_cnt_cur  <= data_cnt_cur + cfg_if_sz_in_bytes;
          trans_cnt     <= '0;
        end
      end
      
      WR_1: begin
        trans_cnt   <= trans_cnt  + 1;
        if (trans_cnt == cfg_wr_1_len) begin
          if (data_cnt_cur < data_cnt_max)  begin
            if (end_of_word)
              stt <= WAITING_DATA;
            else begin
              stt <= WR_0;
              WR  <= 1'b0;
              OE  <= 1'b1;
              DO  <= wr_data;
              DC  <= 1'b1;
            end
          end
          else begin
            if (~cfg_te_mode)
              stt  <= IDLE;
            else
              stt  <= WAITING_TE;
            DC   <= 1'b1;
            OE   <= 1'b0;
          end
          trans_cnt     <= '0;
        end  
      end

      RD_0: begin
        trans_cnt   <= trans_cnt  + 1;
        if (trans_cnt == cfg_rd_0_len) begin
          stt       <= RD_1;
          RD        <= 1'b1;
          trans_cnt <= '0;
        end
      end
      
      RD_1: begin
        trans_cnt   <= trans_cnt  + 1;
        if (trans_cnt == cfg_rd_1_len) begin
          stt         <= IDLE;
          trans_cnt   <= '0;
        end  
      end
      
      WAITING_DATA: begin
        if (~data_fifo_empty) begin
          stt             <= WR_0;
          WR              <= 1'b0;
          OE              <= 1'b1;
          DO              <= data_fifo_dout[IF_DATA_SIZE-1:0];
          DC              <= 1'b1;
          data_fifo_rd_en <= 1'b1;
          wr_word         <= data_fifo_dout;
        end
      end

      SYNC: begin
        stt         <= IDLE;
      end
      
      default: begin
        stt          <= IDLE;
      end
    endcase
end 



endmodule
