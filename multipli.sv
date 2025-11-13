module multipli #(
  parameter int tamano = 8
)(
  input  logic                          CLOCK,
  input  logic                          RESET,     // activo en bajo
  input  logic                          START,
  input  logic signed [tamano-1:0]      A,         // con signo
  input  logic signed [tamano-1:0]      B,         // con signo
  output logic signed [2*tamano-1:0]    S,         // con signo
  output logic                          END_MULT
);

  // ------------------------------------------------------------------
  // Parámetros internos: más ancho para soportar ±2M correctamente
  // ------------------------------------------------------------------
  localparam int W_ACC = tamano + 2;                 // acumulador ampliado
  localparam int W_QAX = W_ACC + tamano + 1;         // {Accu, LO, X}

  // ------------------------------------------------------------------
  // Estados
  // ------------------------------------------------------------------
  typedef enum logic [2:0] { IDLE, INIT, OP, SHIFT, NOTIFY } state_t;
  state_t state, next_state;

  // ------------------------------------------------------------------
  // Registros internos
  // ------------------------------------------------------------------
  logic signed [W_ACC-1:0] Accu;        // Acumulador ampliado
  logic signed [W_ACC-1:0] M_ext;       // Multiplicando extendido a W_ACC
  logic        [tamano-1:0] LO;         // Q (multiplicador)
  logic                     X;          // q(-1)
  logic [$clog2(tamano+1)-1:0] count;   // cuenta bits (de 2 en 2)

  // ------------------------------------------------------------------
  // Registro de estado
  // ------------------------------------------------------------------
  always_ff @(posedge CLOCK or negedge RESET) begin
    if (!RESET)
      state <= IDLE;
    else
      state <= next_state;
  end

  // ------------------------------------------------------------------
  // Lógica secuencial de datos y salidas
  // ------------------------------------------------------------------
  always_ff @(posedge CLOCK or negedge RESET) begin
    if (!RESET) begin
      Accu     <= '0;
      M_ext    <= '0;
      LO       <= '0;
      X        <= 1'b0;
      count    <= '0;
      END_MULT <= 1'b0;
    end else begin
      unique case (state)

        // ---------------- IDLE ----------------
        IDLE: begin
          END_MULT <= 1'b0;
        end

        // ---------------- INIT ----------------
        INIT: begin
          Accu     <= '0;
          LO       <= A;   // multiplicador
          // B extendido a W_ACC bits (sign-extend)
          M_ext    <= {{(W_ACC-tamano){B[tamano-1]}}, B};
          X        <= 1'b0;
          count    <= '0;
          END_MULT <= 1'b0;
        end

        // ---------------- OP (Booth radix-4) ----------------
        OP: begin
          logic [2:0] code;
          code = {LO[1:0], X};

          // usamos siempre M_ext ya extendido
          unique case (code)
            3'b000, 3'b111: Accu <= Accu;                  //  0
            3'b001, 3'b010: Accu <= Accu +      M_ext;     // +M
            3'b011:         Accu <= Accu + (M_ext <<< 1);  // +2M
            3'b100:         Accu <= Accu - (M_ext <<< 1);  // -2M
            3'b101, 3'b110: Accu <= Accu -      M_ext;     // -M
            default:        Accu <= Accu;
          endcase

          count <= count + 2;
        end

        // ---------------- SHIFT (aritmético 2 bits) ----------------
        SHIFT: begin
          logic signed [W_QAX-1:0] QAX;

          QAX = {Accu, LO, X};  // concatenamos todo
          QAX = QAX >>> 2;      // desplazamiento aritmético 2 bits

          // reparto automático por tamaños
          {Accu, LO, X} <= QAX;
        end

        // ---------------- NOTIFY ----------------
        NOTIFY: begin
          END_MULT <= 1'b1;
        end

        default: begin
          END_MULT <= 1'b0;
        end

      endcase
    end
  end

  // ------------------------------------------------------------------
  // Próximo estado
  // ------------------------------------------------------------------
  always_comb begin
    next_state = state;
    unique case (state)
      IDLE:    next_state = (START) ? INIT       : IDLE;
      INIT:    next_state = OP;
      OP:      next_state = SHIFT;
      SHIFT:   next_state = (count >= tamano) ? NOTIFY : OP;
      NOTIFY:  next_state = (START) ? NOTIFY    : IDLE;
      default: next_state = IDLE;
    endcase
  end

  // ------------------------------------------------------------------
  // Resultado:
  // De {Accu, LO} (W_ACC + tamano bits) tomamos 2*tamano LSB:
  // los bits más altos de Accu son solo extensión de signo.
  // ------------------------------------------------------------------
  assign S = {Accu[tamano-1:0], LO};

endmodule


