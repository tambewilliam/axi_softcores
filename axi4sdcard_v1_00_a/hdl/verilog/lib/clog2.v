
// Function which compute
// the ceiling of log2().
// When the argument is
// 0 or 1, the value returned
// is 1.
function integer clog2;
	
	input integer value;
	
	begin
		
		if (value > 1) begin
			
			value = value - 1;
			
			for (clog2 = 0; value > 0; clog2 = clog2 + 1)
				value = value >> 1;
			
		end else clog2 = 1;
		
	end
	
endfunction
