`timescale 1ns/1ps

module tb_multipli_top;

  // Señales TB
  logic clk;
  logic reset;
  logic start;
  logic signed [7:0]  A, B;
  logic signed [15:0] S;
  logic               END_MULT;

  // Instancia del DUV
  multipli #(.tamano(8)) duv (
    .CLOCK    (clk),
    .RESET    (reset),
    .START    (start),
    .A        (A),
    .B        (B),
    .S        (S),
    .END_MULT (END_MULT)
  );

  // Instancia del entorno de estímulos (program)
  tb_multipli_prog tb_env (
    .clk      (clk),
    .reset    (reset),
    .start    (start),
    .A        (A),
    .B        (B),
    .S        (S),
    .END_MULT (END_MULT)
  );

  // Generador de reloj
  always #5 clk = ~clk;

  // Solo inicializamos el reloj. El program se encarga del reset y estímulos.
  initial begin
    clk = 1'b0;
  end

endmodule