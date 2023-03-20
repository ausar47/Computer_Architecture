`timescale 1ns / 1ps

module ExceptionUnit(
    input clk, rst,             // 时钟，重�?
    input csr_rw_in,
    input[1:0] csr_wsc_mode_in,
    input csr_w_imm_mux,
    input[11:0] csr_rw_addr_in,
    input[31:0] csr_w_data_reg,
    input[4:0] csr_w_data_imm,
    output[31:0] csr_r_data_out, // 仿真的CSRout_MEM

    input interrupt,            // 外部中断
    input illegal_inst,         // 非法指令
    input l_access_fault,       // load access fault
    input s_access_fault,       // store access fault
    input ecall_m,

    input mret,

    input[31:0] epc_cur,
    input[31:0] epc_next,
    output[31:0] PC_redirect,   // 仿真的redirect
    output redirect_mux,

    output reg_FD_flush, reg_DE_flush, reg_EM_flush, reg_MW_flush, 
    output RegWrite_cancel
);

    reg[11:0] csr_raddr, csr_waddr;
    reg[31:0] csr_wdata;
    reg csr_w;
    reg[1:0] csr_wsc;

    wire[31:0] mstatus;

    //According to the diagram, design the Exception Unit
    reg[31:0] mepc, mtval, mcause; // 感觉mtval没啥用？
    wire[31:0] mtvec, mepc_out;

    wire exception, trap;
    assign exception = illegal_inst | l_access_fault | s_access_fault | ecall_m;
    assign trap = mstatus[3] & (interrupt | exception);
    assign redirect_mux = (mret | trap) ? 1'b1 : 1'b0;
    assign reg_FD_flush = (mret | trap) ? 1'b1 : 1'b0;
    assign reg_DE_flush = (mret | trap) ? 1'b1 : 1'b0;
    assign reg_EM_flush = (mret | trap) ? 1'b1 : 1'b0;
    assign reg_MW_flush = trap ? 1'b1 : 1'b0;
    assign RegWrite_cancel = trap ? 1'b1 : 1'b0;
    assign PC_redirect = mret ? mepc_out : mtvec;

    always @* begin
        if (csr_rw_in) begin //
            csr_w <= 1;
            csr_wsc <= csr_wsc_mode_in;
            csr_raddr <= csr_rw_addr_in;
            csr_waddr <= csr_rw_addr_in;
            csr_wdata <= csr_w_imm_mux ? csr_w_data_imm : csr_w_data_reg;
        end 
        else begin
            csr_w <= 0;
            csr_wsc <= 0;
            csr_raddr <= 0;
            csr_waddr <= 0;
            csr_wdata <= 0;
        end
        if (interrupt & mstatus[3]) begin
            mepc <= epc_next;
            mcause <= 32'h80000000;
        end
        else if (illegal_inst & mstatus[3]) begin
            mepc <= epc_cur;
            mcause <= 32'd2;
        end
        else if (l_access_fault & mstatus[3]) begin
            mepc <= epc_cur;
            mcause <= 32'd5;
        end
        else if (s_access_fault & mstatus[3]) begin
            mepc <= epc_cur;
            mcause <= 32'd7;
        end
        else if (ecall_m & mstatus[3]) begin
            mepc <= epc_cur;
            mcause <= 32'd11;
        end
        else if (mret) begin
            mepc <= 0;
            mcause <= 0;
        end
        else begin
            mepc = 0;
            mcause = 0;
        end
    end

    CSRRegs csr(.clk(clk),.rst(rst),.csr_w(csr_w),.raddr(csr_raddr),.waddr(csr_waddr),
        .wdata(csr_wdata),.rdata(csr_r_data_out),.mstatus(mstatus),.csr_wsc_mode(csr_wsc),
        .trap(trap),.mret(mret),.mepc(mepc),.mcause(mcause),.mtvec(mtvec),.mepc_out(mepc_out));
endmodule