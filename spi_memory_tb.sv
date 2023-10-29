interface intf(input bit clk);
  
   logic rst,wr;
   logic [7:0]din,addr;
   logic done,err;
   logic [7:0]dout; 
  
endinterface

class transaction;

  typedef enum bit [1:0] {write=0, read=1, writeer=2, reader=3} oper_type;
    rand oper_type   oper;
       bit wr;
       rand bit[7:0]din,addr;
       bit done,err;
       bit [7:0]dout;
  
  constraint cn1{addr<32; }
  constraint cn4{ if( (oper==3) | (oper==2))
                       din==0;
                }
  constraint cn2 {din inside {[0:100]};}
  constraint cn3 {oper dist{0:=35, 1:=35, 2:=35, 3:=35};}
  constraint cn5 {solve oper before din;}

    function void display(string s);    
      $display("%s\tOPER=%s\tADDR=%0d\tDIN=%0d\t@%0d",s,oper.name(),addr,din,$time);
    endfunction

endclass
//--------------------------------------------------------------------------------------------------------------------------------------------------
class generator;
  mailbox #(transaction) gen2driv;
  mailbox gen2cov;
    int repeat_no;
    event drivnext;
    event scbnext;
    event ended;
    int i;

  function new(mailbox #(transaction) gen2driv, mailbox gen2cov);
        this.gen2driv=gen2driv;
        this.gen2cov=gen2cov;
    endfunction

    task main();
        transaction t;
        t=new();
        i=1;
        repeat(repeat_no) begin
            
            if(!t.randomize)
              $fatal("RANDOMIZATION FAILED");
            else begin
              $display("\nTRANSECTION NUMBER = %0d",i);
              t.display("GENERATOR ");
            end
          gen2driv.put(t);
          gen2cov.put(t);
          i++;
          @(scbnext);
        end
        ->ended;
    endtask
endclass
//--------------------------------------------------------------------------------------------------------------------------------------------------
class driver;
  mailbox #(transaction)gen2driv;
    mailbox #(transaction) driv2scb;
    event drivnext;
    int no_trans=0;
    virtual intf intf_h;
    int i=1;
    bit[7:0] din;
transaction t;
  function new(mailbox #(transaction) gen2driv, mailbox #(transaction) driv2scb,virtual intf intf_h);
        this.gen2driv=gen2driv;
        this.driv2scb=driv2scb;
        this.intf_h=intf_h;
    t=new();
    endfunction

    task reset();
        $display("\nRESET STARTED");
        intf_h.rst<=1'b1;
        intf_h.wr<=0;
        intf_h.din<=0;
        intf_h.addr<=0;
        @(posedge intf_h.clk);
        intf_h.rst<=1'b0;
      $display("RESET FINISHED");
    endtask

    task main();
        
      
        forever begin
		  
        gen2driv.get(t); 
        driv2scb.put(t);
          
        if(t.oper==2'b00) begin //write transfer  //@15 start
         
           intf_h.wr<=1;
           intf_h.din<=t.din;
           intf_h.addr<=t.addr;
          @(posedge intf_h.clk);          //15 signals will be updated.
           $display("DRIVER    \t\tTRANSMITTED DATA IS %0d   \t@%0d",t.din,$time);
            wait(intf_h.done);
          @(posedge intf_h.clk);
           ->drivnext;
        end
          
      //---------------------------------------------------------------------------
           
        else if(t.oper==2'b01)begin
          
           intf_h.wr<=0;
           intf_h.din<=t.din;
           intf_h.addr<=t.addr;
           @(posedge intf_h.clk);           //15 signals will be updated.
           $display("DRIVER    \t\tDATA READ REQUESTED @%0d ADDR LOCATON \t@%0d",t.addr,$time);
             wait(intf_h.done);
           @(posedge intf_h.clk);
          
           ->drivnext;
         
        end
         
       //---------------------------------------------------------------------------
          
        else if(t.oper==2'b10)begin //write transfer  //@15 start
        					       
           intf_h.wr<=1;
           intf_h.din<=t.din;
          intf_h.addr<=$urandom_range(32,50);
           @(posedge intf_h.clk);           //15 signals will be updated.
           $display("DRIVER    \t\tTRANSMITTED DATA IS %0d   \t@%0d",t.din,$time);
           wait(intf_h.done);
           @(posedge intf_h.clk);
           ->drivnext;
        end
      //---------------------------------------------------------------------------
        else if(t.oper==2'b11)begin
           
           intf_h.wr<=0;
           intf_h.din<=t.din;
           intf_h.addr<=$urandom_range(32,50);
           @(posedge intf_h.clk);           //15 signals will be updated.
           $display("DRIVER    \t\tDATA READ REQUESTED @%0d ADDR LOCATON \t@%0d",t.addr,$time);
            wait(intf_h.done);
           @(posedge intf_h.clk);
           ->drivnext;
         
        end
      //---------------------------------------------------------------------------
          
         
    end
      
      
    endtask


endclass
//--------------------------------------------------------------------------------------------------------------------------------------------------
class monitor;
    mailbox #(transaction) mon2scb;
    virtual intf intf_h;
    int i;
    transaction t;

     function new(mailbox #(transaction) mon2scb,virtual intf intf_h);
        this.mon2scb=mon2scb;
        this.intf_h=intf_h;
        t=new();
    endfunction

    task main();
      forever begin     
        @(posedge intf_h.clk);
        wait(intf_h.done);
        t.wr=intf_h.wr;
        t.din=intf_h.din;
        t.addr=intf_h.addr;
        t.dout=intf_h.dout;
        t.err=intf_h.err;
        mon2scb.put(t);
      end
       
    endtask

endclass
//--------------------------------------------------------------------------------------------------------------------------------------------------
class coverage;
    transaction t;
    mailbox gen2cov;
    covergroup cg;
      c1: coverpoint  t.oper;  
      c2: coverpoint  t.addr{bins b0={32'd0}; bins b1={32'd1};
                              bins b2={32'd2}; bins b3={32'd3};
                              bins b4={32'd4}; bins b5={32'd5};
                              bins b6={32'd6}; bins b7={32'd7};
                              bins b8={32'd8}; bins b9={32'd9};
                             bins b10={32'd10}; bins b11={32'd11};
                             bins b12={32'd12}; bins b13={32'd13};
                             bins b15={32'd15}; bins b14={32'd14};
                             bins b16={[16:23]}; bins b17={[24:32]};  }
      c3: coverpoint  t.din;
      c4: cross c1,c2;
        
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
//--------------------------------------------------------------------------------------------------------------------------------------------------
class scoreboard;
    mailbox #(transaction)mon2scb;
    mailbox #(transaction)driv2scb;
    event scbnext;
    int no_trans;
    bit [31:0]rdata;
  bit [7:0]pwdata[32]='{default:'0};
    int q[$];
    int i=1;
  transaction t,t1;

  function new(mailbox #(transaction) mon2scb, mailbox #(transaction) driv2scb);
        this.driv2scb=driv2scb;
        this.mon2scb=mon2scb;
        t=new();
    endfunction

    task main();
      
      forever begin
        
      driv2scb.get(t1);
      mon2scb.get(t);
      
      if(t1.oper==2'b00) begin
        pwdata[t.addr]=t.din;
        $display("SCOREBOARD\t\t DATA WRITTEN ON MEMORY @%0d LOCATION IS %0d",t.addr,t.din);
                end
          //---------------------------------------------------------------------------
          
          if(t1.oper==2'b01) begin
                  
                  rdata=pwdata[t.addr];
            $display("SCOREBOARD\t\tDATA READ ON MEMORY @%0d LOCATION IS %0d",t.addr,t.dout);
                  
            if(rdata==t.dout)
                   	 $display("           \t\tDATA MATCHED");
                  
                   else begin
                     $display("          \t\t DATA MISMATCHED ACTUAL DATA =%0d %0d",rdata,t.dout);
                     $display("%p",pwdata);
                      q.push_front(i);
                      
                    end
            
          end
          //---------------------------------------------------------------------------
          if(t1.oper==2'b10) begin
              if(t.err)
                $display("SCOREBOARD\t\tERROR DETECTED & VERIFICATION OF ERROR +VE");
               else begin
                 $display("SCOREBOARD\t\tERROR DETECTED & VERIFICATION OF ERROR -VE");
                 q.push_front(i);
               end
                end
         //---------------------------------------------------------------------------
          
          if(t1.oper==2'b11) begin
              if(t.err)
                $display("SCOREBOARD\t\tERROR DETECTED & VERIFICATION OF ERROR +VE");
               else begin
                 $display("SCOREBOARD\t\tERROR DETECTED & VERIFICATION OF ERROR -VE");
                 q.push_front(i);
               end
                end
        //---------------------------------------------------------------------------   
           
          i++;
            ->scbnext;
           
      end
            
    endtask
  
  task report_g;
     transaction t;
      int i;
      int temp;
      
      if(q.size()) begin
        $display("The  Failed Transections are %0d",q.size());
          foreach (q[i]) begin
            $display("%0d",q[i]);
          end
      end
      else
        $display("Passed all testcases");
    endtask
  
endclass
//--------------------------------------------------------------------------------------------------------------------------------------------------

class environment;
    mailbox #(transaction) gen2driv;
    mailbox # (transaction) driv2scb;
    mailbox # (transaction) mon2scb;
  	mailbox gen2cov;

    event nextgd;
    event nextgs;
    generator g;
    driver d;
    monitor m;
    scoreboard s;
  	coverage c;
    virtual intf intf_h;

    function new(virtual intf intf_h);
        this.intf_h=intf_h;
        gen2driv=new();
        driv2scb=new();
        mon2scb=new();
      	gen2cov=new();

        g=new(gen2driv,gen2cov);
        d=new(gen2driv,driv2scb,intf_h);
        m=new(mon2scb,intf_h);
        s=new(mon2scb,driv2scb);
    c=new(gen2cov);

        g.drivnext=nextgd;
        d.drivnext=nextgd;
        g.scbnext=nextgs;
        s.scbnext=nextgs;
    endfunction

    task pre_test();
        d.reset();
    endtask

    task test();
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
       s.report_g();
       $display("-------------------------------------------------------------------------------");
      c.display();
      $display("-------------------------------------------------------------------------------");
        $finish();
         
    endtask

    task run();
         pre_test();
         test();
        post_test();
    endtask

endclass
//--------------------------------------------------------------------------------------------------------------------------------------------------
program test(intf intf_h);
    environment e;
    initial begin
        e=new(intf_h);
        e.g.repeat_no=900;
      e.run();

    end
endprogram
//--------------------------------------------------------------------------------------------------------------------------------------------------
module tb;
    
    bit clk;

    initial begin
        clk=0;
    end
  
  always #5 clk=~clk;
 
	initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end
  
  intf a(clk);
  test t(a);

  spi_top dut(a.clk,a.rst,a.wr,a.din,a.addr,a.done,a.err,a.dout);
     
   

endmodule
