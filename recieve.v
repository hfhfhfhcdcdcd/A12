module recieve (
    input sysclk,
    input rst,
    input [2:0]Baud_set,
    input uart_rx,
    output reg [7:0]Data,
    output reg rx_done
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
/*-------------------------------Baud_27---------------------------------*/
reg [13:0]Baud_27;//1 bit be seperated to 16 parts
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        Baud_27<=27;//means the freqency of 1 bit's 1/16 is 27(115200)
    end
    else case (Baud_set)
        0:Baud_27<=27;                 //115200; 
        1:Baud_27<=325;                  //9600; 
        2:Baud_27<=651;                   //9600;
        default:Baud_27<=27;             //115200; 
    endcase
end
/*----------------------------------------En_rx---------------------------To detect the start signal--*/
reg En_rx;//a signal to indicate the start of receiving
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        En_rx<=0;
    end
    else if (nedge) begin
        En_rx<=1;
    end
    else if (rx_done) begin//What time does the reception end? When the rx_done signal is pulled high
        En_rx<=0;
    end
    else
        En_rx<=En_rx;
end
/*-------------------------------Baud_cnt_27(from 0 to 27 )---------------------------------*/
reg [9:0]Baud_cnt_27;//a counter to count the number of each part of the 16 Baud_27
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        Baud_cnt_27<=0;
    end
    else if(En_rx) begin
        if (Baud_cnt_27==Baud_27-1) begin//Baud_27 is a parameter == 27
            Baud_cnt_27<=0;
        end
        else
            Baud_cnt_27<=Baud_cnt_27+1;
    end
    else//(!En_rx)   when the En_rx signal is not pulled high, means the transmission has not yet begun
        Baud_cnt_27<=0;
end
/*-------------------------------cnt_16---------------------------------*/
reg [7:0]cnt_16;//a counter to count the number of the 16 parts of the Baud_27
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        cnt_16<=0;
    end
    else if (En_rx) begin
        if (Baud_cnt_27==(Baud_27/2)-1) begin
            cnt_16<=cnt_16+1;
        end
        else if ((Baud_cnt_27==Baud_27-1)&&(cnt_16==159)) begin
            cnt_16<=0;
        end
        else
            cnt_16<=cnt_16;
    end
        
end
/*-------------------------------r_data---------------------------------*/
reg [2:0]r_data[7:0];//store the number of the 16 parts of the Data bit
reg [2:0]sta_bit;
reg [2:0]sto_bit;

always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        sta_bit<=0;
        r_data[0]<=0;
        r_data[1]<=0;
        r_data[2]<=0;
        r_data[3]<=0;
        r_data[4]<=0;
        r_data[5]<=0;
        r_data[6]<=0;
        r_data[7]<=0;
        sto_bit<=0;
    end
    else if (Baud_cnt_27==(Baud_27/2)-1) begin //when each 1/16's counter count to 12
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
    else if ((Baud_cnt_27==Baud_27-1)&&(cnt_16==159)) begin
        sta_bit<=0;
        r_data[0]<=0;
        r_data[1]<=0;
        r_data[2]<=0;
        r_data[3]<=0;
        r_data[4]<=0;
        r_data[5]<=0;
        r_data[6]<=0;
        r_data[7]<=0;
        sto_bit<=0;
    end
end
/*-------------------------------Data---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        Data <= 8'd0;
    end
    else if(En_rx) begin//cuz the transfer is started from the r_data[0]
        if ((Baud_cnt_27==Baud_27-1)&&(cnt_16==159)) begin
            Data <= sta_bit>=4  ?1:0;
            Data <= r_data[0]>=4?1:0;
            Data <= r_data[1]>=4?1:0;
            Data <= r_data[2]>=4?1:0;
            Data <= r_data[3]>=4?1:0;
            Data <= r_data[4]>=4?1:0;
            Data <= r_data[5]>=4?1:0;
            Data <= r_data[6]>=4?1:0;
            Data <= r_data[7]>=4?1:0;
            Data <= sto_bit>=4  ?1:0;
        end
        else
            Data <= 8'd0;    
    end
    else
        Data <= 8'd0;
end
/*-------------------------------rx_done---------------------------------*/
always @(posedge sysclk or negedge rst) begin
    if (!rst) begin
        rx_done <= 0;
    end
    else if ((Baud_cnt_27==Baud_27-1)&&(cnt_16==159)) begin//when cnt_16 is 159, one byte has been received, and then rx_done is 1
        rx_done <= 1;
    end
    else
        rx_done <= 0;
end
/*-------------------------------cnt2---------------------------------*/
reg [3:0] cnt2;
always @(posedge sysclk or negedge rst) begin
   if (!rst) begin
        cnt2 <= 4'd0;
    end
    else if ((Baud_cnt_27==Baud_27-1)&&(cnt2<4'd9)) begin
        case (cnt_16)
            15, 31, 47, 63, 79, 95, 111, 127, 143: cnt2 <= cnt2 + 1;
            default:cnt2 <= cnt2 ;
        endcase
    end
    else if ((cnt2==4'd9)&&(Baud_cnt_27==26)&&(cnt_16==159)) begin
        cnt2 <= 4'd0;
    end
    else
        cnt2 <= cnt2;
end
endmodule
