$regfile = "m328def.dat"
$crystal = 16000000                                         '16MHz
$hwstack = 60
$swstack = 60
$framesize = 60

'########################################
'
' https://github.com/dekoch/China2WDuno.git
'
'########################################
'
'                    ARDUINO-Pin    ATMEGA328P-Port   FUNCTION             Sensor Shield V5.0
'Digital ( PWM~ )    0              PD.0              RX (UART)            COM / APC220 / Bluetooth
'                    1              PD.1              TX (UART)            COM / APC220 / Bluetooth
'm                   2              PD.2              INT0                 LCD-Serial / LCD-Parallel
'                    3              PD.3              INT1                 LCD-Serial / LCD-Parallel
'                    4              PD.4              T0                   LCD-Serial / LCD-Parallel
'                    5              PD.5              T1                   LCD-Parallel
'                    6              PD.6              AIN0                 LCD-Parallel
'                    7              PD.7              AIN1                 LCD-Parallel
'                    8              PB.0              ICP1 / CLK0          LCD-Parallel
'                    9              PB.1                                   LCD-Parallel
'                    10             PB.2                                   SD / LCD-Parallel
'                    11             PB.3              MOSI (ICSP)          SD / LCD-Parallel
'                    12             PB.4              MISO (ICSP)          SD / LCD-Parallel
'                    13             PB.5              SCK (ICSP) and LED   SD / LED / LCD-Parallel
'                    SDA            PC.4              SDA (I2C)            IIC
'                    SCL            PC.5              SCL (I2C)            IIC
'Analog-In (Digital) A0 (14)        PC.0                                   URF01 (HC-SR04 Trig)
'                    A1 (15)        PC.1                                   URF01 (HC-SR04 Echo)
'                    A2 (16)        PC.2
'                    A3 (17)        PC.3
'                    A4 (18)        PC.4              SDA (I2C)            IIC
'                    A5 (19)        PC.5              SCL (I2C)            IIC


Config Com1 = 57600 , Synchrone = 0 , Parity = None , Stopbits = 1 , Databits = 8 , Clockpol = 0

'Config Servos use TIMER0
'Servo1 = US direction
Config Servos = 1 , Servo1 = Portb.0 , Reload = 10

'pseudo multitasking use TIMER2
Config Timer2 = Timer , Prescale = 256
Enable Timer2
Const Timer2_preload = 131                                  ' 2 ms
Timer2 = Timer2_preload
On Timer2 Scheduler


'Inputs
Config Pinc.1 = Input
Iusecho Alias Pinc.1


'Outputs
Config Portb.0 = Output                                     'US Servo

Config Portb.1 = Output
Qmotorin1 Alias Portb.1

Config Portb.2 = Output
Qmotorin2 Alias Portb.2

Config Portb.3 = Output
Qmotorin3 Alias Portb.3

Config Portb.4 = Output
Qmotorin4 Alias Portb.4

Config Portb.5 = Output
Qled Alias Portb.5

Config Portc.0 = Output
Qustrig Alias Portc.0


'Input PullUp / PullDown
Iusecho = 0                                                 '0 = PullDown


'Variables, Subs and Functions
Declare Sub Selectnexttask()
Declare Function Getusdistance(byref Error As Bit) As Word

'pseudo multitasking
Dim T As Byte
Dim Flaga1 As Bit
Dim Flaga2 As Bit
Dim Flaga3 As Bit


Enable Interrupts


'Init Output State
Qmotorin1 = 0
Qmotorin2 = 0
Qmotorin3 = 0
Qmotorin4 = 0
Qled = 0                                                    '0 = LED off
Qustrig = 0

Servo(1) = 50


Do
   '-----------------------------
   Task1:


   Call Selectnexttask()


   '-----------------------------
   Task2:


   Call Selectnexttask()


   '-----------------------------
   Task3:


   Call Selectnexttask()

Loop


End




Function Getusdistance(byref Error As Bit) As Word

   Local Woutput As Word

   Pulseout Portc , 0 , 20                                  'Min. 10us pulse

   Pulsein Woutput , Pinc , 1 , 1                           'read distance

   If Err = 0 Then
      Woutput = Woutput * 10                                'calcullate to
      Woutput = Woutput / 58                                ' centimeters
      'wOutput = wOutput / 6 ' milimeters
      Getusdistance = Woutput
   Else
      'Pulsein timed out
      Error = 1
      Getusdistance = 0
   End If
End Function





Scheduler:
   Timer2 = Timer2_preload

   Incr T

   Reset Flaga1
   Reset Flaga2
   Reset Flaga3

   Select Case T

      Case 2:
         Flaga1 = 1                                         'for example task 1 starts if t=2 and ended if t=4

      Case 5:
         Flaga2 = 1

      Case 8
         Flaga3 = 1
         T = 0

   End Select

Return


Sub Selectnexttask()

   If Flaga1 = 1 Then
      Goto Task1
   Elseif Flaga2 = 1 Then
      Goto Task2
   Else
      Goto Task3
   End If

End Sub