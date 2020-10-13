//-----------------------------------------------------------------
//                    SDRAM Controller (AXI4)
//                           V1.0
//                     Ultra-Embedded.com
//                     Copyright 2015-2019
//
//                 Email: admin@ultra-embedded.com
//
//                         License: GPL
// If you would like a version with a more permissive license for
// use in closed source commercial applications please contact me
// for details.
//-----------------------------------------------------------------
//
// This file is open source HDL; you can redistribute it and/or 
// modify it under the terms of the GNU General Public License as 
// published by the Free Software Foundation; either version 2 of 
// the License, or (at your option) any later version.
//
// This file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public 
// License along with this file; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
// USA
//-----------------------------------------------------------------

//-----------------------------------------------------------------
//                          Generated File
//-----------------------------------------------------------------

module sdram_axi_core
#(
    parameter DW                 = 32,
    parameter SDRAM_MHZ          = 50,
    parameter SDRAM_ROW_W        = 13,
    parameter SDRAM_BANK_W       = 2,
    parameter SDRAM_COL_W        = 9,
    parameter SDRAM_READ_LATENCY = 2
)
(
    // Reset & clock
    input                     rst_i,
    input                     clk_i,
    
    input          [DW/8-1:0] inport_wr_i,
    input                     inport_rd_i,
    input               [7:0] inport_len_i,
    input              [31:0] inport_addr_i,
    input            [DW-1:0] inport_write_data_i,
    output           [DW-1:0] inport_read_data_o,
    output                    inport_accept_o,
    output                    inport_ack_o,

    // SDRAM I/F
    output                    sdram_clk_o,
    output                    sdram_cke_o,
    output                    sdram_cs_o,
    output                    sdram_ras_o,
    output                    sdram_cas_o,
    output                    sdram_we_o,
    output         [DW/8-1:0] sdram_dqm_o,
    output  [SDRAM_ROW_W-1:0] sdram_addr_o,
    output [SDRAM_BANK_W-1:0] sdram_ba_o,
    input            [DW-1:0] sdram_data_input_i,
    output           [DW-1:0] sdram_data_output_o,
    output                    sdram_data_out_en_o
);



//-----------------------------------------------------------------
// Key Params
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// Defines / Local params
//-----------------------------------------------------------------
localparam SDRAM_DQM_W           = DW/8;
localparam SDRAM_DQM_LOG2_W      = $clog2(SDRAM_DQM_W);
localparam SDRAM_BANKS           = 1 << SDRAM_BANK_W;
localparam SDRAM_REFRESH_CNT     = 1 << SDRAM_ROW_W;
localparam SDRAM_START_DELAY     = 100000 / (1000 / SDRAM_MHZ); // 100uS
localparam SDRAM_REFRESH_CYCLES  = (64000 * SDRAM_MHZ) / SDRAM_REFRESH_CNT - 1;

localparam CMD_W             = 4;
localparam CMD_NOP           = 4'b0111;
localparam CMD_ACTIVE        = 4'b0011;
localparam CMD_READ          = 4'b0101;
localparam CMD_WRITE         = 4'b0100;
localparam CMD_TERMINATE     = 4'b0110;
localparam CMD_PRECHARGE     = 4'b0010;
localparam CMD_REFRESH       = 4'b0001;
localparam CMD_LOAD_MODE     = 4'b0000;

// Mode: BL1, CAS=2/3
localparam MODE_BL1          = 3'b000;
localparam MODE_BL2          = 3'b001;
localparam MODE_BL4          = 3'b010;
localparam MODE_BL8          = 3'b011;
localparam MODE_CLx          = (SDRAM_MHZ > 100) ? 3'b011 : 3'b010;
localparam MODE_REG          = {{SDRAM_ROW_W-10{1'b0}},1'b0,2'b00,MODE_CLx,1'b0,MODE_BL1};

// SM states
localparam STATE_W           = 3;
localparam STATE_INIT        = 3'd0;
localparam STATE_DELAY       = 3'd1;
localparam STATE_IDLE        = 3'd2;
localparam STATE_ACTIVATE    = 3'd3;
localparam STATE_READ        = 3'd4;
localparam STATE_WRITE       = 3'd5;
localparam STATE_PRECHARGE   = 3'd6;
localparam STATE_REFRESH     = 3'd7;

localparam AUTO_PRECHARGE    = 10;
localparam ALL_BANKS         = 10;

localparam SDRAM_DATA_W      = DW;

localparam CYCLE_TIME_NS     = 1000 / SDRAM_MHZ;

// SDRAM timing
localparam SDRAM_TRCD_CYCLES = (20 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
localparam SDRAM_TRP_CYCLES  = (20 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
localparam SDRAM_TRFC_CYCLES = (60 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;

//-----------------------------------------------------------------
// External Interface
//-----------------------------------------------------------------
wire [DW/8-1:0] ram_wr_w         = inport_wr_i;
wire            ram_rd_w         = inport_rd_i;
wire            ram_accept_w;

wire            ram_req_w        = |{ram_wr_w, ram_rd_w };

assign inport_ack_o       = ack_q;
assign inport_read_data_o = data_buffer_q;
assign inport_accept_o    = ram_accept_w;

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------

// Xilinx placement pragmas:
//synthesis attribute IOB of command_q is "TRUE"
//synthesis attribute IOB of addr_q is "TRUE"
//synthesis attribute IOB of dqm_q is "TRUE"
//synthesis attribute IOB of cke_q is "TRUE"
//synthesis attribute IOB of bank_q is "TRUE"
//synthesis attribute IOB of data_q is "TRUE"

reg         [CMD_W-1:0] command_q;
reg   [SDRAM_ROW_W-1:0] addr_q;
reg  [SDRAM_DATA_W-1:0] data_q;
reg                     data_rd_en_q;
reg   [SDRAM_DQM_W-1:0] dqm_q;
reg                     cke_q;
reg  [SDRAM_BANK_W-1:0] bank_q;

// Buffer half word during read and write commands
reg  [SDRAM_DATA_W-1:0] data_buffer_q;

reg                     refresh_q;

reg   [SDRAM_BANKS-1:0] row_open_q;
reg   [SDRAM_ROW_W-1:0] active_row_q [0:SDRAM_BANKS-1];

reg       [STATE_W-1:0] state_q;
reg       [STATE_W-1:0] next_state_r;
reg       [STATE_W-1:0] target_state_r;
reg       [STATE_W-1:0] target_state_q;
reg       [STATE_W-1:0] delay_state_q;

// Address bits :
// ==============
wire  [SDRAM_ROW_W-1:0] addr_col_w;
wire  [SDRAM_ROW_W-1:0] addr_row_w;
wire [SDRAM_BANK_W-1:0] addr_bank_w;
// +------------------+-------------------+------------------+-----------------------+
// | SDRAM_ROW_W bits | SDRAM_BANK_W bits | SDRAM_COL_W bits | SDRAM_DQM_LOG2_W bits |
// +------------------+-------------------+------------------+-----------------------+
assign addr_row_w  = inport_addr_i[SDRAM_DQM_LOG2_W + SDRAM_COL_W + SDRAM_BANK_W +: SDRAM_ROW_W];
assign addr_bank_w = inport_addr_i[SDRAM_DQM_LOG2_W + SDRAM_COL_W +: SDRAM_BANK_W];
assign addr_col_w  = inport_addr_i[SDRAM_DQM_LOG2_W +: SDRAM_ROW_W];

//-----------------------------------------------------------------
// SDRAM State Machine
//-----------------------------------------------------------------
always @ *
begin
    next_state_r   = state_q;
    target_state_r = target_state_q;

    case (state_q)
    //-----------------------------------------
    // STATE_INIT
    //-----------------------------------------
    STATE_INIT :
    begin
        if (refresh_q)
            next_state_r = STATE_IDLE;
    end
    //-----------------------------------------
    // STATE_IDLE
    //-----------------------------------------
    STATE_IDLE :
    begin
        // Pending refresh
        // Note: tRAS (open row time) cannot be exceeded due to periodic
        //        auto refreshes.
        if (refresh_q)
        begin
            // Close open rows, then refresh
            if (|row_open_q)
                next_state_r = STATE_PRECHARGE;
            else
                next_state_r = STATE_REFRESH;

            target_state_r = STATE_REFRESH;
        end
        // Access request
        else if (ram_req_w)
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w])
            begin
                if (!ram_rd_w)
                    next_state_r = STATE_WRITE;
                else
                    next_state_r = STATE_READ;
            end
            // Row miss, close row, open new row
            else if (row_open_q[addr_bank_w])
            begin
                next_state_r   = STATE_PRECHARGE;

                if (!ram_rd_w)
                    target_state_r = STATE_WRITE;
                else
                    target_state_r = STATE_READ;
            end
            // No open row, open row
            else
            begin
                next_state_r   = STATE_ACTIVATE;

                if (!ram_rd_w)
                    target_state_r = STATE_WRITE;
                else
                    target_state_r = STATE_READ;
            end
        end
    end
    //-----------------------------------------
    // STATE_ACTIVATE
    //-----------------------------------------
    STATE_ACTIVATE :
    begin
        // Proceed to read or write state
        next_state_r = target_state_r;
    end
    //-----------------------------------------
    // STATE_READ
    //-----------------------------------------
    STATE_READ :
    begin
        next_state_r = STATE_IDLE;

        // Another pending read request (with no refresh pending)
        if (!refresh_q && ram_req_w && ram_rd_w)
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w])
                next_state_r = STATE_READ;
        end
    end
    //-----------------------------------------
    // STATE_WRITE
    //-----------------------------------------
    STATE_WRITE :
    begin
        next_state_r = STATE_IDLE;

        // Another pending write request (with no refresh pending)
        if (!refresh_q & ram_req_w & (|ram_wr_w))
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w])
                next_state_r = STATE_WRITE;
        end
    end
    //-----------------------------------------
    // STATE_PRECHARGE
    //-----------------------------------------
    STATE_PRECHARGE :
    begin
        // Closing row to perform refresh
        if (target_state_r == STATE_REFRESH)
            next_state_r = STATE_REFRESH;
        // Must be closing row to open another
        else
            next_state_r = STATE_ACTIVATE;
    end
    //-----------------------------------------
    // STATE_REFRESH
    //-----------------------------------------
    STATE_REFRESH :
    begin
        next_state_r = STATE_IDLE;
    end
    //-----------------------------------------
    // STATE_DELAY
    //-----------------------------------------
    STATE_DELAY :
    begin
        next_state_r = delay_state_q;
    end
    default:
        ;
   endcase
end

//-----------------------------------------------------------------
// Delays
//-----------------------------------------------------------------
localparam DELAY_W = 4;

reg [DELAY_W-1:0] delay_q;
reg [DELAY_W-1:0] delay_r;

/* verilator lint_off WIDTH */

always @ *
begin
    case (state_q)
    //-----------------------------------------
    // STATE_ACTIVATE
    //-----------------------------------------
    STATE_ACTIVATE :
    begin
        // tRCD (ACTIVATE -> READ / WRITE)
        delay_r = SDRAM_TRCD_CYCLES;        
    end
    //-----------------------------------------
    // STATE_READ
    //-----------------------------------------
    STATE_READ :
    begin
        delay_r = SDRAM_READ_LATENCY;

        // Another pending read request (with no refresh pending)
        if (!refresh_q && ram_req_w && ram_rd_w)
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w])
                delay_r = 4'd0;
        end        
    end    
    //-----------------------------------------
    // STATE_PRECHARGE
    //-----------------------------------------
    STATE_PRECHARGE :
    begin
        // tRP (PRECHARGE -> ACTIVATE)
        delay_r = SDRAM_TRP_CYCLES;
    end
    //-----------------------------------------
    // STATE_REFRESH
    //-----------------------------------------
    STATE_REFRESH :
    begin
        // tRFC
        delay_r = SDRAM_TRFC_CYCLES;
    end
    //-----------------------------------------
    // STATE_DELAY
    //-----------------------------------------
    STATE_DELAY:
    begin
        delay_r = delay_q - 4'd1;  
    end
    //-----------------------------------------
    // Others
    //-----------------------------------------
    default:
    begin
        delay_r = {DELAY_W{1'b0}};
    end
    endcase
end
/* verilator lint_on WIDTH */

// Record target state
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    target_state_q   <= STATE_IDLE;
else
    target_state_q   <= target_state_r;

// Record delayed state
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    delay_state_q   <= STATE_IDLE;
// On entering into delay state, record intended next state
else if (state_q != STATE_DELAY && delay_r != {DELAY_W{1'b0}})
    delay_state_q   <= next_state_r;

// Update actual state
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    state_q   <= STATE_INIT;
// Delaying...
else if (delay_r != {DELAY_W{1'b0}})
    state_q   <= STATE_DELAY;
else
    state_q   <= next_state_r;

// Update delay flops
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    delay_q   <= {DELAY_W{1'b0}};
else
    delay_q   <= delay_r;

//-----------------------------------------------------------------
// Refresh counter
//-----------------------------------------------------------------
localparam REFRESH_CNT_W = 17;

reg [REFRESH_CNT_W-1:0] refresh_timer_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    refresh_timer_q <= SDRAM_START_DELAY[REFRESH_CNT_W-1:0] + 'd100;
else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}})
    refresh_timer_q <= SDRAM_REFRESH_CYCLES[REFRESH_CNT_W-1:0];
else
    refresh_timer_q <= refresh_timer_q - 'd1;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    refresh_q <= 1'b0;
else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}})
    refresh_q <= 1'b1;
else if (state_q == STATE_REFRESH)
    refresh_q <= 1'b0;

//-----------------------------------------------------------------
// Input sampling
//-----------------------------------------------------------------

reg [SDRAM_DATA_W-1:0] r_sdram_data_in_p1;
reg [SDRAM_DATA_W-1:0] r_sdram_data_in_p2;

always @ (posedge clk_i or posedge rst_i) begin : SDRAM_IN_P1_P2

    if (rst_i) begin
        r_sdram_data_in_p1 <= {SDRAM_DATA_W{1'b0}};
        r_sdram_data_in_p2 <= {SDRAM_DATA_W{1'b0}};
    end
    else begin
        r_sdram_data_in_p1 <= sdram_data_input_i;
        r_sdram_data_in_p2 <= r_sdram_data_in_p1;
    end
end

//-----------------------------------------------------------------
// Command Output
//-----------------------------------------------------------------
integer idx;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    command_q       <= CMD_NOP;
    data_q          <= {SDRAM_DATA_W{1'b0}};
    addr_q          <= {SDRAM_ROW_W{1'b0}};
    bank_q          <= {SDRAM_BANK_W{1'b0}};
    cke_q           <= 1'b0; 
    dqm_q           <= {SDRAM_DQM_W{1'b0}};
    data_rd_en_q    <= 1'b1;

    for (idx=0;idx<SDRAM_BANKS;idx=idx+1)
        active_row_q[idx] <= {SDRAM_ROW_W{1'b0}};

    row_open_q      <= {SDRAM_BANKS{1'b0}};
end
else
begin
    case (state_q)
    //-----------------------------------------
    // STATE_IDLE / Default (delays)
    //-----------------------------------------
    default:
    begin
        // Default
        command_q    <= CMD_NOP;
        addr_q       <= {SDRAM_ROW_W{1'b0}};
        bank_q       <= {SDRAM_BANK_W{1'b0}};
        data_rd_en_q <= 1'b1;
    end
    //-----------------------------------------
    // STATE_INIT
    //-----------------------------------------
    STATE_INIT:
    begin
        // Assert CKE
        if (refresh_timer_q == 50)
        begin
            // Assert CKE after 100uS
            cke_q <= 1'b1;
        end
        // PRECHARGE
        else if (refresh_timer_q == 40)
        begin
            // Precharge all banks
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b1;
        end
        // 2 x REFRESH (with at least tREF wait)
        else if (refresh_timer_q == 20 || refresh_timer_q == 30)
        begin
            command_q <= CMD_REFRESH;
        end
        // Load mode register
        else if (refresh_timer_q == 10)
        begin
            command_q <= CMD_LOAD_MODE;
            addr_q    <= MODE_REG;
        end
        // Other cycles during init - just NOP
        else
        begin
            command_q   <= CMD_NOP;
            addr_q      <= {SDRAM_ROW_W{1'b0}};
            bank_q      <= {SDRAM_BANK_W{1'b0}};
        end
    end
    //-----------------------------------------
    // STATE_ACTIVATE
    //-----------------------------------------
    STATE_ACTIVATE :
    begin
        // Select a row and activate it
        command_q     <= CMD_ACTIVE;
        addr_q        <= addr_row_w;
        bank_q        <= addr_bank_w;

        active_row_q[addr_bank_w]  <= addr_row_w;
        row_open_q[addr_bank_w]    <= 1'b1;
    end
    //-----------------------------------------
    // STATE_PRECHARGE
    //-----------------------------------------
    STATE_PRECHARGE :
    begin
        // Precharge due to refresh, close all banks
        if (target_state_r == STATE_REFRESH)
        begin
            // Precharge all banks
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b1;
            row_open_q          <= {SDRAM_BANKS{1'b0}};
        end
        else
        begin
            // Precharge specific banks
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b0;
            bank_q              <= addr_bank_w;

            row_open_q[addr_bank_w] <= 1'b0;
        end
    end
    //-----------------------------------------
    // STATE_REFRESH
    //-----------------------------------------
    STATE_REFRESH :
    begin
        // Auto refresh
        command_q   <= CMD_REFRESH;
        addr_q      <= {SDRAM_ROW_W{1'b0}};
        bank_q      <= {SDRAM_BANK_W{1'b0}};        
    end
    //-----------------------------------------
    // STATE_READ
    //-----------------------------------------
    STATE_READ :
    begin
        command_q   <= CMD_READ;
        addr_q      <= addr_col_w;
        bank_q      <= addr_bank_w;

        // Disable auto precharge (auto close of row)
        addr_q[AUTO_PRECHARGE]  <= 1'b0;

        // Read mask (all bytes in burst)
        dqm_q       <= {SDRAM_DQM_W{1'b0}};
    end
    //-----------------------------------------
    // STATE_WRITE
    //-----------------------------------------
    STATE_WRITE :
    begin
        command_q       <= (|ram_wr_w) ? CMD_WRITE : CMD_NOP;
        addr_q          <= addr_col_w;
        bank_q          <= addr_bank_w;
        data_q          <= inport_write_data_i;

        // Disable auto precharge (auto close of row)
        addr_q[AUTO_PRECHARGE]  <= 1'b0;

        // Write mask
        dqm_q           <= ~ram_wr_w;

        data_rd_en_q    <= 1'b0;
    end
    endcase
end

//-----------------------------------------------------------------
// Record read events
//-----------------------------------------------------------------
reg [SDRAM_READ_LATENCY+1:0] rd_q;

always @ (posedge rst_i or posedge clk_i) begin

    if (rst_i) begin
        rd_q <= {(SDRAM_READ_LATENCY+2){1'b0}};
    end
    else begin
        rd_q[SDRAM_READ_LATENCY+1:1] <= rd_q[SDRAM_READ_LATENCY:0];
        rd_q[0] <= (state_q == STATE_READ) ? 1'b1 : 1'b0;
    end
end

//-----------------------------------------------------------------
// Data Buffer
//-----------------------------------------------------------------

// Buffer upper 16-bits of write data so write command can be accepted
// in WRITE0. Also buffer lower 16-bits of read data.
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    data_buffer_q <= {SDRAM_DATA_W{1'b0}};
else if (rd_q[SDRAM_READ_LATENCY+1])
    data_buffer_q <= r_sdram_data_in_p2;

//-----------------------------------------------------------------
// ACK
//-----------------------------------------------------------------
reg ack_q;

always @ (posedge rst_i or posedge clk_i) begin

    if (rst_i) begin
        ack_q <= 1'b0;
    end
    else begin
        ack_q <= (state_q == STATE_WRITE) ? 1'b1 : rd_q[SDRAM_READ_LATENCY+1];
    end
end

// Accept command in READ or WRITE states
assign ram_accept_w = (state_q == STATE_READ) || (state_q == STATE_WRITE) ? 1'b1 : 1'b0;

//-----------------------------------------------------------------
// SDRAM I/O
//-----------------------------------------------------------------
assign sdram_clk_o           = ~clk_i;
assign sdram_data_out_en_o   = ~data_rd_en_q;
assign sdram_data_output_o   =  data_q;

assign sdram_cke_o  = cke_q;
assign sdram_cs_o   = command_q[3];
assign sdram_ras_o  = command_q[2];
assign sdram_cas_o  = command_q[1];
assign sdram_we_o   = command_q[0];
assign sdram_dqm_o  = dqm_q;
assign sdram_ba_o   = bank_q;
assign sdram_addr_o = addr_q;

//-----------------------------------------------------------------
// Simulation only
//-----------------------------------------------------------------
`ifdef verilator
/* verilator lint_off UNUSED */
reg [79:0] dbg_state;

always @ (*) begin
    case (state_q)
        STATE_INIT      : dbg_state = "INIT";
        STATE_DELAY     : dbg_state = "DELAY";
        STATE_IDLE      : dbg_state = "IDLE";
        STATE_ACTIVATE  : dbg_state = "ACTIVATE";
        STATE_READ      : dbg_state = "READ";
        STATE_WRITE     : dbg_state = "WRITE";
        STATE_PRECHARGE : dbg_state = "PRECHARGE";
        STATE_REFRESH   : dbg_state = "REFRESH";
        default         : dbg_state = "UNKNOWN";
    endcase
end
/* verilator lint_on UNUSED */
`endif

endmodule
