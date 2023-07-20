 module spi_master(clk,rst,cs,din,newd,mosi,miso,sclk,data_reg);

input clk;
input rst;
input [11:0]din;
input newd;
input miso;
output reg mosi;
output reg cs;
output sclk;
output [11:0]data_reg;

reg[1:0]countc;
reg [1:0]state;
reg [3:0]data_count;

parameter idle=2'd0,
           send=2'd1,
           recieve=2'd2;
 

always @(posedge clk or posedge rst) begin
    if(rst) begin
        countc<=2'b0;
    end
    else if (countc==1'b1) begin
        countc<=1'b0;
    end
    else 
     countc<=countc+1'b1;
end

always @(posedge sclk ) begin
    if(rst) begin
        
    end
end

assign sclk=countc[0];

   always @(posedge sclk or posedge rst) begin
    if(rst) begin
        state<=idle;
        cs<=1'b1;
        data_count<=4'b1;
      	mosi<=1'b0;
    end
    else begin
        case (state)

           idle : begin
                if(newd && (din!=0) ) begin
                    state<=send;
                    cs<=1'b0;
                  	mosi<=din[11];
                end
                else begin
                state<=idle;
                end
           end

           send : begin
                if(data_count==4'd12) begin
                    state<=idle;
                    data_count<=4'b1;
                    cs<=1'b1;
                end
                else begin
                 mosi<=din[11-data_count];
                 data_count<=data_count+1'b1;
                end
           end

           default: state<=idle;
             
        endcase
    end
      
end

/*always @(negedge sclk or posedge rst) begin
    if(rst) begin
        state<=idle;
         
        cs<=1'b1;
        data_count<=4'b1;
      	mosi<=1'b0;
    end
    else begin
        case (state)

           idle : begin
                if(newd && (din==0) ) begin
                    state<=recieve;
                    cs<=1'b0;
                  	data_reg[11]<=miso;
                end

                else begin
                state<=idle;
                end
           end

            recieve : begin  
                if(data_count==4'd12) begin
                    state<=idle;
                    data_count<=4'b1;
                    cs<=1'b1;
                end
                else begin
                 data_reg[11-data_count]<=miso;
                 data_count<=data_count+1'b1;
                end
           end

           default: state<=idle;
             
        endcase
    end
      
end*/



endmodule

module spi_master_tb;
  wire sclk;
  reg rst;
  reg clk;
  reg [11:0]din;
  reg newd;
  wire cs,mosi,sclk;
  wire [11:0]data_reg;
  
  spi_master dut (clk,rst,cs,din,newd,mosi,miso,sclk,data_reg);
  
  initial begin
    clk=0;rst=1;din=12'b1010101010101010;
    #5 rst=0;
    #15 newd=1'b1;
  end
  always #5 clk=~clk;
  
  initial begin 
    $dumpfile("dump.vcd"); 
  $dumpvars(1);
    #300 $finish();
  end
endmodule