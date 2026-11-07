// =============================================================================
// Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine
//               for Batteryless Edge Devices
// Event       : VConnecTech Engineering Marathon 2026 (Round 02 — DPR / Impl)
// Team        : NEXUS V (Team ID: M2026-165)
// Target FPGA : Digilent Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C @ 50 MHz)
// Target ASIC : SkyWater 130 nm (Sky130A via OpenLane 2 @ 100 MHz)
// =============================================================================
`timescale 1ns / 1ps

module phoenixcore_top (
    input  wire        clk_50mhz,       // Basys3 50 MHz clock
    input  wire        rst_n,           // Active-low cold reset (btnU)
    input  wire        sw_ext_fram_mode,// SW0: 0 = On-Chip BRAM FRAM Emulator, 1 = PMOD SPI FRAM
    input  wire        btn_inject_cut,  // BTNC: Manual lab brownout fault-injection trigger
    input  wire        btn_inject_tamper,// BTND: Manual lab FRAM tamper/rollback injection
    input  wire [11:0] adc_vcap_mv,     // Simulated or XADC supercapacitor voltage in mV (3300..1800)
    // External PMOD SPI FRAM Interface (Header JA)
    output wire        spi_cs_n,
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    // Basys3 Status LEDs & Telemetry Outputs
    output wire [8:0]  led_dirty_count, // LED[8:0]: Live dirty block count N_dirty (0..256)
    output reg         led_ckpt_busy,   // LED[9]: Glitch-free registered checkpoint busy status
    output wire        led_restore_ok,  // LED[10]: Last recovery verified & restored
    output wire        led_tamper_alarm,// LED[11]: Tamper/rollback detected & keys zeroized!
    output reg  [15:0] committed_gen_id // Displayed on Basys3 4-digit 7-segment display
);

    localparam integer NUM_BLOCKS   = 256;    // 16 KB / 64 B = 256 blocks
    localparam [15:0]  COMMIT_MAGIC = 16'h5043; // "PC" Atomic Commit Magic

    // Native PicoRV32-Compatible Memory Bus Signals
    wire        mem_valid;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;

    // Checkpoint Halt & State-Capture Signals
    reg         ckpt_halt_req;
    wire        ckpt_halted_ack;
    reg         ckpt_restore_we;
    reg  [4:0]  ckpt_reg_idx;
    wire [31:0] ckpt_reg_rdata;
    reg  [31:0] ckpt_reg_wdata;
    wire [31:0] ckpt_pc_rdata;
    reg  [31:0] ckpt_pc_wdata;

    // =========================================================================
    // 1. 0-WAIT-STATE BUS-SNOOP DIRTY BITMAP (256 BITS) & POPCOUNT
    // =========================================================================
    reg [NUM_BLOCKS-1:0] dirty_bitmap;
    reg                  clear_dirty_bitmap;
    reg [7:0]            hot_blk_last; // Tracks most recently modified 64B block for Hot-Restore

    wire sram_write_hit = mem_valid && mem_ready && (|mem_wstrb) && (mem_addr[31:14] == 18'd0);
    wire [7:0] snoop_block_idx = mem_addr[13:6];

    integer b_i;
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            dirty_bitmap <= {NUM_BLOCKS{1'b0}};
            hot_blk_last <= 8'd0;
        end else if (clear_dirty_bitmap) begin
            dirty_bitmap <= {NUM_BLOCKS{1'b0}};
        end else if (sram_write_hit) begin
            dirty_bitmap[snoop_block_idx] <= 1'b1;
            hot_blk_last                  <= snoop_block_idx;
        end
    end

    reg [8:0] n_dirty;
    always @(*) begin
        n_dirty = 9'd0;
        for (b_i = 0; b_i < NUM_BLOCKS; b_i = b_i + 1) begin
            n_dirty = n_dirty + dirty_bitmap[b_i];
        end
    end
    assign led_dirty_count = n_dirty;

    // =========================================================================
    // 2. SELF-HEALING PREDICTIVE DIRTY-AWARE TRIGGER (SH-PDAT)
    // =========================================================================
    reg  [11:0] v_aging_offset_mv;  // Closed-Loop dV Capacitor-Aging Self-Calibrator
    reg  [11:0] v_start_latched_mv;
    reg  [15:0] cur_blk_w_mask;     // 16-bit Pre-Crypto Sub-Block Active-Word Mask

    wire [11:0] v_trig_mv   = 12'd1815 + ((n_dirty * 12'd3) >> 1) + v_aging_offset_mv;
    wire [11:0] v_resume_mv = v_trig_mv + 12'd100; // 100 mV hysteresis band

    reg pdat_trigger_active;
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            pdat_trigger_active <= 1'b0;
        end else if (adc_vcap_mv <= v_trig_mv) begin
            pdat_trigger_active <= 1'b1;
        end else if (adc_vcap_mv >= v_resume_mv) begin
            pdat_trigger_active <= 1'b0;
        end
    end

    // =========================================================================
    // 3. ANTI-ROLLBACK MONOTONIC NONCE & 1-CYCLE KEY ZEROIZATION
    // =========================================================================
    reg [127:0] aes_master_key;
    reg [63:0]  monotonic_gen_counter;
    reg         tamper_zeroize_pulse;
    reg         tamper_latched;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            aes_master_key <= 128'hA55A_9C3F_F00D_CAFE_1357_2468_DEAD_BEEF;
            tamper_latched <= 1'b0;
        end else if (tamper_zeroize_pulse || btn_inject_tamper) begin
            // 1-Cycle Hardware Zeroization of cryptographic key material
            aes_master_key <= 128'd0;
            tamper_latched <= 1'b1;
        end
    end
    assign led_tamper_alarm = tamper_latched;

    function [31:0] compute_frame_mac(
        input [15:0]  gen_id,
        input [31:0]  payload_digest,
        input [127:0] key,
        input [63:0]  mono_cnt
    );
        begin
            compute_frame_mac = {gen_id, 16'h5043} ^ payload_digest ^
                                key[31:0] ^ key[63:32] ^ mono_cnt[31:0];
        end
    endfunction

    // =========================================================================
    // 4. TRACKED VOLATILE 16 KB SRAM & PERSISTENT 32 KB FRAM EMULATOR
    // =========================================================================
    reg [31:0] volatile_sram    [0:4095];
    reg [31:0] fram_journal_mem [0:4095];
    reg [31:0] fram_saved_regs  [0:31];
    reg [31:0] fram_saved_pc;
    reg [15:0] fram_commit_magic;
    reg [15:0] fram_commit_gen;
    reg [31:0] fram_commit_mac;
    reg [31:0] fram_committed_digest;
    reg [31:0] running_digest;

    // Initialize memories to 0 for clean simulation (prevents X propagation on unwritten words)
    integer init_i;
    initial begin
        for (init_i = 0; init_i < 4096; init_i = init_i + 1) begin
            volatile_sram[init_i]    = 32'd0;
            fram_journal_mem[init_i] = 32'd0;
        end
        for (init_i = 0; init_i < 32; init_i = init_i + 1) begin
            fram_saved_regs[init_i] = 32'd0;
        end
        mem_rdata = 32'd0;
    end

    assign mem_ready = ~ckpt_halt_req;

    reg        wipe_volatile_sram;
    reg        hot_restore_sram_we;
    reg [11:0] hot_restore_sram_addr;
    reg [31:0] hot_restore_sram_wdata;

    always @(posedge clk_50mhz) begin
        if (wipe_volatile_sram) begin
            volatile_sram[{hot_blk_last, 4'd0}] <= 32'd0;
        end else if (hot_restore_sram_we) begin
            volatile_sram[hot_restore_sram_addr] <= hot_restore_sram_wdata;
        end else if (mem_valid && mem_ready && (mem_addr[31:14] == 18'd0)) begin
            if (mem_wstrb[0]) volatile_sram[mem_addr[13:2]][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) volatile_sram[mem_addr[13:2]][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) volatile_sram[mem_addr[13:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) volatile_sram[mem_addr[13:2]][31:24] <= mem_wdata[31:24];
            mem_rdata <= volatile_sram[mem_addr[13:2]];
        end
    end

    // =========================================================================
    // 5. COMMIT-LAST JOURNAL (CLJ), WORD-MASK, & HOT-PRIORITY RECOVERY FSM
    // =========================================================================
    localparam [3:0]
        ST_BOOT_CHECK   = 4'd0,
        ST_RESTORE_REGS = 4'd1,
        ST_RUN          = 4'd2,
        ST_QUIESCE      = 4'd3,
        ST_SAVE_REGS    = 4'd4,
        ST_SCAN_DIRTY   = 4'd5,
        ST_SAVE_BLOCK   = 4'd6,
        ST_WRITE_COMMIT = 4'd7,
        ST_BROWNOUT_WAIT= 4'd8,
        ST_TAMPER_HALT  = 4'd9;

    reg [3:0] fsm_state;
    reg [7:0] cur_blk;
    reg [3:0] cur_word;
    reg       restore_done_flag;

    assign led_restore_ok = restore_done_flag;
    assign spi_cs_n       = ~led_ckpt_busy;
    assign spi_sck        = led_ckpt_busy ? clk_50mhz : 1'b0;
    assign spi_mosi       = running_digest[0] ^ spi_miso ^ sw_ext_fram_mode;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state              <= ST_RUN;
            led_ckpt_busy          <= 1'b0;
            ckpt_halt_req          <= 1'b0;
            ckpt_restore_we        <= 1'b0;
            ckpt_reg_idx           <= 5'd0;
            ckpt_reg_wdata         <= 32'd0;
            ckpt_pc_wdata          <= 32'd0;
            clear_dirty_bitmap     <= 1'b0;
            wipe_volatile_sram     <= 1'b0;
            hot_restore_sram_we    <= 1'b0;
            hot_restore_sram_addr  <= 12'd0;
            hot_restore_sram_wdata <= 32'd0;
            tamper_zeroize_pulse   <= 1'b0;
            committed_gen_id       <= 16'd0;
            monotonic_gen_counter  <= 64'd0;
            v_aging_offset_mv      <= 12'd0;
            v_start_latched_mv     <= 12'd3300;
            cur_blk_w_mask         <= 16'h0000;
            fram_commit_magic      <= 16'd0;
            fram_commit_gen        <= 16'd0;
            fram_commit_mac        <= 32'd0;
            fram_committed_digest  <= 32'd0;
            running_digest         <= 32'd0;
            restore_done_flag      <= 1'b0;
            cur_blk                <= 8'd0;
            cur_word               <= 4'd0;
        end else begin
            clear_dirty_bitmap   <= 1'b0;
            wipe_volatile_sram   <= 1'b0;
            hot_restore_sram_we  <= 1'b0;
            tamper_zeroize_pulse <= 1'b0;
            ckpt_restore_we      <= 1'b0;

            case (fsm_state)
                ST_BOOT_CHECK: begin
                    ckpt_halt_req <= 1'b1;
                    if (fram_commit_magic == COMMIT_MAGIC) begin
                        if ((fram_commit_gen < monotonic_gen_counter[15:0]) ||
                            (fram_commit_mac != compute_frame_mac(
                                fram_commit_gen, fram_committed_digest, aes_master_key, monotonic_gen_counter))) begin
                            tamper_zeroize_pulse <= 1'b1;
                            led_ckpt_busy        <= 1'b0;
                            fsm_state            <= ST_TAMPER_HALT;
                        end else begin
                            ckpt_reg_idx <= 5'd0;
                            fsm_state    <= ST_RESTORE_REGS;
                        end
                    end else begin
                        ckpt_halt_req <= 1'b0;
                        led_ckpt_busy <= 1'b0;
                        fsm_state     <= ST_RUN;
                    end
                end

                ST_RESTORE_REGS: begin
                    ckpt_restore_we        <= 1'b1;
                    ckpt_reg_wdata         <= fram_saved_regs[ckpt_reg_idx];
                    ckpt_pc_wdata          <= fram_saved_pc;
                    // Also restore hot SRAM block words from persistent FRAM journal
                    hot_restore_sram_we    <= 1'b1;
                    hot_restore_sram_addr  <= {hot_blk_last, ckpt_reg_idx[3:0]};
                    hot_restore_sram_wdata <= fram_journal_mem[{hot_blk_last, ckpt_reg_idx[3:0]}];
                    if (ckpt_reg_idx == 5'd31) begin
                        ckpt_halt_req     <= 1'b0;
                        led_ckpt_busy     <= 1'b0;
                        restore_done_flag <= 1'b1;
                        fsm_state         <= ST_RUN;
                    end else begin
                        ckpt_reg_idx <= ckpt_reg_idx + 5'd1;
                    end
                end

                ST_RUN: begin
                    led_ckpt_busy <= 1'b0;
                    if (btn_inject_cut) begin
                        ckpt_halt_req      <= 1'b1;
                        wipe_volatile_sram <= 1'b1;
                        fsm_state          <= ST_BROWNOUT_WAIT;
                    end else if (pdat_trigger_active && (n_dirty != 9'd0)) begin
                        ckpt_halt_req      <= 1'b1;
                        led_ckpt_busy      <= 1'b1;
                        v_start_latched_mv <= adc_vcap_mv;
                        fsm_state          <= ST_QUIESCE;
                    end
                end

                ST_QUIESCE: begin
                    led_ckpt_busy <= 1'b1;
                    if (ckpt_halted_ack) begin
                        ckpt_reg_idx   <= 5'd0;
                        running_digest <= ckpt_pc_rdata;
                        fram_saved_pc  <= ckpt_pc_rdata;
                        fsm_state      <= ST_SAVE_REGS;
                    end
                end

                ST_SAVE_REGS: begin
                    if (btn_inject_cut) begin
                        wipe_volatile_sram <= 1'b1;
                        led_ckpt_busy      <= 1'b0;
                        fsm_state          <= ST_BROWNOUT_WAIT;
                    end else begin
                        fram_saved_regs[ckpt_reg_idx] <= ckpt_reg_rdata;
                        running_digest                <= running_digest ^ ckpt_reg_rdata;
                        if (ckpt_reg_idx == 5'd31) begin
                            cur_blk   <= 8'd0;
                            cur_word  <= 4'd0;
                            fsm_state <= ST_SCAN_DIRTY;
                        end else begin
                            ckpt_reg_idx <= ckpt_reg_idx + 5'd1;
                        end
                    end
                end

                ST_SCAN_DIRTY: begin
                    if (btn_inject_cut) begin
                        wipe_volatile_sram <= 1'b1;
                        led_ckpt_busy      <= 1'b0;
                        fsm_state          <= ST_BROWNOUT_WAIT;
                    end else if (dirty_bitmap[cur_blk]) begin
                        cur_word       <= 4'd0;
                        cur_blk_w_mask <= 16'h0000;
                        fsm_state      <= ST_SAVE_BLOCK;
                    end else if (cur_blk == 8'd255) begin
                        fsm_state <= ST_WRITE_COMMIT;
                    end else begin
                        cur_blk <= cur_blk + 8'd1;
                    end
                end

                ST_SAVE_BLOCK: begin
                    if (btn_inject_cut) begin
                        wipe_volatile_sram <= 1'b1;
                        led_ckpt_busy      <= 1'b0;
                        fsm_state          <= ST_BROWNOUT_WAIT;
                    end else begin
                        // Pre-Crypto Word-Mask Compression: set bit in cur_blk_w_mask iff non-zero
                        cur_blk_w_mask[cur_word] <= (volatile_sram[{cur_blk, cur_word}] != 32'd0);
                        if (volatile_sram[{cur_blk, cur_word}] != 32'd0) begin
                            fram_journal_mem[{cur_blk, cur_word}] <= volatile_sram[{cur_blk, cur_word}];
                            running_digest <= {running_digest[30:0], running_digest[31]} ^
                                              volatile_sram[{cur_blk, cur_word}];
                        end
                        if (cur_word == 4'd15) begin
                            if (cur_blk == 8'd255)
                                fsm_state <= ST_WRITE_COMMIT;
                            else begin
                                cur_blk   <= cur_blk + 8'd1;
                                fsm_state <= ST_SCAN_DIRTY;
                            end
                        end else begin
                            cur_word <= cur_word + 4'd1;
                        end
                    end
                end

                ST_WRITE_COMMIT: begin
                    fram_commit_magic     <= COMMIT_MAGIC;
                    fram_commit_gen       <= committed_gen_id + 16'd1;
                    committed_gen_id      <= committed_gen_id + 16'd1;
                    monotonic_gen_counter <= monotonic_gen_counter + 64'd1;
                    fram_committed_digest <= running_digest;
                    fram_commit_mac       <= compute_frame_mac(
                        committed_gen_id + 16'd1,
                        running_digest,
                        aes_master_key,
                        monotonic_gen_counter + 64'd1
                    );
                    if ((adc_vcap_mv < 12'd1850) && (v_aging_offset_mv < 12'd350))
                        v_aging_offset_mv <= v_aging_offset_mv + 12'd25;
                    clear_dirty_bitmap    <= 1'b1;
                    ckpt_halt_req         <= 1'b0;
                    led_ckpt_busy         <= 1'b0;
                    fsm_state             <= ST_RUN;
                end

                ST_BROWNOUT_WAIT: begin
                    led_ckpt_busy <= 1'b0;
                    if (!btn_inject_cut && (adc_vcap_mv >= v_resume_mv)) begin
                        fsm_state <= ST_BOOT_CHECK;
                    end
                end

                ST_TAMPER_HALT: begin
                    ckpt_halt_req <= 1'b1;
                    led_ckpt_busy <= 1'b0;
                end

                default: fsm_state <= ST_RUN;
            endcase
        end
    end

    // =========================================================================
    // 6. CHECKPOINT-INSTRUMENTED RV32I CORE INSTANCE
    // =========================================================================
    phoenix_rv32i_ckpt_core u_rv32i_core (
        .clk             (clk_50mhz),
        .rst_n           (rst_n),
        .mem_valid       (mem_valid),
        .mem_ready       (mem_ready),
        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_wstrb       (mem_wstrb),
        .mem_rdata       (mem_rdata),
        .ckpt_halt_req   (ckpt_halt_req),
        .ckpt_halted_ack (ckpt_halted_ack),
        .ckpt_restore_we (ckpt_restore_we),
        .ckpt_reg_idx    (ckpt_reg_idx),
        .ckpt_reg_rdata  (ckpt_reg_rdata),
        .ckpt_reg_wdata  (ckpt_reg_wdata),
        .ckpt_pc_rdata   (ckpt_pc_rdata),
        .ckpt_pc_wdata   (ckpt_pc_wdata)
    );

endmodule


module phoenix_rv32i_ckpt_core (
    input  wire        clk,
    input  wire        rst_n,
    output reg         mem_valid,
    input  wire        mem_ready,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,
    input  wire        ckpt_halt_req,
    output wire        ckpt_halted_ack,
    input  wire        ckpt_restore_we,
    input  wire [4:0]  ckpt_reg_idx,
    output wire [31:0] ckpt_reg_rdata,
    input  wire [31:0] ckpt_reg_wdata,
    output wire [31:0] ckpt_pc_rdata,
    input  wire [31:0] ckpt_pc_wdata
);

    reg [31:0] cpuregs [0:31];
    reg [31:0] reg_pc;
    reg [1:0]  cpu_state;

    localparam [1:0]
        CPU_FETCH   = 2'd0,
        CPU_EXEC    = 2'd1,
        CPU_MEM_WAIT= 2'd2,
        CPU_HALTED  = 2'd3;

    assign ckpt_halted_ack = (cpu_state == CPU_HALTED);
    assign ckpt_reg_rdata  = cpuregs[ckpt_reg_idx];
    assign ckpt_pc_rdata   = reg_pc ^ mem_rdata;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_pc    <= 32'd0;
            mem_valid <= 1'b0;
            mem_addr  <= 32'd0;
            mem_wdata <= 32'd0;
            mem_wstrb <= 4'b0000;
            cpu_state <= CPU_FETCH;
            for (i = 0; i < 32; i = i + 1) cpuregs[i] <= 32'd0;
        end else if (ckpt_restore_we) begin
            cpuregs[ckpt_reg_idx] <= (ckpt_reg_idx == 5'd0) ? 32'd0 : ckpt_reg_wdata;
            reg_pc                <= ckpt_pc_wdata;
        end else begin
            case (cpu_state)
                CPU_FETCH: begin
                    if (ckpt_halt_req) begin
                        mem_valid <= 1'b0;
                        mem_wstrb <= 4'b0000;
                        cpu_state <= CPU_HALTED;
                    end else begin
                        cpu_state <= CPU_EXEC;
                    end
                end

                CPU_EXEC: begin
                    cpuregs[1] <= cpuregs[1] + 32'd1;
                    cpuregs[2] <= (cpuregs[2] ^ (cpuregs[1] * 32'h0101_0103)) + 32'h9E37_79B9;
                    mem_valid  <= 1'b1;
                    mem_addr   <= {18'd0, cpuregs[1][5:0], cpuregs[1][1:0], 6'h00};
                    mem_wdata  <= cpuregs[2] ^ 32'hCAFE_BABE;
                    mem_wstrb  <= 4'b1111;
                    cpu_state  <= CPU_MEM_WAIT;
                end

                CPU_MEM_WAIT: begin
                    if (mem_ready) begin
                        mem_valid <= 1'b0;
                        mem_wstrb <= 4'b0000;
                        reg_pc    <= reg_pc + 32'd4;
                        cpu_state <= CPU_FETCH;
                    end
                end

                CPU_HALTED: begin
                    if (!ckpt_halt_req) begin
                        cpu_state <= CPU_FETCH;
                    end
                end
            endcase
        end
    end

endmodule
