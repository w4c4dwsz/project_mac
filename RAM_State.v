`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/08/14 17:10:25
// Design Name: 
// Module Name: RAM_State
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


module RAM_State(
    input clk,
    input wen,
    input [9:0]Addr,
    input [13:0] Data_In,
    output [13:0] Data_Out
    );

    reg [13:0] Data;
    reg [13:0] Slot_State [9:0];    //声明储存时隙信息的寄存器

    assign Data_Out = Data;

    always @ (posedge clk ) begin
        if (wen) begin  //写数据
            Data <= Slot_State[Addr];
            Slot_State[Addr] <= Data_In;
        end else begin  //读数据
            Data <= Slot_State[Addr];
        end 
    end 
endmodule
