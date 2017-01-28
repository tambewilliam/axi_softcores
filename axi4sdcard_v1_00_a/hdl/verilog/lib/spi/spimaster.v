
`ifndef LIBSPIMASTER
`define LIBSPIMASTER

// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// Module implementing a SPI master.


// Parameters.
// 
// BUFFERSIZE:
// 	Size of the receive and transmit
// 	buffer which respectively
// 	store the data received
// 	and the data to transmit.
// 	It must be greater than 1
// 	and a power of 2.
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
// 	It must be non-null. ei: 6;
// 	with the above example, the
// 	maximum value that can be set
// 	on the input "sclkdivide" is 5.


// Ports.
// 
// input rst
// 	Reset signal.
// 	This input reset empty
// 	the receive and transmit buffer.
// 	To prevent unwanted data in
// 	the receive buffer after reset,
// 	this input should be kept high
// 	for a clock cycle count of at least:
// 	(DATABITSIZE * (2 << SCLKDIVIDELIMIT))
// 	of the input "phyclk".
// 
// input clk
// 	Clock input used
// 	by the reset signal,
// 	and used to write data
// 	in the transmit buffer,
// 	and read data from
// 	the receive buffer.
// 
// input phyclk
// 	Clock input used by
// 	the physical device
// 	which transmit/receive
// 	each data bit.
// 	Its frequency determine
// 	the transmission bitrate
// 	which is computed as follow:
// 	(phyclockspeed/(2<<sclkdivide)).
// 	For a phyclockspeed of 100 Mhz
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
// 	follow: (phyclockspeed/(2<<sclkdivide)).
// 	For a phyclockspeed of 100 Mhz and
// 	a value of 0 for this input,
// 	it yield a bitrate of 50 Mbps.
// 
// input txbufferwriteenable
// input[DATABITSIZE] txbufferdatain
// output[clog2(BUFFERSIZE) +1] txbufferusage
// 	Fifo interface to buffer
// 	the data to transmit.
// 	Refer to "fifo.v" for help
// 	on using the interface.
// 	The output "ss" become high
// 	when there is no data in
// 	the transmit buffer to send
// 	after the last data has been
// 	transmitted.
// 	A decrement of the output "txbufferusage"
// 	indicate that a data was taken out
// 	of the transmit buffer and will be
// 	transmitted on the next active
// 	edge of the clock input "phyclk".
// 	When the output "ss" is high, and
// 	data is added to the empty transmit
// 	buffer, transmission begin on the
// 	second active clock edge of "phyclk".
// 
// input rxbufferreadenable
// output[DATABITSIZE] rxbufferdataout
// output[clog2(BUFFERSIZE) +1] rxbufferusage
// 	Fifo interface to retrieve
// 	the data received.
// 	Refer to "fifo.v" for help
// 	on using the interface.


// Uncomment to have bits
// transmitted on both
// the rising and falling
// edge of the signal "sclk".
//`define SCLKBOTHEDGE
// It is used within
// "phy.spimaster.v" .


`include "lib/fifo.v"

`include "phy.spimaster.v"

module spimasterlib (
	
	rst,
	
	clk, phyclk,
	
	sclk, mosi, miso, ss,
	
	sclkdivide,
	
	txbufferwriteenable, txbufferdatain, txbufferusage,
	
	rxbufferreadenable, rxbufferdataout, rxbufferusage
);

`include "lib/clog2.v"

parameter BUFFERSIZE = 0;
parameter DATABITSIZE = 0;
parameter SCLKDIVIDELIMIT = 0;

input rst;

input clk;
input phyclk;

output sclk;
output mosi;
input miso;
output ss;

input[clog2(SCLKDIVIDELIMIT) -1 : 0] sclkdivide;

input txbufferwriteenable;
input[DATABITSIZE -1 : 0] txbufferdatain;
output[(clog2(BUFFERSIZE) +1) -1 : 0] txbufferusage;

input rxbufferreadenable;
output[DATABITSIZE -1 : 0] rxbufferdataout;
output[(clog2(BUFFERSIZE) +1) -1 : 0] rxbufferusage;


// Instantiate the module
// that implement a spi master.

// This register is set to 1,
// when data was read from txfifo.
reg txfifowasread;

wire masterspidataneeded;

wire masterspidatareceived;

wire[DATABITSIZE -1 : 0] masterspidataout;

wire[DATABITSIZE -1 : 0] txfifodataout;

// Master SPI phy.
spimasterphy #(
	
	.SCLKDIVIDELIMIT (SCLKDIVIDELIMIT),
	.DATABITSIZE (DATABITSIZE)
	
) masterspi (
	
	.clk (phyclk),
	
	.sclk (sclk),
	.mosi (mosi),
	.miso (miso),
	.ss (ss),
	
	.transmit (masterspidataneeded && txfifowasread),
	.dataneeded (masterspidataneeded),
	.datareceived (masterspidatareceived),
	.sclkdivide (sclkdivide),
	.dataout (masterspidataout),
	.datain (txfifodataout)
);


// fifo for storing data received.
fifo #(
	.DATABITSIZE (DATABITSIZE),
	.BUFFERSIZE (BUFFERSIZE)
	
) rxfifo (
	
	.rst (rst),
	
	.usage (rxbufferusage),
	
	.readclk (clk),
	.readenable (rxbufferreadenable),
	.dataout (rxbufferdataout),
	
	.writeclk (phyclk),
	// Note that the output
	// "masterspi.datareceived"
	// is high only for a single
	// clock cycle of "phyclk".
	.writeenable (masterspidatareceived),
	.datain (masterspidataout)
);


wire txfiforeadenable = (txbufferusage && !txfifowasread);

// fifo for buffering
// data to transmit.
fifo #(
	.DATABITSIZE (DATABITSIZE),
	.BUFFERSIZE (BUFFERSIZE)
	
) txfifo (
	
	.rst (rst),
	
	.usage (txbufferusage),
	
	.readclk (phyclk),
	.readenable (txfiforeadenable),
	.dataout (txfifodataout),
	
	.writeclk (clk),
	.writeenable (txbufferwriteenable),
	.datain (txbufferdatain)
);


// Register used to save the state
// of "masterspi.dataneeded" in order
// to detect its falling edge.
reg masterspidataneededsampled;

// Logic that set the net
// masterspidataneedednegedge
// when a falling edge of
// masterspi.dataneeded occur.
wire masterspidataneedednegedge = (masterspidataneeded < masterspidataneededsampled);

always @(posedge phyclk) begin
	// Logic that update txfifowasread.
	if (rst || (txfifowasread && masterspidataneedednegedge)) txfifowasread <= 0;
	else if (txfiforeadenable) txfifowasread <= 1;
	
	// Save the current state
	// of masterspi.dataneeded;
	masterspidataneededsampled <= masterspidataneeded;
end

`ifdef SIMULATION
// ### Needed for Verilog simulation.
initial begin
	// This register is set to 1,
	// when data was read from txfifo.
	txfifowasread = 0;
	
	// Register used to save the state
	// of "masterspi.transmit" in order
	// to detect its falling edge.
	masterspidataneededsampled = masterspidataneeded;
end
`endif


endmodule

`endif
