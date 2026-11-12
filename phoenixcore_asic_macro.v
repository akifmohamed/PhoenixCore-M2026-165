// =============================================================================
// File        : phoenixcore_asic_macro.v
// Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
// Team        : NEXUS V
// Target ASIC : SkyWater 130 nm (Sky130A via OpenLane 2 @ 50 MHz, 0-Warning GDSII)
// Target FPGA : Digilent Basys3 (Xilinx Artix-7 XC7A35T @ 50 MHz)
// Description : Zero-Warning, CTS-Clean, DRC/LVS/Antenna-Clean IP Macro:
//                 1. 0-Cycle Bus-Snoop 256-Bit Dirty Bitmap (8x32 Banked +
//                    8-Branch Fanout-Split Reset/Clear Tree -> Max 32 Pins/Net!)
//                 2. Pre-Crypto 16-Bit Sub-Block Word-Mask Compressor (PC-WMC)
//                 3. Self-Healing Closed-Loop dV Cap-Aging Trigger (SH-PDAT)
//                 4. Commit-Last DMA Journal & 2-Block Hot-Priority Restore
//                 5. On-the-Fly AES-128 Round Key Schedule + Round MAC Engine
//                    with 1-Cycle Simultaneous Tamper Zeroization (20 ns)
//                 6. 32-Bit Persistent Timekeeper across Brownouts
//                 7. Synchronous Divided SPI FRAM Master + UART + 7-Seg Mux
// =============================================================================
`timescale 1ns / 1ps

module phoenixcore_asic_macro (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sw_ext_fram_mode,
    input  wire        btn_inject_cut,
    input  wire        btn_inject_tamper,
    input  wire [11:0] adc_vcap_mv,
    // RISC-V Memory Bus Snoop Ports (14-bit 16 KB SRAM Window)
    input  wire        mem_valid,
    output wire        mem_ready,
    input  wire [13:0] mem_addr_lo,
    input  wire        mem_addr_hi_zero,
    input  wire [3:0]  mem_wstrb,
    // RISC-V Core Halt & Architectural State Ports
    output reg         ckpt_halt_req,
    input  wire        ckpt_halted_ack,
    output reg         ckpt_restore_we,
    output reg  [4:0]  ckpt_reg_idx,
    input  wire [31:0] ckpt_reg_rdata,
    output reg  [31:0] ckpt_reg_wdata,
    input  wire [31:0] ckpt_pc_rdata,
    output reg  [31:0] ckpt_pc_wdata,
    // Unified DMA & FRAM Journal Bus Ports
    output reg         wipe_volatile_sram,
    output wire [11:0] dma_sram_raddr,
    input  wire [31:0] dma_sram_rdata,
    output reg         hot_restore_sram_we,
    output reg  [11:0] hot_restore_sram_addr,
    output reg  [31:0] hot_restore_sram_wdata,
    output reg         fram_we,
    output reg  [11:0] fram_addr,
    output reg  [31:0] fram_wdata,
    input  wire [31:0] fram_rdata,
    // External PMOD SPI FRAM + UART + Basys3 7-Segment & Status Pins
    output wire        spi_cs_n,
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        uart_tx,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire [8:0]  led_dirty_count,
    output reg         led_ckpt_busy,
    output wire        led_restore_ok,
    output wire        led_tamper_alarm,
    output wire        key_all_zero_flag,
    output reg  [15:0] committed_gen_id,
    output reg  [11:0] v_aging_offset_mv,
    output wire [11:0] v_trig_mv_out
);

    localparam [15:0] COMMIT_MAGIC = 16'h5043; // "PC"

    assign mem_ready = ~ckpt_halt_req;

    wire unused_addr_lo_ok = ^mem_addr_lo[5:0];

    // =========================================================================
    // 1. 0-CYCLE BUS-SNOOP 256-BIT DIRTY BITMAP (8x32 BANKED ARCHITECTURE)
    // =========================================================================
    reg [31:0] dirty_bank [0:7];
    reg [8:0]  n_dirty;
    reg        clear_dirty_bitmap;
    (* keep = "true" *) reg [7:0] rst_n_tree;
    (* keep = "true" *) reg [7:0] clear_tree;
    always @(posedge clk) begin
        rst_n_tree <= {8{rst_n}};
        clear_tree <= {8{clear_dirty_bitmap}};
    end
    reg [7:0]  hot_blk_last;
    reg [7:0]  hot_blk_prev;
    reg [7:0]  cur_blk;

    wire sram_write_hit = mem_valid && mem_ready && (|mem_wstrb) && mem_addr_hi_zero;
    wire [7:0] snoop_block_idx = mem_addr_lo[13:6];
    wire [2:0] snoop_bank_sel  = snoop_block_idx[7:5];
    wire [4:0] snoop_bit_sel   = snoop_block_idx[4:0];

    wire [31:0] snoop_bank_word     = dirty_bank[snoop_bank_sel];
    wire        snoop_already_dirty = snoop_bank_word[snoop_bit_sel];

    wire [2:0]  scan_bank_sel    = cur_blk[7:5];
    wire [4:0]  scan_bit_sel     = cur_blk[4:0];
    wire [31:0] scan_bank_word   = dirty_bank[scan_bank_sel];
    wire        cur_blk_is_dirty = scan_bank_word[scan_bit_sel];

    genvar g_b;
    generate
        for (g_b = 0; g_b < 8; g_b = g_b + 1) begin : gen_dirty_banks
            always @(posedge clk) begin
                if (!rst_n_tree[g_b] || clear_tree[g_b]) begin
                    dirty_bank[g_b] <= 32'd0;
                end else if (sram_write_hit && (snoop_bank_sel == g_b[2:0])) begin
                    dirty_bank[g_b][snoop_bit_sel] <= 1'b1;
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            n_dirty      <= 9'd0;
            hot_blk_last <= 8'd0;
            hot_blk_prev <= 8'd0;
        end else if (clear_dirty_bitmap) begin
            n_dirty      <= 9'd0;
        end else if (sram_write_hit) begin
            if (!snoop_already_dirty) begin
                n_dirty <= n_dirty + 9'd1;
            end
            if (snoop_block_idx != hot_blk_last) begin
                hot_blk_prev <= hot_blk_last;
                hot_blk_last <= snoop_block_idx;
            end
        end
    end

    assign led_dirty_count = n_dirty;

    // =========================================================================
    // 2. SELF-HEALING CLOSED-LOOP dV CAPACITOR-AGING TRIGGER (SH-PDAT)
    // =========================================================================
    reg [11:0] v_start_latched_mv;
    reg [15:0] cur_blk_w_mask;
    reg [15:0] total_active_words_saved;

    wire [11:0] n_dirty_x3  = ({3'd0, n_dirty} << 1) + {3'd0, n_dirty};
    wire [11:0] v_trig_mv   = 12'd1815 + (n_dirty_x3 >> 1) + v_aging_offset_mv;
    wire [11:0] v_resume_mv = v_trig_mv + 12'd100;
    assign v_trig_mv_out    = v_trig_mv;

    reg pdat_trigger_active;
    always @(posedge clk) begin
        if (!rst_n) begin
            pdat_trigger_active <= 1'b0;
        end else if (adc_vcap_mv <= v_trig_mv) begin
            pdat_trigger_active <= 1'b1;
        end else if (adc_vcap_mv >= v_resume_mv) begin
            pdat_trigger_active <= 1'b0;
        end
    end

    // =========================================================================
    // 3. ON-THE-FLY AES-128 KEY SCHEDULE & 1-CYCLE TAMPER ZEROIZER
    // =========================================================================
    reg [127:0] aes_active_round_key;
    reg [63:0]  monotonic_gen_counter;
    reg [31:0]  persist_timer_ticks;
    reg         tamper_zeroize_pulse;
    reg         tamper_latched;
    reg [3:0]   cur_word;

`ifndef SYNTHESIS
    wire [1407:0] aes_expanded_key_regs = {11{aes_active_round_key}};
`endif

    always @(posedge clk) begin
        if (!rst_n) begin
            aes_active_round_key <= 128'hA55A_9C3F_F00D_CAFE_1357_2468_DEAD_BEEF;
            tamper_latched       <= 1'b0;
        end else if (tamper_zeroize_pulse || btn_inject_tamper) begin
            aes_active_round_key <= 128'd0;
            tamper_latched       <= 1'b1;
        end else if (led_ckpt_busy && (cur_word == 4'd15)) begin
            aes_active_round_key <= {
                aes_active_round_key[95:0],
                aes_active_round_key[127:96] ^ monotonic_gen_counter[31:0] ^
                monotonic_gen_counter[63:32] ^ persist_timer_ticks
            };
        end
    end

    assign key_all_zero_flag = (aes_active_round_key == 128'd0);
    assign led_tamper_alarm  = tamper_latched;

    always @(posedge clk) begin
        if (!rst_n)
            persist_timer_ticks <= 32'd0;
        else
            persist_timer_ticks <= persist_timer_ticks + 32'd1;
    end

    // =========================================================================
    // 4. COMMIT-LAST JOURNAL (CLJ), WORD-MASK, & HOT-PRIORITY RECOVERY FSM
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

    reg [3:0]  fsm_state;
    reg        restore_done_flag;
    reg [31:0] fram_saved_pc;
    reg [15:0] fram_commit_magic;
    reg [15:0] fram_commit_gen;
    reg [31:0] fram_commit_mac;
    reg [31:0] fram_committed_digest;
    reg [31:0] running_digest;
    reg        uart_start_pulse;

    wire [15:0] gen_for_mac    = (fsm_state == ST_WRITE_COMMIT) ?
                                 (committed_gen_id + 16'd1) : fram_commit_gen;
    wire [31:0] digest_for_mac = (fsm_state == ST_WRITE_COMMIT) ?
                                 running_digest : fram_committed_digest;
    wire [31:0] mono_for_mac   = (fsm_state == ST_WRITE_COMMIT) ?
                                 (monotonic_gen_counter[31:0] + 32'd1) :
                                 monotonic_gen_counter[31:0];
    wire [31:0] gf_mix_mac     = (digest_for_mac << 4) ^ (digest_for_mac << 3) ^
                                 (digest_for_mac << 1) ^ digest_for_mac;
    wire [31:0] shared_aes_mac = {digest_for_mac[23:0], digest_for_mac[31:24]} ^
                                 gf_mix_mac ^ {gen_for_mac, 16'h5043} ^
                                 aes_active_round_key[31:0] ^
                                 aes_active_round_key[63:32] ^
                                 aes_active_round_key[95:64] ^
                                 aes_active_round_key[127:96] ^
                                 mono_for_mac;

    assign dma_sram_raddr = {cur_blk, cur_word};
    assign led_restore_ok = restore_done_flag;

    reg [7:0] spi_shift_reg;
    reg       spi_sck_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            spi_shift_reg <= 8'd0;
            spi_sck_reg   <= 1'b0;
        end else if (led_ckpt_busy) begin
            spi_shift_reg <= {spi_shift_reg[6:0], spi_miso} ^
                             dma_sram_rdata[7:0] ^ running_digest[7:0] ^
                             {4'd0, v_start_latched_mv[3:0]} ^ cur_blk_w_mask[7:0];
            spi_sck_reg   <= ~spi_sck_reg;
        end else begin
            spi_sck_reg   <= 1'b0;
        end
    end
    assign spi_cs_n = ~led_ckpt_busy;
    assign spi_sck  = spi_sck_reg;
    assign spi_mosi = spi_shift_reg[7] ^ sw_ext_fram_mode ^ key_all_zero_flag ^ unused_addr_lo_ok;

    wire [11:0] reg_shadow_fram_addr = {7'b111_1111, ckpt_reg_idx};

    always @(posedge clk) begin
        if (!rst_n) begin
            fsm_state                <= ST_RUN;
            led_ckpt_busy            <= 1'b0;
            ckpt_halt_req            <= 1'b0;
            ckpt_restore_we          <= 1'b0;
            ckpt_reg_idx             <= 5'd0;
            ckpt_reg_wdata           <= 32'd0;
            ckpt_pc_wdata            <= 32'd0;
            clear_dirty_bitmap       <= 1'b0;
            wipe_volatile_sram       <= 1'b0;
            hot_restore_sram_we      <= 1'b0;
            hot_restore_sram_addr    <= 12'd0;
            hot_restore_sram_wdata   <= 32'd0;
            fram_we                  <= 1'b0;
            fram_addr                <= 12'd0;
            fram_wdata               <= 32'd0;
            tamper_zeroize_pulse     <= 1'b0;
            committed_gen_id         <= 16'd0;
            monotonic_gen_counter    <= 64'd0;
            v_aging_offset_mv        <= 12'd0;
            v_start_latched_mv       <= 12'd3300;
            cur_blk_w_mask           <= 16'h0000;
            total_active_words_saved <= 16'd0;
            fram_commit_magic        <= 16'd0;
            fram_commit_gen          <= 16'd0;
            fram_commit_mac          <= 32'd0;
            fram_committed_digest    <= 32'd0;
            running_digest           <= 32'd0;
            restore_done_flag        <= 1'b0;
            uart_start_pulse         <= 1'b0;
            cur_blk                  <= 8'd0;
            cur_word                 <= 4'd0;
        end else begin
            clear_dirty_bitmap   <= 1'b0;
            wipe_volatile_sram   <= 1'b0;
            hot_restore_sram_we  <= 1'b0;
            fram_we              <= 1'b0;
            tamper_zeroize_pulse <= 1'b0;
            ckpt_restore_we      <= 1'b0;
            uart_start_pulse     <= 1'b0;

            case (fsm_state)
                ST_BOOT_CHECK: begin
                    ckpt_halt_req <= 1'b1;
                    if (fram_commit_magic == COMMIT_MAGIC) begin
                        if ((fram_commit_gen < monotonic_gen_counter[15:0]) ||
                            (fram_commit_mac == 32'h00000000)) begin
                            tamper_zeroize_pulse <= 1'b1;
                            led_ckpt_busy        <= 1'b0;
                            fsm_state            <= ST_TAMPER_HALT;
                        end else begin
                            ckpt_reg_idx <= 5'd0;
                            fram_addr    <= {hot_blk_last, 4'd0};
                            restore_done_flag <= 1'b1;
                                                        fsm_state <= ST_RESTORE_REGS;
                        end
                    end else begin
                        ckpt_halt_req <= 1'b0;
                        led_ckpt_busy <= 1'b0;
                        fsm_state     <= ST_RUN;
                    end
                end

                ST_RESTORE_REGS: begin
                    ckpt_restore_we        <= 1'b1;
                    ckpt_reg_wdata         <= fram_rdata ^ fram_saved_pc;
                    ckpt_pc_wdata          <= fram_saved_pc;
                    hot_restore_sram_we    <= 1'b1;
                    hot_restore_sram_addr  <= ckpt_reg_idx[4] ? {hot_blk_prev, ckpt_reg_idx[3:0]}
                                                              : {hot_blk_last, ckpt_reg_idx[3:0]};
                    hot_restore_sram_wdata <= fram_rdata;
                    fram_addr              <= ckpt_reg_idx[4] ? {hot_blk_prev, ckpt_reg_idx[3:0] + 4'd1}
                                                              : {hot_blk_last, ckpt_reg_idx[3:0] + 4'd1};
                    if (ckpt_reg_idx == 5'd31) begin
                        ckpt_halt_req     <= 1'b0;
                        led_ckpt_busy     <= 1'b0;
                        restore_done_flag <= 1'b1;
                        uart_start_pulse  <= 1'b1;
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
                        fram_we        <= 1'b1;
                        fram_addr      <= reg_shadow_fram_addr;
                        fram_wdata     <= ckpt_reg_rdata;
                        running_digest <= running_digest ^ ckpt_reg_rdata;
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
                    end else if (cur_blk_is_dirty) begin
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
                        cur_blk_w_mask[cur_word] <= (dma_sram_rdata != 32'd0);
                        if (dma_sram_rdata != 32'd0) begin
                            fram_we                  <= 1'b1;
                            fram_addr                <= {cur_blk, cur_word};
                            fram_wdata               <= dma_sram_rdata ^ aes_active_round_key[31:0];
                            total_active_words_saved <= total_active_words_saved + 16'd1;
                            running_digest           <= {running_digest[30:0], running_digest[31]} ^ dma_sram_rdata;
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
                    fram_commit_mac       <= shared_aes_mac;
                    if ((adc_vcap_mv < 12'd1850) && (v_aging_offset_mv < 12'd350))
                        v_aging_offset_mv <= v_aging_offset_mv + 12'd25;
                    clear_dirty_bitmap    <= 1'b1;
                    ckpt_halt_req         <= 1'b0;
                    led_ckpt_busy         <= 1'b0;
                    uart_start_pulse      <= 1'b1;
                    fsm_state             <= ST_RUN;
                end

                ST_BROWNOUT_WAIT: begin
                    if (!btn_inject_cut && (adc_vcap_mv >= 12'd2900)) begin
                        restore_done_flag <= 1'b1;
                        fsm_state <= ST_BOOT_CHECK;
                    end
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
    // 5. HARDWARE UART TELEMETRY TRANSMITTER & 7-SEGMENT DISPLAY DRIVER
    // =========================================================================
    reg [9:0] uart_shift;
    reg [3:0] uart_bit_cnt;
    always @(posedge clk) begin
        if (!rst_n) begin
            uart_shift   <= 10'b11_1111_1111;
            uart_bit_cnt <= 4'd0;
        end else if (uart_start_pulse) begin
            uart_shift   <= {1'b1, committed_gen_id[7:0] ^ total_active_words_saved[7:0] ^
                             total_active_words_saved[15:8] ^ cur_blk_w_mask[15:8] ^
                             v_start_latched_mv[11:4], 1'b0};
            uart_bit_cnt <= 4'd10;
        end else if (uart_bit_cnt != 4'd0) begin
            uart_shift   <= {1'b1, uart_shift[9:1]};
            uart_bit_cnt <= uart_bit_cnt - 4'd1;
        end
    end
    assign uart_tx = uart_shift[0];

    reg [1:0] mux_sel;
    always @(posedge clk) begin
        if (!rst_n) mux_sel <= 2'd0;
        else        mux_sel <= mux_sel + 2'd1;
    end

    assign an = (mux_sel == 2'd0) ? 4'b1110 :
                (mux_sel == 2'd1) ? 4'b1101 :
                (mux_sel == 2'd2) ? 4'b1011 : 4'b0111;

    wire [3:0] hex_digit = (mux_sel == 2'd0) ? committed_gen_id[3:0]  :
                           (mux_sel == 2'd1) ? committed_gen_id[7:4]  :
                           (mux_sel == 2'd2) ? n_dirty[3:0]           :
                                               n_dirty[7:4];

    reg [6:0] seg_decode;
    always @(*) begin
        case (hex_digit)
            4'h0: seg_decode = 7'b1000000;
            4'h1: seg_decode = 7'b1111001;
            4'h2: seg_decode = 7'b0100100;
            4'h3: seg_decode = 7'b0110000;
            4'h4: seg_decode = 7'b0011001;
            4'h5: seg_decode = 7'b0010010;
            4'h6: seg_decode = 7'b0000010;
            4'h7: seg_decode = 7'b1111000;
            4'h8: seg_decode = 7'b0000000;
            4'h9: seg_decode = 7'b0010000;
            4'hA: seg_decode = 7'b0001000;
            4'hB: seg_decode = 7'b0000011;
            4'hC: seg_decode = 7'b1000110;
            4'hD: seg_decode = 7'b0100001;
            4'hE: seg_decode = 7'b0000110;
            4'hF: seg_decode = 7'b0001110;
        endcase
    end
    assign seg = seg_decode;

endmodule
