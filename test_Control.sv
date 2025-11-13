//============================================================
// test_Control.sv
//============================================================
`timescale 1ns/1ps
import scoreboard_pkg::*;

program automatic test_bench (tb_if.test_mp tb);

  // ---------- Clase RCSG ----------
  class numeros_rcsg;
    rand logic signed [7:0] A;
    rand logic signed [7:0] B;

    constraint c_PP { A[0] == 1'b0; B[0] == 1'b0; }
    constraint c_PI { A[0] == 1'b0; B[0] == 1'b1; }
    constraint c_IP { A[0] == 1'b1; B[0] == 1'b0; }
    constraint c_II { A[0] == 1'b1; B[0] == 1'b1; }
  endclass

  numeros_rcsg gen;
  scoreboard sb; // instancia del scoreboard
  event comprobar; // evento para sincronizar comparaciones
  logic signed [15:0] cola[$]; // cola de resultados del modelo ideal

  // ---------- Covergroup ----------
  covergroup cg_paridad @(posedge tb.END_MULT);
    cpA : coverpoint tb.A[0] { bins par = {0}; bins imp = {1}; }
    cpB : coverpoint tb.B[0] { bins par = {0}; bins imp = {1}; }
    crossAB : cross cpA, cpB;
  endgroup

  cg_paridad cv = new();

  // ---------- Task RESET ----------
  task automatic reset_seq();
    tb.RESET = 0;
    tb.START = 0;
    repeat(5) @(negedge tb.CLOCK);
    tb.RESET = 1;
    @(negedge tb.CLOCK);
  endtask

  // ---------- Task TEST ----------
  task automatic run_test();
    gen = new();
    sb  = new();

    // Desactivar constraints
    gen.c_PP.constraint_mode(0);
    gen.c_PI.constraint_mode(0);
    gen.c_IP.constraint_mode(0);
    gen.c_II.constraint_mode(0);

    // === FASE 1: PARES x PARES ===
    $display("\n[FASE 1] PARES x PARES");
    gen.c_PP.constraint_mode(1);
    repeat (5) begin
      assert(gen.randomize());
      tb.A = gen.A; tb.B = gen.B;
      tb.START = 1; @(negedge tb.CLOCK);
      tb.START = 0;
      // Esperar un ciclo para que multipli_parallel calcule
      @(posedge tb.CLOCK);
      cola.push_front(tb.S_ref);
      @(posedge tb.END_MULT);
      sb.compare(tb.S_duv, cola.pop_back());
      cv.sample();
    end
    gen.c_PP.constraint_mode(0);

    // === FASES RESTANTES (PI, IP, II) ===
    // se repiten igual cambiando constraint activa...

    $display("Cobertura: %0.2f %%", cv.crossAB.get_coverage());
  endtask

  // ---------- Secuencia principal ----------
  initial begin
    reset_seq();
    run_test();
    $finish;
  end

endprogram