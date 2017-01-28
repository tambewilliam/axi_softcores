
// ----------------------------------
// Copyright (c) William Fonkou Tambe
// All rights reserved.
// ----------------------------------


// Module implementing an
// sd/mmc card controller
// using SPI mode.
// MMC, SDSC, SDHC and SDXC
// cards are supported.
// HighSpeed mode (50MHz)
// is used when available,
// otherwise DefaultSpeed
// mode (25MHz) is used.
// CRC is turned-on.

// Refer to the sd/mmc card spec
// for details on the format of
// the commands and responses used.
// A copy of the spec and information
// on how to access an sd/mmc card
// can be found in doc/.
// 
// After poweron or reset, the spec
// demand to allow at least 250ms
// for the card to reach a stable
// powered state; and then to issue
// at least 74 cycles on the card's
// input "sclk", with the input "cs"
// held high during the 74 "sclk" cycles.
// The frequency of the card's input
// "sclk" should be between 100 KHz
// and 400 KHz.
// The card is ready to receive
// a command when 0xff keep being
// received from it; similarly,
// when waiting or reading responses
// from the card, 0xff must keep
// being transmitted to it.
// The input "cs" of the card must
// be driven high to low prior
// to sending a command, and held
// low during the transaction (Command,
// response and data transfer if any).
// 
// The card must be initialized
// before data transfer can occur.
// 
// Initialization or reset of
// the card is done as follow:
// - Send CMD0; Software reset.
// 	Expect response R1 with
// 	idle state bit set to 1.
// - Send CMD59; Turn-on CRC.
// 	Expect response R1.
// - Send CMD8.
// 	Expect response R7.
// 	If illigal command returned,
// 	the card is either SDv1 or MMC,
// 	otherwise the card is SDv2.
// - If card is SDv2, send ACMD41
// 	with the HCS bit of the command
// 	set to 1.
// 	Expect response R1.
// 	If idle state bit set to 1,
// 	repeat this step until idle
// 	state bit get set to 0.
// - If card is not SDv2, send ACMD41
// 	with the HCS bit of the command
// 	set to 0.
// 	Expect response R1.
// 	If illigal command returned,
// 	the card is MMC; else if idle
// 	state bit set to 1, repeat
// 	this step until idle state
// 	bit get set to 0.
// - If card is MMC, send CMD1.
// 	Expect reponse R1.
// 	If idle state bit set to 1,
// 	repeat this step until idle
// 	state bit get set to 0.
// - If idle state bit set to 0,
// 	send CMD6 to enable high
// 	speed mode if available.
// 	Expect response R1.
// 	If no error reported,
// 	expect data packet.
// - Send CMD9 to read the card's CSD
// 	register from which the max
// 	"sclk" frequency and capacity
// 	will be computed.
// 	Expect response R1.
// 	If no error reported,
// 	expect data packet.
// - Send CMD58 to determine
// 	whether the card is block
// 	or byte aligned.
// 	Expect response R3.
// 	If bit30 of OCR is 0, the card
// 	is byte aligned, otherwise
// 	the card is block aligned.
// - Send CMD16 to set block size
// 	to 512 Bytes.
// 	Expect response R1.
// 
// Reading data from the card
// is done as follow:
// - Send CMD17; read a 512bytes
// 	block of data.
// 	Expect response R1.
// 	If no error reported,
// 	expect data packet.
// 
// Writing data to the card
// is done as follow:
// - Send CMD24; write a 512bytes
// 	block of data.
// 	Expect response R1.
// 	If no error reported,
// 	send data packet, and
// 	expect data response byte.
// 	If no error reported,
// 	send CMD13 to check whether
// 	the write was successful.
// 	Expect response R2.


// Parameters.
// 
// CLKFREQ:
// 	Frequency of the clock input "clk" in Hz.
// 	It should be at least 500KHz in
// 	order to provide at least 250KHz
// 	on the card's input "sclk". ei:
// 	`define CLKFREQ 100000000


// Description of the ports.
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
// output sclk
// output di
// input do
// output cs
// 	SPI interface to the card.
// 
// output cacheread
// output cachewrite
// output[8] cachedatain
// input[8] cachedataout
// 	Interface used by this module
// 	to get or provide each byte
// 	of a data block to write-to or
// 	read-from the card respectively.
// 	A data block is 512 bytes.
// 	The output "cacheread" will be
// 	set high when a byte is needed,
// 	expecting the byte needed to be
// 	present on the input "cachedataout"
// 	instantaneously.
// 	The output "cachewrite" will be
// 	set high when a byte has been set
// 	on the output "cachedatain" which
// 	should be sampled on the next
// 	active clock edge.
// 	There is no reporting of the byte
// 	offset within the data block being
// 	transfered; because at every rising
// 	edge of the output "bsy" which
// 	occur before the start of each data
// 	block transfer, it is assumed that
// 	the offset of the first byte is 0.
// 	Note that a data block is 512 bytes.
// 
// input devread
// input devwrite
// input[32] devaddr
// 	Interface to initiate
// 	a data block transfer
// 	between the controller
// 	and the card.
// 	The input "devaddr" is the
// 	block index within the card.
// 	When the input "devread"
// 	is set high, a data block
// 	at the index given by
// 	the input "devaddr" is
// 	read from the card.
// 	When the output "devwrite"
// 	is set high, a data block
// 	is written at the index
// 	given by the input "devaddr".
// 	When the input "devread"
// 	is high, the input "devwrite"
// 	is ignored if it also high.
// 	The input "devaddr" must
// 	remain constant while
// 	the output "bsy" is high.
// 
// output[32] blockcount
// 	This signal is set to the total
// 	number of blocks available in the
// 	card after it has been initialized.
// 
// output bsy
// 	This signal is high
// 	while this module is busy
// 	communicating with the card.
// 
// output err
// 	This signal is high when
// 	an error occured; a reset
// 	is needed to clear the error.

// Note that there is no reporting of
// timeout, as it is best implemented
// in software by timing how long
// the card has been busy.


`include "lib/spi/spimaster.v"

module sdcardphy (
	
	rst,
	
	clk,
	
	sclk, di, do, cs,
	
	cacheread,
	cachewrite,
	cachedatain,
	cachedataout,
	
	devread,
	devwrite,
	devaddr,
	
	blockcount,
	
	bsy,
	err
);

`include "lib/clog2.v"

// Clock frequency in Hz.
// It should be at least 500KHz
// in order to provide at least
// 250KHz needed to drive
// the card's input "sclk".
parameter CLKFREQ = 0;

input rst;

input clk;

output sclk;
output di;
input do;
output cs;

output cacheread;
output cachewrite;
output[8 -1 : 0] cachedatain;
input[8 -1 : 0] cachedataout;

input devread;
input devwrite;
input[32 -1 : 0] devaddr;

output[32 -1 : 0] blockcount;

output bsy;
output err;


// Register used to implement timeout.
// The largest value that it will be set to,
// is the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock
// cycles using a clock frequency of CLKFREQ
// would be CLKFREQ/4; the result of that
// value would largely be greater than
// (($SPIDATABITSIZE + 1) * (2 << $SCLKDIVIDELIMIT))
// which is the minimum number of clock
// cycles needed to reset spimaster; in fact
// CLKFREQ must be at least 500 KHz.
reg[clog2(CLKFREQ/4) -1 : 0] timeout;


// Constants used with
// the register state.

// When in this state,
// the controller is resseting
// by waiting 250ms, before
// driving the card spi interface,
// and then issuing at least 74
// "sclk" cycles with the card
// input "cs" high.
parameter RESETTING	= 0;

// When in this state,
// the controller is
// not busy.
parameter READY		= 1;

// States that send
// a command.
parameter SENDCMD0	= 2;
parameter SENDCMD59	= 3;
parameter SENDCMD8	= 4;
parameter SENDINIT	= 5;
parameter SENDCMD41	= 6;
parameter SENDCMD6	= 7;
parameter SENDCMD9	= 8;
parameter SENDCMD58	= 9;
parameter SENDCMD16	= 10;
parameter SENDCMD17	= 11;
parameter SENDCMD24	= 12;
parameter SENDCMD13	= 13;

// States that wait
// for a command's
// response.
parameter CMD0RESP	= 14;
parameter CMD59RESP	= 15;
parameter CMD8RESP	= 16;
parameter INITRESP	= 17;
parameter CMD6RESP	= 18;
parameter CMD9RESP	= 19;
parameter CMD58RESP	= 20;
parameter CMD16RESP	= 21;
parameter CMD17RESP	= 22;
parameter CMD24RESP	= 23;
parameter CMD13RESP	= 24;

// States that prepare
// the card for the next
// command to send.
parameter PREPCMD59	= 25;
parameter PREPCMD8	= 26;
parameter PREPINIT	= 27;
parameter PREPCMD41	= 28;
parameter PREPCMD9	= 29;
parameter PREPCMD58	= 30;
parameter PREPCMD16	= 31;
parameter PREPCMD13 	= 32;
parameter PREPREADY	= 33;

// When in this state,
// an error occured, and
// a reset is required.
parameter ERROR		= 34;


// Register used to hold the
// state of the controller.
// There are less than 64
// different values that can
// be set in this register.
reg[clog2(64) -1 : 0] state;

assign bsy = (state != READY);

assign err = (state == ERROR);


// Instantiate spimaster
// and connect its ports.

wire sdspiss;

// Number of division by 2 needed
// to go from CLKFREQ to 250 KHz.
parameter SCLKDIVIDELIMIT = (clog2(CLKFREQ/250000));

// Register that hold the value of
// the input "sdspi.sclkdivide".
reg[clog2(SCLKDIVIDELIMIT) -1 : 0] sdspisclkdivide;

// Register that hold the value of
// the input "sdspi.txbufferwriteenable".
reg sdspitxbufferwriteenable;

// Register that hold the value of
// the input "sdspi.txbufferdatain".
reg[8 -1 : 0] sdspitxbufferdatain;

// Size of the spimaster buffer.
// It is minimal to keep latency
// at its lowest when waiting for
// the transmission to end or when
// waiting for the transmit buffer
// to be full.
parameter SPIBUFFERSIZE = 2;

wire[(clog2(SPIBUFFERSIZE) +1) -1 : 0] sdspitxbufferusage;

// Register that hold the value of
// the input "sdspi.rxbufferreadenable".
reg sdspirxbufferreadenable;

wire[8 -1 : 0] sdspirxbufferdataout;

wire[(clog2(SPIBUFFERSIZE) +1) -1 : 0] sdspirxbufferusage;

// spimaster which will be used
// to communicate with the card.
spimasterlib #(
	
	.SCLKDIVIDELIMIT (SCLKDIVIDELIMIT),
	.DATABITSIZE (8),
	.BUFFERSIZE (SPIBUFFERSIZE)
	
) sdspi (
	// The spimaster is kept
	// in a reset state for as
	// long as the controller
	// is resetting.
	.rst (state == RESETTING),
	
	// To insure that the CRC
	// computation has enough
	// clock cycles to complete,
	// "sdspi.clk" and "sdspi.phyclk"
	// must be the same, so that
	// when sdspi.sclkdivide == 0,
	// there be at least 16 clock
	// cycles between the transmission
	// of each byte used in the
	// CRC computation.
	// In fact when the inputs
	// "clk" and "phyclk" are
	// the same, and the input
	// "bstbdivide" is 0, the
	// bitrate value is half
	// the clock frequency value.
	.clk (clk),
	.phyclk (clk),
	
	.sclk (sclk),
	.mosi (di),
	.miso (do),
	.ss (sdspiss),
	
	.sclkdivide (sdspisclkdivide),
	
	.txbufferwriteenable (sdspitxbufferwriteenable),
	.txbufferdatain (sdspitxbufferdatain),
	.txbufferusage (sdspitxbufferusage),
	
	.rxbufferreadenable (sdspirxbufferreadenable),
	.rxbufferdataout (sdspirxbufferdataout),
	.rxbufferusage (sdspirxbufferusage)
);

assign cachedatain = sdspirxbufferdataout;

// Register which when 1 keep
// the sdcard input "cs" high.
reg keepsdcardcshigh;

assign cs = (sdspiss | keepsdcardcshigh);


// Register used for
// multiple purposes.
reg miscflag;

// Register set to 1 when
// the card is found to
// be SDv2, otherwise
// it is set to 0.
reg issdcardver2;

// Register set to 1 when
// the card is found to
// be MMC, otherwise
// it is set to 0.
reg issdcardmmc;

// Register set to 1
// if the card addressing
// is block aligned, otherwise
// it is set to 0.
reg issdcardaddrblockaligned;


// Register which will be
// used to store the value
// of the card CSD register.
reg[8 -1 : 0] sdcardcsd[16 -1 : 0];


// ### Net declared as reg
// ### so as to be useable
// ### by verilog within
// ### the always block.
reg[32 -1 : 0] blockcount;

always @* begin
	// Logic which set blockcount
	// to the block count of
	// the card, computed from
	// its CSD register.
	if (sdcardcsd[0][7:6] == 'b00) begin
		// I get here if the card
		// CSD format is 1.0;
		
		// I compute the block count
		// using extracted CSD fields.
		blockcount = ((
			// I extract the CSIZE field.
			(({sdcardcsd[6], sdcardcsd[7], sdcardcsd[8]} & 'h03ffc0) >> 6)
				+ 1) << (
					// I extract the CSIZEMULT field.
					(({sdcardcsd[9], sdcardcsd[10]} & 'h0380) >> 7)
						+ 2 +
							// I extract the READBLLEN field.
							(sdcardcsd[5] & 'h0f)
								)) >> 9;
		
	end else if (sdcardcsd[0][7:6] == 'b01) begin
		// I get here if the card
		// CSD format is 2.0;
		
		// I compute the block count
		// using extracted CSD fields.
		blockcount = (
			// I extract the CSIZE field.
			({sdcardcsd[7], sdcardcsd[8], sdcardcsd[9]} & 'h3fffff)
				+ 1) << 10;
		
	end else begin
		// I get here if the card
		// CSD format is unsupported.
		
		// I set the block count to 1,
		// since the card should surely
		// have at least a single block.
		blockcount = 1;
	end
end


// Net which will be
// set to the value
// to set on the input
// "sdspi.sclkdivide"
// in order to attain
// the maximum transmission
// frequency safe to use.
// It is computed from
// the card CSD register.
// ### Nets declared as reg
// ### so as to be useable
// ### by verilog within
// ### the always block.
reg[clog2(SCLKDIVIDELIMIT) -1 : 0] safemaxsdspisclkdivide;

always @* begin
	// Logic that set safemaxsdspisclkdivide.
	// For unsupported values of sdcardcsd[3],
	// the minimum transmission frequency is used.
	if (sdcardcsd[3] == 'h2b) safemaxsdspisclkdivide = (clog2(CLKFREQ/200000000) -1);	// 200 Mbps.
	else if (sdcardcsd[3] == 'h0b) safemaxsdspisclkdivide = (clog2(CLKFREQ/100000000) -1);	// 100 Mbps.
	else if (sdcardcsd[3] == 'h5a) safemaxsdspisclkdivide = (clog2(CLKFREQ/50000000) -1);	// 50 Mbps.
	else if (sdcardcsd[3] == 'h32) safemaxsdspisclkdivide = (clog2(CLKFREQ/25000000) -1);	// 25 Mbps.
	else safemaxsdspisclkdivide = (SCLKDIVIDELIMIT -1'b1);					// 250 Kbps.
end


// Commands to be sent to the card.
// All commands are 6 bytes,
// but I append 0xff so that the
// register sdspitxbufferdatain
// be 0xff once the 6 bytes of
// the command have been transmitted,
// and so as to keep transmitting 0xff
// while waiting for a response from
// the card.

wire[63 : 0] dmc0 = 64'hff400000000001ff;
wire[7:0] cmd0[7:0];
assign cmd0[0] = dmc0[7:0];
assign cmd0[1] = dmc0[15:8];
assign cmd0[2] = dmc0[23:16];
assign cmd0[3] = dmc0[31:24];
assign cmd0[4] = dmc0[39:32];
assign cmd0[5] = dmc0[47:40];
assign cmd0[6] = dmc0[55:48];
assign cmd0[7] = dmc0[63:56];

wire[63 : 0] dmc8 = 64'hff48000001aa01ff;
wire[7:0] cmd8[7:0];
assign cmd8[0] = dmc8[7:0];
assign cmd8[1] = dmc8[15:8];
assign cmd8[2] = dmc8[23:16];
assign cmd8[3] = dmc8[31:24];
assign cmd8[4] = dmc8[39:32];
assign cmd8[5] = dmc8[47:40];
assign cmd8[6] = dmc8[55:48];
assign cmd8[7] = dmc8[63:56];

wire[63 : 0] dmc1 = 64'hff410000000001ff;
wire[7:0] cmd1[7:0];
assign cmd1[0] = dmc1[7:0];
assign cmd1[1] = dmc1[15:8];
assign cmd1[2] = dmc1[23:16];
assign cmd1[3] = dmc1[31:24];
assign cmd1[4] = dmc1[39:32];
assign cmd1[5] = dmc1[47:40];
assign cmd1[6] = dmc1[55:48];
assign cmd1[7] = dmc1[63:56];

wire[63 : 0] dmc55 = 64'hff770000000001ff;
wire[7:0] cmd55[7:0];
assign cmd55[0] = dmc55[7:0];
assign cmd55[1] = dmc55[15:8];
assign cmd55[2] = dmc55[23:16];
assign cmd55[3] = dmc55[31:24];
assign cmd55[4] = dmc55[39:32];
assign cmd55[5] = dmc55[47:40];
assign cmd55[6] = dmc55[55:48];
assign cmd55[7] = dmc55[63:56];

wire[63 : 0] dmc41 = 64'hff690000000001ff;
wire[7:0] cmd41[7:0];
assign cmd41[0] = dmc41[7:0];
assign cmd41[1] = dmc41[15:8];
assign cmd41[2] = dmc41[23:16];
assign cmd41[3] = dmc41[31:24];
assign cmd41[4] = dmc41[39:32];
assign cmd41[5] = dmc41[47:40];
assign cmd41[6] = dmc41[55:48];
assign cmd41[7] = dmc41[63:56];

wire[63 : 0] dmc41hcs = 64'hff694000000001ff;
wire[7:0] cmd41hcs[7:0];
assign cmd41hcs[0] = dmc41hcs[7:0];
assign cmd41hcs[1] = dmc41hcs[15:8];
assign cmd41hcs[2] = dmc41hcs[23:16];
assign cmd41hcs[3] = dmc41hcs[31:24];
assign cmd41hcs[4] = dmc41hcs[39:32];
assign cmd41hcs[5] = dmc41hcs[47:40];
assign cmd41hcs[6] = dmc41hcs[55:48];
assign cmd41hcs[7] = dmc41hcs[63:56];

wire[63 : 0] dmc58 = 64'hff7a0000000001ff;
wire[7:0] cmd58[7:0];
assign cmd58[0] = dmc58[7:0];
assign cmd58[1] = dmc58[15:8];
assign cmd58[2] = dmc58[23:16];
assign cmd58[3] = dmc58[31:24];
assign cmd58[4] = dmc58[39:32];
assign cmd58[5] = dmc58[47:40];
assign cmd58[6] = dmc58[55:48];
assign cmd58[7] = dmc58[63:56];

wire[63 : 0] dmc16 = 64'hff500000020001ff;
wire[7:0] cmd16[7:0];
assign cmd16[0] = dmc16[7:0];
assign cmd16[1] = dmc16[15:8];
assign cmd16[2] = dmc16[23:16];
assign cmd16[3] = dmc16[31:24];
assign cmd16[4] = dmc16[39:32];
assign cmd16[5] = dmc16[47:40];
assign cmd16[6] = dmc16[55:48];
assign cmd16[7] = dmc16[63:56];

wire[63 : 0] dmc9 = 64'hff490000000001ff;
wire[7:0] cmd9[7:0];
assign cmd9[0] = dmc9[7:0];
assign cmd9[1] = dmc9[15:8];
assign cmd9[2] = dmc9[23:16];
assign cmd9[3] = dmc9[31:24];
assign cmd9[4] = dmc9[39:32];
assign cmd9[5] = dmc9[47:40];
assign cmd9[6] = dmc9[55:48];
assign cmd9[7] = dmc9[63:56];

wire[31:0] devaddrshiftedleft = (devaddr << 9);

wire[63 : 0] dmc17 = {16'hff51, issdcardaddrblockaligned ? devaddr : devaddrshiftedleft, 16'h01ff};
wire[7:0] cmd17[7:0];
assign cmd17[0] = dmc17[7:0];
assign cmd17[1] = dmc17[15:8];
assign cmd17[2] = dmc17[23:16];
assign cmd17[3] = dmc17[31:24];
assign cmd17[4] = dmc17[39:32];
assign cmd17[5] = dmc17[47:40];
assign cmd17[6] = dmc17[55:48];
assign cmd17[7] = dmc17[63:56];

wire[63 : 0] dmc24 = {16'hff58, issdcardaddrblockaligned ? devaddr : devaddrshiftedleft, 16'h01ff};
wire[7:0] cmd24[7:0];
assign cmd24[0] = dmc24[7:0];
assign cmd24[1] = dmc24[15:8];
assign cmd24[2] = dmc24[23:16];
assign cmd24[3] = dmc24[31:24];
assign cmd24[4] = dmc24[39:32];
assign cmd24[5] = dmc24[47:40];
assign cmd24[6] = dmc24[55:48];
assign cmd24[7] = dmc24[63:56];

wire[63 : 0] dmc13 = 64'hff4d0000000001ff;
wire[7:0] cmd13[7:0];
assign cmd13[0] = dmc13[7:0];
assign cmd13[1] = dmc13[15:8];
assign cmd13[2] = dmc13[23:16];
assign cmd13[3] = dmc13[31:24];
assign cmd13[4] = dmc13[39:32];
assign cmd13[5] = dmc13[47:40];
assign cmd13[6] = dmc13[55:48];
assign cmd13[7] = dmc13[63:56];

wire[63 : 0] dmc6 = 64'hff4680fffff101ff;
wire[7:0] cmd6[7:0];
assign cmd6[0] = dmc6[7:0];
assign cmd6[1] = dmc6[15:8];
assign cmd6[2] = dmc6[23:16];
assign cmd6[3] = dmc6[31:24];
assign cmd6[4] = dmc6[39:32];
assign cmd6[5] = dmc6[47:40];
assign cmd6[6] = dmc6[55:48];
assign cmd6[7] = dmc6[63:56];

wire[63 : 0] dmc59 = 64'hff7b0000000101ff;
wire[7:0] cmd59[7:0];
assign cmd59[0] = dmc59[7:0];
assign cmd59[1] = dmc59[15:8];
assign cmd59[2] = dmc59[23:16];
assign cmd59[3] = dmc59[31:24];
assign cmd59[4] = dmc59[39:32];
assign cmd59[5] = dmc59[47:40];
assign cmd59[6] = dmc59[55:48];
assign cmd59[7] = dmc59[63:56];


// Register used as the controller counter.
// The largest value that it will be set to,
// is the clock cycle count equivalent of 250ms.
// Since 250ms is 4 Hz, the number of clock
// cycles using a clock frequency of CLKFREQ
// would be CLKFREQ/4; the result of that
// value would largely be greater than
// (($SPIDATABITSIZE + 1) * (2 << $SCLKDIVIDELIMIT))
// which is the minimum number of clock
// cycles needed to reset spimaster; in fact
// CLKFREQ must be at least 500 KHz.
reg[clog2(CLKFREQ/4) -1 : 0] counter;


// Logics that respectively
// set cacheread and cachewrite.
assign cacheread = ((state == CMD24RESP) && (sdspitxbufferusage != SPIBUFFERSIZE) && counter && counter <= 512);
assign cachewrite = ((state == CMD17RESP) && sdspirxbufferusage && counter > 1 && counter <= 513);


// CRC7 value.
reg[7 -1 : 0] crc7;

// CRC16 value.
reg[16 -1 : 0] crc16;

// Byte value to accumulate
// in the CRC computation.
reg[8 -1 : 0] crcarg;

// Register used to keep
// track of the number
// of clock cycles left
// in the CRC computation.
// It is set to 8 for each
// byte to accumulate in
// the CRC computation.
reg[clog2(8 + 1) -1 : 0] crccounter;

// Net set to the bit
// that will stream through
// the register crc7.
wire crc7in = (crcarg[7] ^ crc7[6]);

// Net set to the bit
// that will stream through
// the register crc16.
wire crc16in = (crcarg[7] ^ crc16[15]);


always @(posedge clk) begin
	// Logic computing
	// the CRC7 or CRC16
	// per the card spec.
	if (crccounter) begin
		
		crc7[6] <= crc7[5];
		crc7[5] <= crc7[4];
		crc7[4] <= crc7[3];
		crc7[3] <= crc7[2] ^ crc7in;
		crc7[2] <= crc7[1];
		crc7[1] <= crc7[0];
		crc7[0] <= crc7in;
		
		crc16[15] <= crc16[14];
		crc16[14] <= crc16[13];
		crc16[13] <= crc16[12];
		crc16[12] <= crc16[11] ^ crc16in;
		crc16[11] <= crc16[10];
		crc16[10] <= crc16[9];
		crc16[9] <= crc16[8];
		crc16[8] <= crc16[7];
		crc16[7] <= crc16[6];
		crc16[6] <= crc16[5];
		crc16[5] <= crc16[4] ^ crc16in;
		crc16[4] <= crc16[3];
		crc16[3] <= crc16[2];
		crc16[2] <= crc16[1];
		crc16[1] <= crc16[0];
		crc16[0] <= crc16in;
		
		// Get the next msb
		// to accumulate in
		// the CRC computation.
		crcarg <= crcarg << 1'b1;
		
		crccounter <= crccounter - 1'b1;
		
	end else if (!counter) begin
		// Note that the register
		// counter is never
		// null when the CRC
		// computation is needed,
		// hence it is used to
		// reset null the registers
		// that will contain
		// the result of the CRC
		// computation.
		
		crc7 <= 0;
		
		crc16 <= 0;
	end
	
	
	// Controller logic.
	if (rst) begin
		// Reset logic.
		
		miscflag <= 0;
		
		// I move onto the state
		// which will wait 250ms,
		// as required by the card
		// spec after poweron.
		state <= RESETTING;
		
		// I set counter to its maximum
		// value which is a clock cycle count
		// which yield at least 250ms.
		counter <= -1;
		
		// I set the spi clock to
		// a frequency between 100 KHz
		// and 400 KHz, as required by
		// the card spec after poweron.
		sdspisclkdivide <= (SCLKDIVIDELIMIT -1'b1);
		
		// I set keepsdcardcshigh
		// to 1 so that the card
		// input cs be kept high.
		keepsdcardcshigh <= 1;
		
		// I set sdspi.txbufferwriteenable
		// to 0 to stop the spi clock.
		sdspitxbufferwriteenable <= 0;
		
		// There is no need to set
		// sdspi.rxbufferreadenable
		// because regardless of its
		// value, the receive buffer
		// will be emptied and there
		// will be no data received
		// since the spi clock would
		// be stopped.
		
	end else if (state == RESETTING) begin
		// I come to this state after
		// a falling edge of the
		// input "rst"; I wait 250ms
		// and then issue at least 74
		// "sclk" cycles with the card
		// input "cs" high, as required
		// by the card spec after poweron.
		
		if (miscflag) begin
			
			if (counter) begin
				// I decrement counter only
				// if the transmit buffer is
				// not full, otherwise bytes
				// to send will get skipped.
				if (sdspitxbufferusage != SPIBUFFERSIZE) counter <= counter - 1'b1;
				
			end else begin
				// I wait that the spimaster
				// transmit all buffered data.
				if (sdspiss) begin
					// When I get here, the card
					// should be in idle sate.
					
					// I set keepsdcardcshigh
					// to 0 so that the card
					// input "cs" be controllable
					// by spimaster.
					keepsdcardcshigh <= 0;
					
					// I move onto the state
					// which will send CMD0
					// to the card.
					state <= SENDCMD0;
					// The register counter
					// is set in such a way that
					// the transmit buffer be full
					// with 0xff bytes before sending
					// each byte of the command;
					// in fact keeping the buffer
					// full while sending each
					// byte of the command is used
					// to insure that there be enough
					// clock cycles to compute the CRC
					// between each byte transmitted.
					// +2 account for the number
					// of clock cycles needed for
					// the first byte to make it
					// to the empty transmit buffer,
					// where it will be immediately
					// removed for transmission, and
					// after which $BUFFERSIZE bytes
					// will be added to the transmit
					// buffer to fill it up.
					counter <= (6 + SPIBUFFERSIZE + 2);
				end
				
				// I stop writting in the transmit
				// buffer since I wish to wait that
				// sdspi.ss become high.
				sdspitxbufferwriteenable <= 0;
			end
			
		end else begin
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// When I get here, 250ms
				// has passed since the input
				// "rst" was de-asserted.
				
				// I set counter to 10 in
				// order to write ten 0xff bytes
				// in the transmit buffer which
				// will issue 80 "sclk" cycles,
				// well above 74 "sclk" cycles.
				counter <= 10;
				
				// Byte value to write
				// in the transmit buffer
				// 10 times.
				sdspitxbufferdatain <= 'hff;
				
				sdspitxbufferwriteenable <= 1;
				
				// I set sdspi.rxbufferreadenable
				// to 1 so as to discard any data
				// received while bytes are
				// being transmitted.
				sdspirxbufferreadenable <= 1;
				
				miscflag <= 1;
			end
		end
		
	end else if (state == READY) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// Until there is something to do,
		// sdspitxbufferwriteenable == 0,
		// which is power efficient because
		// the spi clock will remain stopped.
		
		// sdspirxbufferreadenable
		// can remain 1 in order
		// to discard any data
		// in the receive buffer.
		
		if (devread) begin
			// I move onto the state
			// which will send CMD17
			// to the card.
			state <= SENDCMD17;
			
		end else if (devwrite) begin
			// I move onto the state
			// which will send CMD24
			// to the card.
			state <= SENDCMD24;
		end
		
	end else if (state == SENDCMD0) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		issdcardver2 <= 0;
		
		issdcardmmc <= 0;
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd0[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd0[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD0RESP;
			end
		end
		
	end else if (state == SENDCMD59) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd59[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd59[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD59RESP;
			end
		end
		
	end else if (state == SENDCMD8) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd8[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd8[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD8RESP;
			end
		end
		
	end else if (state == SENDINIT) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		// miscflag == 1;
		
		if (!miscflag) begin
			// If I get here,
			// the card is done
			// initializing.
			
			// I move onto the state
			// which will send CMD6
			// to the card.
			state <= SENDCMD6;
			
			// There is no need to set
			// counter, because
			// it would have already
			// been set to 6 when
			// coming to this state.
			
		end else begin
			// I write the command
			// in the transmit buffer.
			sdspitxbufferwriteenable <= 1;
			
			// I wait that the transmit buffer
			// is not full, before doing anything,
			// otherwise bytes will get lost.
			if (sdspitxbufferusage != SPIBUFFERSIZE) begin
				
				if (counter <= 6) begin
					// If the card is MMC, use CMD1
					// to initialize it, otherwise use
					// ACMD41 which start with CMD55.
					if (issdcardmmc) begin
						// Transmit the byte containing
						// the CRC7 when counter == 1,
						// otherwise transmit the command
						// bytes.
						if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
						else sdspitxbufferdatain <= cmd1[counter];
						
						if (counter > 1) crcarg <= cmd1[counter];
						
					end else begin
						
						// Transmit the byte containing
						// the CRC7 when counter == 1,
						// otherwise transmit the command
						// bytes.
						if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
						else sdspitxbufferdatain <= cmd55[counter];
						
						if (counter > 1) crcarg <= cmd55[counter];
					end
					
					// Note that when I get here,
					// crccounter == 0, because
					// between the transmission
					// of each byte, there is
					// at least 16 clock cycles.
					
					if (counter > 1) crccounter <= 8;
				end
				
				if (counter) counter <= counter - 1'b1;
				else begin
					// I move onto the state
					// which will wait for
					// the response.
					state <= INITRESP;
					
					// If ACMD41 need to be sent to
					// the card, set counter[0]
					// to 1 to signal it to the state
					// INITRESP.
					if (!issdcardmmc) counter[0] <= 1;
				end
			end
		end
		
	end else if (state == SENDCMD41) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// If the card is SDv2,
				// I use ACMD41 with
				// its bit HCS == 1.
				if (issdcardver2) begin
					// Transmit the byte containing
					// the CRC7 when counter == 1,
					// otherwise transmit the command
					// bytes.
					if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
					else sdspitxbufferdatain <= cmd41hcs[counter];
					
					if (counter > 1) crcarg <= cmd41hcs[counter];
					
				end else begin
					
					// Transmit the byte containing
					// the CRC7 when counter == 1,
					// otherwise transmit the command
					// bytes.
					if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
					else sdspitxbufferdatain <= cmd41[counter];
					
					if (counter > 1) crcarg <= cmd41[counter];
				end
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) crccounter <= 8;
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= INITRESP;
			end
		end
		
	end else if (state == SENDCMD6) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd6[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd6[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD6RESP;
			end
		end
		
	end else if (state == SENDCMD9) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd9[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd9[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD9RESP;
			end
		end
		
	end else if (state == SENDCMD58) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// Note that I will come to this
		// state for all type of cards;
		// but OCR[30] in the response R3
		// exist only for SDv2 cards, but
		// should correctly be 0 for SDv1 and
		// MMC cards as for those two types
		// of card it is a reserved bit.
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd58[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd58[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD58RESP;
			end
		end
		
	end else if (state == SENDCMD16) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd16[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd16[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD16RESP;
			end
		end
		
	end else if (state == SENDCMD17) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd17[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd17[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD17RESP;
			end
		end
		
	end else if (state == SENDCMD24) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd24[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd24[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD24RESP;
			end
		end
		
	end else if (state == SENDCMD13) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 0;
		// counter == (6 + SPIBUFFERSIZE + 2);
		
		// I write the command
		// in the transmit buffer.
		sdspitxbufferwriteenable <= 1;
		
		// I wait that the transmit buffer
		// is not full, before doing anything,
		// otherwise bytes will get lost.
		if (sdspitxbufferusage != SPIBUFFERSIZE) begin
			
			if (counter <= 6) begin
				// Transmit the byte containing
				// the CRC7 when counter == 1,
				// otherwise transmit the command
				// bytes.
				if (counter == 1) sdspitxbufferdatain <= {crc7, 1'b1};
				else sdspitxbufferdatain <= cmd13[counter];
				
				// Note that when I get here,
				// crccounter == 0, because
				// between the transmission
				// of each byte, there is
				// at least 16 clock cycles.
				
				if (counter > 1) begin
					
					crcarg <= cmd13[counter];
					
					crccounter <= 8;
				end
			end
			
			if (counter) counter <= counter - 1'b1;
			else begin
				// I move onto the state
				// which will wait for
				// the response.
				state <= CMD13RESP;
			end
		end
		
	end else if (state == CMD0RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// the response R1 from the card
			// and it must be [0[5:0], x],
			// otherwise throw an error.
			// Following the reception of
			// a valid reponse R1, I move
			// onto the state which will
			// set SENDCMD59.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else state <= PREPCMD59;
		end
		
	end else if (state == CMD59RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// the response R1 from the card
			// and it must be [0[5:0], x],
			// otherwise throw an error.
			// Following the reception of
			// a valid reponse R1, I move
			// onto the state which will
			// set SENDCMD8.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else state <= PREPCMD8;
		end
		
	end else if (state == CMD8RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		
		if (issdcardver2) begin
			// If I get here, the card
			// must be SDv2; I evaluate
			// the 4 bytes that follow
			// the first byte of
			// response R7; the 12 bits
			// in the least significant
			// bytes should be 0x1aa,
			// otherwise throw an error.
			if (sdspirxbufferusage) begin
				// I get here for each
				// byte received.
				// The byte received is
				// evaluated next time
				// that sdspi.rxbufferusage
				// become non-null; hence
				// when counter == 0,
				// the byte following the
				// first byte of response R7
				// has been received, but
				// sdspi.rxbufferdataout still
				// has the value of the first
				// byte of response R7 and
				// will be updated with the
				// received byte on the next
				// clock edge.
				
				if (counter == 3) begin
					
					if (sdspirxbufferdataout[0] != 1) state <= ERROR;
					
				end else if (counter == 4) begin
					// If no error is found,
					// I move onto the state
					// which will set SENDINIT.
					if (sdspirxbufferdataout != 'haa) state <= ERROR;
					else state <= PREPINIT;
				end
				
				counter <= counter + 1'b1;
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			
			issdcardver2 <= !sdspirxbufferdataout[2];
			
			issdcardmmc <= 0;
			
			// If I get here, I received
			// the first byte of response R7
			// from the card; if bit2 is 1,
			// the card is either SDv1 or MMC
			// and I should move onto the state
			// which will set SENDINIT;
			// otherwise issdcardver2 get set,
			// and checks on whether the card
			// is a valid SDv2 follow.
			if (sdspirxbufferdataout[2]) state <= PREPINIT;
		end
		
	end else if (state == INITRESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// and if ACMD41 need to be sent,
		// counter[0] == 1, otherwise
		// counter[0] == 0;
		
		if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// the initialization response.
			
			if (counter[0]) begin
				// If no error is found,
				// I move onto the state which
				// will prepare the second portion
				// of ACMD41 to send to the card.
				if (sdspirxbufferdataout[6:1]) state <= ERROR;
				else state <= PREPCMD41;
				
			end else begin
				// I update miscflag
				// with the card idle state.
				miscflag <= sdspirxbufferdataout[0];
				
				if (!issdcardver2 && !issdcardmmc && sdspirxbufferdataout[2]) begin
					// If I get here,
					// the card is MMC.
					issdcardmmc <= 1;
				end
				
				// If no error is found,
				// I move onto the state
				// which will set SENDINIT.
				if (sdspirxbufferdataout[6:1]) state <= ERROR;
				else state <= PREPINIT;
			end
		end
		
	end else if (state == CMD6RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		// miscflag == 0;
		
		// When I get here, miscflag
		// can be re-used for something
		// else; so here I use it to
		// determine whether I can start
		// looking at the data packet
		// which follow the response R1,
		// and which contain the SD status.
		if (miscflag) begin
			// If I get here, I expect
			// the data packet that follow
			// the response R1.
			
			if (!counter) begin
				
				if (sdspirxbufferdataout == 'hfe) begin
					// If I get here, I received
					// the byte which start
					// a data packet.
					
					counter <= counter + 1'b1;
					
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else state <= ERROR;
				
			end else begin
				// If I get here, I receive
				// and ignore the data packet
				// which contain the 64 bytes
				// SD status.
				
				if (sdspirxbufferusage) begin
					// I get here for each
					// byte received.
					// The byte received is
					// evaluated next time
					// that sdspi.rxbufferusage
					// become non-null; hence
					// when counter == 0,
					// the byte following the
					// byte starting a data packet
					// has been received, but
					// sdspi.rxbufferdataout still
					// has the value of the byte
					// starting a data packet and
					// will be updated with the
					// following byte on the next
					// clock edge.
					
					if (counter >= 66) begin
						// If I get here, I am done
						// reading the 64 bytes SD status.
						// I ignore the 2 CRC bytes
						// that terminate the response.
						
						// I move onto the state
						// which will set SENDCMD9.
						state <= PREPCMD9;
					end
					
					counter <= counter + 1'b1;
				end
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// response R1 from the card;
			// move onto the state which
			// will set SENDCMD9
			// if it is not [0[5:0], x],
			// otherwise look at the data
			// packet that follow.
			if (sdspirxbufferdataout[6:1]) state <= PREPCMD9;
			else begin
				miscflag <= 1;
				timeout <= -1;
			end
		end
		
	end else if (state == CMD9RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		// miscflag == 1;
		
		// When I get here, miscflag
		// can be re-used for something
		// else; so here I use it to
		// determine whether I can start
		// looking at the data packet
		// which follow the response R1,
		// and which contain the bytes
		// from the card CSD register.
		if (!miscflag) begin
			// If I get here, I expect
			// the data packet that follow
			// the response R1.
			
			if (!counter) begin
				
				if (sdspirxbufferdataout == 'hfe) begin
					// If I get here, I received
					// the byte which start
					// a data packet.
					
					counter <= counter + 1'b1;
					
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else state <= ERROR;
				
			end else begin
				// If I get here, I receive
				// the data packet which
				// contain the 16 bytes from
				// the card CSD register.
				
				if (sdspirxbufferusage) begin
					// I get here for each
					// byte received.
					// The byte received is
					// evaluated next time
					// that sdspi.rxbufferusage
					// become non-null; hence
					// when counter == 0,
					// the byte following the
					// byte starting a data packet
					// has been received, but
					// sdspi.rxbufferdataout still
					// has the value of the byte
					// starting a data packet and
					// will be updated with the
					// following byte on the next
					// clock edge.
					
					if (counter == 19) begin
						// I check the second CRC16 byte.
						if (sdspirxbufferdataout != crc16[7:0]) state <= ERROR;
						else begin
							// Set the maximum spi clock
							// frequency safe to use.
							sdspisclkdivide <= safemaxsdspisclkdivide;
							
							// I move onto the state
							// which will set SENDCMD58.
							state <= PREPCMD58;
						end
						
					end else if (counter == 18) begin
						// If I get here, I am done
						// reading the 16 bytes from
						// the card CSD register.
						
						// I check the first CRC16 byte.
						if (sdspirxbufferdataout != crc16[15:8]) state <= ERROR;
						
					end else if (counter > 1) begin
						
						sdcardcsd[counter -2] <= sdspirxbufferdataout;
						
						// Note that when I get here,
						// crccounter == 0, because
						// between the reception
						// of each byte, there is
						// at least 16 clock cycles.
						
						crcarg <= sdspirxbufferdataout;
						
						crccounter <= 8;
						
					end
					
					if (counter != 19) counter <= counter + 1'b1;
					else begin
						// Setting the register
						// counter to null
						// so that the logic
						// computing the CRC
						// reset itself null.
						counter <= 0;
					end
				end
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// response R1 from the card;
			// throw an error if it is not
			// [0[5:0], x], otherwise look
			// at the data packet that follow.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else begin
				miscflag <= 0;
				timeout <= -1;
			end
		end
		
	end else if (state == CMD58RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		// miscflag == 0;
		
		// When I get here, miscflag
		// can be re-used for something
		// else; so here I use it to
		// determine whether I can start
		// looking at the 4bytes that
		// follow the first byte of
		// response R3.
		if (miscflag) begin
			// I evaluate the 4 bytes
			// that follow the first byte
			// of response R3.
			if (sdspirxbufferusage) begin
				// I get here for each
				// byte received.
				// The byte received is
				// evaluated next time
				// that sdspi.rxbufferusage
				// become non-null; hence
				// when counter == 0,
				// the byte following the
				// first byte of response R3
				// has been received, but
				// sdspi.rxbufferdataout still
				// has the value of the first
				// byte of response R3 and
				// will be updated with the
				// received byte on the next
				// clock edge.
				
				if (counter == 1) begin
					// I set issdcardaddrblockaligned
					// using bit30 of the OCR register
					// from the response R3.
					issdcardaddrblockaligned <= |(sdspirxbufferdataout & 'h40);
					
				end else if (counter == 4) begin
					// I get here when I have
					// received the 4 bytes
					// that follow the first
					// byte of response R3.
					
					// I move onto the state
					// which will set SENDCMD16.
					state <= PREPCMD16;
				end
				
				counter <= counter + 1'b1;
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// the first byte of response R3
			// from the card; throw an error
			// if it is not [0[5:0], x], otherwise
			// look at the following 4bytes.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else miscflag <= 1;
		end
		
	end else if (state == CMD16RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// the response R1 from the card
			// and it must be [0[5:0], x],
			// otherwise throw an error.
			// Following the reception of
			// a valid reponse R1, I move
			// onto the state which will
			// set READY.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else state <= PREPREADY;
		end
		
	end else if (state == CMD17RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		// miscflag == 1;
		
		// When I get here, miscflag
		// can be re-used for something
		// else; so here I use it to
		// determine whether I can start
		// looking at the data packet
		// which follow the response R1.
		if (!miscflag) begin
			// If I get here, I expect
			// the data packet that follow
			// the response R1.
			
			if (!counter) begin
				
				if (sdspirxbufferdataout == 'hfe) begin
					// If I get here, I received
					// the byte which start
					// a data packet.
					
					counter <= counter + 1'b1;
					
				end else if (timeout)
					timeout <= timeout - 1'b1;
				else state <= ERROR;
				
			end else begin
				// If I get here, I receive
				// the 512 bytes data packet.
				
				if (sdspirxbufferusage) begin
					// I get here for each
					// byte received. Since
					// sdspirxbufferreadenable
					// is being held high,
					// sdspi.rxbufferusage will
					// become null on the next
					// active clock edge.
					
					// The byte received is
					// evaluated next time
					// that sdspi.rxbufferusage
					// become non-null; hence
					// when counter == 0,
					// the byte following the
					// byte starting a data packet
					// has been received, but
					// sdspi.rxbufferdataout still
					// has the value of the byte
					// starting a data packet and
					// will be updated with the
					// following byte on the next
					// clock edge.
					
					if (counter == 515) begin
						// I check the second CRC16 byte.
						if (cachedatain != crc16[7:0]) state <= ERROR;
						else begin
							// I move onto the state
							// which will set READY.
							state <= PREPREADY;
						end
						
					end else if (counter == 514) begin
						// If I get here, I am done
						// receiving the 512 bytes
						// data packet.
						
						// I check the first CRC16 byte.
						if (cachedatain != crc16[15:8]) state <= ERROR;
						
					end else if (counter > 1) begin
						// Note that when I get here,
						// crccounter == 0, because
						// between the reception
						// of each byte, there is
						// at least 16 clock cycles.
						
						crcarg <= cachedatain;
						
						crccounter <= 8;
					end
					
					if (counter != 515) counter <= counter + 1'b1;
					else begin
						// Setting the register
						// counter to null
						// so that the logic
						// computing the CRC
						// reset itself null.
						counter <= 0;
					end
				end
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// response R1 from the card;
			// throw an error if it is not
			// [0[5:0], x], otherwise look
			// at the data packet that follow.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else begin
				miscflag <= 0;
				timeout <= -1;
			end
		end
		
	end else if (state == CMD24RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		// miscflag == 1;
		
		// When I get here, miscflag
		// can be re-used for something
		// else; so here I use it to
		// determine whether I can start
		// sending the data packet.
		if (!miscflag) begin
			
			if (counter == 516) begin
				// If I get here, I wait for
				// the data response byte.
				
				if (sdspirxbufferdataout != 'hff) begin
					// If I get here, I received
					// the data response byte.
					// The only bits of interest
					// in the data response are
					// bit3 thru bit1.
					if ((sdspirxbufferdataout[3:1]) == 'b010) begin
						// I move onto the state
						// which will skip busy bytes
						// and set SENDCMD13.
						state <= PREPCMD13;
						
					end else state <= ERROR;
					
					// Setting the register
					// counter to null
					// so that the logic
					// computing the CRC
					// reset itself null.
					counter <= 0;
				end
				
			end else begin
				// If I get here, I send the data packet.
				
				if (sdspitxbufferusage != SPIBUFFERSIZE) begin
					// Since sdspitxbufferwriteenable
					// is being held high and the fact
					// that it take more than 1 clock
					// cycle to transmit a single byte,
					// sdspi.txbufferusage will certainly
					// be SPIBUFFERSIZE after the next
					// active clock edge.
					
					if (counter) begin
						// When counter == 513,
						// the last byte of the 512
						// bytes data packet has been
						// buffered for transmission;
						// I buffer the CRC16 value
						// followed by 0xff to keep
						// transmitting 0xff until
						// a data response is received.
						if (counter == 515) sdspitxbufferdatain <= 'hff;
						else if (counter == 514) sdspitxbufferdatain <= crc16[7:0];
						else if (counter == 513) sdspitxbufferdatain <= crc16[15:8];
						else begin
							
							sdspitxbufferdatain <= cachedataout;
							
							// Note that when I get here,
							// crccounter == 0, because
							// between the transmission
							// of each byte, there is
							// at least 16 clock cycles.
							
							crcarg <= cachedataout;
							
							crccounter <= 8;
						end
						
					end else begin
						// The first byte to transmit must
						// be 0xfe; it must be preceded by
						// at least a single 0xff byte which
						// is guaranteed to be have been
						// buffered for transmission since
						// sdspitxbufferwriteenable was being
						// held high with sdspitxbufferdatain
						// set to 0xff.
						sdspitxbufferdatain <= 'hfe;
					end
					
					counter <= counter + 1'b1;
				end
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// response R1 from the card;
			// throw an error if it is not
			// [0[5:0], x], otherwise start
			// sending the data packet.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else miscflag <= 0;
		end
		
	end else if (state == CMD13RESP) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		// counter == 0;
		// miscflag == 0;
		
		// When I get here, miscflag
		// can be re-used for something
		// else; so here I use it to
		// determine whether I can start
		// looking at the byte that
		// follow the first byte of
		// response R2.
		if (miscflag) begin
			// I evaluate the byte
			// that follow the first
			// byte of response R2.
			if (sdspirxbufferusage) begin
				// I get here for each
				// byte received.
				// The byte received is
				// evaluated next time
				// that sdspi.rxbufferusage
				// become non-null; hence
				// when counter == 0,
				// the byte following the
				// first byte of response R2
				// has been received, but
				// sdspi.rxbufferdataout still
				// has the value of the first
				// byte of response R2 and
				// will be updated with the
				// received byte on the next
				// clock edge.
				
				if (counter == 1) begin
					// I get here when I have
					// received the byte that
					// follow the first byte
					// of response R2.
					
					// If no error is found,
					// I move onto the state
					// which will set READY.
					if (sdspirxbufferdataout) state <= ERROR;
					else state <= PREPREADY;
				end
				
				counter <= counter + 1'b1;
			end
			
		end else if (sdspirxbufferdataout != 'hff) begin
			// If I get here, I received
			// the first byte of response R2
			// from the card; throw an error
			// if it is not [0[5:0], x], otherwise
			// look at the following byte.
			if (sdspirxbufferdataout[6:1]) state <= ERROR;
			else miscflag <= 1;
		end
		
	end else if (state == PREPCMD59) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD59
			// to the card.
			state <= SENDCMD59;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPCMD8) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD8
			// to the card.
			state <= SENDCMD8;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPINIT) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		// When coming to this state,
		// "sdspi.ss" is certainly null, since
		// sdspitxbufferwriteenable == 1
		// and data is being written in
		// the transmit buffer; I take advantage
		// of that to set "counter" to the
		// equivalent clock cycle count for 50ms
		// in order to wait for that long between
		// checks of the card idle state, and
		// prevent too many unnecessary checks;
		// per the card spec, the card idle
		// state should be polled at less
		// than 50ms intervals.
		if (sdspiss) begin
			// After 50ms has elapsed,
			// I move onto the state
			// which will send the init
			// command to the card.
			if (counter) counter <= counter - 1'b1;
			else begin
				state <= SENDINIT;
				// The register counter
				// is set in such a way that
				// the transmit buffer be full
				// with 0xff bytes before sending
				// each byte of the command;
				// in fact keeping the buffer
				// full while sending each
				// byte of the command is used
				// to insure that there be enough
				// clock cycles to compute the CRC
				// between each byte transmitted.
				// +2 account for the number
				// of clock cycles needed for
				// the first byte to make it
				// to the empty transmit buffer,
				// where it will be immediately
				// removed for transmission, and
				// after which $BUFFERSIZE bytes
				// will be added to the transmit
				// buffer to fill it up.
				counter <= (6 + SPIBUFFERSIZE + 2);
			end
			
		end else counter <= (CLKFREQ/20) -1; // 50ms is 20Hz.
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPCMD41) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD41
			// to the card.
			state <= SENDCMD41;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPCMD9) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD9
			// to the card.
			state <= SENDCMD9;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPCMD58) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD58
			// to the card.
			state <= SENDCMD58;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPCMD16) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD16
			// to the card.
			state <= SENDCMD16;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPCMD13) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// which will send CMD13
			// to the card.
			state <= SENDCMD13;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high; and I do
		// so only after skipping all busy
		// bytes from CMD24, since I come
		// to this from CMD24RESP.
		if (sdspirxbufferdataout == 'hff) sdspitxbufferwriteenable <= 0;
		
	end else if (state == PREPREADY) begin
		// When I come to this state I expect:
		// sdspirxbufferreadenable == 1;
		// sdspitxbufferwriteenable == 1;
		
		// I set miscflag to 1,
		// which is expected by
		// the state CMD17RESP.
		miscflag <= 1;
		
		// I wait that the spimaster
		// transmit all buffered data
		// in order to complete the
		// previous transaction, and
		// start a new transaction.
		if (sdspiss) begin
			// I move onto the state
			// in which the card is
			// ready to be accessed.
			state <= READY;
			// The register counter
			// is set in such a way that
			// the transmit buffer be full
			// with 0xff bytes before sending
			// each byte of the command;
			// in fact keeping the buffer
			// full while sending each
			// byte of the command is used
			// to insure that there be enough
			// clock cycles to compute the CRC
			// between each byte transmitted.
			// +2 account for the number
			// of clock cycles needed for
			// the first byte to make it
			// to the empty transmit buffer,
			// where it will be immediately
			// removed for transmission, and
			// after which $BUFFERSIZE bytes
			// will be added to the transmit
			// buffer to fill it up.
			counter <= (6 + SPIBUFFERSIZE + 2);
		end
		
		// I stop writting in the transmit
		// buffer since I wish to wait that
		// sdspi.ss become high.
		sdspitxbufferwriteenable <= 0;
		
	end else if (state == ERROR) begin
		// I get here, if an error occured.
		// Nothing get done until reset.
		
		// I stop writing in the transmit
		// buffer in order to stop the spi
		// clock, which is power efficient.
		sdspitxbufferwriteenable <= 0;
		
		// While in this state,
		// sdspirxbufferreadenable
		// can remain 1 in order
		// to discard any data
		// in the receive buffer.
	end
end


endmodule
