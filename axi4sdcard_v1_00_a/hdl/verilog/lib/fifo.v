
`ifndef LIBFIFO
`define LIBFIFO

// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// Module implementing a fifo.

// Writting data to the fifo
// add it to its buffer, while
// reading data from the fifo
// remove it from its buffer.
// Data are read from the fifo
// in the order they were written
// in the fifo.

// A fifo is useful, not only
// for buffering data, but also
// to safely move data between
// two modules that use different
// clocks, in order words to move
// data between two clock domains.


// Parameters.
// 
// DATABITSIZE:
// 	Number of bits used by
// 	each data in the fifo.
// 	It must be non-null.
// 
// BUFFERSIZE:
// 	Total number of data
// 	that the fifo can contain.
// 	It must be at least 2
// 	and a power of 2.


// Ports:
// 
// input rst
// 	If high, on the clockedge
// 	of the input "writeclk",
// 	the fifo reset itself empty.
// 	It must be low to write data
// 	in the fifo.
// 
// output[clog2(BUFFERSIZE) +1] usage
// 	The value of this signal
// 	is the number of data
// 	currently in the fifo.
// 
// Ports for reading from the fifo.
// 
// input readclk
// 	Clock signal used to update
// 	the ouput "dataout".
// 
// input readenable
// 	If high, on the clockedge
// 	of the input "readclk",
// 	if the fifo is not empty,
// 	data from the fifo get set
// 	on the output "dataout",
// 	but if the fifo is empty,
// 	the output "dataout"
// 	remain constant.
// 
// output[DATABITSIZE] dataout
// 	Signal set to data from the fifo.
// 	Its value is updated on the clockedge
// 	of the input "readclk" if the input
// 	"readenable" is high.
// 
// Ports for writing to the fifo.
// 
// input writeclk
// 	Clock signal used to write
// 	in the fifo the data on
// 	the input "datain".
// 
// input writeenable
// 	If high, on the clockedge
// 	of the input "writeclk",
// 	if the fifo is not full,
// 	the value of the input
// 	"datain" get written in
// 	the fifo, but if the fifo
// 	is full, nothing is written
// 	in the fifo.
// 
// input[DATABITSIZE] datain
// 	Data to write in the fifo
// 	on the clockedge of the
// 	input "writeclk" if the
// 	input "writeenable" is high.

// Note that the fifo has
// two clock domains driven
// respectively by the inputs
// "readclk" and "writeclk".
// To prevent hazards, both
// clock should transition
// at the same time; also,
// both clocks should have
// the same speed, or
// one clock should have
// a speed that is the speed
// of the other clock times
// a power of 2.
// If the frequency speed ratio,
// describe above, between the
// two clocks cannot be guaranteed,
// before attempting to read the
// fifo, the output "usage" should
// be lowpass filtered for at
// least two stable samples
// using the read clock, and
// its value checked to insure
// that the fifo is not empty; and
// before attempting to write
// the fifo, the output "usage"
// should be lowpass filtered
// for at least two stable
// samples using the write clock,
// and its value checked to insure
// that the fifo is not full.
// the lowpass filtering remove
// noise from hazards generated
// while the internal combinational
// logic of the fifo is settling
// after a clock edge.


module fifo (
	
	rst,
	
	usage,
	
	readclk, readenable, dataout,
	
	writeclk, writeenable, datain
);

`include "lib/clog2.v"

parameter DATABITSIZE = 0;
parameter BUFFERSIZE = 0;

input rst;

output[(clog2(BUFFERSIZE) +1) -1 : 0] usage;

input readclk;
input readenable;
output[DATABITSIZE -1 : 0] dataout;

input writeclk;
input writeenable;
input[DATABITSIZE -1 : 0] datain;

// Register holding the value
// of the output dataout.
reg[DATABITSIZE -1 : 0] dataout;


// Buffer containing the data of the fifo.
reg[DATABITSIZE -1 : 0] buffer[BUFFERSIZE -1 : 0];

// Read and write index within the buffer.
// Only the clog2(BUFFERSIZE) lsb are
// used for indexing.
reg[(clog2(BUFFERSIZE) +1) -1 : 0] readindex, writeindex;

// Number of data in the buffer.
assign usage = (writeindex - readindex);

// Net set to 1 when
// the buffer is empty.
wire empty = (usage == 0);

// Net set to 1 when
// the buffer is full.
wire full = (usage == BUFFERSIZE);

// This block implement
// the reading of the fifo.
always @(posedge readclk) begin
	
	if (rst) begin
		
		dataout <= {DATABITSIZE{1'b0}};
		
		// Setting readindex
		// to writeindex make
		// the fifo empty.
		readindex <= writeindex;
		
	end else if (readenable && !empty) begin
		// Read data from the fifo
		// and increment readindex which
		// effectively remove the data
		// read from the fifo.
		
		dataout <= buffer[readindex[clog2(BUFFERSIZE) -1 : 0]];
		
		// Set readindex to the next
		// location in the buffer where
		// data should be read next.
		readindex <= readindex + 1'b1;
	end
end

// This block implement
// the writting of the fifo.
always @(posedge writeclk) begin
	
	if (writeenable && !full) begin
		// Write data in the buffer
		// and increment writeindex
		// which effectively add the
		// data written in the fifo.
		
		buffer[writeindex[clog2(BUFFERSIZE) -1 : 0]] <= datain;
		
		// Set writeindex to the next
		// location in the buffer where
		// data should be written next.
		writeindex <= writeindex + 1'b1;
	end
end


// ### Needed by verilog
// ### for simulation.
`ifdef SIMULATION

integer i;

initial begin
	
	dataout = 0;
	
	for (i = 0; i < BUFFERSIZE; i = i + 1)
		buffer[i] = 0;
	
	readindex = 0;
	writeindex = 0;
end
`endif


endmodule

`endif
