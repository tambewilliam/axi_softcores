
`ifndef LIBSPIMASTERPHY
`define LIBSPIMASTERPHY

// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// Module implementing the physical device
// which transmit/receive each data bit.


// Parameters.
// 
// DATABITSIZE:
// 	Number of bits per data
// 	to transmit; it must be
// 	greater than 1.
// 
// SCLKDIVIDELIMIT:
// 	Limit below which
// 	the input "sclkdivide"
// 	must be set.
// 	It must be non-null. ei:
// 	`define SCLKDIVIDELIMIT 6
// 	With the above example, the
// 	maximum value that can be set
// 	on the input "sclkdivide" is 5.


// Ports.
// 
// input clk
// 	Clock signal.
// 	Its frequency determine
// 	the transmission bitrate
// 	which is computed as follow:
// 	(clockspeed/(2 << sclkdivide)).
// 	For a clockspeed of 100 Mhz
// 	and a value of 0 on the input
// 	"sclkdivide", it result in
// 	a bitrate of 50 Mbps.
// 
// output sclk
// output mosi
// input miso
// output ss
// 	SPI master signals.
// 
// input[clog2(SCLKDIVIDELIMIT)] sclkdivide
// 	This input is used to adjust the bitrate.
// 	The resulting bitrate is computed as
// 	follow: (clockspeed/(2 << sclkdivide)).
// 	For a clockspeed of 100 Mhz and
// 	a value of 0 for this input,
// 	it yield a bitrate of 50 Mbps.
// 
// input transmit
// 	This signal is set high to begin
// 	transmitting the data value on
// 	the input "datain" and receiving
// 	a data value on the input "dataout".
// 	When the output "dataneeded"
// 	is high, transmission begin
// 	on the next active edge
// 	of the clock input "clk".
// 	To prevent the output "ss"
// 	from becoming high between each
// 	data transmission, this signal
// 	must be set high as soon as the
// 	output "dataneeded" become high.
// 
// output dataneeded
// 	This signal is used to indicate
// 	that data is needed for transmission.
// 	The data to transmit must be
// 	present on the input "datain"
// 	as soon as this signal is found
// 	to be high.
// 
// output datareceived
// 	This signal is used to indicate
// 	that data has been received
// 	and is ready to be sampled
// 	from the output "dataout".
// 	This signal is high for
// 	a single clock cycle.
// 
// output[DATABITSIZE] dataout
// 	Data value received.
// 	Its value is valid only while
// 	the output "datareceived" is high.
// 
// input[DATABITSIZE] datain
// 	Data value to transmit
// 	through the output "mosi".
// 	The data value is captured
// 	for transmission on the falling
// 	edge of the output "dataneeded";
// 	hence the next data to transmit
// 	must be present on the input
// 	"datain" before the falling
// 	edge of the output "dataneeded".
// 
// To skip unknown states on
// the outputs "mosi" and "ss"
// after poweron, this module
// must be run for a clock
// cycle count of at least
// (DATABITSIZE * (2 << SCLKDIVIDELIMIT))
// with the input "transmit" set low;
// unknown states get flushed out of
// the module.


// When defined, bits are
// transmitted on both the
// rising and falling edge
// of the signal "sclk".
//`define SCLKBOTHEDGE


module spimasterphy (
	
	clk,
	
	sclk, mosi, miso, ss,
	
	transmit, dataneeded, datareceived, sclkdivide,
	
	dataout, datain
);

`include "lib/clog2.v"

parameter DATABITSIZE = 0;
parameter SCLKDIVIDELIMIT = 0;

input clk;

output sclk;
output mosi;
input miso;
output ss;

input transmit;
output dataneeded;
output datareceived;
input[clog2(SCLKDIVIDELIMIT) -1 : 0] sclkdivide;

output[DATABITSIZE -1 : 0] dataout;
input[DATABITSIZE -1 : 0] datain;

// The master insure that
// the active edge of its
// output "sclk" occur half
// way between the start
// and end of each bit that
// it transmit, which allow
// it to sample bits transmitted
// from the slave half way
// between their start and end,
// since the slave transmit and
// sample bits right after
// an active edge is detected
// on its input "sclk".

`ifdef SCLKBOTHEDGE
// Register holding the value
// of the output "sclk".
reg sclk;
`endif

// Register holding the value
// of the output "ss".
reg ss;


// Register holding bits used
// to set the output "mosi".
reg[DATABITSIZE -1 : 0] mosibits;

assign mosi = mosibits[DATABITSIZE -1];


// Register holding bits sampled
// from the input "miso".
reg[DATABITSIZE -1 : 0] misobits;

assign dataout = misobits;


// Register used to set
// the output "sclk" to
// a frequency that is
// a power of 2 slower
// than the input "clk".
// It is also used to keep
// track of the number
// of clock cycles.
reg[SCLKDIVIDELIMIT -1 : 0] counter;

`ifndef SCLKBOTHEDGE
// Logic driving the output "sclk".
assign sclk = counter[sclkdivide];
`endif


// Register which is used
// to keep track of the number
// of bits left to transmit.
reg[clog2(DATABITSIZE) -1 : 0] bitcount;

assign dataneeded = !bitcount;


// Register used to detect
// a falling edge on "dataneeded".
reg dataneededsampled;

// This logic set the net dataneedednegedge
// to 1 when the falling edge of the output
// "dataneeded" occur.
wire dataneedednegedge = (dataneeded < dataneededsampled);


// Register used to detect
// a falling or rising edge
// on "ss".
reg sssampled;

// This logic set the net ssnegedge
// to 1 when the falling edge of
// the output "ss" occur.
wire ssnegedge = (ss < sssampled);

// This logic set the net ssposedge
// to 1 when the rising edge of
// the output "ss" occur.
wire ssposedge = (ss > sssampled);


// Data has been received when either
// of the following condition occur:
// - A falling edge on "dataneeded";
// 	in this condition, data has
// 	been received only if there was
// 	no falling edge on "ss", otherwise
// 	it mean that the transmission just
// 	started and data still has yet
// 	to be received.
// - A rising edge on "ss".
// 
// "datareceived" is high only
// for a single clock cycle since
// dataneededsampled and sssampled
// are updated every clock cycles.
assign datareceived = ((dataneedednegedge && !ssnegedge) || ssposedge);


always @(posedge clk) begin
	// The input "miso" is sampled
	// right before the active edge
	// of the output "sclk".
	if (counter == ((1 << sclkdivide) -1)) begin
		
		misobits <= {misobits[DATABITSIZE -2 : 0], miso};
		
		`ifdef SCLKBOTHEDGE
		if (!ss) sclk <= ~sclk;
		`endif
	end
	
	// When the output "ss" is low,
	// this block execute only after
	// every clock cycle count of
	// ((2 << sclkdivide) -1); when
	// the output "ss" is high, this
	// block execute every clock cycle.
	// ">=" is used so that the register
	// "counter" get correctly wrapped
	// around when "sclkdivide" is
	// suddently set to a value that
	// make the register "counter"
	// greater than or equal to
	// ((2 << sclkdivide) -1).
	if (ss || counter >= ((2 << sclkdivide) -1)) begin
		// Logic shifting mosibits
		// which is used to set
		// the output "mosi".
		if (bitcount) mosibits <= (mosibits << 1);
		else mosibits <= datain;
		
		// Logic updating bitcount.
		if (bitcount) bitcount <= bitcount - 1'b1;
		else if (transmit) bitcount <= (DATABITSIZE -1);
		
		// Logic updating the output "ss".
		ss <= !(bitcount || transmit);
		
		counter <= 0;
		
	end else counter <= counter + 1'b1;
	
	// Save the current state of "dataneeded".
	dataneededsampled <= dataneeded;
	
	// Save the current state of "ss'.
	sssampled <= ss;
end


`ifdef SIMULATION
// ### Needed for Verilog simulation.
initial begin
	`ifdef SCLKBOTHEDGE
	// Register holding the value
	// of the output "sclk".
	sclk = 0;
	`endif
	
	// Register holding the value
	// of the output "ss".
	// Active low logic.
	ss = 1;
	
	// Register holding bits used
	// to set the output "mosi".
	mosibits = 0;
	
	// Register holding bits sampled
	// from the input "miso".
	misobits = 0;
	
	// Register used to set
	// the output "sclk" to
	// a frequency that is
	// a power of 2 slower
	// than the input "clk".
	// It is also used to keep
	// track of the number
	// of clock cycles.
	counter = 0;
	
	// Register which is used
	// to keep track of the number
	// of bits left to transmit.
	bitcount = 0;
	
	// Register used to detect
	// a falling edge on "dataneeded".
	dataneededsampled = dataneeded;
	
	// Register used to detect
	// a falling or rising edge
	// on "ss".
	sssampled = ss;
end
`endif


endmodule

`endif
