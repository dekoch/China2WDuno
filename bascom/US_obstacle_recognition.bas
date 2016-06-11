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

Config Watchdog = 2048

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



'Variables, Subs and Functions
Declare Sub SelectNextTask()
Declare Function GetUSDistance() As Word
Declare Function GetUSAverage() As Word

'pseudo multitasking
Dim T As Byte
Dim Flaga1 As Bit
Dim Flaga2 As Bit
Dim Flaga3 As Bit

Dim sTemp As Single
Dim sOffset As Single

Const cMeasPoints = 18
Dim bCurrMeasPoint As Byte
Dim wUSMeasPoints(cMeasPoints) As Word
Dim bUSWaitTime As Byte
Dim mSearchRight As Bit
Dim bNewDirection As Byte


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
bNewDirection = 90 '0 = right / 90 = middle / 180 = left

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
   Task1:


   Call SelectNextTask()


   '-----------------------------
   'communication
   Task2:


   Call SelectNextTask()


   '-----------------------------
   'obstacle recognition
   Task3:
   'task needs 38ms if no obstacle found

   If bUSWaitTime = 0 Then

      'mesure distance and log value into array
      wUSMeasPoints(bCurrMeasPoint) = GetUSDistance()


      Dim mMeasComplete As Bit

      'decide which direction for next measuring point
      If mSearchRight = 0 Then

         bCurrMeasPoint = bCurrMeasPoint + 1

         If bCurrMeasPoint >= cMeasPoints Then

            mSearchRight = 1
            mMeasComplete = 1
         End If
      Else

         bCurrMeasPoint = bCurrMeasPoint - 1

         If bCurrMeasPoint <= 1 Then

            mSearchRight = 0
            mMeasComplete = 1
         End If
      End If

      'if series of measurements is complete, set new direction
      If mMeasComplete = 1 Then

         Dim b As Byte

         For b = 1 To cMeasPoints

            Print "US Points: " ; wUSMeasPoints(b)
         Next b


         Dim bIndex As Byte
         Dim wMaxValue As Word
         Dim wLeftValue As Word
         Dim wRightValue As Word
         Dim wAverage As Word
         Dim mFreeDirection As Bit

         mFreeDirection = 1


         wAverage = GetUSAverage()

         Print "US Average: " ; wAverage


         Max(wUSMeasPoints(1) , wMaxValue , bIndex)


         If bIndex > 0 Then
            wLeftValue = wUSMeasPoints(bIndex - 1)

            If wLeftValue < wAverage Then

               mFreeDirection = 0
            End If
         End If

         If bIndex < cMeasPoints Then
            wRightValue = wUSMeasPoints(bIndex + 1)

            If wRightValue < wAverage Then

               mFreeDirection = 0
            End If
         End If

         'if left and right measuring point (relative to max. value)
         'is over average, then set new direction 0..180 degree
         If mFreeDirection = 1 Then

            sTemp = cMeasPoints - 1
            sTemp = 180 / sTemp

            sOffset = sTemp

            sTemp = sTemp * bIndex
            sTemp = sTemp - sOffset

            bNewDirection = sTemp

            Print "New Direction: " ; bNewDirection
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

   Call SelectNextTask()


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
   Dim mValid As Bit

   mValid = 1


   Pulseout PortC , 0 , 20 'min. 10us pulse

   Pulsein wOutput , PinC , 1 , 1 'read distance, timeout 655.35ms


   'Pulsein timeout
   If Err = 1 Then

      mValid = 0
   End If

   'sensor timeout
   If wOutput > 30 Then

      mValid = 0
   End If


   If mValid = 1 Then
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


   If bUSWaitTime >= 2 Then
      bUSWaitTime = bUSWaitTime - 2
   End If
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