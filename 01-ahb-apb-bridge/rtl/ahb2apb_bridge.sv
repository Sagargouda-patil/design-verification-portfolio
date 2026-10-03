//------------------------------------------------------------------------------
// AHB-Lite to APB Bridge
// FSM: IDLE -> SETUP -> ACCESS (per APB protocol)
//  - IDLE  : HREADYOUT=1, waits for a valid AHB address phase (NONSEQ/SEQ)
//  - SETUP : APB setup phase  (PSEL=1, PENABLE=0), AHB stalled (HREADYOUT=0)
//  - ACCESS: APB access phase (PSEL=1, PENABLE=1), stays until PREADY=1
// Write data is taken directly from HWDATA, which the AHB master must hold
// stable while HREADY is low during the data phase.
//------------------------------------------------------------------------------
module ahb2apb_bridge #(
  parameter AW = 32,
  parameter DW = 32
)(
  input  logic          HCLK,
  input  logic          HRESETn,
  // AHB-Lite slave interface
  input  logic          HSEL,
  input  logic [AW-1:0] HADDR,
  input  logic          HWRITE,
  input  logic [1:0]    HTRANS,
  input  logic [2:0]    HSIZE,
  input  logic [DW-1:0] HWDATA,
  input  logic          HREADY,
  output logic [DW-1:0] HRDATA,
  output logic          HREADYOUT,
  output logic          HRESP,
  // APB master interface
  output logic [AW-1:0] PADDR,
  output logic          PSEL,
  output logic          PENABLE,
  output logic          PWRITE,
  output logic [DW-1:0] PWDATA,
  input  logic [DW-1:0] PRDATA,
  input  logic          PREADY
);

  localparam [1:0] IDLE = 2'd0, SETUP = 2'd1, ACCESS = 2'd2;

  logic [1:0]    state, next_state;
  logic [AW-1:0] addr_q;
  logic          write_q;

  // A valid AHB address phase is presented to us
  wire ahb_req = HSEL & HTRANS[1] & HREADY;

  // Latch address/control in the AHB address phase
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      addr_q  <= '0;
      write_q <= 1'b0;
    end else if (ahb_req) begin
      addr_q  <= HADDR;
      write_q <= HWRITE;
    end
  end

  // State register
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) state <= IDLE;
    else          state <= next_state;
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:   if (ahb_req) next_state = SETUP;
      SETUP:               next_state = ACCESS;
      ACCESS: if (PREADY)  next_state = ahb_req ? SETUP : IDLE; // back-to-back
      default:             next_state = IDLE;
    endcase
  end

  // Outputs
  assign PSEL      = (state == SETUP) || (state == ACCESS);
  assign PENABLE   = (state == ACCESS);
  assign PADDR     = addr_q;
  assign PWRITE    = write_q;
  assign PWDATA    = HWDATA;                 // held by master during data phase
  assign HRDATA    = PRDATA;
  assign HREADYOUT = (state == IDLE) || (state == ACCESS && PREADY);
  assign HRESP     = 1'b0;                   // OKAY (no error response)

endmodule
