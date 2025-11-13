`timescale 1ns/1ps

module tb_multipli_avanzada;

  localparam int TAM    = 8;
  localparam int CLK_NS = 10;

  // Señales compartidas
  logic                          CLOCK = 1'b0;
  logic                          RESET = 1'b0;   // activo en bajo
  logic                          START = 1'b0;
  logic signed [TAM-1:0]         A     = '0;
  logic signed [TAM-1:0]         B     = '0;
  logic signed [2*TAM-1:0]       S;
  logic                          END_MULT;

  // DUT
  multipli #(.tamano(TAM)) dut (
    .CLOCK    (CLOCK),
    .RESET    (RESET),
    .START    (START),
    .A        (A),
    .B        (B),
    .S        (S),
    .END_MULT (END_MULT)
  );

  // Reloj
  always #(CLK_NS/2) CLOCK = ~CLOCK;

  // Instancia del program de verificación
  tb_prog #(.TAM(TAM)) env (
    .CLOCK    (CLOCK),
    .RESET    (RESET),
    .START    (START),
    .A        (A),
    .B        (B),
    .S        (S),
    .END_MULT (END_MULT)
  );

endmodule
