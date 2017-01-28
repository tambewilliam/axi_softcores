
// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// AXI4 to TambeCore bridge.


`define SDRAMSDR
`include "sdram.v"
`undef SDRAMSDR

//`include "debugprobe.v"

module axi4sdrsdram (
	// Clock.
	S_AXI_ACLK,
	
	// Reset, active low.
	S_AXI_ARESETN,
	
	// Read address channel.
	S_AXI_ARADDR,
	S_AXI_ARVALID,
	S_AXI_ARREADY,
	S_AXI_ARID,
	S_AXI_ARLEN,
	S_AXI_ARSIZE,
	S_AXI_ARBURST,
	S_AXI_ARLOCK,
	S_AXI_ARCACHE,
	S_AXI_ARPROT,
	
	// Read data channel.
	S_AXI_RDATA,
	S_AXI_RVALID,
	S_AXI_RREADY,
	S_AXI_RRESP,
	S_AXI_RID,
	S_AXI_RLAST,
	
	// Write address channel.
	S_AXI_AWADDR,
	S_AXI_AWVALID,
	S_AXI_AWREADY,
	S_AXI_AWID,
	S_AXI_AWLEN,
	S_AXI_AWSIZE,
	S_AXI_AWBURST,
	S_AXI_AWLOCK,
	S_AXI_AWCACHE,
	S_AXI_AWPROT,
	
	// Write data channel.
	S_AXI_WDATA,
	S_AXI_WVALID,
	S_AXI_WREADY,
	S_AXI_WSTRB,
	S_AXI_WLAST,
	
	// Write response channel.
	S_AXI_BREADY,
	S_AXI_BRESP,
	S_AXI_BVALID,
	S_AXI_BID,
	
	// SDRAM signals.
	S_SDRAMCK,
	S_SDRAMCKE,
	S_SDRAMRAS,
	S_SDRAMCAS,
	S_SDRAMWE,
	S_SDRAMBA,
	S_SDRAMA,
	S_SDRAMDQ_I,
	S_SDRAMDQ_O,
	S_SDRAMDQ_T,
	S_SDRAMDM
	
	// DebugProbe signal.
	//,S_DEBUGPROBETX
);
	
	`include "lib/clog2.v"
	
	parameter C_S_AXI_ID_WIDTH		= 4;
	parameter C_S_AXI_ADDR_WIDTH		= 32;
	parameter C_S_AXI_DATA_WIDTH		= 32;
	parameter C_S_AXI_ACLK_FREQ_HZ	= 100000000;
	parameter C_S_AXI_MEM0_BASEADDR	= 32'hffffffff;
	
	parameter C_SDRAMCACHESIZE		= 1024;
	
	// Timing parameters for
	// Winbond W9825G6JH-6 SDR.
	parameter C_SDRAMPOWERONDELAY	= 5000;
	parameter C_SDRAMTCK			= 133000000;
	parameter C_SDRAMTREFI			= 128000;
	parameter C_SDRAMTRFC			= 16000000;
	parameter C_SDRAMTRCD			= 67000000;
	parameter C_SDRAMTWR			= (67000000/2);
	parameter C_SDRAMTRP			= 67000000;
	parameter C_SDRAMTMRD			= (83333333/2);
	parameter C_SDRAMCASLATENCY		= 2;
	parameter C_SDRAMBURSTLENGTH 	= 8;
	parameter C_SDRAMBANKCOUNT 		= 4;
	parameter C_SDRAMCLOG2BANKCOUNT	= 2;
	parameter C_SDRAMROWCOUNT 		= 8192;
	parameter C_SDRAMCOLUMNCOUNT	= 512;
	parameter C_SDRAMABITSIZE		= 13;
	parameter C_SDRAMDQBITSIZE		= 16;
	
	
	input S_AXI_ACLK; // Clock.
	input S_AXI_ARESETN; // Reset, active low.
	
	// Read address channel.
	input[C_S_AXI_ADDR_WIDTH -1 : 0] S_AXI_ARADDR; // Read address.
	input S_AXI_ARVALID; // Read address valid.
	output S_AXI_ARREADY; // Read address ready.
	input[C_S_AXI_ID_WIDTH -1 : 0] S_AXI_ARID; // Read address ID.
	input[8 -1 : 0] S_AXI_ARLEN; // Burst lenght (number of data transfers).
	input[3 -1 : 0] S_AXI_ARSIZE; // Burst size (size of each transfer).
	input[2 -1 : 0] S_AXI_ARBURST; // Burst type.
	input S_AXI_ARLOCK; // Lock type (atomic characteristics).
	input[4 -1 : 0] S_AXI_ARCACHE; // Memory type.
	input[3 -1 : 0] S_AXI_ARPROT; // Protection type.
	
	// Read data channel.
	output[C_S_AXI_DATA_WIDTH -1 : 0] S_AXI_RDATA; // Read data.
	output S_AXI_RVALID; // Read valid.
	input S_AXI_RREADY; // Read ready.
	output[1 : 0] S_AXI_RRESP; // Read response.
	output[C_S_AXI_ID_WIDTH -1 : 0] S_AXI_RID; // Read ID.
	output S_AXI_RLAST; // Indicate last read transfer in burst.
	
	// Write address channel.
	input[C_S_AXI_ADDR_WIDTH -1 : 0] S_AXI_AWADDR; // Write address.
	input S_AXI_AWVALID; // Write address valid.
	output S_AXI_AWREADY; // Write address ready.
	input[C_S_AXI_ID_WIDTH -1 : 0] S_AXI_AWID; // Write address ID.
	input[8 -1 : 0] S_AXI_AWLEN; // Burst lenght (number of data transfers).
	input[3 -1 : 0] S_AXI_AWSIZE; // Burst size (size of each transfer).
	input[2 -1 : 0] S_AXI_AWBURST; // Burst type.
	input S_AXI_AWLOCK; // Lock type (atomic characteristics).
	input[4 -1 : 0] S_AXI_AWCACHE; // Memory type.
	input[3 -1 : 0] S_AXI_AWPROT; // Protection type.
	
	// Write data channel.
	input[C_S_AXI_DATA_WIDTH -1 : 0] S_AXI_WDATA; // Write data.
	input S_AXI_WVALID; // Write valid.
	output S_AXI_WREADY; // Write ready.
	input[(C_S_AXI_DATA_WIDTH/8) -1 : 0] S_AXI_WSTRB; // Write strobes.
	input S_AXI_WLAST; // Indicate last write transfer in burst.
	
	// Write response channel.
	input S_AXI_BREADY; // Write response ready. 
	output[1 : 0] S_AXI_BRESP; // Write response.
	output S_AXI_BVALID; // Write response valid.
	output[C_S_AXI_ID_WIDTH -1 : 0] S_AXI_BID; // Write response ID.
	
	// SDRAM signals.
	output S_SDRAMCK;
	output S_SDRAMCKE;
	output S_SDRAMRAS;
	output S_SDRAMCAS;
	output S_SDRAMWE;
	output[clog2(C_SDRAMBANKCOUNT) -1 : 0] S_SDRAMBA;
	output[C_SDRAMABITSIZE -1 : 0] S_SDRAMA;
	input[C_SDRAMDQBITSIZE -1 : 0] S_SDRAMDQ_I;
	output[C_SDRAMDQBITSIZE -1 : 0] S_SDRAMDQ_O;
	output S_SDRAMDQ_T;
	output[(C_SDRAMDQBITSIZE/8) -1 : 0] S_SDRAMDM;
	
	// DebugProbe signal.
	//output S_DEBUGPROBETX;
	
	
	// The sdram pin "cke"
	// is kept always high.
	assign S_SDRAMCKE = 1;
	
	
	wire DEVRDY;
	
	
	wire AXIREADOP = (S_AXI_ARVALID & S_AXI_RREADY);
	wire AXIWRITEOP = (S_AXI_AWVALID & S_AXI_WVALID & S_AXI_BREADY);
	
	
	// ### Net declared as reg
	// ### so to be usable
	// ### within always@block.
	reg[4 -1 : 0] RSTRB;
	
	
	// ----------------- Logic Implementing exclusive access -----------------
	
	parameter OKAY = 2'b00;
	parameter EXOKAY = 2'b01;
	
	reg[1 : 0] RRESP;
	reg[1 : 0] BRESP;
	
	reg[(C_S_AXI_ADDR_WIDTH-2) -1 : 0] EXACCESS_ADDR[(1<<(C_S_AXI_ID_WIDTH-1)) -1 : 0];
	reg[4 -1 : 0] EXACCESS_STRB[(1<<(C_S_AXI_ID_WIDTH-1)) -1 : 0];
	reg EXACCESS_VALID[(1<<(C_S_AXI_ID_WIDTH-1)) -1 : 0];
	
	integer i;
	
	always @(posedge S_AXI_ACLK) begin
		
		if (DEVRDY) begin
			
			if (S_AXI_ARLOCK) begin
				
				if (AXIREADOP) begin
					
					RRESP <= EXOKAY;
					
					EXACCESS_ADDR[S_AXI_ARID] <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH -1 : 2];
					
					EXACCESS_STRB[S_AXI_ARID] <= RSTRB;
					
					EXACCESS_VALID[S_AXI_ARID] <= 1;
					
				end else RRESP <= OKAY;
				
			end else RRESP <= OKAY;
			
			if (AXIWRITEOP) begin
				
				if (S_AXI_AWLOCK) begin
					
					if (EXACCESS_ADDR[S_AXI_AWID] == S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH -1 : 2] &&
						!(|(EXACCESS_STRB[S_AXI_AWID] ^ S_AXI_WSTRB)) && EXACCESS_VALID[S_AXI_AWID])
						BRESP <= EXOKAY;
					else BRESP <= OKAY;
					
				end else begin
					
					for (i = 0; i < (1<<(C_S_AXI_ID_WIDTH-1)); i = i + 1) begin
						
						EXACCESS_VALID[i] <=
							!(EXACCESS_ADDR[i] == S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH -1 : 2] &&
								(|(EXACCESS_STRB[i] & S_AXI_WSTRB)));
					end
					
					BRESP <= OKAY;
				end
				
			end else BRESP <= OKAY;
		end
	end
	
	// ### Net declared as reg
	// ### so to be usable
	// ### within always@block.
	reg EXACCESS_WVALID;
	
	always @* begin
		
		if (S_AXI_AWLOCK) begin
			
			EXACCESS_WVALID =
				(EXACCESS_ADDR[S_AXI_AWID] == S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH -1 : 2] &&
				!(|(EXACCESS_STRB[S_AXI_AWID] ^ S_AXI_WSTRB)) && EXACCESS_VALID[S_AXI_AWID]);
			
		end else EXACCESS_WVALID = 1;
	end
	
	// ----------------------------------------------------------------------
	
	
	reg[C_S_AXI_ID_WIDTH -1 : 0] S_AXI_ARID_SAVED;
	reg[C_S_AXI_ID_WIDTH -1 : 0] S_AXI_AWID_SAVED;
	
	always @(posedge S_AXI_ACLK) begin
		
		if (DEVRDY) begin
			
			if (AXIREADOP) S_AXI_ARID_SAVED <= S_AXI_ARID;
			
			if (AXIWRITEOP) S_AXI_AWID_SAVED <= S_AXI_AWID;
		end
	end
	
	
	reg therewasaread;
	
	always @(posedge S_AXI_ACLK) begin
		if (DEVRDY) therewasaread <= AXIREADOP;
	end
	
	reg therewasawrite;
	
	always @(posedge S_AXI_ACLK) begin
		if (DEVRDY) therewasawrite <= AXIWRITEOP;
	end
	
	assign S_AXI_ARREADY = DEVRDY;
	assign S_AXI_RVALID = (therewasaread & DEVRDY);
	assign S_AXI_RRESP = RRESP;
	assign S_AXI_RID = S_AXI_ARID_SAVED;
	assign S_AXI_RLAST = (therewasaread & DEVRDY);
	assign S_AXI_AWREADY = DEVRDY;
	assign S_AXI_WREADY = DEVRDY;
	assign S_AXI_BRESP = BRESP;
	assign S_AXI_BVALID = (therewasawrite & DEVRDY);
	assign S_AXI_BID = S_AXI_AWID_SAVED;
	
	
	always @* begin
		
		if (S_AXI_ARSIZE == 3'b000) begin
			
			if      (S_AXI_ARADDR[1:0] == 2'b00) RSTRB = 4'b0001;
			else if (S_AXI_ARADDR[1:0] == 2'b01) RSTRB = 4'b0010;
			else if (S_AXI_ARADDR[1:0] == 2'b10) RSTRB = 4'b0100;
			else                                 RSTRB = 4'b1000;
			
		end else if (S_AXI_ARSIZE == 3'b001) begin
			
			if (S_AXI_ARADDR[1] == 1'b0) RSTRB = 4'b0011;
			else                         RSTRB = 4'b1100;
			
		end else RSTRB = 4'b1111;
	end
	
	
	sdram #(
		
		.PHYCLKFREQ	(C_S_AXI_ACLK_FREQ_HZ),
		.CACHESIZE	(C_SDRAMCACHESIZE),
		.POWERONDELAY	(C_SDRAMPOWERONDELAY),
		.TCK			(C_SDRAMTCK),
		.TREFI		(C_SDRAMTREFI),
		.TRFC		(C_SDRAMTRFC),
		.TRCD		(C_SDRAMTRCD),
		.TWR			(C_SDRAMTWR),
		.TRP			(C_SDRAMTRP),
		.TMRD		(C_SDRAMTMRD),
		.CASLATENCY	(C_SDRAMCASLATENCY),
		.BURSTLENGTH	(C_SDRAMBURSTLENGTH),
		.BANKCOUNT	(C_SDRAMBANKCOUNT),
		.ROWCOUNT	(C_SDRAMROWCOUNT),
		.COLUMNCOUNT	(C_SDRAMCOLUMNCOUNT),
		.ABITSIZE		(C_SDRAMABITSIZE),
		.DQBITSIZE		(C_SDRAMDQBITSIZE)
		
	) sdram0 (
		
		.rst (~S_AXI_ARESETN),
		
		.clk (S_AXI_ACLK),
		.phyclk (S_AXI_ACLK),
		
		.ck (S_SDRAMCK),
		.ras (S_SDRAMRAS),
		.cas (S_SDRAMCAS),
		.we (S_SDRAMWE),
		.ba (S_SDRAMBA),
		.a (S_SDRAMA),
		.dq_i (S_SDRAMDQ_I),
		.dq_o (S_SDRAMDQ_O),
		.dq_t (S_SDRAMDQ_T),
		.dm (S_SDRAMDM),
		
		.memop ({AXIREADOP, AXIWRITEOP & EXACCESS_WVALID}),
		.memaddr ({{S_AXI_ARVALID ? S_AXI_ARADDR : S_AXI_AWADDR} - C_S_AXI_MEM0_BASEADDR}[C_S_AXI_ADDR_WIDTH -1 : 2]),
		.memdatain (S_AXI_WDATA),
		.memdataout (S_AXI_RDATA),
		.membyteselect (S_AXI_ARVALID ? RSTRB : S_AXI_WSTRB),
		.memrdy (DEVRDY)
	);
	
	
	/*
	wire[4 -1 : 0] debugprobeop = {2'b00, AXIREADOP, AXIWRITEOP};
	wire[32 -1 : 0] debugprobeaddr = ({S_AXI_ARVALID ? S_AXI_ARADDR : S_AXI_AWADDR} - C_S_AXI_MEM0_BASEADDR);
	wire[4 -1 : 0] debugprobebyteselect = (S_AXI_ARVALID ? RSTRB : S_AXI_WSTRB);
	
	debugprobe #(
		
		.CLKFREQ 			(C_S_AXI_ACLK_FREQ_HZ),
		.PROBEBITSIZE		(32+32+32+4+4),
		.PROBEBUFFERSIZE	(2048),
		.TXBUFFERSIZE		(8192)
		
	) debugprobe0 (
		
		.rst (~S_AXI_ARESETN),
		
		.clk (S_AXI_ACLK),
		
		.probe (((debugprobeop || therewasaread) && DEVRDY) ? {debugprobeaddr, S_AXI_RDATA, S_AXI_WDATA, debugprobeop, debugprobebyteselect} : 104'd0),
		
		.tx (S_DEBUGPROBETX)
	);
	*/
	
endmodule
