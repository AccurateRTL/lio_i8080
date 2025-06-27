module lio_i8080_display_memory #(
    parameter DATA_WIDTH = 8,     // 8-битные данные
    parameter MEM_SIZE   = 255  // Размер памяти (64K)
)(    
    // Объединенная шина адреса/данных (мультиплексированная)
    inout tri [DATA_WIDTH-1:0] d,  // Шина команд/данных
    
    // Сигналы управления
    input logic ce,             // Сигнал выбора устройства
    input logic dc,             // Сигнал выбора команда(0)/данные(1) 
    input logic rd,             // Сигнал чтения (активный низкий)
    input logic wr              // Сигнал записи (активный низкий)
);

localparam MEM_WRITE_CMD = 8'h1C;
localparam MEM_READ_CMD  = 8'h1D;

// Внутренняя память
logic [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];

// Защелка команды
logic [DATA_WIDTH-1:0] latched_cmd;

// Управление шиной данных
logic [DATA_WIDTH-1:0] data_out;
logic data_en;

logic [7:0] wr_addr;
logic [7:0] rd_addr;
logic first_rd;

// Выходной буфер для шины команд/данных
assign d = (data_en && !rd) ? data_out : 'z;
    
// Защелкивание команды по стробу записи и dc=0
always_ff @(posedge wr) begin
  if (!dc) begin
    latched_cmd <= d;
    wr_addr    <= 0;
  end  
  else
    case (latched_cmd)
      MEM_WRITE_CMD: begin    
        mem[wr_addr] = d;
        wr_addr<=wr_addr+1;
      end
      
      default: begin
      end
    endcase  
end
    
always @(posedge wr or posedge rd) begin
  if (wr & (~dc)) begin
    if (d==MEM_READ_CMD)
      first_rd <= 1'b1;
  end  
  if (!rd) 
    first_rd <= 1'b0;
end    
    
always @(edge rd) begin
  if (rd) begin
    data_out <= 8'heb;
    data_en  <= 1'b0;
  end  
  else
    if (latched_cmd==MEM_READ_CMD) begin
      data_en  <= 1'b1;
      if (!first_rd) begin
        data_out   <= mem[rd_addr];
        rd_addr    <= rd_addr + 1;
      end  
      else 
        rd_addr    <= '0;
    end
    else 
      $display("i8080 ERROR: rd without command!\n");
      
end
    
  /*  
    // Основная логика работы памяти
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Сброс памяти (опционально)
            foreach(mem[i]) mem[i] <= 8'h00;
            data_en <= 1'b0;
        end else begin
            // По умолчанию отключаем выход
            data_en <= 1'b0;
            
            // Операция чтения
            if (!rd) begin
                data_out <= mem[latched_addr];
                data_en  <= 1'b1;
            end
            
            // Операция записи
            if (!wr) begin
                mem[latched_addr] <= ad;
            end
        end
    end
   */ 
endmodule
