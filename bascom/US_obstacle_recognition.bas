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
Declare Function GetUSDistance() As Word
Declare Function GetUSAverage() As Word

'pseudo multitasking
Dim T As Byte
Dim Task1 As Bit
Dim Task2 As Bit
Dim Task3 As Bit

Dim bTemp As Byte
Dim sTemp As Single
Dim sOffset As Single
Dim bIndex As Byte

Const cMeasPoints = 18
Dim bCurrMeasPoint As Byte
Dim wUSMeasPoints(cMeasPoints) As Word
Dim bUSWaitTime As Byte
Dim mSearchRight As Bit
Dim bFreeDirection As Byte
Dim mLastDirection As Bit '0 = left / 1 = right


Enable Interrupts


'Init State
'Input PullUp / PullDown
iUSEcho = 0 '0 = PullDown

qMotorIn1 = 0
qMotorIn2 = 0
qMotorIn3 = 0
qMotorIn4 = 0
qLED = 0 '0 = LED off
qUSTrig = 0

bCurrMeasPoint = 1
bFreeDirection = cMeasPoints / 2 '0 = right / 9 = middle / 18 = left

Servo(1) = 0


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
   'movement control
   If Task1 = 1 Then

      Dim wMinValue As Word

      Min(wUSMeasPoints(1) , wMinValue , bIndex)


      If wMinValue < 10 Then

         'stop motors


         If mLastDirection = 0 Then
            'turn left

         Else
            'turn tight

         End If
      Else

         bTemp = cMeasPoints / 2
         bTemp = bTemp + 2 'threshold

         'turn left
         If bFreeDirection > bTemp Then

            mLastDirection = 0


         End If


         bTemp = cMeasPoints / 2
         bTemp = bTemp - 2 'threshold

         'turn right
         If bFreeDirection < bTemp Then

            mLastDirection = 1


         End If
      End If

   End If


   '-----------------------------
   'communication
   If Task2 = 1 Then


   End If


   '-----------------------------
   'obstacle recognition
   If Task3 = 1 Then
      'task needs 38ms if no obstacle found

      If bUSWaitTime = 0 Then

         'mesure distance and log value into array
         wUSMeasPoints(bCurrMeasPoint) = GetUSDistance()


         Dim mMeasComplete As Bit

         'decide which direction for next measuring point
         If mSearchRight = 0 Then

            If bCurrMeasPoint >= cMeasPoints Then

               mSearchRight = 1
               mMeasComplete = 1

               bCurrMeasPoint = bCurrMeasPoint - 1
            Else

               bCurrMeasPoint = bCurrMeasPoint + 1
            End If
         Else

            If bCurrMeasPoint <= 1 Then

               mSearchRight = 0
               mMeasComplete = 1

               bCurrMeasPoint = bCurrMeasPoint + 1
            Else

               bCurrMeasPoint = bCurrMeasPoint - 1
            End If
         End If

         'if series of measurements is complete, set new direction
         If mMeasComplete = 1 Then

            Dim b As Byte

            For b = 1 To cMeasPoints

               Print "US Points: " ; wUSMeasPoints(b)
            Next b


            Dim wMaxValue As Word
            Dim wValue As Word
            Dim wAverage As Word
            Dim mFreeDirection As Bit

            mFreeDirection = 1


            wAverage = GetUSAverage()

            Print "US Average: " ; wAverage


            Max(wUSMeasPoints(1) , wMaxValue , bIndex)


            If bIndex > 1 Then
               wValue = wUSMeasPoints(bIndex - 1)

               If wValue < wAverage Then

                  mFreeDirection = 0
               End If
            End If

            If bIndex < cMeasPoints Then
               wValue = wUSMeasPoints(bIndex + 1)

               If wValue < wAverage Then

                  mFreeDirection = 0
               End If
            End If

            'if left and right measuring point (relative to max. value)
            'is over average, then set new direction
            If mFreeDirection = 1 Then

               bFreeDirection = bIndex

               Print "Free Direction: " ; bFreeDirection
            End If
         End If


         'set servo angle
         'measuring points 1..18 = servo signal 0..100 = 0..180 degree
         sTemp = cMeasPoints - 1
         sTemp = 100 / sTemp

         sOffset = sTemp

         sTemp = sTemp * bCurrMeasPoint
         sTemp = sTemp - sOffset

         Servo(1) = sTemp


         bUSWaitTime = 10 'wait min. 10ms for servo
      End If

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


Function GetUSAverage() As Word

   Dim lAverage As Long
   Local Dim b As Byte

   For b = 1 To cMeasPoints

      lAverage = lAverage + wUSMeasPoints(b)
   Next b

   lAverage = lAverage / cMeasPoints

   GetUSAverage = lAverage
End Function





Scheduler:
   Timer2 = Timer2_Preload

   Incr T

   If T >= 1 Then
      Task1 = 1
      Task2 = 0
      Task3 = 0
   End If

   If T >= 5 Then
      Task1 = 0
      Task2 = 1
      Task3 = 0
   End If

   If T >= 9 Then
      Task1 = 0
      Task2 = 0
      Task3 = 1

      T = 0
   End If


   If bUSWaitTime >= 2 Then
      bUSWaitTime = bUSWaitTime - 2
   End If
Return