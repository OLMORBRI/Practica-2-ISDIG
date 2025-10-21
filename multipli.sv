module multipli(CLOCK, RESET, END_MULT, A, B, S, START);

	//TAMAÑO
	parameter tamano=8;
	
	//ENTRADAS
	input CLOCK, RESET;
	input logic START;
	input logic [tamano-1:0] A;
	input logic [tamano-1:0] B;
	
	//SALIDAS
	output logic [2*tamano-1:0] S;
	output logic END_MULT;

	// DEFINICION DE ESTADOS
	typedef enum logic [2:0]{
	IDLE, 
	INIT, 
	OP, 
	SHIFT,
	NOTIFY
	} state_t;
	
	state_t state, next_state;
	
	//REGISTROS INTERNOS
	logic [8:0] Accu;
	logic [tamano-1:0] LO;
	logic [tamano-1:0] M;
	logic [3:0] count;
	logic X;
	
	//BLOQUE SECUENCIAL DEL RESET DE ESTADOS
	always_ff @(posedge CLOCK or negedge RESET)
		if(!RESET)
			state <= IDLE;
		else
			state <= next_state;
			
	//BLOQUE SECUENCIAL DE SALIDAS Y REGISTROS INTERNOS
	always_ff @(posedge CLOCK or negedge RESET)
		begin
			if (!RESET)
				begin
               Accu <= 9'd0;
               LO <= 8'd0;
               M <= 8'd0;
               X <= 1'b0;
               count <= 4'd0;
               END_MULT <= 1'b0;
				end 
			else 
				begin
					case(state)
						IDLE:
							END_MULT <= 1'b0;
						INIT:
							begin
								Accu <=9'h000;
								count <=0;
								LO <=A;
								M <=B;
								X <=1'b0;
							end
						OP:
							begin
								count <= count + 4'd2;

								if ({LO[1],LO[0], X} == 3'b000 || {LO[1],LO[0], X} == 3'b111) //NO HACER NADA
									Accu <= Accu;
									
								else if({LO[1],LO[0], X} == 3'b001 || {LO[1],LO[0], X} == 3'b010) //ACCU+M
									Accu <= Accu + M;
									
								else if({LO[1],LO[0], X} == 3'b101 || {LO[1],LO[0], X} == 3'b110) //ACCU-M
									Accu <= Accu - M;
									
								else if({LO[1],LO[0], X} == 3'b011) //ACCU+2M
									Accu <= Accu + (M << 1);
									
								else if({LO[1],LO[0], X} == 3'b100) //ACCU-2M
									Accu <= Accu - (M << 1);
								
								else 
									Accu <= Accu;
							end
						SHIFT:
							Accu <= {Accu[8], Accu[8], LO[7:1]};
						NOTIFY:
							END_MULT <= 1'b1;
							
						default:
							END_MULT <= 1'b0;
						
					endcase
				end
		end
	
	//BLOQUE COMBINACIONAL DE LOS SALTOS DE ESTADOS
	always_comb
		case(state)
			IDLE:
				begin
					if(START)
						next_state = INIT;
					else
						next_state = IDLE;
				end	
			INIT:
				next_state = OP;
			OP:
				next_state = SHIFT;
			SHIFT:
				begin
					if(count == tamano)
						next_state = NOTIFY;
					else
						next_state = OP;
				end
			NOTIFY:
				begin
					if(START)
						next_state = NOTIFY;
					else
						next_state = IDLE;
				end
			
			default:
				next_state = IDLE;
		endcase
		
	//ASIGNACION DE LA VARIABLE DEL RESULTADO
	assign S = {Accu[tamano-1:0],LO};
	
endmodule 