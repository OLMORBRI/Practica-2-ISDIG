//============================================================
// scoreboard.sv
//============================================================
package scoreboard_pkg;

  class scoreboard;
    task automatic compare(logic signed [15:0] real_val,
                           logic signed [15:0] ideal_val);
      if (real_val === ideal_val)
        $display("[%0t] OK   -> %0d == %0d", $time, real_val, ideal_val);
      else
        $error("[%0t] ERROR -> DUV=%0d  REF=%0d", $time, real_val, ideal_val);
    endtask
  endclass

endpackage