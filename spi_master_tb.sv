 module spi_master(clk,rst,cs,din,newd,mosi,sclk);

input clk;
input rst;
input [11:0]din;
input newd;
output reg mosi;
output reg cs;
output sclk;
 
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
   
endmodule
//-------------------------------------------------------------------------------------------------
interface intf(input bit clk,rst);

 logic [11:0]din;
 logic newd;
 logic mosi;
 logic cs;
 logic sclk;

endinterface

class transaction;

rand bit [11:0]din;
 bit mosi;
 bit cs;
 bit sclk;
 bit [11:0]dref;

    task display(string name);  
      $display("[%0s]\t(DIN)=%0d\t(DREF)=%0d\t@%0d",name,din,dref,$time);
    endtask
    
endclass
//-------------------------------------------------------------------------------
class generator;
    mailbox gen2driv;
    mailbox gen2cov;
     mailbox gen2mon;
     event scbnext2;
  
  event ended;
  int i=1;
  int repeat_no;

  function new(mailbox  gen2driv, mailbox gen2cov,mailbox gen2mon);
        this.gen2driv=gen2driv;
        this.gen2cov=gen2cov;
        this.gen2mon=gen2mon;  
    endfunction

    task main;
      
      repeat (repeat_no) begin
      transaction t;
 	  t=new();
        if(!t.randomize)
                $fatal("RANDOMIZATION FAILED");
            else begin
                gen2driv.put(t);
                gen2cov.put(t);
                gen2mon.put(t);
                $display(" ");
              	 $display("TRANSECTION NUMBER = %0d",i);
                t.display("GENERATOR");
            end
            @(scbnext2);
           i++;
        end
      ->ended;
    endtask
endclass
//-------------------------------------------------------------------------------
class driver;
event drivnext;
virtual intf a;
mailbox gen2driv;

function new(mailbox gen2driv, virtual intf a);
    this.a=a;
    this.gen2driv=gen2driv;
endfunction


task reset;
  wait(a.rst==1);
      a.din=0;
      a.newd=0;
  wait(a.rst==0);
  $display("%0d",$time);
endtask

task main;
    transaction t;
  forever begin
      
    gen2driv.get(t);
       @(posedge a.sclk);
       a.newd=1;
       a.din=t.din;
       @(posedge a.sclk);
       a.newd=0;
    
    t.display("DRIVER");
     
    end
endtask

endclass
//-------------------------------------------------------------------------------

class monitor;
event scbnext;
virtual intf a;
mailbox mon2scb;
mailbox gen2mon;
  bit[11:0]dref;
int i=0;
  transaction t;
  function new(mailbox mon2scb,mailbox gen2mon ,virtual intf a);
    this.mon2scb=mon2scb;
    this.gen2mon=gen2mon;
    this.a=a;
    
endfunction

task main;
  
   forever begin
     gen2mon.get(t);
     i=0;
     repeat(2)@(posedge a.sclk);
     repeat(12) @(negedge a.sclk)begin
       dref[11-i]=a.mosi;
       i++;
     end 
          t.dref=dref;
    
     mon2scb.put(t);
        t.display("MONITOR");
        //->scbnext;
    end
endtask
endclass

//------------------------------------------------------------------------------------------
  class coverage;
    transaction t;
    mailbox gen2cov;
    covergroup cg;
    c1: coverpoint t.din;

  endgroup

  function new(mailbox gen2cov);
    	this.gen2cov=gen2cov; 
        t=new();
   	 	cg=new();
    endfunction

    task main();
      forever begin
       gen2cov.get(t);
       cg.sample(); 
      end
    endtask

    task display();
      $display("COVERAGE=%f",cg.get_coverage());
    endtask

endclass
//-------------------------------------------------------------------------------
class scoreboard;
    event scbnext2;
  mailbox mon2scb;
  
   transaction t; 
  bit [11:0]dref;
 
  function new(mailbox mon2scb);
    this.mon2scb=mon2scb;
    
endfunction
  
  task main();
   
   forever  begin
   
     mon2scb.get(t);
  
     if((t.din) == (t.dref) ) begin
      
       $display("VERIFICATION OF TEST CASE SUCESS");
     end
    else begin
       
      $display("VERIFICATION OF TEST CASE FAILURE");
    end
        
   	->scbnext2;
    
   end
  	
   endtask
  
endclass
//-------------------------------------------------------------------------------

class environment;

virtual intf a;
mailbox mon2scb;
mailbox gen2cov;
mailbox gen2driv;
mailbox gen2mon;
generator g;
monitor m;
scoreboard s;
coverage c;
 
     event nextgs2;
 
driver d;

function new(virtual intf a);

    this.a=a;
    mon2scb=new();
    gen2mon=new();
    gen2driv=new();
    gen2cov=new();
  g=new(gen2driv,gen2cov,gen2mon);
    d=new(gen2driv,a);
  m=new(mon2scb,gen2mon,a);
  s=new(mon2scb); 
   c=new(gen2cov);
         
         g.scbnext2=nextgs2;
         s.scbnext2=nextgs2;

endfunction

task pretest;
    d.reset();
endtask

task test;
    fork
        g.main();
        d.main();
        m.main();
      	s.main();
        c.main();
    join_any
endtask

 task post_test();
   wait(g.ended.triggered);
       $display("-------------------------------------------------------------------------------");
        c.display();
      $display("-------------------------------------------------------------------------------");
        $finish();
 endtask

task run;
  begin
    pretest();
    test();
    post_test(); 
         
  end
    
endtask

endclass
//-------------------------------------------------------------------------------

program test(intf a);
  
    environment env;
    initial begin
        env=new(a);
        env.g.repeat_no=824;
      env.run();
    end
endprogram
//-------------------------------------------------------------------------------

module add_tb;
  bit clk,rst;
initial begin
        clk=0;
        forever #5 clk=~clk;
    end
    initial begin
      rst=1;
      repeat(2) @(posedge clk);
      rst=0;
    end
  intf a(clk,rst);
  

test t1(a);

  spi_master dut (a.clk,a.rst,a.cs,a.din,a.newd,a.mosi,a.sclk);

initial begin 
    $dumpfile("dump.vcd"); 
  $dumpvars(1);
    
  end
endmodule

//-------------------------------------------------------------------------------

 