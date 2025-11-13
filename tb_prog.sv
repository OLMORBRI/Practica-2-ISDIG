`timescale 1ns/1ps

program tb_prog #(
  parameter int TAM = 8
)(
  input  logic                    CLOCK,
  output logic                    RESET,
  output logic                    START,
  output logic signed [TAM-1:0]   A,
  output logic signed [TAM-1:0]   B,
  input  logic signed [2*TAM-1:0] S,
  input  logic                    END_MULT
);

  localparam int MAX_POS = (1 << (TAM-1)) - 1;
  localparam int MIN_NEG = - (1 << (TAM-1));

  int total_tests = 0;
  int pass_tests  = 0;
  int fail_tests  = 0;

  // =======================
  // Clase RCSG
  // =======================
  class Numeros;
    rand logic signed [TAM-1:0] valorA;
    rand logic signed [TAM-1:0] valorB;

    constraint c_rango {
      valorA inside {[MIN_NEG:MAX_POS]};
      valorB inside {[MIN_NEG:MAX_POS]};
    }

    // PARES * PARES
    constraint c_PP { valorA[0] == 1'b0; valorB[0] == 1'b0; }
    // PARES * IMPARES
    constraint c_PI { valorA[0] == 1'b0; valorB[0] == 1'b1; }
    // IMPARES * PARES
    constraint c_IP { valorA[0] == 1'b1; valorB[0] == 1'b0; }
    // IMPARES * IMPARES
    constraint c_II { valorA[0] == 1'b1; valorB[0] == 1'b1; }
  endclass

  Numeros numeros_rcsg;

  // =======================
  // Covergroup
  // =======================
  covergroup cg_paridad @(posedge END_MULT);
    cpA : coverpoint A[0] {
      bins par = {1'b0};
      bins imp = {1'b1};
    }
    cpB : coverpoint B[0] {
      bins par = {1'b0};
      bins imp = {1'b1};
    }
    cross_paridad : cross cpA, cpB; // PP, PI, IP, II
  endgroup

  cg_paridad cov_paridad;

  // =======================
  // Reset
  // =======================
  task automatic do_reset();
    RESET = 1'b0;
    START = 1'b0;
    A     = '0;
    B     = '0;
    repeat (5) @(negedge CLOCK);
    RESET = 1'b1;
    @(negedge CLOCK);
  endtask

  // =======================
  // Aplicar & comprobar
  // =======================
  task automatic apply_and_check(
    input logic signed [TAM-1:0] a_i,
    input logic signed [TAM-1:0] b_i,
    input string                 tag
  );
    logic signed [2*TAM-1:0] exp_s;
    begin
      @(negedge CLOCK);
      A     = a_i;
      B     = b_i;
      START = 1'b1;
      @(negedge CLOCK);
      START = 1'b0;

      @(posedge END_MULT);

      exp_s = a_i * b_i;
      total_tests++;

      if (S === exp_s) begin
        pass_tests++;
        $display("[%0t] %s OK   A=%0d B=%0d -> S=%0d",
                 $time, tag, a_i, b_i, S);
      end else begin
        fail_tests++;
        $error("[%0t] %s FAIL A=%0d B=%0d -> S=%0d  EXP=%0d",
               $time, tag, a_i, b_i, S, exp_s);
      end

      cov_paridad.sample();

      @(negedge CLOCK);
    end
  endtask

  // =======================
  // Init objetos
  // =======================
  initial begin
    numeros_rcsg = new();
    cov_paridad  = new();
  end

  // =======================
  // Secuencia principal
  // =======================
  initial begin : main
    do_reset();

    // Desactivar todas las constraints específicas
    numeros_rcsg.c_PP.constraint_mode(0);
    numeros_rcsg.c_PI.constraint_mode(0);
    numeros_rcsg.c_IP.constraint_mode(0);
    numeros_rcsg.c_II.constraint_mode(0);

    // Fase 1: PP
    $display("\n[FASE 1] PARES x PARES");
    numeros_rcsg.c_PP.constraint_mode(1);
    while (cov_paridad.cross_paridad.get_coverage() < 25.0) begin
      assert(numeros_rcsg.randomize())
        else $fatal("Randomize PP");
      apply_and_check(numeros_rcsg.valorA, numeros_rcsg.valorB, "PP");
    end
    numeros_rcsg.c_PP.constraint_mode(0);

    // Fase 2: PI
    $display("\n[FASE 2] PARES x IMPARES");
    numeros_rcsg.c_PI.constraint_mode(1);
    while (cov_paridad.cross_paridad.get_coverage() < 50.0) begin
      assert(numeros_rcsg.randomize())
        else $fatal("Randomize PI");
      apply_and_check(numeros_rcsg.valorA, numeros_rcsg.valorB, "PI");
    end
    numeros_rcsg.c_PI.constraint_mode(0);

    // Fase 3: IP
    $display("\n[FASE 3] IMPARES x PARES");
    numeros_rcsg.c_IP.constraint_mode(1);
    while (cov_paridad.cross_paridad.get_coverage() < 75.0) begin
      assert(numeros_rcsg.randomize())
        else $fatal("Randomize IP");
      apply_and_check(numeros_rcsg.valorA, numeros_rcsg.valorB, "IP");
    end
    numeros_rcsg.c_IP.constraint_mode(0);

    // Fase 4: II
    $display("\n[FASE 4] IMPARES x IMPARES");
    numeros_rcsg.c_II.constraint_mode(1);
    while (cov_paridad.cross_paridad.get_coverage() < 100.0) begin
      assert(numeros_rcsg.randomize())
        else $fatal("Randomize II");
      apply_and_check(numeros_rcsg.valorA, numeros_rcsg.valorB, "II");
    end
    numeros_rcsg.c_II.constraint_mode(0);

    // Resumen
    $display("\n======================================");
    $display("  RESUMEN VERIFICACIÓN AVANZADA");
    $display("  Total tests : %0d", total_tests);
    $display("  Passed      : %0d", pass_tests);
    $display("  Failed      : %0d", fail_tests);
    $display("  Cobertura cross paridad: %0.2f %%",
             cov_paridad.cross_paridad.get_coverage());
    $display("======================================");

    if (fail_tests == 0 && cov_paridad.cross_paridad.get_coverage() == 100.0)
      $display("STATUS: OK ✅");
    else
      $display("STATUS: ERROR ❌");

    $finish;
  end

endprogram