module recieve (
    input sysclk,
    input rst,
    input [2:0]Baud_set,
    input uart_rx,
    output [7:0]Data,
    output rx_done
    );
/*--------------------------------Uart_rx_buf--------------------------------*/
reg [1:0]uart_rx_buf;//a buffer to store the previous clock cycle and the current clock cycle of the uart_rx signal
always@(posedge sysclk) begin
uart_rx_buf[0]<=uart_rx;
uart_rx_buf[1]<=uart_rx_buf[0];
end
/*--------------------------------nedge and pede--------------------------------*/
wire pedge;//a signal to indicate the rising edge of the uart_rx signal
wire nedge;//a signal to indicate the falling edge of the uart_rx signal
assign nedge=(uart_rx_buf==2'b10);
assign pedge=(uart_rx_buf==2'b01);
/*-------------------------------Baud_16---------------------------------*/
reg [13:0]Baud_16;//1 bit be seperated to 16 parts
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
/*----------------------------------------En---------------------------To detect the start signal--*/
/*-------------------------------Baud_cnt_16(from 0 to 27/2 = 13 )---------------------------------*/
reg [9:0]Baud_cnt_16;//a counter to count the number of each part of the 16 Baud_16
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        Baud_cnt_16<=0;
    end
    else if (Baud_cnt_16==Baud_16-1) begin//Baud_16 is a parameter == 27
        Baud_cnt_16<=0;
    end
    else
        Baud_cnt_16<=Baud_cnt_16+1;
end
/*-------------------------------cnt_16---------------------------------*/
reg [7:0]cnt_16;//a counter to count the number of the 16 parts of the Baud_16
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
/*-------------------------------r_data---------------------------------*/
reg [2:0]r_data[7:0];//store the number of the 16 parts of the Data bit
reg [2:0]sta_bit;
reg [2:0]sto_bit;

always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        sta_bit<=0; 
        sto_bit<=0; 
        r_data[0]<=0;
        r_data[1]<=0;
        r_data[2]<=0;
        r_data[3]<=0;
        r_data[4]<=0;
        r_data[5]<=0;
        r_data[6]<=0;
        r_data[7]<=0;
        sta_bit<=0;
        sto_bit<=0;
    end
    else if (Baud_cnt_16==(Baud_16/2)-1) begin //when each 1/16's counter count to 12
        case (cnt_16)
            5,6,7,8,9:           begin sta_bit<=sta_bit+uart_rx;end //count the middle part of start bit           
            21,22,23,24,25:      begin r_data[0]<=r_data[0] + uart_rx ;end//count the middle part of r_data[0]
            37,38,39,40,41:      begin r_data[1]<=r_data[1] + uart_rx ;end//count the middle part of r_data[1]
            53,54,55,56,57:      begin r_data[2]<=r_data[2] + uart_rx ;end//count the middle part of r_data[2]
            69,70,71,72,73:      begin r_data[3]<=r_data[3] + uart_rx ;end//count the middle part of r_data[3]
            85,86,87,88,89:      begin r_data[4]<=r_data[4] + uart_rx ;end//count the middle part of r_data[4]
            101,102,103,104,105: begin r_data[5]<=r_data[5] + uart_rx ;end//count the middle part of r_data[5]
            117,118,119,120,121: begin r_data[6]<=r_data[6] + uart_rx ;end//count the middle part of r_data[6]
            133,134,135,136,137: begin r_data[7]<=r_data[7] + uart_rx ;end//count the middle part of r_data[7]
            149,150,151,152,153: begin sto_bit<=sto_bit+uart_rx; end//count the middle part of stop bit
            default: ;//when cnt_16 is not in the above cases, do nothing
        endcase
    end
/*-------------------------------Data---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    
end
/*-------------------------------rx_done---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    
end
endmodule
