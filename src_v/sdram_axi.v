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

module sdram_axi
#(
    parameter                 DW                 = 32,
    parameter                 SDRAM_MHZ          = 50,
    parameter                 SDRAM_ROW_W        = 13,
    parameter                 SDRAM_BANK_W       = 2,
    parameter                 SDRAM_COL_W        = 9,
    parameter                 SDRAM_READ_LATENCY = 2
)
(
    // Reset & clock
    input                     rst_i,
    input                     clk_i,
    
    // AXI-4 I/F
    input              [31:0] s00_axi_awaddr_i,
    input               [3:0] s00_axi_awid_i,
    input               [7:0] s00_axi_awlen_i,
    input               [1:0] s00_axi_awburst_i,
    input                     s00_axi_awvalid_i,
    output                    s00_axi_awready_o,
    
    input            [DW-1:0] s00_axi_wdata_i,
    input          [DW/8-1:0] s00_axi_wstrb_i,
    input                     s00_axi_wvalid_i,
    input                     s00_axi_wlast_i,
    output                    s00_axi_wready_o,
    
    output              [3:0] s00_axi_bid_o,
    output              [1:0] s00_axi_bresp_o,
    output                    s00_axi_bvalid_o,
    input                     s00_axi_bready_i,
    
    input              [31:0] s00_axi_araddr_i,
    input               [3:0] s00_axi_arid_i,
    input               [7:0] s00_axi_arlen_i,
    input               [1:0] s00_axi_arburst_i,
    input                     s00_axi_arvalid_i,
    output                    s00_axi_arready_o,

    output           [DW-1:0] s00_axi_rdata_o,
    output                    s00_axi_rvalid_o,
    output                    s00_axi_rlast_o,
    output              [3:0] s00_axi_rid_o,
    output              [1:0] s00_axi_rresp_o,
    input                     s00_axi_rready_i,

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
// AXI Interface
//-----------------------------------------------------------------
wire     [31:0] w_ram_addr;
wire [DW/8-1:0] w_ram_wr;
wire            w_ram_rd;
wire            w_ram_accept;
wire   [DW-1:0] w_ram_write_data;
wire   [DW-1:0] w_ram_read_data;
wire      [7:0] w_ram_len;
wire            w_ram_ack;

sdram_axi_pmem
#(
    .DW                  (DW)
)
u_axi
(
    .rst_i               (rst_i),
    .clk_i               (clk_i),

    // AXI port
    .axi_awaddr_i        (s00_axi_awaddr_i),
    .axi_awid_i          (s00_axi_awid_i),
    .axi_awlen_i         (s00_axi_awlen_i),
    .axi_awburst_i       (s00_axi_awburst_i),
    .axi_awvalid_i       (s00_axi_awvalid_i),
    .axi_awready_o       (s00_axi_awready_o),

    .axi_wdata_i         (s00_axi_wdata_i),
    .axi_wstrb_i         (s00_axi_wstrb_i),
    .axi_wvalid_i        (s00_axi_wvalid_i),
    .axi_wlast_i         (s00_axi_wlast_i),
    .axi_wready_o        (s00_axi_wready_o),

    .axi_bid_o           (s00_axi_bid_o),
    .axi_bresp_o         (s00_axi_bresp_o),
    .axi_bvalid_o        (s00_axi_bvalid_o),
    .axi_bready_i        (s00_axi_bready_i),

    .axi_araddr_i        (s00_axi_araddr_i),
    .axi_arid_i          (s00_axi_arid_i),
    .axi_arlen_i         (s00_axi_arlen_i),
    .axi_arburst_i       (s00_axi_arburst_i),
    .axi_arvalid_i       (s00_axi_arvalid_i),
    .axi_arready_o       (s00_axi_arready_o),

    .axi_rdata_o         (s00_axi_rdata_o),
    .axi_rvalid_o        (s00_axi_rvalid_o),
    .axi_rlast_o         (s00_axi_rlast_o),
    .axi_rid_o           (s00_axi_rid_o),
    .axi_rresp_o         (s00_axi_rresp_o),
    .axi_rready_i        (s00_axi_rready_i),
    
    // RAM interface
    .ram_addr_o          (w_ram_addr),
    .ram_accept_i        (w_ram_accept),
    .ram_wr_o            (w_ram_wr),
    .ram_rd_o            (w_ram_rd),
    .ram_len_o           (w_ram_len),
    .ram_write_data_o    (w_ram_write_data),
    .ram_ack_i           (w_ram_ack),
    .ram_read_data_i     (w_ram_read_data)
);

//-----------------------------------------------------------------
// SDRAM Controller
//-----------------------------------------------------------------
sdram_axi_core
#(
    .DW                  (DW),
    .SDRAM_MHZ           (SDRAM_MHZ),
    .SDRAM_ROW_W         (SDRAM_ROW_W),
    .SDRAM_BANK_W        (SDRAM_BANK_W),
    .SDRAM_COL_W         (SDRAM_COL_W),
    .SDRAM_READ_LATENCY  (SDRAM_READ_LATENCY)
)
u_core
(
    .rst_i               (rst_i),
    .clk_i               (clk_i),
    
    .inport_wr_i         (w_ram_wr),
    .inport_rd_i         (w_ram_rd),
    .inport_len_i        (w_ram_len),
    .inport_addr_i       (w_ram_addr),
    .inport_write_data_i (w_ram_write_data),
    .inport_accept_o     (w_ram_accept),
    .inport_ack_o        (w_ram_ack),
    .inport_read_data_o  (w_ram_read_data),
    
    .sdram_clk_o         (sdram_clk_o),
    .sdram_cke_o         (sdram_cke_o),
    .sdram_cs_o          (sdram_cs_o),
    .sdram_ras_o         (sdram_ras_o),
    .sdram_cas_o         (sdram_cas_o),
    .sdram_we_o          (sdram_we_o),
    .sdram_dqm_o         (sdram_dqm_o),
    .sdram_addr_o        (sdram_addr_o),
    .sdram_ba_o          (sdram_ba_o),
    .sdram_data_output_o (sdram_data_output_o),
    .sdram_data_out_en_o (sdram_data_out_en_o),
    .sdram_data_input_i  (sdram_data_input_i)
);

endmodule
