$regfile = "m328def.dat"
$crystal = 16000000  '16MHz
$hwstack = 60
$swstack = 60
$framesize = 60
$baud = 38400

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
Const cMeasPoints = 18
Const cServoOffset = 50

Const cBREAK = 0
Const cFWD = 201
Const cBWD = 202
Const cFFWD = 211
Const cFBWD = 212

Const cTimer2Sample = 2


Config Watchdog = 2048

Config Serialin = Buffered , Size = 10, Bytematch = 13

Echo off

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
Declare Function GetUSAverage() As Word
Declare Sub MotorControl()
Declare Sub MotorStop()

'pseudo multitasking
Dim T As Byte
Dim Task1 As Bit
Dim Task2 As Bit
Dim Task3 As Bit

Dim bTemp As Byte
Dim sTemp As Single
Dim sOffset As Single
Dim bIndex As Byte
Dim strRx10 As String * 10

Dim bIsAliveWaitTime As Byte

Dim bCurrMeasPoint As Byte
Dim wUSMeasPoints(cMeasPoints) As Word
Dim bUSWaitTime As Byte
Dim mSearchRight As Bit
Dim bFreeDirection As Byte
Dim mLastDirection As Bit '0 = left / 1 = right

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

bCurrMeasPoint = 1
bFreeDirection = cMeasPoints / 2 '0 = right / 9 = middle / 18 = left

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
   'movement control
   If Task1 = 1 Then

      Dim wMinValue As Word

      Min(wUSMeasPoints(1) , wMinValue , bIndex)


      If wMinValue < 10 Then

         If mLastDirection = 0 Then

            'turn right
            bLeftMotor = cFWD
            bRightMotor = cBWD
            bSpeed = 5
         Else

            'turn left
            bLeftMotor = cBWD
            bRightMotor = cFWD
            bSpeed = 5
         End If
      Else

         bLeftMotor = cFFWD
         bRightMotor = cFFWD


         bTemp = cMeasPoints / 2
         bTemp = bTemp + 2 'threshold

         'turn left
         If bFreeDirection > bTemp Then

            mLastDirection = 0

            bLeftMotor = cBREAK
            bRightMotor = cFWD
            bSpeed = 5
         End If


         bTemp = cMeasPoints / 2
         bTemp = bTemp - 2 'threshold

         'turn right
         If bFreeDirection < bTemp Then

            mLastDirection = 1

            bLeftMotor = cFWD
            bRightMotor = cBREAK
            bSpeed = 5
         End If
      End If


   '-----------------------------
   'communication
   ElseIf Task2 = 1 Then

      If strRx10 <> "" Then

         Dim str10 As String * 10

         str10 = strRx10

         strRx10 = ""


         Select Case str10

            Case "hi"

               Print "hello"


            Case "reboot":

               Print "stopping motors"

               Call MotorStop()

               'message for rebootUno.exe
               Print "bye"
               'reboot the controller into bootloader
               Goto 0


         End Select
      End If


   '-----------------------------
   'obstacle recognition
   ElseIf Task3 = 1 Then
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

         Servo(1) = sTemp + cServoOffset


         bUSWaitTime = 10 'wait min. 10ms for servo
      End If

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


Function GetUSAverage() As Word

   Dim lAverage As Long
   Local Dim b As Byte

   For b = 1 To cMeasPoints

      lAverage = lAverage + wUSMeasPoints(b)
   Next b

   lAverage = lAverage / cMeasPoints

   GetUSAverage = lAverage
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


Sub MotorStop()

   qMotorIn1 = mTempA
   qMotorIn2 = mTempB

   qMotorIn3 = mTempA
   qMotorIn4 = mTempB

   bLeftMotor = cBREAK
   bRightMotor = cBREAK
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

   Call WaitByte(bUSWaitTime)

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



Serial0charmatch:

   Input strRx10

   Clear Serialin

   Delchars strRx10, 10
   Delchars strRx10, 13

   strRx10 = Trim(strRx10)

Return