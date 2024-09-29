# 一、**功能描述：**

verilog语言写串口接收模块，接收8bit的数据。

# 二、**端口描述：**

| 端口 | 描述 | 备注 |
| :------------ | :--| :-- |
|sysclk |系统时钟| |
|rst|复位信号||
|Baud_set|设置接收模块 的接收波特率||
|uart_rx|内部的串口接收信号|外部的串口发送信号通过uart_rx传数据给串口接收模块|
|Data|输出的8bit并行数据|uart_rx是一位一位传进来的;Data是一次性以8 bit 的形式输出的|
|rx_done|接收8bit数据完成的信号|它的拉高需要符合一个保证不出错约定  [^1] |
||||

[^1]: 约定：先发0xAB，再发0xCD，最后8bit数据接收完要以0xEF结尾，这样接收模块接收的数据才会被赋给Data输出。

# 三、**模块描述：**

| 模块名称 | 描述 |  备注  |
| :------------:| :--| :-- |
|Uart_rx_buf|接收窗口发送过来的数据，首先要检测下降沿。下降沿就是前 1 bit是1，后1 bit是0。用2个寄存器来寄存前1bit和后1bit。uart_rx是传进来的数据。uart_rx_buf[0] 存后1bit;uart_rx_buf[1] 存前1bit。| |
|nedge and pede|描述寄存器的模块：如果是uart_rx_buf==10，就说明是下降沿，就可以开始接收数据了。如果Uart_rx_buf==01，就说明是上升沿。||
|Baud_27|设置接收模块的波特率的，控制接收的速率。检测Baud_set的值，如果是0，代表1s，传送115200 bit。|因为芯片晶振是50M的，也就是1个时钟周期为20ns。1s=1_000_000_000ns, 1bit所需时间为8680ns。8680ns/20ns是时钟周期个数 = 434个。1bit被分为了16份儿 [^2] 了。434/16=27个拍子。 |
|Baud_cnt_27|数拍子的计数器|每数到27，就清零|
|En_rx|接收使能信号|默认低电平，高电平有效，遇到rx_done就拉低了|
|cnt_16|1bit 被分成16个part ，1 个 part ==27 个拍子，每当Baud_cnt_27记到12的时候，cnt=cnt+1。加到16清零||
|r_data|这个模块采样。在每bit最中间的时候采样，采到的值1寄存到寄存器里面|1个sta_bit起始位，8个8bit的寄存器，1个停止位sto_bit ```reg [2:0]r_data[7:0]```|
|Data|判断r_data里面的值，大于3，代表采样到的值是1；否则是0.把每bit采样的值赋给对应的Data寄存器|最后输出的Data是一个8位数组|
|rx_done|传输结束的信号，1bit是16part，串口发送一次是10bit。当cnt记到159的时候，清零。此时rx_done拉高，代表一次传输结束。||
||||

[^2]:1bit是高还是低，要看采样出来的信号。被分成16part是为了提高采样的精度。在每bit的中间采样，采出来的信号累加，如果原本传输的是0，则采样累加之后也是0，包括上采样中出现的误差，最大值定位3，大于3就代表1；小于3就代表0。

# 四、代码
* 接收代码
``` verilog
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
/*------------------------------En_rx----------------------To detect the start signal--*/
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
            Data[0] <= r_data[0]>=4?1:0;
            Data[1] <= r_data[1]>=4?1:0;
            Data[2] <= r_data[2]>=4?1:0;
            Data[3] <= r_data[3]>=4?1:0;
            Data[4] <= r_data[4]>=4?1:0;
            Data[5] <= r_data[5]>=4?1:0;
            Data[6] <= r_data[6]>=4?1:0;
            Data[7] <= r_data[7]>=4?1:0;
        end
            
    end
    else
        Data <= Data;    
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
//reg [3:0] cnt2;
//always @(posedge sysclk or negedge rst) begin
//   if (!rst) begin
//        cnt2 <= 0;
//   end
//   else case ()
//    : 
//    default: 
//   endcase
//end
endmodule

```
* 测试代码 [^3]
``` verilog
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
uart_rx1(8'b0000_1111);
   
uart_rx1(8'b1111_1111);

uart_rx1(8'b0000_1111);
#5000;        
$stop;
end

/*-----------task -------------*/
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

``` 

[^3]:task任务语法：
task 任务名；
input 输入参数；
    begin 任务内容；
    end
endtask



# 五、**details**

| 问题 | 回答 | 备注 |
| :------------ | :--| :-- |
|0|| 期待大家的问题，让我更好的学习|
|1|||
|2|||
|3|||
|4|||
|5|||
|6|||
|7|||
