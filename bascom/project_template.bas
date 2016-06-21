$regfile = "m328def.dat"
$crystal = 16000000  '16MHz
$hwstack = 60
$swstack = 60
$framesize = 60

'########################################
'
' https://github.com/dekoch/China2WDuno
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

'Config and Settings
Const cServoOffset = 50

Const cBREAK = 0
Const cFWD = 201
Const cBWD = 202
Const cFFWD = 211
Const cFBWD = 212

Const cTimer2Sample = 2


Config Watchdog = 2048

Config Com1 = 57600 , Synchrone = 0 , Parity = None , Stopbits = 1 , Databits = 8 , Clockpol = 0

'Config Servos use TIMER0
'Servo1 = US direction
Config Servos = 1 , Servo1 = Portb.0 , Reload = 10

'pseudo multitasking use TIMER2
Config Timer2 = Timer , Prescale = 256
On Timer2 Scheduler
Const Timer2_Preload = 131
Load Timer2 = Timer2_Preload ' 2 ms sample
Enable Timer2
Start Timer2


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



'Variables, Subs and Functions
Declare Sub WaitByte(byref t As Byte)
Declare Sub WaitWord(byref t As Word)
Declare Function GetUSDistance() As Word
Declare Sub MotorControl()

'pseudo multitasking
Dim T As Byte
Dim Task1 As Bit
Dim Task2 As Bit
Dim Task3 As Bit

Dim bIsAliveWaitTime As Byte

Dim bSpeed As Byte
Dim bLeftMotor As Byte
Dim bRightMotor As Byte
Dim bMotorWaitTime As Byte


'Init State
'Input PullUp / PullDown
iUSEcho = 0 '0 = PullDown

qMotorIn1 = 0
qMotorIn2 = 0
qMotorIn3 = 0
qMotorIn4 = 0
qLED = 0 '0 = LED off
qUSTrig = 0

Servo(1) = cServoOffset


Enable Interrupts


'hello sequence
qLed = 1

Waitms 500

qLed = 0

Waitms 500

qLed = 1

Wait 1

qLed = 0



Do
   Start Watchdog

   '-----------------------------
   If Task1 = 1 Then



   '-----------------------------
   ElseIf Task2 = 1 Then



   '-----------------------------
   ElseIf Task3 = 1 Then



   End If


   If bIsAliveWaitTime = 0 Then

      Toggle qLED

      'if a task needs more than the reserved time (6ms),
      'the led will begin to flicker.
      'use this to improve your cycle time.
      bIsAliveWaitTime = cTimer2Sample * 3
   End If


   Stop Watchdog
Loop


End



'HC-SR04
'ultrasonic sensor
'Trigger 10us
'Echo 150us..25ms (38ms if no obstacle found)
'Ranging Distance 2..400 cm
Function GetUSDistance() As Word

   Local wOutput As Word


   Pulseout PortC , 0 , 20 'min. 10us pulse

   Pulsein wOutput , PinC , 1 , 1 'read distance, timeout 655.35ms


   If Err = 0 Then
      wOutput = wOutput / 58 'centimeters

      GetUSDistance = wOutput
   Else
      'timed out
      GetUSDistance = 0
   End If
End Function


Sub MotorControl()

   Local bMotor As Byte
   Dim mTempA As Bit
   Dim mTempB As Bit
   Local bT1 As Byte

   For bT1 = 1 To 2

      If bT1 = 1 Then

         bMotor = bLeftMotor
         mTempA = qMotorIn1
         mTempB = qMotorIn2
      ElseIf bT1 = 2 Then

         bMotor = bRightMotor
         mTempA = qMotorIn3
         mTempB = qMotorIn4
      End If


      Select Case bMotor

         Case cBREAK:
            mTempA = 0
            mTempB = 0


         Case cFWD:
            Toggle mTempA
            mTempB = 0

         Case cFFWD:
            mTempA = 1
            mTempB = 0

            bSpeed = 20


         Case cBWD:
            mTempA = 0
            Toggle mTempB

         Case cFBWD:
            mTempA = 0
            mTempB = 1

            bSpeed = 20

      End Select


      If bT1 = 1 Then

         qMotorIn1 = mTempA
         qMotorIn2 = mTempB
      ElseIf bT1 = 2 Then

         qMotorIn3 = mTempA
         qMotorIn4 = mTempB
      End If

   Next bT1


   If bSpeed > 20 Then

      bSpeed = 20
   End If


   bMotorWaitTime = 20 - bSpeed
End Sub




Scheduler:

   Incr T

   'enable other task on every third cycle
   If T >= 1 Then
      Task1 = 1
      Task2 = 0
      Task3 = 0
   End If

   If T >= 4 Then
      Task1 = 0
      Task2 = 1
      Task3 = 0
   End If

   If T >= 7 Then
      Task1 = 0
      Task2 = 0
      Task3 = 1
   End If

   If T >= 9 Then
      T = 0
      Delay
   End If


   Call WaitByte(bIsAliveWaitTime)

   Call WaitByte(bMotorWaitTime)


   If bMotorWaitTime = 0 Then

      Call MotorControl()
   End If


   Timer2 = Timer2_Preload
Return


Sub WaitByte(byref t As Byte)

   If t >= cTimer2Sample Then
      t = t - cTimer2Sample
   ElseIf t = 1 Then
      t = 0
   End If
End Sub


Sub WaitWord(byref t As Word)

   If t >= cTimer2Sample Then
      t = t - cTimer2Sample
   ElseIf t = 1 Then
      t = 0
   End If
End Sub