module spi_master (
input clk,rst,wr,
input ready,op_done,miso,
input [7:0]din,
input [7:0]addr,
output reg mosi,cs,
output [7:0]dout,
output reg done,err
);

typedef enum bit[2:0] {idle=0,load=1,check_op=2,write=3,send_addr=4,check_ready=5,read=6,error=7}state_type;

state_type state;         
reg [16:0]din_reg;
reg [7:0]dout_reg;
integer count;

assign dout = dout_reg;

always @(posedge clk) begin
    
    if(rst) begin
        state<=idle;
        cs<=1'b1;
        mosi<=1'b0;
        dout_reg<=8'b0;
        done<=1'b0;
        err<=1'b0;
        count<=32'b0;
        din_reg<=17'b0; 
    end

    else begin
        case (state)

        idle: begin
            state<=load;
            cs<=1'b1;
            mosi<=1'b0;
            dout_reg<=8'b0;
            done<=1'b0;
            err<=1'b0;
            count<=32'b0;
            din_reg<=17'b0;  
         end
        
        load: begin
            din_reg<={din,addr,wr};
            state<=check_op;
        end

        check_op: begin
          if(wr==1'b1 && addr<32) begin
            cs<=1'b0;
            state<=write;
          end
          else if(wr==1'b0 && addr<32) begin
            cs<=1'b0;
            state<=send_addr;
          end
          else  begin
            state<=error;
          end
            
         end

        write: begin 
            if(count<=16) begin
                mosi<=din_reg[count];
                count<=count+1'b1;
                state<=write;
            end
            else begin
                cs<=1'b1;
                mosi<=1'b0;
                if(op_done) begin
                  done<=1'b1;
                  state<=idle;
                  count<=1'b0;
                end
                else begin
                    state<=write;
                end
            end
        end

        send_addr: begin
          if(count<=8) begin
                mosi<=din_reg[count];
                count<=count+1'b1;
                state<=send_addr;
            end
            else begin
                cs<=1'b1;
                mosi<=1'b0;
                count<=1'b0;
                state<=check_ready;
            end
        end

        check_ready: begin
          if (ready) begin
            state<=read;
          end
          else begin
            state<=check_ready;
          end
        end

        read: begin
          if(count<=7) begin
            dout_reg[count]<=miso;
            count<=count+1'b1;
            state<=read;
          end
          else begin
             count<=0;
             state<=idle;
             done<=1'b1;
          end
        end

          error: begin
            err<=1'b1;
            state<=idle;
            done<=1'b1;
          end
      
        endcase
    end
end
 
endmodule

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module  spi_memory(
    input miso,cs,
    input clk,rst,
    output reg mosi,ready,op_done
);

  typedef enum bit[2:0]{idle=0,detect=1,receive_data=2,addr=3,send_data=4,start=5}state_type;
state_type state;

reg [7:0]mem[32];
integer count;
integer i;
reg [15:0] data_reg;
reg [7:0]addr_reg;
reg [7:0]data_out;


always @(posedge clk) begin
  if(rst) begin
        state<=idle;
        count<=0;
        mosi<=1'b0;
        ready<=1'b0;
        op_done<=1'b0;
        data_reg<=8'b0;
        addr_reg<=8'b0;
        data_out<=8'b0;
        for(i=0;i<32;i=i+1) begin
            mem[i]<=8'b0;
        end
    end

    else begin
        case(state)
          idle: begin
            count<=1'b0;
            mosi<=1'b1;
            ready<=1'b0;
            op_done<=1'b0;
            data_reg<=8'b0;
            addr_reg<=8'b0;
            data_out<=8'b0;
             if((cs==0)) 
             state<=detect;
            else 
              state<=idle;

          end

        detect: begin
            if(miso & (cs==0)) 
             state<=receive_data;
            else if ((!miso) & (cs==0))
              state<=addr; 
            else 
              state<=detect;
        end

        receive_data: begin
            if(count<=15) begin
                data_reg[count]<=miso;
                count<=count+1'b1;
                state<=receive_data;
            end

            else begin
                count<=1'b0;
                mem[{data_reg[7:0]}]<=data_reg[15:8];
                state<=idle;
                op_done<=1'b1;
            end

        end

       addr:begin
         if(count<=7)begin
            addr_reg[count]<=miso;
            count<=count+1'b1;
            state<=addr;
         end
         else begin
            count<=0;
            state<=send_data;
            ready<=1'b1;
            data_out<=mem[addr_reg];
         end
       end

       send_data: begin
        if(count<=7)begin
            mosi<=data_out[count];
            count<=count+1'b1;
            state<=send_data;
         end
         else begin
            count<=0;
            state<=idle;
            op_done<=1'b1;
         end
       end

       default: 
         state<=idle;

        endcase
    end
    
end
    
endmodule

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module spi_top(
    input clk,rst,wr,
    input [7:0]din,addr,
    output done,err,
    output [7:0]dout
);

wire cs,mosi,miso,op_done,ready;

spi_master dut1(clk,rst,wr,ready,op_done,miso,din,addr,mosi,cs,dout,done,err);
spi_memory dut2(mosi,cs,clk,rst,miso,ready,op_done);
  
  
endmodule
