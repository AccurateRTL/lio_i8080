module lio_i8080_tb #(
    parameter A_WIDTH = 32,
    parameter IF_DATA_SIZE = 16
)(    
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

    input                       TE,   
    output logic                int_strb    
);

logic                    data_fifo_ready;
logic                    RSTn;
logic                    DC;
logic                    CSn;
logic                    WR; 
logic                    RD;
logic                    OE;
logic [IF_DATA_SIZE-1:0] DO;
logic [IF_DATA_SIZE-1:0] DI;
wire  [IF_DATA_SIZE-1:0] D;

lio_i8080 #(.IF_DATA_SIZE(IF_DATA_SIZE)) lio_i8080_i(
    .aclk,
    .arstn,

    .awaddr,
    .awprot,
    .awvalid,
    .awready,
    .wdata,
    .wstrb,
    .wvalid,
    .wready,
    .bresp,
    .bvalid,
    .bready,

    .araddr,
    .arprot,
    .arvalid,
    .arready,
    .rdata,
    .rvalid,
    .rready,
    .rresp,
    
    .data_fifo_ready,
    .RSTn,
    .DC,
    .CSn,
    .WR, 
    .RD,
    .OE,
    .DO,
    .DI,    

    .TE,
    .int_strb
);

assign D  = (OE  ? DO : 'z);
assign DI = (!OE ? D : DO);

lio_i8080_display_vip #(
    .DATA_WIDTH(IF_DATA_SIZE), 
    .MEM_SIZE(255)
) lio_i8080_display_vip_i(    
    .d(D),               // Шина команд/данных
    .ce(CSn),            // Сигнал выбора устройства
    .dc(DC),             // Сигнал выбора команда(0)/данные(1) 
    .rd(RD),             // Сигнал чтения (активный низкий)
    .wr(WR)              // Сигнал записи (активный низкий)
);

endmodule
