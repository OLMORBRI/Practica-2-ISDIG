`timescale 1ns/1ps

module tb_multipli;

  // Parámetros
  localparam int TAM    = 8;
  localparam int CLK_NS = 10;  // 100 MHz

  // Señales TB
  logic                          CLOCK = 1'b0;
  logic                          RESET = 1'b0;   // activo en bajo
  logic                          START = 1'b0;
  logic signed [TAM-1:0]         A     = '0;     // signed
  logic signed [TAM-1:0]         B     = '0;     // signed
  logic signed [2*TAM-1:0]       S;              // signed
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

  // --- Tarea: ejecuta caso y comprueba (signed) ---
  task automatic run_case(
    input logic signed [TAM-1:0] a_i,
    input logic signed [TAM-1:0] b_i,
    input string                 tag = ""
  );
    logic signed [2*TAM-1:0] exp_s;
    begin
      // Preparar operandos
      @(negedge CLOCK);
      A = a_i;
      B = b_i;

      // Pulso START
      START = 1'b1;
      @(negedge CLOCK);
      START = 1'b0;

      // Esperar a fin
      @(posedge END_MULT);

      // Esperado (signed)
      exp_s = a_i * b_i;

      // Mostrar y comprobar
      if (S === exp_s) begin
        $display("[%0t] %s  (signed) A=%0d B=%0d -> S=%0d  OK",
                 $time, tag, A, B, S);
      end else begin
        $display("[%0t] %s  (signed) A=%0d B=%0d -> S=%0d  EXP=%0d  **FAIL**",
                 $time, tag, A, B, S, exp_s);
      end

      // 1 ciclo extra para volver a IDLE
      @(negedge CLOCK);
    end
  endtask

  // Secuencia principal
  initial begin
    // Reset asíncrono activo en bajo
    RESET = 1'b0;
    START = 1'b0;
    A     = '0;
    B     = '0;

    repeat (5) @(negedge CLOCK);
    RESET = 1'b1;  // liberar reset
    @(negedge CLOCK);

    // Casos básicos (coinciden signed/unsigned)
    run_case(8'sd0,     8'sd0,     "TC1  0 * 0");
    run_case(8'sd3,     8'sd5,     "TC2  3 * 5");
    run_case(8'sd10,    8'sd12,    "TC3  10 * 12");
    run_case(8'sd15,    8'sd15,    "TC4  15 * 15");

    // Casos que fallaban si comparabas en unsigned (ahora correctos en signed)
    // Mismos bits: 255= -1, 128= -128, 200= -56, 150= -106
    run_case(-1,    2,      "TC5  bits(255,2)    => -2");
	 run_case(-128,  2,      "TC6  bits(128,2)    => -256");
	 run_case(-56,   -106,   "TC7  bits(200,150)  => 5936");

    // Aleatorios signed
    run_case(-37,    23,     "RND1");
    run_case(105,    -71,    "RND2");
    run_case(-128,   -128,   "RND3");
    repeat (5) @(negedge CLOCK);
    $finish;
  end

endmodule