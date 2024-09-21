module recieve (
    input sysclk,
    input rst,
    input [2:0]Baud_set,
    input uart_rx,
    output [7:0]Data,
    output rx_done
    );
/*--------------------------------parameters declaration--------------------------------*/
reg [13:0]Baud_16;//i bit be seperated to 16 parts
reg [9:0]Baud_cnt_16;//a counter to count the number of each part of the 16 Baud_16
reg [1:0]uart_rx_buf;//a buffer to store the previous clock cycle and the current clock cycle of the uart_rx signal
wire pedge;//a signal to indicate the rising edge of the uart_rx signal
wire nedge;//a signal to indicate the falling edge of the uart_rx signal
reg [7:0]cnt_16;//a counter to count the number of the 16 parts of the Baud_16
/*--------------------------------Uart_rx_buf--------------------------------*/
always@(posedge sysclk) begin
uart_rx_buf[0]<=uart_rx;
uart_rx_buf[1]<=uart_rx_buf[0];
end
/*--------------------------------nedge and pede--------------------------------*/
assign nedge=(uart_rx_buf==2'b10);
assign pedge=(uart_rx_buf==2'b01);
/*-------------------------------Baud_16---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        Baud_16<=27;//means the freqency of 1 bit's 1/16 is 27(115200)
    end
    else case (Baud_set)
        0:Baud_16<=651;                 //4800; 
        1:Baud_16<=325;                  //9600; 
        2:Baud_16<=27;                   //115200;
        default:Baud_16<=27;             //115200; 
    endcase
end
/*-------------------------------Baud_cnt_16(from 0 to 27/2 = 13 )---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        Baud_cnt_16<=0;
    end
    else if (Baud_cnt_16==(Baud_16/2)-1) begin
        Baud_cnt_16<=0;
    end
    else
        Baud_cnt_16<=Baud_cnt_16+1;
end
/*-------------------------------cnt_16---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        cnt_16<=0;
    end
    else if (Baud_cnt_16==(Baud_16/2)-1) begin
        cnt_16<=cnt_16+1;
    end
    else if (cnt_16==159) begin
        cnt_16<=0;
    end
    else
        cnt_16<=cnt_16;
end
/*-------------------------------Data---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    
end
/*-------------------------------rx_done---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    
end
endmodule
