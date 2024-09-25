`timescale 1ns/1ps
module tb;
reg  sysclk;
reg  rst   ;
reg  [2:0]Baud_set;
reg  uart_rx;
wire [7:0]Data;
wire rx_done;

recieve r1(
    .sysclk  (sysclk  ),
    .rst     (rst     ),
    .Baud_set(Baud_set),
    .uart_rx (uart_rx ),
    .Data    (Data    ),
    .rx_done (rx_done )
);
/*---------------------------sysclk-------------------------------*/
initial begin
    sysclk=0;
end
always #10 sysclk=~sysclk;
/*---------------------------sysclk-------------------------------*/
initial begin
//0:
rst     =0;
Baud_set=0;
uart_rx =1;
//1:
#201
rst =1; 
#40;
Baud_set=0;
uart_rx=1;
#40;
uart_rx1(8'hAB);
#100;       
uart_rx1(8'hCD);
#100;        
$stop;
end

/*------------------------------task----------------------------------*/
task uart_rx1;
input [7:0]data;
begin
    uart_rx=1;
    #20;
    uart_rx=0;
    #8680;
    uart_rx=data[0];
    #8680;
    uart_rx=data[1];
    #8680;
    uart_rx=data[2];
    #8680;
    uart_rx=data[3];
    #8680;
    uart_rx=data[4];
    #8680;
    uart_rx=data[5];
    #8680;
    uart_rx=data[6];
    #8680;
    uart_rx=data[7];
    #8680;
    uart_rx=1;
    #8680;
end
endtask

endmodule
