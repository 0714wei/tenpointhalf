`timescale 1ns/1ps
`define CYCLE 10

// ================================================================
// Filename: lab_mid_tenthirty.v
// Date: 2026/05/10
// Lab: EELAB716
// Creator: kueiyoulu@gmail.com
// Note: Plz read the midterm file to modify the define below.
// Setup: Adjust TEST_MODE and GAME_MODE macros to select between 
//        functional or boundary verification under simple/difficult rules.
// ================================================================

// ================================================================
// You can modify the MODE for desirable testsetup
// ================================================================
// 0: FUNC (Functional Test), 1: BORDER (Boundary Test)
`ifndef TEST_MODE
    `define TEST_MODE 0 
`endif

// 0: COM (Simple Mode), 1: PRO (Difficult Mode)
`ifndef GAME_MODE
    `define GAME_MODE 0 
`endif
// ================================================================

module tb_tenthirty ();

    reg  clk = 0;
    reg  rst_n;
    reg  sw;
    reg  btn_m; 
    reg  btn_r; 
    
    wire [7:0] seg7_sel;
    wire [7:0] seg7;
    wire [7:0] seg7_l; 
    wire [2:0] led;
    wire       led_mode;
    
    integer i, k;
    integer actual_p_hits, actual_d_hits;
    integer timeout_cnt;

    always begin
        #(`CYCLE/2) clk = ~clk;
    end

    // ================================================================
    //  !!!!!! This clk setup is to let the clock between DUT and TB perform the same value !!!!!!!
    // If you encounter the situation that simulation time is too slow for TB, just modify DUT's clock setup!
    // ================================================================
    wire dut_d_clk = inst_tenthirty.d_clk;

    // ================================================================
    // True Golden Model Setup (Independent from DUT)
    // ================================================================
    reg [3:0] golden_deck [0:51];
    integer tb_ptr; 
    
    reg [5:0] tb_p_score;
    reg [5:0] tb_d_score;
    integer   tb_p_cards;
    integer   tb_d_cards;
    reg [2:0] expected_led;

    initial begin
        golden_deck[ 0]=10; golden_deck[ 1]=13; golden_deck[ 2]= 8; golden_deck[ 3]= 3;
        golden_deck[ 4]=10; golden_deck[ 5]= 2; golden_deck[ 6]=11; golden_deck[ 7]=11;
        golden_deck[ 8]= 1; golden_deck[ 9]= 5; golden_deck[10]= 1; golden_deck[11]= 4;
        golden_deck[12]=13; golden_deck[13]=10; golden_deck[14]=11; golden_deck[15]=13; 
        golden_deck[16]= 6; golden_deck[17]= 5; golden_deck[18]=12; golden_deck[19]= 3; 
        golden_deck[20]= 1; golden_deck[21]= 6; golden_deck[22]= 8; golden_deck[23]= 5; 
        golden_deck[24]= 8; golden_deck[25]= 3; golden_deck[26]= 4; golden_deck[27]= 7;
        golden_deck[28]= 7; golden_deck[29]= 9; golden_deck[30]= 7; golden_deck[31]= 4; 
        golden_deck[32]= 6; golden_deck[33]= 2; golden_deck[34]= 9; golden_deck[35]=12; 
        golden_deck[36]= 3; golden_deck[37]= 9; golden_deck[38]= 5; golden_deck[39]=12; 
        golden_deck[40]= 2; golden_deck[41]=10; golden_deck[42]=12; golden_deck[43]= 2; 
        golden_deck[44]= 6; golden_deck[45]=13; golden_deck[46]= 1; golden_deck[47]= 4; 
        golden_deck[48]= 8; golden_deck[49]= 9; golden_deck[50]= 7; golden_deck[51]=11;
    end

    function [5:0] get_card_score;
        input [3:0] card;
        input mode;
        begin
            if (card >= 1 && card <= 10) begin
                get_card_score = {1'b0, card, 1'b0}; 
            end 
            else if (card == 11 || card == 12) begin
                get_card_score = (mode) ? 6'd20 : 6'd1;  
            end 
            else if (card == 13) begin
                get_card_score = 6'd1; 
            end 
            else begin
                get_card_score = 6'd0; 
            end
        end
    endfunction

    task predict_round;
        input integer player_hits;
        input integer dealer_hits;
        integer j;
        reg [3:0] current_card;
        begin
            actual_p_hits = 0;
            actual_d_hits = 0;
            
            current_card = (tb_ptr < 52) ? golden_deck[tb_ptr] : 4'd0;
            tb_p_score = get_card_score(current_card, sw);
            tb_ptr = tb_ptr + 1; tb_p_cards = 1;
            
            current_card = (tb_ptr < 52) ? golden_deck[tb_ptr] : 4'd0;
            tb_d_score = get_card_score(current_card, sw);
            tb_ptr = tb_ptr + 1; tb_d_cards = 1;

            for (j = 0; j < player_hits; j = j + 1) begin
                if (tb_p_cards < 5 && tb_p_score < 21) begin
                    current_card = (tb_ptr < 52) ? golden_deck[tb_ptr] : 4'd0;
                    tb_p_score = tb_p_score + get_card_score(current_card, sw);
                    tb_ptr = tb_ptr + 1; tb_p_cards = tb_p_cards + 1;
                    actual_p_hits = actual_p_hits + 1;
                end
            end

            for (j = 0; j < dealer_hits; j = j + 1) begin
                if (tb_d_cards < 5 && tb_d_score < 21) begin
                    current_card = (tb_ptr < 52) ? golden_deck[tb_ptr] : 4'd0;
                    tb_d_score = tb_d_score + get_card_score(current_card, sw);
                    tb_ptr = tb_ptr + 1; tb_d_cards = tb_d_cards + 1;
                    actual_d_hits = actual_d_hits + 1;
                end
            end

            if (tb_p_score > 6'd21)      expected_led = 3'b010; 
            else if (tb_d_score > 6'd21) expected_led = 3'b001; 
            else if (tb_p_score > tb_d_score) expected_led = 3'b001; 
            else expected_led = 3'b010; 
        end
    endtask

    // ================================================================
    // Action Tasks
    // ================================================================
    task press_btn_m;
        begin
            btn_m = 1;
            repeat(2) @(negedge dut_d_clk); 
            btn_m = 0;
            repeat(2) @(negedge dut_d_clk); 
        end
    endtask

    task press_btn_r;
        begin
            btn_r = 1;
            repeat(2) @(negedge dut_d_clk);
            btn_r = 0;
            repeat(2) @(negedge dut_d_clk);
        end
    endtask

    // ================================================================
    // Result Checker
    // ================================================================
    task verify_result;
        begin
            if (led === expected_led) begin
                $display("--------------------------------------------------");
                $display("[PASS] Time: %0t", $time);
                $display("       TB Predict -> Player: %d, Dealer: %d | LED: %b", tb_p_score, tb_d_score, expected_led);
                $display("       DUT Output -> Player: %d, Dealer: %d | LED: %b", inst_tenthirty.total_player, inst_tenthirty.total_dealer, led);
                $display("--------------------------------------------------");
            end 
            else begin
                $display("--------------------------------------------------");
                $display("[FAIL] Time: %0t", $time);
                $display("       TB Predict -> Player: %d, Dealer: %d | LED: %b", tb_p_score, tb_d_score, expected_led);
                $display("       DUT Output -> Player: %d, Dealer: %d | LED: %b", inst_tenthirty.total_player, inst_tenthirty.total_dealer, led);
                $display("--------------------------------------------------");
                $stop; 
            end
        end
    endtask

    // ================================================================
    // Main flow
    // ================================================================
    initial begin
        rst_n = 0;
        btn_m = 0;
        btn_r = 0;
        tb_ptr = 0; 
        
        sw = `GAME_MODE; 
        
        repeat(4) @(negedge clk);
        rst_n = 1;
        
        repeat(10) @(negedge dut_d_clk);

        if (`TEST_MODE == 0) begin
            $display("\n================ START FUNC TEST ================");
            $display("Mode: %s", (`GAME_MODE == 1) ? "PRO (Difficult Mode)" : "COM (Simple Mode)");
            
            for (i = 0; i < 4; i = i + 1) begin
                $display("\n--- Round %0d ---", i+1);
                
                predict_round(1, 0); 
                
                press_btn_m(); 
                
                for (k = 0; k < actual_p_hits; k = k + 1) begin
                    press_btn_m();
                end
                
                if (tb_p_score < 21 && tb_p_cards < 5) begin
                    press_btn_r(); 
                end
                
                for (k = 0; k < actual_d_hits; k = k + 1) begin
                    press_btn_m();
                end
                
                if (tb_d_score < 21 && tb_d_cards < 5) begin
                    press_btn_r();
                end
                
                timeout_cnt = 0;
                while (led !== 3'b001 && led !== 3'b010 && timeout_cnt < 200) begin
                    @(negedge dut_d_clk);
                    timeout_cnt = timeout_cnt + 1;
                end
                
                if (timeout_cnt >= 200) begin
                    $display("--------------------------------------------------");
                    $display("[FAIL] Time: %0t", $time);
                    $display("       [TIMEOUT] DUT Deadlocked");
                    $display("--------------------------------------------------");
                    $stop;
                end
                
                verify_result();
                
                press_btn_r(); 
                
                timeout_cnt = 0;
                while (led !== 3'b000 && led !== 3'b100 && timeout_cnt < 200) begin
                    @(negedge dut_d_clk);
                    timeout_cnt = timeout_cnt + 1;
                end
                
                if (timeout_cnt >= 200) begin
                    $display("--------------------------------------------------");
                    $display("[FAIL] Time: %0t", $time);
                    $display("       [TIMEOUT] DUT Deadlocked");
                    $display("--------------------------------------------------");
                    $stop;
                end
            end
            
        end 
        else begin
            $display("\n=============== START BORDER TEST ===============");
            $display("Mode: %s", (`GAME_MODE == 1) ? "PRO (Difficult Mode)" : "COM (Simple Mode)");
            
            $display("\n--- Test 1: 5-Card Boundary ---");
            predict_round(4, 0); 
            
            press_btn_m(); 
            for (k = 0; k < actual_p_hits; k = k + 1) begin
                press_btn_m();
            end
            
            if (tb_p_score < 21 && tb_p_cards < 5) begin
                press_btn_r();
            end
            
            for (k = 0; k < actual_d_hits; k = k + 1) begin
                press_btn_m();
            end
            
            if (tb_d_score < 21 && tb_d_cards < 5) begin
                press_btn_r();
            end
            
            timeout_cnt = 0;
            while (led !== 3'b001 && led !== 3'b010 && timeout_cnt < 200) begin
                @(negedge dut_d_clk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            if (timeout_cnt >= 200) begin
                $display("--------------------------------------------------");
                $display("[FAIL] Time: %0t", $time);
                $display("       [TIMEOUT] DUT Deadlocked");
                $display("--------------------------------------------------");
                $stop;
            end
             
            verify_result();
            press_btn_r();
            
            timeout_cnt = 0;
            while (led !== 3'b000 && led !== 3'b100 && timeout_cnt < 200) begin
                @(negedge dut_d_clk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            if (timeout_cnt >= 200) begin
                $display("--------------------------------------------------");
                $display("[FAIL] Time: %0t", $time);
                $display("       [TIMEOUT] DUT Deadlocked");
                $display("--------------------------------------------------");
                $stop;
            end

            $display("\n--- Test 2: Bust Boundary ---");
            
            predict_round(4, 0); 
            
            press_btn_m(); 
            for (k = 0; k < actual_p_hits; k = k + 1) begin
                press_btn_m();
            end
            
            if (tb_p_score < 21 && tb_p_cards < 5) begin
                press_btn_r();
            end
            
            for (k = 0; k < actual_d_hits; k = k + 1) begin
                press_btn_m();
            end
            
            if (tb_d_score < 21 && tb_d_cards < 5) begin
                press_btn_r();
            end
            
            timeout_cnt = 0;
            while (led !== 3'b001 && led !== 3'b010 && timeout_cnt < 200) begin
                @(negedge dut_d_clk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            if (timeout_cnt >= 200) begin
                $display("--------------------------------------------------");
                $display("[FAIL] Time: %0t", $time);
                $display("       [TIMEOUT] DUT Deadlocked");
                $display("--------------------------------------------------");
                $stop;
            end
             
            verify_result();
            press_btn_r();
            
            timeout_cnt = 0;
            while (led !== 3'b000 && led !== 3'b100 && timeout_cnt < 200) begin
                @(negedge dut_d_clk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            if (timeout_cnt >= 200) begin
                $display("--------------------------------------------------");
                $display("[FAIL] Time: %0t", $time);
                $display("       [TIMEOUT] DUT Deadlocked");
                $display("--------------------------------------------------");
                $stop;
            end
        end

        if (`TEST_MODE == 0) begin
            timeout_cnt = 0;
            while (led !== 3'b100 && timeout_cnt < 200) begin
                @(negedge dut_d_clk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            if (timeout_cnt >= 200) begin
                $display("--------------------------------------------------");
                $display("[FAIL] Time: %0t", $time);
                $display("       [TIMEOUT] DUT Deadlocked");
                $display("--------------------------------------------------");
                $stop;
            end
        end

        $display("\n================ TEST COMPLETED ================\n");
        repeat(20) @(negedge dut_d_clk); 
        $finish;
    end

    // ================================================================
    // DUT Instantiation
    // ================================================================
    tenthirty inst_tenthirty (
        .clk      (clk),
        .rst_n    (rst_n),
        .btn_m    (btn_m),
        .btn_r    (btn_r),
        .switch   (sw),
        .seg7_sel (seg7_sel),
        .seg7     (seg7),
        .seg7_l   (seg7_l),
        .led      (led),
        .led_mode (led_mode)
    );

endmodule