`timescale 1ns/1ps

// ============================================================
// PROGRAM: Generación de estímulos, sincronización con END_MULT,
// comparación DUV vs modelo paralelo, cobertura funcional
// ============================================================
program automatic multipli_tb_prog
(
  input  logic               CLK,
  input  logic               END_MULT,     // del DUV
  input  logic signed [15:0] S_DUV,        // salida del DUV
  input  logic signed [15:0] S_REF,        // salida del modelo paralelo
  output logic               RESET,
  output logic               START,
  output logic signed [7:0]  A,
  output logic signed [7:0]  B
);

  // ---------- Clocking blocks ----------
  clocking drv_cb @(posedge CLK);
    default input #1ns output #1ns;
    output START, A, B;
    input  END_MULT, S_DUV, S_REF;
  endclocking
  clocking mon_cb @(posedge CLK);
    default input #1ns output #1ns;
    input  START, END_MULT, A, B, S_DUV, S_REF;
  endclocking
  default clocking drv_cb;

  // ---------- Helpers (compatibles Questa 2020.2) ----------
  function automatic bit is_pow2 (logic signed [7:0] v);
    return (v inside { -128, -64, -32, -16, -8, -4, -2, -1,
                        1, 2, 4, 8, 16, 32, 64 });
  endfunction
  function automatic bit is_edge (logic signed [7:0] v);
    return (v inside { -128, -127, -64, -32, -16, -8, -4, -2, -1,
                        0, 1, 2, 3, 7, 15, 31, 63, 64, 126, 127,
                        8'h55, 8'hAA, 8'h81, 8'h7E });
  endfunction

  // ---------- Cola para sincronizar modelo paralelo (combin.) y DUV (multiciclo) ----------
  logic signed [15:0] ref_q[$];

  // ---------- Clase generadora con constraints ----------
  class Ops;
    rand logic signed [7:0] A;
    rand logic signed [7:0] B;

    // Paridad
    constraint c_PP { A[0] == 1'b0; B[0] == 1'b0; }
    constraint c_PI { A[0] == 1'b0; B[0] == 1'b1; }
    constraint c_IP { A[0] == 1'b1; B[0] == 1'b0; }
    constraint c_II { A[0] == 1'b1; B[0] == 1'b1; }

    // Signo
    constraint c_SPP { A[7] == 1'b0; B[7] == 1'b0; }
    constraint c_SNN { A[7] == 1'b1; B[7] == 1'b1; }
    constraint c_SPN { A[7] == 1'b0; B[7] == 1'b1; }
    constraint c_SNP { A[7] == 1'b1; B[7] == 1'b0; }

    // Especiales
    rand bit selA0, selB0, selA1, selB1, selAm1, selBm1;
    constraint c_zero_one_minus1 {
      selA0  -> (A == 0);
      selB0  -> (B == 0);
      selA1  -> (A == 1);
      selB1  -> (B == 1);
      selAm1 -> (A == -1);
      selBm1 -> (B == -1);
    }

    rand bit selAp2, selBp2, selAedge, selBedge, sameAB, negPair;
    constraint c_pow2  { selAp2   -> is_pow2(A);  selBp2   -> is_pow2(B); }
    constraint c_edge  { selAedge -> is_edge(A);  selBedge -> is_edge(B); }
    constraint c_rel   { sameAB -> (B == A);
                         negPair -> (B == -A);
                         !(sameAB && negPair); }
  endclass
  Ops ops;

  // ---------- Covergroups ----------
  covergroup cg_par @(posedge mon_cb.END_MULT);
    cpA_par : coverpoint mon_cb.A[0] { bins par = {0}; bins imp = {1}; }
    cpB_par : coverpoint mon_cb.B[0] { bins par = {0}; bins imp = {1}; }
    cross_par : cross cpA_par, cpB_par;
  endgroup
  cg_par par_cov = new();

  covergroup cg_sign @(posedge mon_cb.END_MULT);
    cpA_s : coverpoint mon_cb.A[7] { bins neg = {1}; bins pos = {0}; }
    cpB_s : coverpoint mon_cb.B[7] { bins neg = {1}; bins pos = {0}; }
    cross_sign : cross cpA_s, cpB_s;
  endgroup
  cg_sign sign_cov = new();

  covergroup cg_special @(posedge mon_cb.END_MULT);
    cpA_zero : coverpoint (mon_cb.A == 0);
    cpB_zero : coverpoint (mon_cb.B == 0);
    cpA_pm1  : coverpoint (mon_cb.A inside {-1,1});
    cpB_pm1  : coverpoint (mon_cb.B inside {-1,1});
    cpA_p2   : coverpoint is_pow2(mon_cb.A);
    cpB_p2   : coverpoint is_pow2(mon_cb.B);
    cpA_edge : coverpoint is_edge(mon_cb.A);
    cpB_edge : coverpoint is_edge(mon_cb.B);
  endgroup
  cg_special spec_cov = new();

  // ---------- Dirigidos: DECLARACIÓN AQUÍ (fuera del initial) ----------
  typedef logic signed [7:0] s8_t;
  s8_t vec_dir [0:12];

  // ---------- Helper para evitar conflictos ----------
  task automatic disable_all_constraints();
    ops.c_PP.constraint_mode(0);
    ops.c_PI.constraint_mode(0);
    ops.c_IP.constraint_mode(0);
    ops.c_II.constraint_mode(0);
    ops.c_SPP.constraint_mode(0);
    ops.c_SNN.constraint_mode(0);
    ops.c_SPN.constraint_mode(0);
    ops.c_SNP.constraint_mode(0);
    ops.selA0=0; ops.selB0=0; ops.selA1=0; ops.selB1=0; ops.selAm1=0; ops.selBm1=0;
    ops.selAp2=0; ops.selBp2=0; ops.selAedge=0; ops.selBedge=0;
    ops.sameAB=0; ops.negPair=0;
  endtask

  // ---------- Monitor de entrada (ref) ----------
  task automatic monitor_input();
    forever begin
      @(mon_cb);
      if (mon_cb.START) begin
        @(negedge mon_cb.START);
        @(posedge CLK);
        ref_q.push_back(mon_cb.S_REF);
      end
    end
  endtask

  // ---------- Monitor de salida (comparación) ----------
  task automatic monitor_output();
    logic signed [15:0] exp;
    forever begin
      @(posedge mon_cb.END_MULT);
      if (ref_q.size() == 0) $fatal("Queue underflow");
      exp = ref_q.pop_front();

      assert (mon_cb.S_DUV === exp)
        else $error("[%0t] ERROR  A=%0d B=%0d  DUV=%0d  REF=%0d",
                    $time, mon_cb.A, mon_cb.B, mon_cb.S_DUV, exp);

      par_cov.sample();
      sign_cov.sample();
      spec_cov.sample();
    end
  endtask

  // ---------- Reset ----------
  task automatic reset_seq();
    RESET = 0; START = 0; A = 0; B = 0;
    repeat (5) @(negedge CLK);
    RESET = 1;
    @(negedge CLK);
  endtask

  // ---------- Driver sincronizado con END_MULT ----------
  task automatic drive_case(input logic signed [7:0] a_i,
                            input logic signed [7:0] b_i);
    @(negedge CLK);
    drv_cb.A     <= a_i;
    drv_cb.B     <= b_i;
    drv_cb.START <= 1'b1;
    @(negedge CLK);
    drv_cb.START <= 1'b0;
    @(posedge mon_cb.END_MULT); // espera a que finalice
    @(negedge CLK);             // un ciclo para estabilizar
  endtask

  // ---------- Secuencia principal ----------
  initial begin
    ops = new();
    fork
      monitor_input();
      monitor_output();
    join_none

    reset_seq();

    // INICIALIZACIÓN (asignación, no declaración) de vec_dir
    vec_dir = '{ 0, 1, -1, 2, -2, 64, -64, 127, -128, 8'h55, 8'hAA, 8'h81, 8'h7E };

    // Casos dirigidos
    foreach (vec_dir[i]) foreach (vec_dir[j])
      drive_case(vec_dir[i], vec_dir[j]);

    // Paridad
    disable_all_constraints(); ops.c_PP.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.c_PI.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.c_IP.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.c_II.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end

    // Signo
    disable_all_constraints(); ops.c_SPP.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.c_SNN.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.c_SPN.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.c_SNP.constraint_mode(1);
    repeat (15) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end

    // Casos especiales
    disable_all_constraints(); ops.selA0=1;  repeat(5)  begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.selAp2=1; repeat(8)  begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.sameAB=1; repeat(8)  begin assert(ops.randomize()); drive_case(ops.A,ops.B); end
    disable_all_constraints(); ops.negPair=1;repeat(8)  begin assert(ops.randomize()); drive_case(ops.A,ops.B); end

    // Aleatorios
    disable_all_constraints();
    repeat (100) begin assert(ops.randomize()); drive_case(ops.A,ops.B); end

    // Resultados
    repeat (20) @(negedge CLK);
    $display("Cobertura paridad   : %0.2f %%", par_cov.cross_par.get_coverage());
    $display("Cobertura signo     : %0.2f %%", sign_cov.cross_sign.get_coverage());
    $display("Cobertura especiales: %0.2f %%", spec_cov.get_inst_coverage());
    $finish;
  end

endprogram


// ============================================================
// TOP: reloj + DUV + modelo paralelo + program
// ============================================================
module tb_multipli_intermedia;

  logic clk;
  logic reset;
  logic start;
  logic signed [7:0]  A, B;
  logic signed [15:0] S_duv, S_ref;
  logic               END_MULT;

  // Reloj
  always #5 clk = ~clk;
  initial clk = 0;

  // DUV (Booth secuencial)
  multipli #(.tamano(8)) duv (
    .CLOCK    (clk),
    .RESET    (reset),
    .START    (start),
    .A        (A),
    .B        (B),
    .S        (S_duv),
    .END_MULT (END_MULT)
  );

  // Modelo paralelo de referencia (profesor)
//  multipli_parallel #(.tamano(8)) ref_model (
//    .CLOCK    (clk),
//    .RESET    (reset),
//    .START    (start),
//    .A        (A),
//    .B        (B),
//    .S        (S_ref),
//    .END_MULT ()
//  );

  // Program principal
  multipli_tb_prog TB (
    .CLK      (clk),
    .END_MULT (END_MULT),
    .S_DUV    (S_duv),
    .S_REF    (S_ref),
    .RESET    (reset),
    .START    (start),
    .A        (A),
    .B        (B)
  );

endmodule


