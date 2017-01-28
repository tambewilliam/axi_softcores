
// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// SDR SDRAM controller.

// An SDRAM has one or more
// banks accessed one at a time;
// each bank has multiple plane,
// and the number of plane is
// the number of bits per data,
// because a single bit is retrieved
// from each plane simultaneously;
// each plane has rows which
// are accessed one at a time;
// each row has columns which
// are accessed one at a time.
// To access data, a command
// is sent to select a bank
// and the same row in every plane,
// then another command is sent
// to access the same column in
// every plane, effectively
// accessing a single bit from
// each plane simultaneously.


// Parameters.
// 
// CLKFREQ:
// 	Frequency of the clock
// 	input "clk" in Hz.
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
// 	Clock signal.
// 
// output ck
// output ras
// output cas
// output we
// output[clog2(BANKCOUNT)] ba
// output[ABITSIZE] a
// inout[DQBITSIZE] dq
// output[DQBITSIZE / 8] dm
// 	SDRAM signals.
// 	The SDRAM signal "cke" is not
// 	used because it is assumed
// 	that it has been set high.
// 	Similarly the SDRAM output
// 	"cs" is not used because
// 	it is assumed that it has
// 	been set low.
// 
// input read
// input write
// output done
// input[clog2(ROWCOUNT) + clog2(BANKCOUNT) + (clog2(COLUMNCOUNT) - clog2(BURSTLENGTH))] addr
// input[DQBITSIZE * BURSTLENGTH] datain
// input[(DQBITSIZE * BURSTLENGTH) / 8] datamask
// output[DQBITSIZE * BURSTLENGTH] dataout
// 	Interface to perform
// 	read/write accesses
// 	from/to the SDRAM.
// 	The input "addr" is the
// 	data index within the SDRAM,
// 	so memory accesses are aligned
// 	to the bitsize of the ports
// 	"datain" and "dataout".
// 	When the input "read" is
// 	set high, a single data
// 	at the index given by
// 	the input "addr" is
// 	read from the SDRAM and
// 	set on the output "dataout".
// 	When the output "write" is
// 	set high, the data on the
// 	input "datain", with masking
// 	using the input "datamask",
// 	is written at the index
// 	given by the input "addr".
// 	Each bit from the input
// 	"datamask" correspond respectively
// 	to each byte in the input "datain",
// 	and when a bit from the input
// 	"datamask" is 1, its corresponding
// 	byte from the input "datain"
// 	do not get written to the SDRAM.
// 	When the input "read" is high,
// 	the input "write" is ignored
// 	if it is also high.
// 	The output "done" is high
// 	whenever the previous read
// 	or write operation completed,
// 	and it is low while a read or
// 	write operation is on-going.
// 	When performing a memory access,
// 	the input "read" or "write"
// 	must be held high until the
// 	falling edge of the output
// 	"done"; and both must be held
// 	low until the rising edge
// 	of the output "done" which
// 	indicate the completion
// 	of the memory access.

// In a system where multiple
// SDRAM are used, the least
// significant bits of the address
// must be used to index an SDRAM,
// to help each SDRAM wear evenly,
// since most memory accesses
// are consecutive.
// The input "cs" of the indexed
// SDRAM must be low, and for the
// other SDRAM it must be high.
// Similarly, to help each bank
// within the SDRAM wear evenly,
// the least significant bits
// of the address are used
// to index a bank.


module sdramphy (
	
	rst,
	
	clk,
	
	ck,
	ras, cas, we,
	ba,
	a,
	dq_i,
	dq_o,
	dq_t,
	dm,
	
	read,
	write,
	done,
	
	addr,
	
	datain,
	datamask,
	dataout
);

`include "lib/clog2.v"

parameter CLKFREQ = 0;
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

input rst;

input clk;

output reg ck;
output reg ras; output reg cas; output reg we;
output reg[clog2(BANKCOUNT) -1 : 0] ba;
output reg[ABITSIZE -1 : 0] a;
input[DQBITSIZE -1 : 0] dq_i;
output[DQBITSIZE -1 : 0] dq_o;
output dq_t;
output reg[(DQBITSIZE / 8) -1 : 0] dm;

input read;
input write;
output reg done;

input[(clog2(ROWCOUNT) + clog2(BANKCOUNT) + (clog2(COLUMNCOUNT) - clog2(BURSTLENGTH))) -1 : 0] addr;

input[(DQBITSIZE * BURSTLENGTH) -1 : 0] datain;
input[((DQBITSIZE * BURSTLENGTH) / 8) -1 : 0] datamask;
output[(DQBITSIZE * BURSTLENGTH) -1 : 0] dataout;

genvar i;

// Register holding the value
// of the output "dataout".
reg[DQBITSIZE -1 : 0] dataoutcasted[BURSTLENGTH -1 : 0];
generate for (i = 0; i < BURSTLENGTH; i = i + 1) begin: gendataout // gendataout is just a label that verilog want to see; and it is not used anywhere.
assign dataout[(DQBITSIZE * (i + 1)) -1 : DQBITSIZE * i] = dataoutcasted[i];
end endgenerate


// Register which when 0,
// make the inout "dq" high-z
// so that it can be driven
// by the SDRAM.
reg dqe;

// Register holding the value
// set on the output "dq".
reg[DQBITSIZE -1 : 0] dqval;

// Logic setting the inout "dq".
//assign dq = dqe ? dqval : {DQBITSIZE{1'bz}};
assign dq_t = ~dqe; // Active-Low TriState Enable.
assign dq_o = dqval;



// Register which will be used
// to sample the input "datain".
reg[(DQBITSIZE * BURSTLENGTH) -1 : 0] datainsample;
wire[DQBITSIZE -1 : 0] datainsamplecasted[BURSTLENGTH -1 : 0];
generate for (i = 0; i < BURSTLENGTH; i = i + 1) begin: gendatainsample // gendatainsample is just a label that verilog want to see; and it is not used anywhere.
assign datainsamplecasted[i] = datainsample[(DQBITSIZE * (i + 1)) -1 : DQBITSIZE * i];
end endgenerate

// Register which will be used
// to sample the input "datamask".
reg[((DQBITSIZE * BURSTLENGTH) / 8) -1 : 0] datamasksample;
wire[(DQBITSIZE / 8) -1 : 0] datamasksamplecasted[BURSTLENGTH -1 : 0];
generate for (i = 0; i < BURSTLENGTH; i = i + 1) begin: gendatamasksample // gendatamasksample is just a label that verilog want to see; and it is not used anywhere.
assign datamasksamplecasted[i] = datamasksample[((DQBITSIZE / 8) * (i + 1)) -1 : (DQBITSIZE / 8) * i];
end endgenerate


// Register which will be used
// to set the SDRAM signal "ba"
// when the bank address is needed.
reg[clog2(BANKCOUNT) -1 : 0] bank;

// Register which will be used
// to set the SDRAM signal "a"
// when the row address is needed.
reg[clog2(ROWCOUNT) -1 : 0] row;

// Register which will be used
// to set the SDRAM signal "a"
// when the column address is needed.
// "- clog2($BURSTLENGTH)"
// represent the burst length,
// hence memory accesses are
// aligned to a bitcount of:
// ($DQBITSIZE * $BURSTLENGTH).
reg[(clog2(COLUMNCOUNT) - clog2(BURSTLENGTH)) -1 : 0] column;


wire[(ABITSIZE+clog2(ROWCOUNT)) -1 : 0] rowzeroextended = {{ABITSIZE{1'b0}}, row};

wire[(ABITSIZE+(clog2(COLUMNCOUNT)-clog2(BURSTLENGTH))) -1 : 0] columnzeroextended = {{ABITSIZE{1'b0}}, column};

wire[ABITSIZE -1 : 0] aconcatenated = (clog2(COLUMNCOUNT) > 10) ?
	{{ABITSIZE{1'b0}}, columnzeroextended[(clog2(COLUMNCOUNT)-clog2(BURSTLENGTH)) -1 : 10-clog2(BURSTLENGTH)], 1'b1, columnzeroextended[9-clog2(BURSTLENGTH):0], {clog2(BURSTLENGTH){1'b0}}} :
	{{ABITSIZE{1'b0}}, 1'b1, columnzeroextended[9-clog2(BURSTLENGTH):0], {clog2(BURSTLENGTH){1'b0}}};


// Constants used with
// the register state.

// When in this state,
// the controller is
// waiting for the clock
// cycle delay set in the
// register counter.
parameter WAIT =	0;

// When in these states,
// the controller is
// initializing the SDRAM.
parameter INIT0 =	1;
parameter INIT1 =	2;
parameter INIT2 =	3;

// When in this state,
// the controller is ready
// to accept a read or write
// operation.
parameter READY =	4;

// When in this state,
// the controller issue
// the command REFRESH.
parameter REFRESH =	5;

// When in this state,
// the controller issue
// the command which will
// open a bank for a subsequent
// command READ or WRITE.
parameter ACTIVATE =	6;

// When in these states,
// the controller is reading
// data from the SDRAM.
parameter READ0 =	7;
parameter READ1 =	8;
parameter READ2 =	9;

// When in these states,
// the controller is writing
// data to the SDRAM.
parameter WRITE0 =	10;
parameter WRITE1 =	11;
parameter WRITE2 =	12;


// Number of states
// used by the phy.
// There are currently
// less than 16 states.
parameter STATECOUNT = 16;

// Register used to hold the
// current state of the controller.
reg[clog2(STATECOUNT) -1 : 0] state;

// Register used to hold the
// pending state of the controller.
reg[clog2(STATECOUNT) -1 : 0] statepending;


// Register used as the controller counter.
// The largest value that it will be set to,
// is the clock cycle count equivalent of
// the poweron delay.
reg[clog2(CLKFREQ / POWERONDELAY) -1 : 0] counter;


// Register used to detect
// a rising edge on the
// SDRAM signal "ck".
reg cksample;
wire ckposedge = (ck && !cksample);

// Register used to keep track of
// the period of the SDRAM signal "ck".
reg[(clog2(CLKFREQ / TCK) + 1) -1 : 0] ckcounter;


// Register used to keep track
// of the duration between the
// issuance of the command REFRESH.
reg[(clog2(CLKFREQ / TREFI) + 1) -1 : 0] refreshcounter;

// Register set to 1 when
// it is needed to issue
// the command REFRESH.
reg refreshneeded;


always @(posedge clk) begin
	// Logic sampling the
	// SDRAM signal "ck".
	cksample <= ck;
	
	// Logic setting the register
	// for the output "ck".
	if (ckcounter >= (CLKFREQ / TCK)) begin
		
		ck <= ~ck;
		
		ckcounter <= 0;
		
	end else ckcounter <= ckcounter + 1'b1;
	
	// Logic setting the register refreshcounter.
	if (refreshcounter >= (CLKFREQ / TREFI))
		refreshcounter <= 0;
	else refreshcounter <= refreshcounter + 1'b1;
	
	// Logic setting the register refreshneeded.
	if (state == REFRESH) refreshneeded <= 0;
	else if (!refreshcounter) refreshneeded <= 1;
	
	// Controller logic.
	if (rst) begin
		// Reset logic.
		
		// Set command NOP.
		ras <= 1; cas <= 1; we <= 1;
		
		// Set the SDRAM signal "dq" high-z.
		dqe <= 0;
		
		done <= 1;
		
		// Set the register
		// counter to its
		// largest value which
		// is the number of
		// clock cycles for
		// the poweron delay.
		counter <= {clog2(CLKFREQ / POWERONDELAY){1'b1}};
		
		// I move onto the state
		// which will start the
		// SDRAM initialization
		// after waiting for
		// the poweron delay.
		state <= WAIT;
		statepending <= INIT0;
		
	end else if (state == WAIT) begin
		// In this state, I wait for
		// the clock cycle delay set
		// in the register counter.
		
		if (ckposedge) begin
			// Set command NOP.
			ras <= 1; cas <= 1; we <= 1;
		end
		
		// Since I wait for the output "ck"
		// to be high before setting the new
		// command, the register counter
		// must be at least 1 to guaranty
		// that the command NOP will be set.
		
		if (!counter) begin
			// I move onto the next state.
			state <= statepending;
		end
		
		counter <= counter - 1'b1;
		
	end else if (state == INIT0) begin
		// In this state, I issue
		// the command which will
		// close all banks.
		
		if (ckposedge) begin
			// Set command PRECHARGE.
			ras <= 0; cas <= 1; we <= 0;
			
			// Set the SDRAM signal a[10]
			// high to close all banks.
			a[10] <= 1;
			
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the delay TRP.
			counter <= (CLKFREQ / TRP);
			
			// I move onto the state which
			// will wait the delay TRP.
			state <= WAIT;
			statepending <= INIT1;
			
			// dqval is temporarily used
			// to keep track of the number of
			// REFRESH to issue during INIT1.
			dqval <= 8;
			// Some SDR SDRAM use less
			// REFRESH during init.
			// 8 is the highest value
			// seen so far.
		end
		
	end else if (state == INIT1) begin
		// In this state, I issue
		// the command REFRESH until
		// dqval become null.
		state <= REFRESH;
		
		if (!dqval) begin
			// If I get here, I am done
			// issuing the REFRESH.
			// I move onto the state which
			// will issue the command
			// LOAD MODE REGISTER.
			statepending <= INIT2;
		end
		
		dqval <= dqval - 1'b1;
		
	end else if (state == INIT2) begin
		// In this state, I issue
		// the command which will
		// load mode registers.
		
		if (ckposedge) begin
			// Set command LOAD MODE REGISTER.
			ras <= 0; cas <= 0; we <= 0;
			
			// The value set on the SDRAM
			// signals "ba" and "a" is
			// the mode register value.
			
			ba <= 'b00;
			
			a <= {{(ABITSIZE - 7){1'b0}}, CASLATENCY[2:0], 1'b0, {
				(BURSTLENGTH == 1) ? 3'b000 :
				(BURSTLENGTH == 2) ? 3'b001 :
				(BURSTLENGTH == 4) ? 3'b010 :
				3'b011}};
			
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the delay TMRD.
			counter <= (CLKFREQ / TMRD);
			
			// I move onto the state which
			// will wait the delay TMRD.
			state <= WAIT;
			
			// After the mode registers have
			// has been loaded, I move onto
			// the state in which the
			// controller is ready to
			// accept operations.
			statepending <= READY;
		end
		
	end else if (state == READY) begin
		// In this state I wait for
		// a read or write request,
		// or a needed refresh.
		
		// Addressing is done as follow
		// from the msb to the lsb:
		// | row | bank | column |
		// Using the least significant
		// bits to first index the bank
		// before the row, help each
		// bank to wear evenly, since
		// most memory accesses are
		// consecutives.
		
		column <= addr[(clog2(COLUMNCOUNT) - clog2(BURSTLENGTH)) -1 : 0];
		
		bank <= addr[(clog2(BANKCOUNT) + (clog2(COLUMNCOUNT) - clog2(BURSTLENGTH))) -1 :
			clog2(COLUMNCOUNT) - clog2(BURSTLENGTH)];
		
		row <= addr[(clog2(ROWCOUNT) + clog2(BANKCOUNT) + (clog2(COLUMNCOUNT) - clog2(BURSTLENGTH))) -1 :
			clog2(BANKCOUNT) + (clog2(COLUMNCOUNT) - clog2(BURSTLENGTH))];
		
		// I sample the input "datain".
		datainsample <= datain;
		
		// I sample the input "datamask".
		datamasksample <= datamask;
		
		// Logic setting the output "done".
		done <= (refreshneeded || !(read || write));
		
		if (refreshneeded) begin
			// I move onto the state
			// which will issue
			// the command REFRESH.
			state <= REFRESH;
			statepending <= READY;
			
		end else if (read) begin
			// I move onto the state
			// which will issue
			// the command READ after
			// the bank has been opened.
			state <= ACTIVATE;
			statepending <= READ0;
			
		end else if (write) begin
			// I move onto the state
			// which will issue
			// the command WRITE after
			// the bank has been opened.
			state <= ACTIVATE;
			statepending <= WRITE0;
		end
		
	end else if (state == REFRESH) begin
		// In this state, I issue
		// the command REFRESH.
		
		if (ckposedge) begin
			// Set command REFRESH.
			ras <= 0; cas <= 0; we <= 1;
			
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the delay TRFC.
			counter <= (CLKFREQ / TRFC);
			
			// I move onto the state which
			// will wait the delay TRFC.
			state <= WAIT;
			// Note that the state WAIT
			// will move onto the pending
			// state in statepending.
		end
		
	end else if (state == ACTIVATE) begin
		// In this state, I issue
		// the command which will
		// open a bank for a subsequent
		// command READ or WRITE.
		
		if (ckposedge) begin
			// Set command ACTIVATE.
			ras <= 0; cas <= 1; we <= 1;
			
			// Set the bank address.
			ba <= bank;
			
			// Set the row address.
			a <= rowzeroextended[ABITSIZE -1 : 0];
			
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the delay TRCD.
			counter <= (CLKFREQ / TRCD);
			
			// I move onto the state which
			// will wait the delay TRCD.
			state <= WAIT;
			// Note that the state WAIT
			// will move onto the pending
			// state in statepending.
		end
		
	end else if (state == READ0) begin
		// In this state, I issue
		// the command READ.
		
		if (ckposedge) begin
			// Set command READ.
			ras <= 1; cas <= 0; we <= 1;
			
			// Note that the state
			// ACTIVATE has already
			// set the bank address.
			
			// Set the column address.
			// There are as many lsb 0 for
			// as much is the burst length;
			// making memory accesses
			// aligned to a bitcount of:
			// ($DQBITSIZE * $BURSTLENGTH).
			// The SDRAM signal "a[10]"
			// is set high so as to close
			// all banks once the burst
			// is complete.
			a <= aconcatenated;
			
			// The SDRAM signal "dm" must be low.
			dm <= {(DQBITSIZE / 8){1'b0}};
			
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the latency CASLATENCY.
			counter <= (CASLATENCY -2);
			
			// I move onto the state which
			// will wait the latency CASLATENCY,
			// and which will prepare for the
			// sampling of data from the SDRAM.
			state <= READ1;
		end
		
	end else if (state == READ1) begin
		// In this state, I wait
		// the latency CASLATENCY
		// and prepare for the sampling
		// of data from the SDRAM.
		
		if (ckposedge) begin
			// Set command NOP.
			ras <= 1; cas <= 1; we <= 1;
			
			// The register counter is
			// decremented for every rising
			// edge of the SDRAM signal "ck".
			if (counter) counter <= counter - 1'b1;
			else begin
				// When I get here, I am done
				// waiting the latency CASLATENCY.
				
				// Set the register counter
				// which will be used to keep
				// track of the number of data
				// left in the burst.
				counter <= BURSTLENGTH;
				
				// I move onto the state
				// which sample data from
				// the SDRAM.
				state <= READ2;
			end
		end
		
	end else if (state == READ2) begin
		// In this state, I sample
		// data from the SDRAM.
		
		// I check whether there is
		// more data from the SDRAM.
		if (!counter) begin
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the delay TRP.
			counter <= (CLKFREQ / TRP);
			
			// Note that the delay to wait,
			// after the last data from
			// the SDRAM has been sampled,
			// is less than TRP, but for
			// safety, that delay is used.
			
			// I move onto the state which
			// will wait the delay TRP.
			state <= WAIT;
			// Then I move onto the state
			// in which the controller
			// is ready to accept
			// another operation.
			statepending <= READY;
			
		end else if (ckposedge) begin
			// I sample each data
			// from the SDRAM at
			// the rising edge of
			// the SDRAM signal "ck".
			dataoutcasted[BURSTLENGTH  - counter] <= dq_i;
			
			// Decrement counter
			// to index where the next
			// data sampled from the
			// SDRAM will be stored.
			counter <= counter - 1'b1;
		end
		
	end else if (state == WRITE0) begin
		// In this state, I issue
		// the command WRITE.
		
		// Drive the SDRAM signal "dq".
		// The datasheet recommend
		// to start driving
		// the SDRAM signal "dq"
		// before the command WRITE.
		dqe <= 1;
		
		if (ckposedge) begin
			// Set command WRITE.
			ras <= 1; cas <= 0; we <= 0;
			
			// Note that the state
			// ACTIVATE has already
			// set the bank address.
			
			// Set the column address.
			// There are as many lsb 0 for
			// as much is the burst length;
			// making memory accesses
			// aligned to a bitcount of:
			// ($DQBITSIZE * $BURSTLENGTH).
			// The SDRAM signal "a[10]"
			// is set high so as to close
			// all banks once the burst
			// is complete.
			a <= aconcatenated;
			
			// Set the first data to
			// set on the output "dq".
			dqval <= datainsamplecasted[0];
			
			// Set the first data mask
			// to set on the output "dm".
			dm <= datamasksamplecasted[0];
			
			// Set the register counter
			// which will be used to keep
			// track of the number of data
			// left in the burst.
			counter <= (BURSTLENGTH - 2);
			
			// I move onto the state which
			// will set the next data
			// to set on the output "dq".
			state <= WRITE1;
		end
		
	end else if (state == WRITE1) begin
		
		if (ckposedge) begin
			// Set command NOP.
			ras <= 1; cas <= 1; we <= 1;
			
			// Set the next data to
			// set on the output "dq".
			dqval <= datainsamplecasted[(BURSTLENGTH -1) - counter];
			
			// Set the next data mask
			// to set on the output "dm".
			dm <= datamasksamplecasted[(BURSTLENGTH -1) - counter];
			
			// I check whether there
			// is a next data to set
			// on the output "dq".
			if (!counter) begin
				// I move onto the state which
				// will terminate sending data
				// to the SDRAM.
				state <= WRITE2;
			end
			
			// Decrement counter
			// to index the next data
			// to set on the output "dq".
			counter <= counter - 1'b1;
		end
		
	end else if (state == WRITE2) begin
		
		if (ckposedge) begin
			// Set the SDRAM signal "dq" high-z.
			dqe <= 0;
			
			// Set the register counter
			// which will be used to keep
			// track of the number of clock
			// cycles left in the delay
			// (TWR + TRP).
			counter <= ((CLKFREQ / TWR) + (CLKFREQ / TRP));
			
			// I move onto the state
			// which will wait the delay
			// (TWR + TRP).
			state <= WAIT;
			// Then I move onto the state
			// in which the controller
			// is ready to accept
			// another operation.
			statepending <= READY;
		end
	end
end


endmodule
