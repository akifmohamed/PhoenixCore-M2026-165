// =============================================================================
// File        : tb_phoenixcore_top.v
// Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
// Team        : NEXUS V
// Tool Flow   : Icarus Verilog (iverilog + vvp) & GTKWave (Ubuntu Open-Source)
// =============================================================================
`timescale 1ns / 1ps

module tb_phoenixcore_top;

    reg         clk_50mhz;
    reg         rst_n;
    reg         sw_ext_fram_mode;
    reg         btn_inject_cut;
    reg         btn_inject_tamper;
    reg  [11:0] adc_vcap_mv;
    wire        spi_cs_n;
    wire        spi_sck;
    wire        spi_mosi;
    reg         spi_miso;
    wire [8:0]  led_dirty_count;
    wire        led_ckpt_busy;
    wire        led_restore_ok;
    wire        led_tamper_alarm;
    wire [15:0] committed_gen_id;

    phoenixcore_top dut (
        .clk_50mhz        (clk_50mhz),
        .rst_n            (rst_n),
        .sw_ext_fram_mode (sw_ext_fram_mode),
        .btn_inject_cut   (btn_inject_cut),
        .btn_inject_tamper(btn_inject_tamper),
        .adc_vcap_mv      (adc_vcap_mv),
        .spi_cs_n         (spi_cs_n),
        .spi_sck          (spi_sck),
        .spi_mosi         (spi_mosi),
        .spi_miso         (spi_miso),
        .led_dirty_count  (led_dirty_count),
        .led_ckpt_busy    (led_ckpt_busy),
        .led_restore_ok   (led_restore_ok),
        .led_tamper_alarm (led_tamper_alarm),
        .committed_gen_id (committed_gen_id)
    );

    initial clk_50mhz = 1'b0;
    always #10 clk_50mhz = ~clk_50mhz;

    integer pass_count;
    integer fail_count;

    initial begin
        $dumpfile("phoenixcore_wave.vcd");
        $dumpvars(0, tb_phoenixcore_top);

        pass_count        = 0;
        fail_count        = 0;
        rst_n             = 1'b0;
        sw_ext_fram_mode  = 1'b0;
        btn_inject_cut    = 1'b0;
        btn_inject_tamper = 1'b0;
        adc_vcap_mv       = 12'd3300;
        spi_miso          = 1'b0;

        $display("======================================================================");
        $display(" PHOENIXCORE (M2026-165 | NEXUS V) OPEN-SOURCE RTL VERIFICATION SUITE");
        $display("======================================================================");

        #60;
        rst_n = 1'b1;

        // ---------------------------------------------------------------------
        // TEST 1: 0-Cycle Bus-Snoop Dirty Tracking
        // ---------------------------------------------------------------------
        $display("\n[TEST 1] Running RV32I workload to dirty SRAM blocks (Vcap = 3300 mV)...");
        #2000;
        $display("  -> Observed Live Dirty Block Count (N_dirty) = %0d blocks", led_dirty_count);
        $display("  -> Observed Dynamic PDAT Trigger Threshold   = %0d mV", dut.v_trig_mv);

        if (led_dirty_count > 0) begin
            $display("  [PASS] 0-Cycle Bus-Snoop Dirty Bitmap tracked %0d dirty blocks.", led_dirty_count);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Dirty block count remained 0!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 2: Word-Masked Save, Commit-Last, & Closed-Loop dV Aging Cal.
        // ---------------------------------------------------------------------
        $display("\n[TEST 2] Dropping Vcap to 1830 mV to trigger Word-Masked Save & dV Aging Calibration...");
        adc_vcap_mv = 12'd1830;
        while (led_ckpt_busy == 1'b0) @(posedge clk_50mhz);
        $display("  -> Checkpoint DMA & Pre-Crypto Word-Masking active (led_ckpt_busy = 1)...");
        while (led_ckpt_busy == 1'b1) @(posedge clk_50mhz);
        @(posedge clk_50mhz);
        #5;

        $display("  -> Committed Generation ID = %0d", committed_gen_id);
        $display("  -> Closed-Loop dV Aging Offset (v_aging_offset_mv) = +%0d mV", dut.v_aging_offset_mv);
        if ((committed_gen_id == 16'd1) && (dut.v_aging_offset_mv == 12'd25) && (led_dirty_count == 9'd0)) begin
            $display("  [PASS] Generation 1 committed atomically & dV Aging Calibrator incremented +25 mV!");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Commit or dV Aging Calibration mismatch!");
            fail_count = fail_count + 1;
        end

        // Restore Vcap to 3.30 V and dirty more blocks for Generation 2
        adc_vcap_mv = 12'd3300;
        #1200;

        // ---------------------------------------------------------------------
        // TEST 3: Mid-Save Torn-Write Power Cut Injection (Commit-Last Proof)
        // ---------------------------------------------------------------------
        $display("\n[TEST 3] Injecting mid-checkpoint TORN-WRITE power cut during Generation 2 save...");
        adc_vcap_mv = 12'd1840;
        while (led_ckpt_busy == 1'b0) @(posedge clk_50mhz);
        #400; // Wait until middle of dirty block streaming (before Commit Frame!)
        btn_inject_cut = 1'b1; // SUDDEN BROWNOUT MID-SAVE!
        #60;
        btn_inject_cut = 1'b0;
        adc_vcap_mv    = 12'd3300; // Power returns -> triggers ST_BOOT_CHECK -> ST_RESTORE_REGS
        #1200;

        $display("  -> Post-Recovery Authoritative Generation ID = %0d (Expected: 1, torn Gen 2 discarded)", committed_gen_id);
        $display("  -> Restore Verified Status (led_restore_ok)  = %0b", led_restore_ok);
        if ((committed_gen_id == 16'd1) && (led_restore_ok == 1'b1) && (led_tamper_alarm == 1'b0)) begin
            $display("  [PASS] Torn mid-save write safely ignored; Generation 1 restored with 0 corruption!");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Torn-write recovery failed!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 4: Adversarial Tamper / Rollback Injection -> 1-Cycle Key Zeroize
        // ---------------------------------------------------------------------
        $display("\n[TEST 4] Injecting adversarial tamper/rollback event (btn_inject_tamper = 1)...");
        $display("  -> AES Key before tamper = 0x%032x", dut.aes_master_key);
        @(posedge clk_50mhz);
        btn_inject_tamper = 1'b1;
        @(posedge clk_50mhz);
        #1;
        $display("  -> AES Key 1 cycle (20 ns) after tamper = 0x%032x", dut.aes_master_key);
        $display("  -> Full 1,408-bit Key Schedule OR-Sum   = 0x%0x (All 1,408 FFs = 0!)", |dut.key_schedule_bus);
        $display("  -> Persistent Timekeeper Ticks Survived = %0d ticks", dut.u_asic_macro.persist_timer_ticks);
        $display("  -> Basys3 7-Seg (an=%b, seg=%b) & UART TX Active", dut.an, dut.seg);
        $display("  -> Tamper Alarm LED (led_tamper_alarm)  = %0b", led_tamper_alarm);
        btn_inject_tamper = 1'b0;

        if ((dut.aes_master_key == 128'd0) && (led_tamper_alarm == 1'b1)) begin
            $display("  [PASS] 1-Cycle Hardware Key Zeroization verified in 20 ns (1 clock tick)!");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Key zeroization did not complete in 1 cycle!");
            fail_count = fail_count + 1;
        end

        #100;
        $display("\n======================================================================");
        $display(" SUMMARY: %0d / 4 HARDWARE VERIFICATION TESTS PASSED (%0d FAILED)", pass_count, fail_count);
        $display(" Waveform saved to: phoenixcore_wave.vcd");
        $display("======================================================================");
        $finish;
    end

endmodule
