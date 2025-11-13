//============================================================
// tb_if.sv
//============================================================
interface tb_if(input logic CLOCK);

  logic RESET, START;
  logic signed [7:0] A, B;
  logic signed [15:0] S_duv, S_ref;
  logic END_MULT;

  // modports para conectar cada bloque
  modport DUV   (input CLOCK, RESET, START, A, B, output S_duv, END_MULT);
  modport IDEAL (input CLOCK, RESET, START, A, B, output S_ref);
  modport TEST  (input CLOCK, output RESET, START, A, B, input S_duv, S_ref, END_MULT);

endinterface