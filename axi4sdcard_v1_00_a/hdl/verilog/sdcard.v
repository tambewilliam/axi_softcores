
// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// Implementation of the TambeCore
// interface to the SDCard controller.
// DeviceMapSz == 256 (1024 bytes).

// Data are transfered in 512 bytes blocks.

// Memory mapping:
// -------------------------------
// Offset 0; Size: 512 bytes.
// Area used to retrieve a data block
// readed from the SDCard, or prepare
// a data block to write to the SDCard.
// Its content become a data block readed
// from the SDCard only after the SWAP command
// has been issued following the READ command.
// Its content is written to the SDCard
// only after the SWAP command has been
// issued followed by the WRITE command.
// Its content can be modified while
// the previously swapped content is being
// written to the SDCard; similarly its content
// can be readed while reading another
// data block from the SDCard.
// -------------------------------
// Offset 512; Size 4 bytes.
// A read return the controller
// status as described below:
// 0: PowerOff.
// 1: Ready.
// 2: Busy.
// 3: Error.
// A write set the argument
// for the command to execute.
// Read/Write to/from this field
// must be 32bits memory accesses.
// -------------------------------
// Offset 516; Size 4 bytes.
// A read return the total
// block count of the SDCard.
// A write execute the command for
// the value writen as described below:
// 0: RESET: Argument is meaningless.
// 1: SWAP: Argument is meaningless.
// 2: READ: Argument must be the block offset within the SDCard.
// 3: WRITE: Argument must be the block offset within the SDCard.
// Read/Write to/from this field
// must be 32bits memory accesses.
// With the exception of the command RESET,
// every other commands must be issued
// when the controller status is ready.
// Copying blocks between locations
// within the SDCard can be done
// simply issuing the command READ
// specifying the source block location,
// followed by the command WRITE
// specifying the destination block
// location.
// -------------------------------


// Parameters.
// 
// CLKFREQ:
// 	Frequency of the clock input "clk" in Hz.
// 	It should be at least 500KHz in order
// 	to provide at least 250KHz required
// 	by the device.


// Size in bytes of each of the two cache
// used to implement double caching
// which allow the controller
// to read/write from/to the device
// while, in parallel, the next block
// of data to transfer is being prepared.
// CMDSWAP is used to swap between
// the cache used by the controller
// and the cache mapped in memory.
// Note also that the value of
// this macro is the block size
// used by the controller as well
// as the value of DeviceMapSz which
// is the size of the memory mapping
// used by the memory interface.
// The value of this macro must be
// greater than or equal to 16 to
// accomodate the memory mapping space
// needed for the four commands
// (CMDRESET, CMDSWAP, CMDREAD, CMDWRITE);
// and the value of this macro must
// be a power of 2.
`define CACHESIZE		512


// Ports.
// 
// input rst
// 	This input reset
// 	this module when
// 	held high and must
// 	be held low for
// 	normal operation.
// 	This input is also
// 	to be used to report
// 	whether the device
// 	driven by the controller
// 	is powered off; hence
// 	this input is to be
// 	held high for as long
// 	as that device is in
// 	a poweroff state.
// 
// input clk
// 	Clock signal.
// 
// output sclk
// output di
// input do
// output cs
// 	SPI interface to the card.
// 
// input[2] memop
// input[clog2(CACHESIZE) -2] memaddr
// input[32] memdatain
// output[32] memdataout
// input[4] membyteselect
// output memrdy
// output[30] memmapsz
// 	Slave memory interface.
// 
// output intrqst
// 	This signal is set high
// 	to request an interrupt;
// 	an interrupt is raised, when
// 	either of the following events
// 	from the controller occur:
// 	- Done resetting; also occur on poweron.
// 	- Done reading.
// 	- Done writing.
// 	- Error.
// 	- Poweroff.
// 
// input intrdy
// 	This signal become low
// 	when the interrupt request
// 	has been acknowledged,
// 	and is used by this module to
// 	automatically lower intrqst.


// Only one of the macro below
// must be uncommented to use
// the desired SDCARD mode.
//`define SDCARDSPIMODE
//`define SDCARDSDMODE

`ifdef SDCARDSPIMODE
`include "spimode.sdcard.v"
`elsif SDCARDSDMODE
`include "sdmode.sdcard.v"
`else
`SDCARDSPIMODE
`endif

module sdcard (
	
	rst,
	
	clk,
	
	sclk, di, do, cs,
	
	memop,
	memaddr,
	memdatain,
	memdataout,
	membyteselect,
	memrdy,
	memmapsz,
	
	intrqst,
	intrdy
);

`include "lib/clog2.v"

parameter CLKFREQ = 0;

input rst;

input clk;

output sclk;
output di;
input do;
output cs;

parameter CACHESIZE = `CACHESIZE;

input[2 -1 : 0] memop;
input[(clog2(CACHESIZE*2) -2) -1 : 0] memaddr;
input[32 -1 : 0] memdatain;
output reg[32 -1 : 0] memdataout; // Registered output.
input[4 -1 : 0] membyteselect;
output memrdy;
output[30 -1 : 0] memmapsz;

output reg intrqst; // Registered output.
input intrdy;


// The output memrdy is always 1
// because all memory operations
// complete immediately.
assign memrdy = 1;

assign memmapsz = ((CACHESIZE*2)/4);


// Memory interface operations.
parameter MEMNOOP		= 2'b00;
parameter MEMWRITEOP		= 2'b01;
parameter MEMREADOP		= 2'b10;
parameter MEMREADWRITEOP	= 2'b11;

// Commands.
parameter CMDRESET		= 0;
parameter CMDSWAP		= 1;
parameter CMDREAD		= 2;
parameter CMDWRITE		= 3;

// Status.
parameter STATUSPOWEROFF	= 0;
parameter STATUSREADY		= 1;
parameter STATUSBUSY		= 2;
parameter STATUSERROR		= 3;


wire phycacheread;
wire phycachewrite;
wire[8 -1 : 0] phycachedatain;
// ### Net declared as reg
// ### so as to be useable
// ### by verilog within
// ### the always block.
reg[8 -1 : 0] phycachedataout;

// Registers holding the value
// of the ports "phy.devread",
// "phy.devwrite" and "phy.devaddr".
reg phydevread, phydevwrite;
reg[32 -1 : 0] phydevaddr;

wire[32 -1 : 0] phyblockcount;

wire phybsy;
wire phyerr;

// A phy reset is done when
// the input "rst" is high
// or when CMDRESET is issued.
// Since the input "rst" is
// also used to report whether
// the device is under power,
// a controller reset will be done
// as soon as the device is poweredon.
wire phyrst = (rst | (memop == MEMWRITEOP && memaddr == (516>>2) && memdatain == CMDRESET));

// Instantiate the phy.
sdcardphy #(
	
	.CLKFREQ (CLKFREQ)
	
) phy (
	
	.rst (phyrst),
	
	.clk (clk),
	
	.sclk (sclk),
	.di (di),
	.do (do),
	.cs (cs),
	
	.cacheread (phycacheread),
	.cachewrite (phycachewrite),
	.cachedatain (phycachedatain),
	.cachedataout (phycachedataout),
	
	.devread (phydevread),
	.devwrite (phydevwrite),
	.devaddr (phydevaddr),
	
	.blockcount (phyblockcount),
	
	.bsy (phybsy),
	.err (phyerr)
);


// When the value of this register
// is 1, "phy" has access to cache1
// otherwise it has access to cache0.
// The cache not being accessed by "phy"
// is accessed by the memory interface.
reg cacheselect;


// The two cache.
reg[32 -1 : 0] cache0[(CACHESIZE/4) -1 : 0];
reg[32 -1 : 0] cache1[(CACHESIZE/4) -1 : 0];

// Register keeping track of
// the cache byte location that
// "phy" will access next.
reg[clog2(CACHESIZE) -1 : 0] phycacheaddr;

// Nets set to the index within
// the respective cache.
// Each cache element is 32bits.
wire[(clog2(CACHESIZE) -2) -1 : 0] cache0addr = cacheselect ? memaddr[(clog2(CACHESIZE) -2) -1 : 0] : phycacheaddr[clog2(CACHESIZE) -1 : 2];
wire[(clog2(CACHESIZE) -2) -1 : 0] cache1addr = cacheselect ? phycacheaddr[clog2(CACHESIZE) -1 : 2] : memaddr[(clog2(CACHESIZE) -2) -1 : 0];

// Nets set to a value indexed
// from the respective cache.
wire[32 -1 : 0] cache0dataout = cache0[cache0addr];
wire[32 -1 : 0] cache1dataout = cache1[cache1addr];

// Nets set to the cache value
// which will be used to preserve
// the other bits in a 32bits
// cache value to modify; they
// are used respectively by
// memdatainbyteselected and
// phycachedatainbyteselected.
wire[32 -1 : 0] cachememdata = cacheselect ? cache0dataout : cache1dataout;
wire[32 -1 : 0] cachephydata = cacheselect ? cache1dataout : cache0dataout;

// Net set to the value from
// the memory interface to
// store in the cache.
wire[32 -1 : 0] memdatainbyteselected = (membyteselect == 4'b0001) ? {cachememdata[31:8], memdatain[7:0]} :
	(membyteselect == 4'b0010) ? {cachememdata[31:16], memdatain[15:8], cachememdata[7:0]} :
	(membyteselect == 4'b0100) ? {cachememdata[31:24], memdatain[23:16], cachememdata[15:0]} :
	(membyteselect == 4'b1000) ? {memdatain[31:24], cachememdata[23:0]} :
	(membyteselect == 4'b0011) ? {cachememdata[31:16], memdatain[15:0]} :
	(membyteselect == 4'b1100) ? {memdatain[31:16], cachememdata[15:0]} : memdatain;

// Net set to the value from
// "phy" to store in the cache.
wire[32 -1 : 0] phycachedatainbyteselected = (phycacheaddr[1:0] == 0) ? {cachephydata[31:8], phycachedatain} :
	(phycacheaddr[1:0] == 1) ? {cachephydata[31:16], phycachedatain, cachephydata[7:0]} :
	(phycacheaddr[1:0] == 2) ? {cachephydata[31:24], phycachedatain, cachephydata[15:0]} : {phycachedatain, cachephydata[23:0]};

// Nets set to the value to write
// in the respective cache.
wire[32 -1 : 0] cache0datain = cacheselect ? memdatainbyteselected : phycachedatainbyteselected;
wire[32 -1 : 0] cache1datain = cacheselect ? phycachedatainbyteselected : memdatainbyteselected;

// phy.cachedataout is set
// to the value read from
// the respective cache.
always @* begin
	if (phycacheaddr[1:0] == 0) phycachedataout = cacheselect ? cache1dataout[7:0] : cache0dataout[7:0];
	else if (phycacheaddr[1:0] == 1) phycachedataout = cacheselect ? cache1dataout[15:8] : cache0dataout[15:8];
	else if (phycacheaddr[1:0] == 2) phycachedataout = cacheselect ? cache1dataout[23:16] : cache0dataout[23:16];
	else phycachedataout = cacheselect ? cache1dataout[31:24] : cache0dataout[31:24];
end


// Register used to detect
// a rising edge on the
// input "rst".
reg rstsampled;
wire rstposedge = (rst && !rstsampled);

// Register used to detect
// a falling edge on "intrdy".
reg intrdysampled;
wire intrdynegedge = (!intrdy && intrdysampled);

// Register used to detect
// a rising edge on "phy.err".
reg phyerrsampled;
wire phyerrposedge = (phyerr && !phyerrsampled);

// Register used to detect
// a falling edge on "phy.bsy".
reg phybsysampled;
wire phybsynegedge = (!phybsy && phybsysampled);


// Nets set to 1 when
// a read/write request
// is done to their
// respective cache.
wire cache0read = cacheselect ? (memop == MEMREADOP && memaddr < (512>>2)) : phycacheread;
wire cache1read = cacheselect ? phycacheread : (memop == MEMREADOP && memaddr < (512>>2));
wire cache0write = cacheselect ? (memop == MEMWRITEOP && memaddr < (512>>2)) : phycachewrite;
wire cache1write = cacheselect ? phycachewrite : (memop == MEMWRITEOP && memaddr < (512>>2));


// Net set to the status to
// be returned by CMDRESET.
// ### Net declared as reg
// ### so as to be useable
// ### by verilog within
// ### the always block.
reg[2 -1 : 0] status;

always @* begin
	if (rst) status = STATUSPOWEROFF;
	else if (phyerr) status = STATUSERROR;
	else if (phybsy || phyrst || phydevread || phydevwrite) status = STATUSBUSY;
	else status = STATUSREADY;
	// For correctness, STATUSBUSY
	// is reported as soon as
	// CMDRESET, CMDREAD or CMDWRITE
	// is issued, and not only when
	// phy.bsy become high.
end


// Used with verilog so
// that a syntax similar
// to this can be used;
// ei: ZERO[29:0]
parameter ZERO = 0;


always @(posedge clk) begin
	// Logic to set/clear intrqst.
	// A rising edge of "rst" mean
	// the card was poweredoff;
	// a rising edge of "phy.err"
	// mean that an error occured
	// while the controller was
	// processing the previous
	// operation, which is either
	// initialization, read or write;
	// a falling edge of "phy.bsy"
	// mean that the controller has
	// completed the previous operation,
	// which is either initialization,
	// read or write.
	// Note that on poweron,
	// it is expected that the device
	// transition from a poweroff
	// state through a busy state
	// to a ready state, in order
	// to trigger a poweron interrupt.
	intrqst <= intrqst ? ~intrdynegedge : (rstposedge || phyerrposedge || phybsynegedge);
	
	// Logic that flip the value
	// of cacheselect when CMDSWAP
	// is issued.
	if (memop == MEMWRITEOP && memaddr == (516>>2) && memdatain == CMDSWAP) cacheselect <= ~cacheselect;
	
	// Logic that set phycacheaddr.
	// Increment phycacheaddr whenever
	// "phy" is not busy and requesting
	// a read/write; reset phycacheaddr
	// to 0 whenever "phy.bsy" is low.
	if (!phybsy) phycacheaddr <= 0;
	else if (cacheselect ? (cache1read | cache1write) : (cache0read | cache0write)) phycacheaddr <= phycacheaddr + 1'b1;
	
	// Logic that set memdataout.
	if (memop == MEMREADOP) begin
		if (memaddr < (512>>2))
			memdataout <= cacheselect ? cache0dataout : cache1dataout;
		else if (memaddr == (512>>2))
			memdataout <= {ZERO[29:0], status};
		else if (memaddr == (516>>2))
			memdataout <= phyblockcount;
	end
	
	// Logic that set cache0.
	if (cache0write) cache0[cache0addr] <= cache0datain;
	
	// Logic that set cache1.
	if (cache1write) cache1[cache1addr] <= cache1datain;
	
	// The port "phy.devread" is held
	// high for a single clock cycle.
	phydevread <= phydevread ? 1'b0 : (memop == MEMWRITEOP && memaddr == (516>>2) && memdatain == CMDREAD);
	
	// The port "phy.devwrite" is held
	// high for a single clock cycle.
	phydevwrite <= phydevwrite ? 1'b0 : (memop == MEMWRITEOP && memaddr == (516>>2) && memdatain == CMDWRITE);
	
	if (memop == MEMWRITEOP && memaddr == (512>>2))
		phydevaddr <= memdatain;
	
	// Sampling used for
	// edge detection.
	rstsampled <= rst;
	intrdysampled <= intrdy;
	phyerrsampled <= phyerr;
	phybsysampled <= phybsy;
end


endmodule


`undef CACHESIZE
