module <modName>(clk, reset, input_valid, input_ready, input_data, output_valid, output_ready, output_data);
	
	parameter M=<M>, N=<N>, T=<T>, R=<R>;
	input clk, reset, input_valid, output_ready;
	input signed [T-1:0] input_data;
	output logic signed [T-1:0] output_data;
	output logic output_valid, input_ready;
 
	logic wr_en_x, clear_acc, en_acc;
	localparam LOGSIZEW = $clog2(M*N);
	localparam LOGSIZEX = $clog2(N);
	logic [LOGSIZEW-1:0] addr_w;
    logic [LOGSIZEX-1:0] addr_x;
 
	controlpath #(M,N, T) controlpathInst(clk, reset, input_valid, input_ready, addr_w, wr_en_x, addr_x, clear_acc, en_acc, output_valid, output_ready);
	datapath #(M,N,T,R) datapathInst(clk, reset, input_data, addr_w, wr_en_x, addr_x, clear_acc, en_acc, output_data);
 
 
endmodule 
 
 
module memory(clk, data_in, data_out, addr, wr_en);
	parameter T=<T>, N=<N>;
	localparam LOGSIZE=$clog2(N);
	input [	T-1:0] data_in;
	output logic [T-1:0] data_out;
	input [LOGSIZE-1:0] addr;
	input clk, wr_en;
	logic [N-1:0][T-1:0] mem;
	always_ff @(posedge clk) begin
	data_out <= mem[addr];
	if (wr_en)
		mem[addr] <= data_in;
	end
endmodule 
 

module counterw(clk, incrw, clearw, countw);
	input clk, clearw, incrw;
	parameter M=<M>, N=<N>;
	localparam LOGSIZE = $clog2(M*N);
	output logic [LOGSIZE-1:0] countw;
	always_ff @(posedge clk) begin
		if (clearw == 1)
			countw<=0;
		else if (incrw)
			countw<=countw+1;
	end
endmodule


module counterx(clk, incrx, clearx, countx);
	input clk, clearx, incrx;
	parameter N=<N>;
	localparam LOGSIZE = $clog2(N);
	output logic [LOGSIZE-1:0] countx;
	always_ff @(posedge clk) begin
		if (clearx == 1)
			countx<=0;
		else if (incrx)
			countx<=countx+1;
	end
endmodule

	
module datapath (clk, reset, input_data, addr_w, wr_en_x, addr_x, clear_acc, en_acc, output_data);
	
	parameter M=<M>,N=<N>,T=<T>,R=<R>;
	input clk, reset, wr_en_x, clear_acc, en_acc;
	input signed [T-1:0] input_data;
	output logic signed [T-1:0] output_data;
	localparam LOGSIZEW = $clog2(M*N);
	localparam LOGSIZEX = $clog2(N);
	input [LOGSIZEW-1:0] addr_w;
	input [LOGSIZEX-1:0] addr_x;
	
	logic signed [T-1:0] wr, xr;
	logic signed [T-1:0] product, sum, preout, in_temp, out_temp;
	logic signed [2*T-1:0] extraProduct;

	<romModName>  memw(clk, addr_w, wr);
	memory #(T, N) mx(clk, input_data, xr, addr_x, wr_en_x);

	always_comb begin
		
		extraProduct = wr*xr;
		product = wr*xr;
		if (extraProduct > (2**(T-1))-1)
			in_temp = (2**(T-1))-1;   //14'h1FFF for T=14
		else if (extraProduct < -(2**(T-1)))
			in_temp = -(2**(T-1));   //14'h2000 for T=14
		else 
			in_temp = product;
				

		sum = output_data + out_temp;
		if ((out_temp[T-1] == 0) && (output_data[T-1] == 0) && (sum[T-1] == 1))
			preout = (2**(T-1))-1;
		else if ((out_temp[T-1] == 1) && (output_data[T-1] == 1) && (sum[T-1] == 0))
			preout = -(2**(T-1));
		else
			preout = sum;
			
	end
	
	
	always_ff @(posedge clk) begin
		if (reset == 1)
			out_temp <= 0;
		else
			out_temp <= in_temp;
	end

	always_ff @(posedge clk) begin
		if (clear_acc == 1)
			output_data <= 0;
		else if (en_acc == 1) begin
			if (R==1 && preout<0)
				output_data <= 0;
			else 
				output_data <= preout;
		end
	end


endmodule




module controlpath (clk, reset, input_valid, input_ready, countwaddr, wr_en_x, countxaddr, clear_acc, en_acc, output_valid, output_ready );
	
	parameter M=<M>,N=<N>,T=<T>;
	input clk, reset, input_valid, output_ready;
	output input_ready, wr_en_x, clear_acc;
	output logic output_valid, en_acc;
	logic incrw, clearw, incrx, clearx, incrwaddr, clearwaddr, incrxaddr, clearxaddr;
	logic finish;
	logic en_temp;
	
	parameter [1:0] START = 0, WRITE = 1, READ = 2;
	logic [1:0] state, nextState;
	
	
	localparam LOGSIZEW=$clog2(M*N+1);
	localparam LOGSIZEX=$clog2(N+2);
	logic [LOGSIZEW-1:0] countw;
	logic [LOGSIZEX-1:0] countx;
	
	//counterw #(M,N) counterwInst(clk, incrw, clearw, countw);
	counterx #(M*N+1) counterxInstwtrack(clk, incrw, clearw, countw);
	counterx #(N+2) counterxInst(clk, incrx, clearx, countx);
	
	localparam LOGSIZEWADDR=$clog2(M*N);
	localparam LOGSIZEXADDR=$clog2(N); 
	output logic [LOGSIZEWADDR-1:0] countwaddr;
	output logic [LOGSIZEXADDR-1:0] countxaddr;
	
	counterw #(M,N) counterwInstwaddr(clk, incrwaddr, clearwaddr, countwaddr);
	counterx #(N) counterxInstxaddr(clk, incrxaddr, clearxaddr, countxaddr);
	
	always_ff @(posedge clk) begin
		if (reset == 1)
			state<=START;
		else 
			state<=nextState;
	end
	
	
	always_comb begin
		if (state == START)
			nextState = WRITE;
		
		else if (state == WRITE) begin
			if (countx<N)
				nextState = WRITE;
			else
				nextState = READ;
		end
		
		else if (state == READ) begin
			if (countw<M*N+1 && finish==0)
				nextState = READ;
			else 
				nextState = WRITE;
		end
		
		else
			nextState = START;
	end 


	always_ff @(posedge clk) begin
		if (state == WRITE) begin
			if (countx>N-1)
				output_valid<=0;	
		end
		else if (state == READ) begin
			if (countw<M*N+1 && finish==0) begin
				if (output_valid==0 || output_ready==0) begin
					if (output_valid==0) begin
						if (countx<N) begin
							en_temp<=1;
							en_acc<=en_temp;
						end
						else if (countx==N) begin
							en_temp<=0;
							en_acc<=en_temp;
						end
						else if (countx==N+1) begin
							output_valid<=1;
							en_acc<=en_temp;
						end
					end  
				end
				else
					output_valid<=0;
			end
			else
				output_valid<=0;
		end
	end
	
	
	
	
	
	assign clearw = ((state == START) || ((state == READ) && (finish==1)));
	assign clearx = ((state == START) || ((state == WRITE) && (countx>N-1)) || ((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==0 || output_ready==0) && (output_valid==0) && (countx==N+1)) || ((state == READ) && (finish==1)));
	assign clear_acc = ((state == START) || ((state == READ) && (finish==1)) || ((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==1 && output_ready==1) && (countw<M*N)));
	assign input_ready = ((state == WRITE) && (countx<N));
	assign incrw = (((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==0 || output_ready==0) && (output_valid==0) && (countx<N)));
	assign wr_en_x = ((state == WRITE) && (countx<N) && (input_valid==1));
	assign incrx = (((state == WRITE) && (countx<N) && (input_valid==1)) || ((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==0 || output_ready==0) && (output_valid==0) && (countx<N+1)));
	assign finish = ((state == READ) && (output_valid==1 && output_ready==1) && (countw==M*N));
	
	
	assign clearwaddr = ((state == START) || ((state == READ) && (finish==1)));
	assign clearxaddr = ((state == START) || ((state == WRITE) && (countx>N-1)) || ((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==0 || output_ready==0) && (output_valid==0) && (countx==N+1)) || ((state == READ) && (finish==1)));
	assign incrwaddr = (((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==0 || output_ready==0) && (output_valid==0) && (countx<N)));
	assign incrxaddr = (((state == WRITE) && (countx<N) && (input_valid==1)) || ((state == READ) && (countw<M*N+1 && finish==0) && (output_valid==0 || output_ready==0) && (output_valid==0) && (countx<N+1)));
	
	
	
	
endmodule
