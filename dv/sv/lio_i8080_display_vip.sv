module lio_i8080_display_vip #(
    parameter DATA_WIDTH = 16,     // Максимальный размер шины данных
    parameter MEM_SIZE   = 256     // Размер памяти (64K)
)(    
    input logic if_mode,           // Ширина шины данных 0 - 8 бит, 1 - 16 бит
    input logic rst_n,             // Сигнал сброса (активный низкий)
    
    inout tri [DATA_WIDTH-1:0] d,  // Шина команд/данных
    
    input logic ce,                // Сигнал выбора устройства
    input logic dc,                // Сигнал выбора команда(0)/данные(1) 
    input logic rd,                // Сигнал чтения (активный низкий)
    input logic wr                 // Сигнал записи (активный низкий)
);

localparam MEM_WRITE_CMD = 8'h1C;
localparam MEM_READ_CMD  = 8'h1D;

// Внутренняя память
logic [8-1:0] mem [0:MEM_SIZE-1];

// Защелка команды
logic [8-1:0] latched_cmd;

// Управление шиной данных
logic [DATA_WIDTH-1:0] data_out;
logic data_en;

logic [7:0] wr_addr;
logic [7:0] rd_addr;
logic first_rd;

// Выходной буфер для шины команд/данных
assign d = (data_en && !rd) ? data_out : 'z;
    
// Защелкивание команды по стробу записи и dc=0, запись данных для разной ширины интерфейса
always_ff @(posedge wr) begin
  if (!ce & rst_n) begin
    if (!dc) begin
        latched_cmd <= d[7:0];
        wr_addr     <= 0;
//         rd_addr     <= 0;
    end  
    else
      case (latched_cmd)
        MEM_WRITE_CMD: begin
          if (if_mode==0) begin
            mem[wr_addr] <= d[7:0];
            wr_addr      <= wr_addr+1;
          end
          else begin
            mem[wr_addr]   <= d[7:0];
            mem[wr_addr+1] <= d[15:8];
            wr_addr        <= wr_addr+2;
          end
        end
        
        default: begin
        end
      endcase
  end 
  else begin
    $display("i8080 MEMORY MODEL ERROR: write without CSn!\n");
  end
end

always @(posedge ce or negedge rd) begin
  if (ce) begin
    rd_addr   <= 0;
  end 
  else 
    if (if_mode==0) 
      rd_addr    <= rd_addr + 1;
    else 
      rd_addr    <= rd_addr + 2;
       
end   
    
// always @(posedge wr) begin
//   if (!ce) begin
//     if (wr & (~dc)) begin
//       if (d==MEM_READ_CMD) begin
//         rd_addr   <= 0;
//       end  
//     end
//   end  
//   else begin
//     $display("i8080 MEMORY MODEL ERROR: read without CSn!\n");
//   end
// end    

// Чтение данных
always @(posedge rd or negedge rd) begin
//   if (ce) begin
//   //  rd_addr  <= 0;
//     data_out <= 16'hdead;
//     data_en  <= 1'b0;
//   end  
//   else
    if (rd | ce | (~rst_n)) begin
      data_out <= 16'hdead;
      data_en  <= 1'b0;
    end  
    else
      if (latched_cmd==MEM_READ_CMD) begin
        data_en    <= 1'b1;
        if (if_mode==0) begin
          data_out   <= mem[rd_addr];
  //        rd_addr    <= rd_addr + 1;
        end
        else begin
          data_out   <= (mem[rd_addr+1]<<8) | mem[rd_addr];
  //        rd_addr    <= rd_addr + 2;
        end
      end
      else begin
        $display("i8080 MEMORY MODEL ERROR: read without command!\n"); 
        data_out <= 16'hdead;
        data_en  <= 1'b1;
      end  
end
    
endmodule
