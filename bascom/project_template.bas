$regfile = "m328def.dat"
$crystal = 16000000  '16MHz
$hwstack = 60
$swstack = 60
$framesize = 60

'########################################
'
' https://sourceforge.net/p/china2wduno
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
Config Timer2 = Timer, Prescale = 256
Enable Timer2
Const Timer2_Preload = 131 ' 2 ms
Timer2 = Timer2_Preload
On Timer2 Scheduler


'Inputs
Config PINC.1 = Input
iUSEcho Alias PINC.1


'Outputs
Config PORTB.0 = Output 'US Servo

Config PORTB.1 = Output
qMotorIn1 Alias Portb.1

Config PORTB.2 = Output
qMotorIn2 Alias Portb.2

Config PORTB.3 = Output
qMotorIn3 Alias Portb.3

Config PORTB.4 = Output
qMotorIn4 Alias Portb.4

Config PORTB.5 = Output
qLED Alias Portb.5

Config PORTC.0 = Output
qUSTrig Alias PortC.0


'Input PullUp / PullDown
iUSEcho = 0 '0 = PullDown


'Variables, Subs and Functions
Declare Sub SelectNextTask()
Declare Function GetUSDistance(Byref error As Bit) As Word

'pseudo multitasking
Dim T As Byte
Dim Flaga1 As Bit
Dim Flaga2 As Bit
Dim Flaga3 As Bit


Enable Interrupts


'Init Output State
qMotorIn1 = 0
qMotorIn2 = 0
qMotorIn3 = 0
qMotorIn4 = 0
qLED = 0 '0 = LED off
qUSTrig = 0

Servo(1) = 50


Do
   '-----------------------------
   Task1:


   Call SelectNextTask()


   '-----------------------------
   Task2:


   Call SelectNextTask()


   '-----------------------------
   Task3:


   Call SelectNextTask()

Loop


End




Function GetUSDistance(Byref error As Bit) As Word

   Local wOutput As Word

   Pulseout PortC , 0 , 20 'Min. 10us pulse

   Pulsein wOutput , PinC , 1 , 1 'read distance

   If Err = 0 Then
      wOutput = wOutput * 10 'calcullate to
      wOutput = wOutput / 58 ' centimeters
      'wOutput = wOutput / 6 ' milimeters
      GetUSDistance = wOutput
   Else
      'Pulsein timed out
      error = 1
      GetUSDistance = 0
   End If
End Function





Scheduler:
   Timer2 = Timer2_Preload

   Incr T

   Reset Flaga1
   Reset Flaga2
   Reset Flaga3

   Select Case T

      Case 2:
         Flaga1 = 1'for example task 1 starts if t=2 and ended if t=4

      Case 5:
         Flaga2 = 1

      Case 8
         Flaga3 = 1
         T = 0

   End Select

Return


Sub SelectNextTask()

   If Flaga1 = 1 Then
      Goto Task1
   Elseif Flaga2 = 1 Then
      Goto Task2
   Else
      Goto Task3
   End If

End Sub