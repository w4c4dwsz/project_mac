`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/08/10 16:30:35
// Design Name: MAC_STATE_UPDATE
// Module Name: State_Update
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 这个模块通过接受到的状态信息，更新状态。本身不储存状态信息
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module State_Update(
        input clk,reset,enable,
        input [7:0] Fi_Sender_Id,Local_Sender_Id,       
        input [11:0]Fi_State,
        input [13:0]Local_State,
        output Update_ready,
        output [13:0] Update_State
    );
    reg [1:0] Fi_Busy,Local_Busy,Update_Busy;   //Busy保存时隙状态
    reg [7:0] Fi_Id,Local_Id,Update_Id;         //ID保存占用的时隙ID
    reg [1:0] Fi_C2H,Local_C2H,Update_C2H;      //C2H保存两跳内占用该时隙的结点数量
    reg [1:0] Local_C3H,Update_C3H;             //C3H保存三跳内占用该时隙的结点数量，只有本地保存
    reg [13:0] Update_Tmp;
    reg ready;
    reg [2:0] i;
    reg enable_daly1; //寄存enable
    wire pos_enable;// enable 上升沿检测
    always @(posedge clk) begin
        enable_daly1 <= enable;
    end
    assign pos_enable = (~enable_daly1) & enable;

    always @ (posedge clk or negedge reset)
    begin
        if (!reset) begin   //置零  
            {Fi_Busy,Local_Busy,Update_Busy} <= 0;  
            {Fi_Id,Local_Id,Update_Id,Fi_C2H,Local_C2H,Update_C2H,Local_C3H,Update_C3H} <= 0;   
            i <= 3'd5;
        end else begin
            begin
                case (i)
                    3'd0:   begin //接受数据
                                {Fi_Busy,Fi_Id,Fi_C2H} <=  Fi_State;
                                {Local_Busy, Local_Id, Local_C2H, Local_C3H} <= Local_State;
                                i <= 3'd1;  //从[0]->[1]
                            end

                    3'd1:   begin   //判断ID是否一样
                                if (Fi_Id == Local_Id)  begin i <= 3'd2; end    //从[1]->[2]
                                else begin i <= 3'd3; end                       //从[1]->[3]
                            end 
                            
                    3'd2:   begin   //时隙占用者ID一致,进行状态更新
                                if (Fi_Sender_Id == Fi_Id & Fi_Busy == 2'b00)    // FI为自己占用时隙
                                begin
                                    if (Local_Busy == 2'b11)//local为冲突，更新为一条占用                                       
                                        begin Update_Busy <= 2'b00;Update_Id <= Local_Id;Update_C2H <= Local_C2H;Update_C3H <= Local_C3H + Fi_C2H;end 
                                    else if (Local_Busy == 2'b00 & Local_Id != Local_Sender_Id)//loacl为一跳占用，更新C2H，确认存活                                                                                           
                                        begin Update_Busy <= Local_Busy;Update_Id <= Local_Id;Update_C2H <= Local_C2H;Update_C3H <= Local_C3H + Fi_C2H; end
                                    else if (Local_Busy == 2'b01) //local为两条占用,更新为一条占用
                                        begin Update_Busy <= 2'b00; Update_Id <= Local_Id; Update_C2H <= Local_C2H; Update_C3H <= Local_C3H + Fi_C2H; end     
                                    else begin Update_Busy <= Local_Busy;Update_Id <= Local_Id;Update_C2H <= Local_C2H;Update_C3H<=Local_C3H;end //无动作
                                end
                                else if (Fi_Sender_Id != Fi_Id & Fi_Busy == 2'b00 & Local_Busy == 2'b01)      //FI为一跳占用 Local为两跳占用 确认存活
                                    begin Update_Busy <= Local_Busy;Update_Id <= Local_Id;Update_C2H <= Local_C2H;Update_C3H <= Local_C3H + Fi_C2H; end  
                                else begin Update_Busy <= Local_Busy;Update_Id <= Local_Id;Update_C2H <= Local_C2H;Update_C3H<=Local_C3H; end //无动作
                                i <= 3'd4;       ////从[2]->[4]
                            end
                            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



                            /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                    3'd3:   begin   //时隙占用者ID不一致，进行状态更新
                            case (Fi_Busy)
                                2'b00:  begin   //FI为忙碌
                                            if (Fi_Sender_Id == Fi_Id) // FI自己占用这个时隙
                                                begin 
                                                    case (Local_Busy)   //判断本地该时隙占用状态
                                                        2'b00:  begin   //local为忙碌
                                                                    if (Local_Sender_Id != Local_Id) begin   //Local为一跳占用这个时隙
                                                                        Update_Busy <= 2'b11;       //发生冲突，时隙状态设为冲突
                                                                        Update_Id <= Local_Id;      //判决上一帧时隙占用者继续保持该时隙
                                                                        Update_C2H <= Local_C2H;    
                                                                        Update_C3H <= Local_C3H + Fi_C2H;
                                                                    end else begin  //local 为自己占用时隙，无动作
                                                                        Update_Busy <= Local_Busy;
                                                                        Update_Id <= Local_Id;
                                                                        Update_C2H <= Local_C2H;
                                                                        Update_C3H <= Local_C3H;
                                                                    end 
                                                                end 
                                                        2'b01:  begin   //local为两条占用 更新C2H,C3H
                                                                    Update_Busy <= Local_Busy;
                                                                    Update_Id <= Local_Id;
                                                                    Update_C2H <= Local_C2H + 1;
                                                                    Update_C3H <= Local_C3H + Fi_C2H;
                                                                end 
                                                        2'b10:  begin   //local为空闲,更新BUSY = 一条占用；更新ID；
                                                                    Update_Busy <= 2'b00;
                                                                    Update_Id <= Fi_Id;
                                                                    Update_C2H <= Local_C2H + 1;
                                                                    Update_C3H <= Local_C3H + Fi_C2H;
                                                                end 
                                                        2'b11:  begin   //local为冲突 无动作
                                                                    Update_Busy <= Local_Busy;
                                                                    Update_Id <= Local_Id;
                                                                    Update_C2H <= Local_C2H;
                                                                    Update_C3H <= Local_C3H;
                                                                end 
                                                    endcase 
                                                end 
                                            else                       // FI的邻居占用这个时隙（一跳占用）
                                                begin
                                                    case (Local_Busy)
                                                        2'd00:  begin   // local 为忙碌
                                                                    if (Fi_Id == Fi_Sender_Id) begin // local 为自己占用 发生冲突
                                                                        Update_Busy <= 2'd11;   //设置状态为冲突
                                                                        Update_Id <= Local_Id;  // 判决时隙上一帧占用者为冲突胜利者；
                                                                        Update_C2H <= Local_C2H;
                                                                        Update_C3H <= Local_C3H;
                                                                    end else begin  // local 为一跳占用 更新C2H和C3H
                                                                        Update_Busy <= Local_Busy;
                                                                        Update_Id <= Local_Id;
                                                                        Update_C2H <= Local_C2H + 1;
                                                                        Update_C3H <= Fi_C2H + Local_C3H;
                                                                    end 
                                                                end 
                                                        2'd01:  begin   // local 为两跳占用 更新C2H和C3H
                                                                    Update_Busy <= Local_Busy;
                                                                    Update_Id <= Local_Id;
                                                                    Update_C2H <= Local_C2H + 1;
                                                                    Update_C3H <= Fi_C2H + Local_C3H;
                                                                end     
                                                        2'd10:  begin   // local 为空闲 BUSY=两条占用；更新ID；C2H+1；C3H+1
                                                                    Update_Busy <= 2'b01;
                                                                    Update_Id <= Fi_Id;
                                                                    Update_C2H <= Local_C2H + 1;
                                                                    Update_C3H <= Local_C3H + Fi_C2H;
                                                                end 
                                                        2'd11:  begin   // local 为冲突 不改变
                                                                    Update_Busy <= Local_Busy;
                                                                    Update_Id <= Local_Id;
                                                                    Update_C2H <= Local_C2H;
                                                                    Update_C3H <= Local_C3H;
                                                                end 
                                                    endcase 
                                                end
                                end
                                2'b01:  begin   //FI为两跳占用
                                    case (Local_Busy)
                                        2'b00:  begin // LOCAL为忙率
                                                    if (Local_Sender_Id == Local_Id) begin  // local为自己占用  只更新C3H
                                                        Update_Busy <= Local_Busy;
                                                        Update_Id <= Local_Id;
                                                        Update_C2H <= Local_C2H;
                                                        Update_C3H <= Local_C3H + Fi_C2H;
                                                    end else begin  //local为一跳占用 只更新C3H
                                                        Update_Busy <= Local_Busy;
                                                        Update_Id <= Local_Id;
                                                        Update_C2H <= Local_C2H;
                                                        Update_C3H <= Local_C3H + Fi_C2H;
                                                    end
                                                end 
                                        2'b01:  begin   //local为两跳，不更新
                                                    Update_Busy <= Local_Busy;
                                                    Update_Id <= Local_Id;
                                                    Update_C2H <= Local_C2H;
                                                    Update_C3H <= Local_C3H;
                                                end 
                                        2'b10:  begin   // local为空闲  只更新C3H
                                                    Update_Busy <= Local_Busy;
                                                    Update_Id <= Local_Id;
                                                    Update_C2H <= Local_C2H;
                                                    Update_C3H <= Local_C3H + Fi_C2H;
                                                end 
                                        2'b11:  begin   // local为冲突  无变化：
                                                    Update_Busy <= Local_Busy;
                                                    Update_Id <= Local_Id;
                                                    Update_C2H <= Local_C2H;
                                                    Update_C3H <= Local_C3H;
                                                end 
                                    endcase 
                                end 
                                2'b10:  begin   //FI为空闲  
                                    case (Local_Busy)
                                        2'b00:  begin   //local为忙碌
                                                    if (Local_Sender_Id == Local_Id) begin  // local为自己占用  无变化
                                                        Update_Busy <= Local_Busy;
                                                        Update_Id <= Local_Id;
                                                        Update_C2H <= Local_C2H;
                                                        Update_C3H <= Local_C3H;
                                                    end else begin  
                                                        if (Fi_Sender_Id == Local_Id) begin //若发送报文的节点时该节点原有的占用者，则BUSY=空闲，C2H-1,C3H-1
                                                            Update_Busy <= 2'b10;
                                                            Update_Id <= 8'b00000000;
                                                            Update_C2H <= Local_C2H - 1;
                                                            Update_C3H <= Local_C3H -1;
                                                        end else begin                      // 否则无变化
                                                            Update_Busy <= Local_Busy;
                                                            Update_Id <= Local_Id;
                                                            Update_C2H <= Local_C2H;
                                                            Update_C3H <= Local_C3H;
                                                        end
                                                    end
                                                end 
                                        2'b01:  begin   //local为两跳占用   
                                                    if (Fi_Sender_Id == Local_Id) begin //若发送报文的节点时该节点原有的占用者，则BUSY=空闲，C2H-1,C3H-1
                                                            Update_Busy <= 2'b10;
                                                            Update_Id <= 8'b00000000;
                                                            Update_C2H <= Local_C2H - 1;
                                                            Update_C3H <= Local_C3H -1;
                                                        end else begin                      // 否则无变化
                                                            Update_Busy <= Local_Busy;
                                                            Update_Id <= Local_Id;
                                                            Update_C2H <= Local_C2H;
                                                            Update_C3H <= Local_C3H;
                                                        end
                                                end 
                                        2'b10:  begin   //local为空闲   无变化
                                                    Update_Busy <= Local_Busy;
                                                    Update_Id <= Local_Id;
                                                    Update_C2H <= Local_C2H;
                                                    Update_C3H <= Local_C3H;
                                                end 
                                        2'b11:  begin   //local为冲突   无变化
                                                    Update_Busy <= Local_Busy;
                                                    Update_Id <= Local_Id;
                                                    Update_C2H <= Local_C2H;
                                                    Update_C3H <= Local_C3H;
                                                end  
                                    endcase     
                                end
                                2'b11:  begin   //FI为冲突,冲突放弃
                                    if (Local_Id == 2'b11) begin    //local为冲突 不更新
                                        Update_Busy <= Local_Busy;
                                        Update_Id <= Local_Id;
                                        Update_C2H <= Local_C2H;
                                        Update_C3H <= Local_C3H;
                                    end else begin  //LOACL不为冲突
                                        if (Fi_Id != Local_Id) begin    //若FI中时隙ID不等于本地时隙信息，以FI中判决ID为冲突的胜者更新状态
                                            Update_Busy <= 2'b01;   //更新状态为两跳占用
                                            Update_Id <= Fi_Id;
                                            Update_C2H <= Local_C2H;
                                            Update_C2H <= Local_C3H;
                                        end else begin                  // 否则不更改状态
                                            Update_Busy <= Local_Busy;
                                            Update_Id <= Local_Id;
                                            Update_C2H <= Local_C2H;
                                            Update_C3H <= Local_C3H;
                                        end
                                    end
                                     
                                end 
                            endcase 
                            i <= 3'd4;  //从[3]->[4]
                        end
                            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                    3'd4:  begin   //发送更新后的状态
                        Update_Tmp <= {Update_Busy,Update_Id,Update_C2H,Update_C3H};
                        ready <= 1;
                        i <= 3'd5;  //从[4]->[5]
                    end
                    3'd5 :  begin   //初始状态
                        ready <= 0;
                        if (pos_enable) begin
                            i <= 3'd0;  //从[5]->[0]    接收到使能信号，更新时隙
                        end else begin
                            i <= 3'd5;  //从[5]->[5]    没接收到使能信号，等待信号
                        end
                    end 
                endcase
            end 
        end 
    end

    //输出驱动  
    assign Update_State = Update_Tmp;
    assign Update_ready = ready;
endmodule
