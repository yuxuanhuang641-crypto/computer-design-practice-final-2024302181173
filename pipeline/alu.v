`include "ctrl_encode_def.v"

module alu(A, B, ALUOp, C, Zero);
   input  signed [31:0] A, B;
   input         [4:0]  ALUOp;
   output signed [31:0] C;
   output Zero;

   reg [31:0] C;

   always @(*) begin
      case (ALUOp)
      `ALUOp_lui:  C = B;
      `ALUOp_add:  C = A + B;
      `ALUOp_sub:  C = A - B;
      `ALUOp_bne:  C = (A != B);
      `ALUOp_blt:  C = (A < B);
      `ALUOp_bge:  C = (A >= B);
      `ALUOp_bltu: C = ($unsigned(A) < $unsigned(B));
      `ALUOp_bgeu: C = ($unsigned(A) >= $unsigned(B));
      `ALUOp_slt:  C = (A < B) ? 32'd1 : 32'd0;
      `ALUOp_sltu: C = ($unsigned(A) < $unsigned(B)) ? 32'd1 : 32'd0;
      `ALUOp_xor:  C = A ^ B;
      `ALUOp_or:   C = A | B;
      `ALUOp_and:  C = A & B;
      `ALUOp_sll:  C = A << B[4:0];
      `ALUOp_srl:  C = $unsigned(A) >> B[4:0];
      `ALUOp_sra:  C = A >>> B[4:0];
      default:     C = A;
      endcase
   end

   assign Zero = (ALUOp == `ALUOp_bne ||
                  ALUOp == `ALUOp_blt ||
                  ALUOp == `ALUOp_bge ||
                  ALUOp == `ALUOp_bltu ||
                  ALUOp == `ALUOp_bgeu) ? (C != 32'b0) : (C == 32'b0);

endmodule
