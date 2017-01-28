
// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// Implementation of the TambeCore
// memory interface for a RAM device
// which is DeviceID == 1.

// A brief description of how
// this module work is that:
// When a memory write access
// is done, it is simultaneously
// written in the cache and
// buffered for writing in the RAM.
// When a memory read access is done,
// if there is a cachehit, the data
// is immediately returned, otherwise
// it is retrieved from the RAM,
// then cached and returned.
// A memory read access stall
// when there was a cachemiss
// and the data is being retrieved
// from the RAM.
// A memory write access stall
// when the buffer, used for
// writing the RAM, is full.


// Parameters.
// 
// PHYCLKFREQ:
// 	Frequency of the clock
// 	input "phyclk" in Hz.
// 
// CACHESIZE:
// 	Size in bytes of the cache.
// 	It must be at least
// 	2*(sizeof(sdramphy.dataout)/8),
// 	a power of 2 and less than
// 	or equal to the SDRAM size.
// 	ei: 4096.
// 
// POWERONDELAY: ei: 200 us == 5 kHz;
// 	Minimum delay after poweron
// 	before applying any command.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: 5000.
// 
// TCK: ei: 7.5 ns == 133 MHz;
// 	Period of the SDRAM signal "ck".
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: 133000000.
// 
// TREFI: ei: 7.8 us == 128 kHz;
// 	Minimum frequency at which
// 	to issue the command REFRESH.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: 128000.
// 
// TRFC: ei: 60 ns == 16 MHz;
// 	Minimum delay after applying
// 	the command REFRESH.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: 16000000.
// 
// TRCD: ei: 15 ns == 67 MHz;
// 	Minimum delay after applying
// 	the command ACTIVATE.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: 67000000.
// 
// TWR: ei: 2 TCK;
// 	Minimum delay after
// 	the last data to
// 	write has been sent
// 	to the SDRAM.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: (TCK / 2).
// 
// TRP: ei: 15 ns == 67 MHz;
// 	Minimum delay after applying
// 	the command PRECHARGE.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: 67000000.
// 
// TMRD: ei: 2 TCK;
// 	Minimum delay after
// 	applying the command
// 	LOAD MODE REGISTER.
// 	The value of this parameter
// 	is its equivalent in Hz.
// 	ei: (TCK / 2).
// 
// CASLATENCY:
// 	Latency after applying
// 	the command READ, and
// 	before the first data
// 	from the SDRAM is
// 	ready to be sampled.
// 	It must be a valid value
// 	from the SDRAM datasheet.
// 	ei: 2.
// 
// BURSTLENGTH:
// 	Number of data transmitted
// 	through the SDRAM inout "dq"
// 	during a single read or single
// 	write operation.
// 	It must be a valid value
// 	from the SDRAM datasheet
// 	that is at least 2.
// 	ei: 4.
// 
// BANKCOUNT:
// 	Number of bank in the SDRAM.
// 	ei: 4.
// 
// ROWCOUNT:
// 	Number of rows in the SDRAM.
// 	ei: 8192.
// 
// COLUMNCOUNT:
// 	Number of columns in the SDRAM.
// 	ei: 512.
// 
// ABITSIZE:
// 	Number of bits used
// 	by the SDRAM signal "a".
// 	ei: 13.
// 
// DQBITSIZE:
// 	Number of bits used
// 	by the SDRAM inout "dq".
// 	ei: 16.


// Ports.
// 
// input rst
// 	This input reset
// 	this module when
// 	held high and must
// 	be held low for
// 	normal operation.
// 
// input clk
// 	Clock input used by
// 	the memory interface.
// 
// input phyclk
// 	Clock input used by the SDRAM phy.
// 
// input[2] memop
// input[sizeof(sdramphy.addr) + ((sizeof(sdramphy.dataout)>32) ? clog2(sizeof(sdramphy.dataout)/32) : 0)] memaddr,
// input[32] memdatain
// output[32] memdataout
// input[4] membyteselect
// output memrdy
// output[30] memmapsz
// 	Slave memory interface.
// 	sizeof(sdramphy.dataout) is assumed at least 32.
// 
// output ck
// output ras
// output cas
// output we
// output[sizeof(sdramphy.ba)] ba
// output[sizeof(sdramphy.a)] a
// inout[sizeof(sdramphy.dq)] dq
// output[sizeof(sdramphy.dm)] dm
// `ifndef SDRAMSDR
// inout[sizeof(sdramphy.dm)] dqs
// `endif
// 	SDRAM signals.
// 	The SDRAM input "cke" is not
// 	used because it is assumed
// 	that it has been set high.
// 	Similarly the SDRAM output
// 	"cs" is not used because
// 	it is assumed that it has
// 	been set low.


// Only one of the macro below
// must be uncommented to use
// the desired SDRAM type.
//`define SDRAMSDR
//`define SDRAMLPDDR1

`ifdef SDRAMSDR
`include "sdr.sdram.v"
`elsif SDRAMLPDDR1
`include "lpddr1.sdram.v"
`elsif SIMULATION
`include "simul.sdram.v"
`else
`SDRAMSDR
`endif

`include "lib/fifo.v"

module sdram (
	
	rst,
	
	clk,
	phyclk,
	
	memop,
	memaddr,
	memdatain,
	memdataout,
	membyteselect,
	memrdy,
	memmapsz
	
	`ifndef SIMULATION
	,ck,
	ras, cas, we,
	ba,
	a,
	dq_i,
	dq_o,
	dq_t,
	dm
	`ifndef SDRAMSDR
	,dqs
	`endif
	`endif
);

`include "lib/clog2.v"

parameter PHYCLKFREQ = 0;
parameter CACHESIZE = 0;
parameter POWERONDELAY = 0;
parameter TCK = 0;
parameter TREFI = 0;
parameter TRFC = 0;
parameter TRCD = 0;
parameter TWR = 0;
parameter TRP = 0;
parameter TMRD = 0;
parameter CASLATENCY = 0;
parameter BURSTLENGTH = 0;
parameter BANKCOUNT = 0;
parameter ROWCOUNT = 0;
parameter COLUMNCOUNT = 0;
parameter ABITSIZE = 0;
parameter DQBITSIZE = 0;

parameter SIZEOFPHYBA = clog2(BANKCOUNT);
parameter SIZEOFPHYA = ABITSIZE;
parameter SIZEOFPHYDQ = DQBITSIZE;
parameter SIZEOFPHYDM = (SIZEOFPHYDQ/8);
`ifndef SDRAMSDR
parameter SIZEOFPHYDQS = (SIZEOFPHYDQ/8);
`endif
parameter SIZEOFPHYADDR = clog2(ROWCOUNT) + clog2(BANKCOUNT) + (clog2(COLUMNCOUNT) - clog2(BURSTLENGTH));
parameter SIZEOFPHYDATAOUT = DQBITSIZE * BURSTLENGTH;
parameter SIZEOFPHYDATAMASK = (SIZEOFPHYDATAOUT/8);

parameter SIZEOFMEMADDR = (SIZEOFPHYADDR + ((SIZEOFPHYDATAOUT>32) ? clog2(SIZEOFPHYDATAOUT/32) : 0));

input rst;

input clk;
input phyclk;

input[2 -1 : 0] memop;
input[SIZEOFMEMADDR -1 : 0] memaddr;
input[32 -1 : 0] memdatain;
output[32 -1 : 0] memdataout;
input[4 -1 : 0] membyteselect;
output memrdy;
output[30 -1 : 0] memmapsz;

`ifndef SIMULATION
output ck;
output ras; output cas; output we;
output[SIZEOFPHYBA -1 : 0] ba;
output[SIZEOFPHYA -1 : 0] a;
input[SIZEOFPHYDQ -1 : 0] dq_i;
output[SIZEOFPHYDQ -1 : 0] dq_o;
output dq_t;
output[SIZEOFPHYDM -1 : 0] dm;
`ifndef SDRAMSDR
inout[SIZEOFPHYDQS -1 : 0] dqs;
`endif
`endif


// Register holding
// the value of the
// output "memdataout".
reg[32 -1 : 0] memdataout;

// Register holding
// the value of the
// output "memrdy".
reg memrdy;


// Size of the SDRAM memory
// in multiples of 4 bytes.
assign memmapsz = (1 << SIZEOFMEMADDR);


// Memory interface operations.
localparam MEMNOOP		= 2'b00;
localparam MEMWRITEOP		= 2'b01;
localparam MEMREADOP		= 2'b10;
localparam MEMREADWRITEOP	= 2'b11;


// This register is set to 1,
// when the memory operation
// issued was MEMREADWRITEOP
// and there was a cachemiss;
// it is used to insure that
// reading complete before writing.
reg memwritependingread;

// The net sdramreadrqstdone is 1,
// when a request to retrieve data
// from the SDRAM has completed.
// The registers sdramreadrqstdonea
// and sdramreadrqstdoneb are used
// so that two combinational
// logics driven by two different
// clock can be used to set
// the value of sdramreadrqstdone.
// sdramreadrqstdonea is driven by
// the clock input "phyclk" while
// sdramreadrqstdoneb is driven
// by the clock input "clk".
reg sdramreadrqstdonea, sdramreadrqstdoneb;
wire sdramreadrqstdone = (sdramreadrqstdonea != sdramreadrqstdoneb);

// Net set to 1, when
// a hit is found in
// the cache.
wire cachehit;

always @(posedge clk) begin
	// Logic that update memwritependingread.
	if (rst || sdramreadrqstdone) memwritependingread <= 0;
	else if (memop == MEMREADWRITEOP && memrdy && !cachehit) memwritependingread <= 1;
end


// This register is set to 1,
// when data was read from
// the buffers used for
// writing the SDRAM.
reg sdrambufferwasread;


// Number of cache elements.
parameter CACHESETCOUNT = (CACHESIZE / (SIZEOFPHYDATAOUT/8));


wire[(clog2(CACHESETCOUNT) +1) -1 : 0] sdrambufferusage;

// Note that when memwritependingread,
// and sdrambufferusage == 1,
// the buffered data is for the
// writing of the MEMREADWRITEOP
// which will be done after the
// reading is complete.
wire sdrambufferreadenable = (sdrambufferusage && !sdrambufferwasread && (!memwritependingread || sdrambufferusage != 1));

wire sdrambufferwriteenable = ((memop == MEMWRITEOP || memop == MEMREADWRITEOP) && memrdy);


wire[SIZEOFPHYADDR -1 : 0] sdramaddrbufferdataout;

wire[SIZEOFPHYADDR -1 : 0] memaddrshiftedright = (memaddr >> clog2(SIZEOFPHYDATAOUT/32));
// If (SIZEOFPHYDATAOUT)
// is greater than sizeof(memdataout),
// shifting is done to get
// the proper value to buffer.
wire[SIZEOFPHYADDR -1 : 0] sdramaddrbufferdatain = (SIZEOFPHYDATAOUT>32) ? memaddrshiftedright : memaddr;

fifo #(
	.DATABITSIZE (SIZEOFPHYADDR),
	.BUFFERSIZE (CACHESETCOUNT)
	
) sdramaddrbuffer (
	
	.rst (rst),
	
	.readclk (phyclk),
	.readenable (sdrambufferreadenable),
	.dataout (sdramaddrbufferdataout),
	
	.writeclk (clk),
	.writeenable (sdrambufferwriteenable),
	.datain (sdramaddrbufferdatain)
);


wire[SIZEOFPHYDATAOUT -1 : 0] sdramdatabufferdataout;

// ### Zero-extension is done before
// shifting to the left so that verilog
// correctly preserve the bits being
// shifted to the left.
wire[SIZEOFPHYDATAOUT -1 : 0] memdatainshiftedleft = {{{SIZEOFPHYDATAOUT{1'b0}}, memdatain} << (32*memaddr[clog2(SIZEOFPHYDATAOUT/32) -1 : 0])};
// If (SIZEOFPHYDATAOUT)
// is greater than sizeof(memdataout),
// shifting is done to get
// the proper value to buffer.
wire[SIZEOFPHYDATAOUT -1 : 0] sdramdatabufferdatain = (SIZEOFPHYDATAOUT>32) ? memdatainshiftedleft : memdatain;

fifo #(
	.DATABITSIZE (SIZEOFPHYDATAOUT),
	.BUFFERSIZE (CACHESETCOUNT)
	
) sdramdatabuffer (
	
	.rst (rst),
	
	.usage (sdrambufferusage),
	
	.readclk (phyclk),
	.readenable (sdrambufferreadenable),
	.dataout (sdramdatabufferdataout),
	
	.writeclk (clk),
	.writeenable (sdrambufferwriteenable),
	.datain (sdramdatabufferdatain)
);


wire[SIZEOFPHYDATAMASK -1 : 0] sdramdatamaskbufferdataout;

// ### Zero-extension is done before
// shifting to the left so that verilog
// correctly preserve the bits being
// shifted to the left.
wire[SIZEOFPHYDATAMASK -1 : 0] membyteselectshiftedleft = {{{SIZEOFPHYDATAMASK{1'b0}}, membyteselect} << (4*memaddr[clog2(SIZEOFPHYDATAOUT/32) -1 : 0])};
// If (SIZEOFPHYDATAOUT)
// is greater than sizeof(memdataout),
// shifting is done to get
// the proper value to buffer.
wire[SIZEOFPHYDATAMASK -1 : 0] sdramdatamaskbufferdatain = ~((SIZEOFPHYDATAOUT>32) ? membyteselectshiftedleft : membyteselect);

fifo #(
	.DATABITSIZE (SIZEOFPHYDATAMASK),
	.BUFFERSIZE (CACHESETCOUNT)
	
) sdramdatamaskbuffer (
	
	.rst (rst),
	
	.readclk (phyclk),
	.readenable (sdrambufferreadenable),
	.dataout (sdramdatamaskbufferdataout),
	
	.writeclk (clk),
	.writeenable (sdrambufferwriteenable),
	.datain (sdramdatamaskbufferdatain)
);


// Register used to save the
// value of the input "memaddr"
// for later use, when a MEMREADOP
// or MEMREADWRITEOP is issued.
reg[SIZEOFMEMADDR -1 : 0] memaddrsaved;

always @(posedge clk) begin
	
	if ((memop == MEMREADOP || memop == MEMREADWRITEOP) && memrdy)
		memaddrsaved <= memaddr;
end


// The net sdramreadrqst is 1,
// when a request to retrieve
// data from the SDRAM is made.
// The registers sdramreadrqsta
// and sdramreadrqstb are used
// so that two combinational
// logics driven by two different
// clock can be used to set
// the value of sdramreadrqst.
// sdramreadrqsta is driven by
// the clock input "clk" while
// sdramreadrqstb is driven by
// the clock input "phyclk".
reg sdramreadrqsta, sdramreadrqstb;
wire sdramreadrqst = (sdramreadrqsta != sdramreadrqstb);

// Register set to 1
// when reading data
// from the SDRAM.
reg sdramreading;

// Register set to 1
// when writing data
// to the SDRAM.
reg sdramwriting;

// Note that "sdramread"
// is not raised until all
// data in the buffer, used
// for writing the SDRAM,
// has been written; if a
// MEMREADWRITEOP was issued,
// "sdramread" is not raised
// until there is one item left
// in the buffer used for writing
// the SDRAM; that one item left
// is for the data to write in
// the SDRAM immediately after
// the read has completed.
wire sdramread = (!sdramreading && sdramreadrqst && !sdrambufferwasread && !sdramwriting &&
	((memwritependingread && sdrambufferusage == 1) || (!memwritependingread && !sdrambufferusage)));

wire sdramwrite = (!sdramwriting && sdrambufferwasread && !sdramreading);

wire sdramdone;

wire[SIZEOFPHYADDR -1 : 0] memaddrsavedshiftedright = (memaddrsaved >> clog2(SIZEOFPHYDATAOUT/32));
// If (SIZEOFPHYDATAOUT)
// is greater than sizeof(memdataout),
// memaddrsaved get shifted in order
// to get the proper value.
wire[SIZEOFPHYADDR -1 : 0] sdramaddr = (SIZEOFPHYDATAOUT>32) ?
	(sdramread ? memaddrsavedshiftedright : sdramaddrbufferdataout) :
	(sdramread ? memaddrsaved : sdramaddrbufferdataout);

wire[SIZEOFPHYDATAOUT -1 : 0] sdramdataout;

// Instantiate the SDRAM phy.
// phy.dataout must be >= 32;
// phy.addr must be <= (30 - ((sizeof(sdramphy.dataout)>32) ? clog2(sizeof(sdramphy.dataout)/32) : 0));
sdramphy #(
	
	.CLKFREQ	(PHYCLKFREQ),
	.POWERONDELAY	(POWERONDELAY),
	.TCK		(TCK),
	.TREFI		(TREFI),
	.TRFC		(TRFC),
	.TRCD		(TRCD),
	.TWR		(TWR),
	.TRP		(TRP),
	.TMRD		(TMRD),
	.CASLATENCY	(CASLATENCY),
	.BURSTLENGTH	(BURSTLENGTH),
	.BANKCOUNT	(BANKCOUNT),
	.ROWCOUNT	(ROWCOUNT),
	.COLUMNCOUNT	(COLUMNCOUNT),
	.ABITSIZE	(ABITSIZE),
	.DQBITSIZE	(DQBITSIZE)
	
) sdram (
	
	.rst (rst),
	
	.clk (phyclk),
	
	`ifndef SIMULATION
	.ck (ck),
	.ras (ras),
	.cas (cas),
	.we (we),
	.ba (ba),
	.a (a),
	.dq_i (dq_i),
	.dq_o (dq_o),
	.dq_t (dq_t),
	.dm (dm),
	`ifndef SDRAMSDR
	.dqs (dqs),
	`endif
	`endif
	
	.read (sdramread),
	.write (sdramwrite),
	.done (sdramdone),
	
	.addr (sdramaddr),
	.datain (sdramdatabufferdataout),
	.datamask (sdramdatamaskbufferdataout),
	.dataout (sdramdataout)
);


// Register used to save
// the state of "sdram.done"
// in order to detect its
// rising or falling edge.
reg sdramdonesampled;

// Logic that set the net
// sdramdoneposedge when
// a rising edge of
// "sdram.done" occur.
wire sdramdoneposedge = (sdramdone > sdramdonesampled);

// Logic that set the net
// sdramdonenegedge when
// a falling edge of
// "sdram.done" occur.
wire sdramdonenegedge = (sdramdone < sdramdonesampled);

always @(posedge phyclk) begin
	// Logic that update sdrambufferwasread.
	if (rst || sdramdonenegedge) sdrambufferwasread <= 0;
	else if (sdrambufferreadenable) sdrambufferwasread <= 1;
	
	// Logic that update sdramreading.
	if (rst) sdramreading <= 0;
	else if (sdramreading) begin
		
		if (sdramdoneposedge) sdramreading <= 0;
		
	end else if (sdramread && sdramdonenegedge)
		sdramreading <= 1;
	
	// Logic that update sdramwriting.
	if (rst) sdramwriting <= 0;
	else if (sdramwriting) begin
		
		if (sdramdoneposedge) sdramwriting <= 0;
		
	end else if (sdramwrite && sdramdonenegedge)
		sdramwriting <= 1;
	
	// Logic setting sdramreadrqst to 0.
	if (rst || (sdramreading && sdramdoneposedge))
		sdramreadrqstb <= sdramreadrqsta;
	
	// Logic setting sdramreadrqstdone to 1.
	if (sdramreading && sdramdoneposedge)
		sdramreadrqstdonea <= ~sdramreadrqstdoneb;
	
	// Save the current
	// state of sdramdone.
	sdramdonesampled <= sdramdone;
end


// Bitsize of a cache tag.
parameter CACHETAGBITSIZE = ((SIZEOFMEMADDR+2) - clog2(CACHESIZE));

// Registers storing
// the cache tags.
reg[CACHETAGBITSIZE -1 : 0] cachetags[CACHESETCOUNT -1 : 0];

// Registers storing
// the cache datas.
reg[SIZEOFPHYDATAOUT -1 : 0] cachedatas[CACHESETCOUNT -1 : 0];

// The caching is 1way set associative.

// Net set to the tag
// value being compared
// for a cache hit.
wire[CACHETAGBITSIZE -1 : 0] cachetag = sdramreadrqstdone ?
	memaddrsaved[SIZEOFMEMADDR -1 : (SIZEOFMEMADDR - CACHETAGBITSIZE)] :
	memaddr[SIZEOFMEMADDR -1 : (SIZEOFMEMADDR - CACHETAGBITSIZE)];

// Net set to the index
// of the cache element
// being compared.
wire[clog2(CACHESETCOUNT) -1 : 0] cacheset = sdramreadrqstdone ?
	memaddrsaved[(SIZEOFMEMADDR - CACHETAGBITSIZE) -1 : ((SIZEOFMEMADDR - CACHETAGBITSIZE) - clog2(CACHESETCOUNT))] :
	memaddr[(SIZEOFMEMADDR - CACHETAGBITSIZE) -1 : ((SIZEOFMEMADDR - CACHETAGBITSIZE) - clog2(CACHESETCOUNT))];

// Net set to the value
// of a cache data indexed
// using the net "cacheset".
wire[SIZEOFPHYDATAOUT -1 : 0] cachedataout = cachedatas[cacheset];

// Register used to save the
// value of cachedatainbitselect
// when MEMREADWRITEOP is issued.
reg[SIZEOFPHYDATAOUT -1 : 0] cachedatainbitselectsaved;

// ### Zero-extension is done before
// shifting to the left so that verilog
// correctly preserve the bits being
// shifted to the left.
wire[SIZEOFPHYDATAOUT -1 : 0] membyteselectexpandedandshiftedleft = {{{SIZEOFPHYDATAOUT{1'b0}}, {8{membyteselect[3]}}, {8{membyteselect[2]}}, {8{membyteselect[1]}}, {8{membyteselect[0]}}} << (32*memaddr[clog2(SIZEOFPHYDATAOUT/32) -1 : 0])};
wire[SIZEOFPHYDATAOUT -1 : 0] membyteselectexpanded = {{8{membyteselect[3]}}, {8{membyteselect[2]}}, {8{membyteselect[1]}}, {8{membyteselect[0]}}};
// Net set to a bitmask used
// to modify only a portion
// of a cache data.
wire[SIZEOFPHYDATAOUT -1 : 0] cachedatainbitselect = sdramreadrqstdone ? ~cachedatainbitselectsaved :
	// If (SIZEOFPHYDATAOUT)
	// is greater than sizeof(memdataout),
	// shifting is done to get the proper
	// value to write in the SDRAM.
	(SIZEOFPHYDATAOUT>32) ? membyteselectexpandedandshiftedleft : membyteselectexpanded;

// Net set to the value
// to write in the cache.
wire[SIZEOFPHYDATAOUT -1 : 0] cachedatain = ((sdramreadrqstdone ? sdramdataout : sdramdatabufferdatain) & cachedatainbitselect) |
	(cachedataout & ~cachedatainbitselect);

// Registers storing
// the cache bitselect.
reg[SIZEOFPHYDATAOUT -1 : 0] cachedatabitselects[CACHESETCOUNT -1 : 0];

// Net set to the value of
// a cache bitselect indexed
// using the net "cacheset".
wire[SIZEOFPHYDATAOUT -1 : 0] cachedatabitselect = cachedatabitselects[cacheset];

wire cachetaghit = (cachetag == cachetags[cacheset]);

// There is a cache hit when
// there is a cache tag hit
// and the selected bits
// are in the cache.
assign cachehit = (cachetaghit && ((cachedatainbitselect & cachedatabitselect) == cachedatainbitselect));


wire[SIZEOFPHYDATAOUT -1 : 0] sdramdataoutshiftedright = {sdramdataout >> (32*memaddrsaved[clog2(SIZEOFPHYDATAOUT/32) -1 : 0])};
wire[SIZEOFPHYDATAOUT -1 : 0] cachedataoutshiftedright = {cachedataout >> (32*memaddr[clog2(SIZEOFPHYDATAOUT/32) -1 : 0])};

always @(posedge clk) begin
	// Logic that update memrdy.
	if (rst) begin
		// Reset logic.
		
		memrdy <= 1;
		
	end else if (!memrdy) begin
		// In this state, I wait
		// that the data request
		// from the SDRAM complete.
		
		// When writing, memrdy should not
		// be set to 1 until the buffer,
		// used for writing the SDRAM,
		// is no longer full, because when
		// memrdy == 1, it is assumed that
		// it is possible to add data to the
		// buffer used for writing the SDRAM.
		// The check for (!sdramreadrqst)
		// insure that memrdy is not set
		// to 1 while waiting for a read
		// from the SDRAM to complete.
		// Note that when a request was
		// made to read from the SDRAM,
		// the actual read do not occur
		// until all data, already in
		// the buffer, used for writing
		// the SDRAM, have been written.
		if (sdramreadrqstdone || (!sdramreadrqst && (sdrambufferusage != CACHESETCOUNT)))
			memrdy <= 1;
		
	end else if (memop == MEMREADOP) begin
		// memrdy is set to 0 if
		// there was a cachemiss.
		memrdy <= cachehit;
		
	end else if (memop == MEMWRITEOP) begin
		// memrdy is set to 0 if
		// the data to write in
		// the SDRAM will make
		// its buffer full.
		memrdy <= (sdrambufferusage != (CACHESETCOUNT-1));
		
	end else if (memop == MEMREADWRITEOP) begin
		// memrdy is set to 0 if
		// there was a cachemiss
		// or if the data to write
		// in the SDRAM will make
		// its buffer full.
		memrdy <= (cachehit && (sdrambufferusage != (CACHESETCOUNT-1)));
	end
	
	
	// Logic that retrieve the data to
	// set on the output "memdataout".
	if (!memrdy) begin
		
		if (sdramreadrqstdone) begin
			// If (SIZEOFPHYDATAOUT)
			// is greater than sizeof(memdataout),
			// shifting is done to get the proper
			// value from the SDRAM.
			memdataout <= ((SIZEOFPHYDATAOUT>32) ? sdramdataoutshiftedright[32 -1 : 0] : sdramdataout[32 -1 : 0]);
		end
		
	end else if (memop == MEMREADOP || memop == MEMREADWRITEOP) begin
		// If (SIZEOFPHYDATAOUT)
		// is greater than sizeof(memdataout),
		// shifting is done to get the proper
		// value from the cache.
		memdataout <= ((SIZEOFPHYDATAOUT>32) ? cachedataoutshiftedright[32 -1 : 0] : cachedataout[32 -1 : 0]);
		
		// If there was a cachemiss,
		// I request the data from
		// the SDRAM.
		if (!cachehit) sdramreadrqsta <= ~sdramreadrqstb;
	end
	
	
	// Logic that write in the cache.
	if (sdramreadrqstdone || sdrambufferwriteenable) begin
		
		cachetags[cacheset] <= cachetag;
		
		cachedatas[cacheset] <= cachedatain;
		
		cachedatabitselects[cacheset] <= ((cachetaghit ? cachedatabitselect : {SIZEOFPHYDATAOUT{1'b0}}) | cachedatainbitselect);
	end
	
	
	// Logic that set cachedatainbitselectsaved.
	if (memrdy) begin
		// Save the cachedatainbitselect used
		// if the memory operation was MEMREADWRITEOP;
		// and if there was a cache miss, it allow
		// to save in the cache the data requested
		// from the SDRAM without overwritting what was
		// written in the cache at the time of the request.
		cachedatainbitselectsaved <= ((memop == MEMREADWRITEOP) ? cachedatainbitselect : {SIZEOFPHYDATAOUT{1'b0}});
	end
	
	
	// Set sdramreadrqstdone to 0.
	sdramreadrqstdoneb <= sdramreadrqstdonea;
end


`ifdef SIMULATION
integer ii, jj;

initial begin
	
	memdataout = 0;
	
	memrdy = 0;
	
	memwritependingread = 0;
	
	sdramreadrqstdonea = 0;
	sdramreadrqstdoneb = 0;
	
	sdrambufferwasread = 0;
	
	memaddrsaved = 0;
	
	sdramreading = 0;
	
	sdramwriting = 0;
	
	sdramdonesampled = 0;
	
	sdramreadrqsta = 0;
	sdramreadrqstb = 0;
	
	for (ii = 0, jj = 32'haaaaaaaa; ii < CACHESETCOUNT; ii = ii + 1, jj = ~jj) begin
		cachetags[ii] = {(SIZEOFPHYDATAOUT/32){jj}};
		cachedatas[ii] = {(SIZEOFPHYDATAOUT/32){~32'd0}};
		cachedatabitselects[ii] = {(SIZEOFPHYDATAOUT/32){jj}};
	end
	
	cachedatainbitselectsaved = 0;
end
`endif


endmodule
