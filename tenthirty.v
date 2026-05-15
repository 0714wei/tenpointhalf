//================================================================
// 2026 FPGA Midterm -- tenthirty
// author: NCHU EE lab716
// date:2026.05.11
// version:1.0
//================================================================

module tenthirty(
    input clk,
    input rst_n,        
    input btn_m,        
    input btn_r,        
    input switch,       
    output reg [7:0] seg7_sel,
    output reg [7:0] seg7,      
    output reg [7:0] seg7_l,    
    output reg [2:0] led,       
    output reg led_mode         
);

//================================================================
// PARAMETER
//================================================================
parameter S_IDLE       = 5'd0;
parameter S_DRAW_P1    = 5'd1;
parameter S_WAIT_P1    = 5'd2;
parameter S_CALC_P1    = 5'd3;
parameter S_HIT_P      = 5'd4;
parameter S_DRAW_P     = 5'd5;
parameter S_WAIT_P     = 5'd6;
parameter S_CALC_P     = 5'd7;

parameter S_DRAW_D1    = 5'd8;
parameter S_WAIT_D1    = 5'd9;
parameter S_CALC_D1    = 5'd10;
parameter S_HIT_D      = 5'd11;
parameter S_DRAW_D     = 5'd12;
parameter S_WAIT_D     = 5'd13;
parameter S_CALC_D     = 5'd14;

parameter S_COMPARE    = 5'd15;
parameter S_DONE       = 5'd16;

//================================================================
// d_clk
//================================================================
reg [24:0] counter;
wire dis_clk;
wire d_clk;

assign dis_clk = counter[15];
assign d_clk = counter[23];

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter <= 0;
    end
    else begin
        counter <= counter + 1;
    end
end

//================================================================
// REG/WIRE
//================================================================
reg [7:0] seg7_temp[0:7];
reg [2:0] dis_cnt;
reg pip;
wire [3:0] number;

reg [5:0] total_player;
reg [5:0] total_dealer;
reg [4:0] state;
reg [2:0] player_cards, dealer_cards;
reg [2:0] round_cnt;

reg [3:0] p_hist [0:4];
reg [4:0] p_hist_valid;
reg [3:0] d_hist [0:4];
reg [4:0] d_hist_valid;

reg btn_m_d, btn_r_d;
wire btn_m_pos = btn_m && !btn_m_d;
wire btn_r_pos = btn_r && !btn_r_d;

// ✨ 加入 Pending 暫存器
reg btn_m_pending;
reg btn_r_pending;

wire [3:0] c_int = (number >= 4'd1 && number <= 4'd10) ? number :
                   (led_mode && (number == 4'd11 || number == 4'd12)) ? 4'd10 : 4'd0;
wire c_hlf = (!led_mode && number >= 4'd11 && number <= 4'd13) ? 1'b1 :
             (led_mode && number == 4'd13) ? 1'b1 : 1'b0;
wire [5:0] c_val = {1'b0, c_int, 1'b0} + c_hlf;

//================================================================
// FSM
//================================================================
always @(posedge d_clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE; pip <= 0; total_player <= 0; total_dealer <= 0;
        player_cards <= 0; dealer_cards <= 0; round_cnt <= 0; led_mode <= 0;
        btn_m_d <= 0; btn_r_d <= 0;
        p_hist_valid <= 5'b00000; d_hist_valid <= 5'b00000;
        btn_m_pending <= 0; btn_r_pending <= 0;
    end else begin
        btn_m_d <= btn_m; btn_r_d <= btn_r;
        
        // ✨ 無論 FSM 在哪個狀態，只要 Testbench 按下按鈕，就立刻鎖定進 Pending
        if (btn_m_pos) btn_m_pending <= 1'b1;
        if (btn_r_pos) btn_r_pending <= 1'b1;

        case (state)
            S_IDLE: begin
                if (btn_m_pos || btn_m_pending) begin 
                    btn_m_pending <= 0; // 消耗按鈕訊號
                    if (round_cnt == 0) led_mode <= switch; 
                    state <= S_DRAW_P1; 
                end
            end
            
            // --- 玩家首抽 ---
            S_DRAW_P1: begin pip <= 1; state <= S_WAIT_P1; end
            S_WAIT_P1: begin pip <= 0; state <= S_CALC_P1; end
            S_CALC_P1: begin
                total_player <= total_player + c_val;
                p_hist[0] <= number;
                p_hist_valid[0] <= 1;
                player_cards <= 1;
                state <= S_DRAW_D1;
            end

            // --- 莊家首抽 (底牌) ---
            S_DRAW_D1: begin pip <= 1; state <= S_WAIT_D1; end
            S_WAIT_D1: begin pip <= 0; state <= S_CALC_D1; end
            S_CALC_D1: begin
                total_dealer <= total_dealer + c_val;
                d_hist[0] <= number;
                d_hist_valid[0] <= 1;
                dealer_cards <= 1;
                state <= S_HIT_P; // 直接交棒，不等待放開
            end

            // --- 玩家補牌 ---
            S_HIT_P: begin
                if (total_player >= 21 || player_cards == 5) begin
                    state <= S_HIT_D;
                    btn_m_pending <= 0; // 爆牌時，清空多餘的連按
                end
                // ✨ 檢查當下的邊緣觸發，或是剛剛被記下來的 Pending
                else if (btn_m_pos || btn_m_pending) begin
                    btn_m_pending <= 0;
                    state <= S_DRAW_P;
                end
                else if (btn_r_pos || btn_r_pending) begin
                    btn_r_pending <= 0;
                    state <= S_HIT_D; 
                end
            end
            S_DRAW_P: begin pip <= 1; state <= S_WAIT_P; end
            S_WAIT_P: begin pip <= 0; state <= S_CALC_P; end
            S_CALC_P: begin
                total_player <= total_player + c_val;
                p_hist[player_cards] <= number; p_hist_valid[player_cards] <= 1'b1;
                player_cards <= player_cards + 1; 
                state <= S_HIT_P;
            end

            // --- 莊家補牌 ---
            S_HIT_D: begin
                if (total_dealer >= 21 || dealer_cards == 5) begin
                    state <= S_COMPARE;
                    btn_m_pending <= 0;
                end
                else if (btn_m_pos || btn_m_pending) begin
                    btn_m_pending <= 0;
                    state <= S_DRAW_D;
                end
                else if (btn_r_pos || btn_r_pending) begin
                    btn_r_pending <= 0;
                    state <= S_COMPARE;
                end
            end
            S_DRAW_D: begin pip <= 1; state <= S_WAIT_D; end
            S_WAIT_D: begin pip <= 0; state <= S_CALC_D; end
            S_CALC_D: begin
                total_dealer <= total_dealer + c_val;
                d_hist[dealer_cards] <= number; d_hist_valid[dealer_cards] <= 1'b1;
                dealer_cards <= dealer_cards + 1; 
                state <= S_HIT_D;
            end

            // --- 結算比對 ---
            S_COMPARE: begin 
                if (btn_r_pos || btn_r_pending) begin
                    btn_r_pending <= 0; // 消耗結束訊號
                    total_player <= 0; total_dealer <= 0; player_cards <= 0; dealer_cards <= 0;
                    p_hist_valid <= 5'b00000; d_hist_valid <= 5'b00000;
                    if (round_cnt < 3) begin round_cnt <= round_cnt + 1; state <= S_IDLE; end else state <= S_DONE;
                end
            end
            S_DONE: state <= S_DONE;
        endcase
    end
end

//================================================================
// DESIGN
//================================================================
function [7:0] decode; input [3:0] v; begin
    case(v)
        0: decode=8'b00111111; 1: decode=8'b00000110; 2: decode=8'b01011011; 3: decode=8'b01001111;
        4: decode=8'b01100110; 5: decode=8'b01101101; 6: decode=8'b01111101; 7: decode=8'b00000111;
        8: decode=8'b01111111; 9: decode=8'b01101111; default: decode=8'b00000001;
    endcase
end endfunction

function [7:0] dec_c; input [3:0] n; input v; begin
    if (!v) dec_c = 8'b00000001;
    else case(n)
        11: dec_c=8'b00001110;
        12: dec_c=8'b10111111;
        13: dec_c=8'b01110110;
        10: dec_c=8'b00111111;
        default: dec_c=decode(n);
    endcase
end endfunction

always @(*) begin
    if (state == S_DONE || state == S_IDLE) begin
        seg7_temp[7]=decode(0); seg7_temp[6]=decode(0);
        seg7_temp[5]=8'b00000001; seg7_temp[4]=8'b00000001;
        seg7_temp[3]=8'b00000001; seg7_temp[2]=8'b00000001;
        seg7_temp[1]=8'b00000001; seg7_temp[0]=8'b00000001;
    end else if (state == S_COMPARE) begin
        seg7_temp[7]=decode(total_dealer[5:1]/10);
        seg7_temp[6]=decode(total_dealer[5:1]%10);
        seg7_temp[5]=total_dealer[0]?8'b10000000:8'b00000001;
        seg7_temp[4]=8'b00000001;
        seg7_temp[3]=8'b00000001;
        seg7_temp[2]=decode(total_player[5:1]/10);
        seg7_temp[1]=decode(total_player[5:1]%10);
        seg7_temp[0]=total_player[0]?8'b10000000:8'b00000001;
    end else if (state >= S_DRAW_D1 && state <= S_CALC_D) begin
        seg7_temp[7]=decode(total_dealer[5:1]/10);
        seg7_temp[6]=decode(total_dealer[5:1]%10);
        seg7_temp[5]=total_dealer[0]?8'b10000000:8'b00000001;
        seg7_temp[4]=dec_c(d_hist[4], d_hist_valid[4]);
        seg7_temp[3]=dec_c(d_hist[3], d_hist_valid[3]);
        seg7_temp[2]=dec_c(d_hist[2], d_hist_valid[2]);
        seg7_temp[1]=dec_c(d_hist[1], d_hist_valid[1]);
        seg7_temp[0]=dec_c(d_hist[0], d_hist_valid[0]);
    end else begin
        seg7_temp[7]=decode(total_player[5:1]/10);
        seg7_temp[6]=decode(total_player[5:1]%10);
        seg7_temp[5]=total_player[0]?8'b10000000:8'b00000001;
        seg7_temp[4]=dec_c(p_hist[4], p_hist_valid[4]);
        seg7_temp[3]=dec_c(p_hist[3], p_hist_valid[3]);
        seg7_temp[2]=dec_c(p_hist[2], p_hist_valid[2]);
        seg7_temp[1]=dec_c(p_hist[1], p_hist_valid[1]);
        seg7_temp[0]=dec_c(p_hist[0], p_hist_valid[0]);
    end
end

//================================================================
// LED
//================================================================
always @(*) begin
    led = 3'b000;
    if (state == S_DONE) begin
        led[2] = 1'b1;
    end
    else if (state == S_COMPARE) begin
        if (total_player > 21) led[1] = 1'b1;
        else if (total_dealer > 21) led[0] = 1'b1;
        else if (total_player > total_dealer) led[0] = 1'b1;
        else led[1] = 1'b1;
    end
end

//================================================================
// SEGMENT (Don't revise)
//================================================================
always@(posedge dis_clk or negedge rst_n) begin
    if(!rst_n) begin
        dis_cnt <= 0;
    end
    else begin
        dis_cnt <= (dis_cnt >= 7) ? 0 : (dis_cnt + 1);
    end
end

always @(posedge dis_clk or negedge rst_n) begin
    if(!rst_n) begin
        seg7 <= 8'b0000_0001;
    end
    else begin
        if(!dis_cnt[2]) begin
            seg7 <= seg7_temp[dis_cnt];
        end
    end
end

always @(posedge dis_clk or negedge rst_n) begin
    if(!rst_n) begin
        seg7_l <= 8'b0000_0001;
    end
    else begin
        if(dis_cnt[2]) begin
            seg7_l <= seg7_temp[dis_cnt];
        end
    end
end

always@(posedge dis_clk or negedge rst_n) begin
    if(!rst_n) begin
        seg7_sel <= 8'b11111111;
    end
    else begin
        case(dis_cnt)
            0 : seg7_sel <= 8'b00000001;
            1 : seg7_sel <= 8'b00000010;
            2 : seg7_sel <= 8'b00000100;
            3 : seg7_sel <= 8'b00001000;
            4 : seg7_sel <= 8'b00010000;
            5 : seg7_sel <= 8'b00100000;
            6 : seg7_sel <= 8'b01000000;
            7 : seg7_sel <= 8'b10000000;
            default : seg7_sel <= 8'b11111111;
        endcase
    end
end

//================================================================
// LUT
//================================================================
lut inst_LUT (.clk(d_clk), .rst_n(rst_n), .pip(pip), .number(number));

endmodule