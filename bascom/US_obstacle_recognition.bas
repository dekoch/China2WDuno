$regfile = "m328pdef.dat"
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
Const cMeasPoints = 6 '6 / 12 / 18
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

Config PINC.2 = Input
iServo1 Alias PINC.2


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
Declare Sub Send(byval text As String)
Declare Sub WaitByte(byref t As Byte)
Declare Sub WaitWord(byref t As Word)
Declare Function GetUSDistance() As Word
Declare Function GetUSAverage(byval bOffset As Byte, byval bRange As Byte) As Word
Declare Function GetUSMin(byval bOffset As Byte, byval bRange As Byte) As Word
Declare Sub MotorControl()
Declare Sub MotorStop()

'pseudo multitasking
Dim T As Byte
Dim Task1 As Bit
Dim Task2 As Bit
Dim Task3 As Bit

Dim bTemp As Byte
Dim sTemp As Single
Dim strTemp25 As String * 25
Dim sOffset As Single
Dim bIndex As Byte
Dim strRx10 As String * 10

Dim bIsAliveWaitTime As Byte

Dim bCurrMeasPoint As Byte
Dim wUSMeasPoints(cMeasPoints) As Word
Dim wUSWaitTime As Word
Dim mSearchRight As Bit
Dim bFreeDirection As Byte
Dim mLastDirection As Bit '0 = left / 1 = right
Dim wMinValue As Word

Dim bSpeed As Byte
Dim bLeftMotor As Byte
Dim bRightMotor As Byte
Dim bMotorWaitTime As Byte
Dim wMotorDriveTime As Word


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

bLeftMotor = cBREAK
bRightMotor = cBREAK


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

      Min(wUSMeasPoints(1) , wMinValue , bIndex)


      If wMinValue < 150 Then

         If mLastDirection = 0 Then

            'turn right
            bLeftMotor = cFWD
            bRightMotor = cBWD
            bSpeed = 2
         Else

            'turn left
            bLeftMotor = cBWD
            bRightMotor = cFWD
            bSpeed = 2
         End If
      Else

         bLeftMotor = cFWD
         bRightMotor = cFWD
         bSpeed = 6


         bTemp = cMeasPoints / 2

         'turn left
         If bFreeDirection > bTemp Then

            mLastDirection = 0

            bLeftMotor = cBREAK
            bRightMotor = cFWD
            bSpeed = 4
         End If


         bTemp = cMeasPoints / 2

         'turn right
         If bFreeDirection < bTemp Then

            mLastDirection = 1

            bLeftMotor = cFWD
            bRightMotor = cBREAK
            bSpeed = 4
         End If
      End If


      If wMotorDriveTime = 0 Then

         Call MotorStop()
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

               Call Send("hello")


            Case "reboot":

               Call Send("stopping motors")

               Call MotorStop()

               'message for rebootUno.exe
               Call Send("bye")
               'reboot the controller into bootloader
               Goto 0


         End Select
      End If


   '-----------------------------
   'obstacle recognition
   ElseIf Task3 = 1 Then
      'task needs 38ms if no obstacle found

      If wUSWaitTime = 0 And wMotorDriveTime = 0 Then

         'mesure distance and log value into array
         wUSMeasPoints(bCurrMeasPoint) = GetUSDistance()


         Dim mMeasComplete As Bit
         mMeasComplete = 0

         'decide which direction for next measuring point
         If mSearchRight = 0 Then

            If bCurrMeasPoint >= cMeasPoints Then

               mSearchRight = 1
               mMeasComplete = 1
            Else

               bCurrMeasPoint = bCurrMeasPoint + 1
            End If
         Else

            If bCurrMeasPoint <= 1 Then

               mSearchRight = 0
               mMeasComplete = 1
            Else

               bCurrMeasPoint = bCurrMeasPoint - 1
            End If
         End If

         'if series of measurements is complete, set new direction
         If mMeasComplete = 1 Then

            'Dim b As Byte

            'For b = 1 To cMeasPoints

            '   strTemp25 = "US Points: " + str(wUSMeasPoints(b))
            '   Call Send(strTemp25)
            'Next b

            'split series into 3 areas and get minimal value for each
            Dim wMinR As Word
            Dim wMinM As Word
            Dim wMinL As Word

            Dim bRange As Byte
            Dim bOffset As Byte

            bRange = cMeasPoints / 3


            bOffset = 1

            wMinR = GetUSMin(bOffset, bRange)


            bOffset = bOffset + bRange

            wMinM = GetUSMin(bOffset, bRange)


            bOffset = bOffset + bRange

            wMinL = GetUSMin(bOffset, bRange)


            'prefer wAverageM
            wMinM = wMinM + 100


            'strTemp25 = "US MinR: " + str(wMinR)
            'Call Send(strTemp25)

            'strTemp25 = "US MinM: " + str(wMinM)
            'Call Send(strTemp25)

            'strTemp25 = "US MinL: " + str(wMinL)
            'Call Send(strTemp25)


            'compare all areas and set new direction
            Dim mLeft As Bit
            Dim mRight As Bit

            mLeft = 0
            mRight = 0


            If wMinR > wMinM Then

               mRight = 1
            End If

            If wMinL > wMinM Then

               mLeft = 1
            End If


            If mRight = 1 Then

               If wMinR > wMinL Then

                  mLeft = 0
               End If
            End If

            If mLeft = 1 Then

               If wMinL > wMinR Then

                  mRight = 0
               End If
            End If


            bFreeDirection = cMeasPoints / 2

            If mRight = 1 Then

               bFreeDirection = 1
            End If

            If mLeft = 1 Then

               bFreeDirection = cMeasPoints
            End If


            'strTemp25 = "Free Direction: " + str(bFreeDirection)
            'Call Send(strTemp25)

            wMotorDriveTime = 500
         End If


         'set servo angle
         'measuring points 1..18 = servo signal 0..100 = 0..180 degree
         sTemp = cMeasPoints - 1
         sTemp = 140 / sTemp

         sOffset = sTemp

         sTemp = sTemp * bCurrMeasPoint
         sTemp = sTemp - sOffset

         Servo(1) = sTemp + cServoOffset


         wUSWaitTime = 150 'wait min. 150ms for servo
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

   wOutput = 0


   Disable Interrupts

   Do

      Pulseout PortC , 0 , 20 'min. 10us pulse

      Pulsein wOutput , PinC , 1 , 1 'read distance, timeout 655.35ms

   Loop Until wOutput > 25

   Enable Interrupts


   'strTemp25 = "US: " + str(wOutput)
   'Call Send(strTemp25)

   GetUSDistance = wOutput
End Function


Function GetUSAverage(byval bOffset As Byte, byval bRange As Byte) As Word

   Local lAverage As Long
   Local bCnt As Byte
   Local bTo As Byte
   Local b As Byte

   lAverage = 0
   bCnt = 0


   If bOffset < 1 Then

      bOffset = 1
   End If


   bTo = bOffset + bRange
   bTo = bTo - 1

   If bTo > cMeasPoints Then

      bTo = cMeasPoints
   End If


   For b = bOffset To bTo

      lAverage = lAverage + wUSMeasPoints(b)

      Incr bCnt
   Next b

   lAverage = lAverage / bCnt

   GetUSAverage = lAverage
End Function


Function GetUSMin(byval bOffset As Byte, byval bRange As Byte) As Word

   Local wOutput As Word
   Local bTo As Byte
   Local b As Byte

   wOutput = 65535


   If bOffset < 1 Then

      bOffset = 1
   End If


   bTo = bOffset + bRange
   bTo = bTo - 1

   If bTo > cMeasPoints Then

      bTo = cMeasPoints
   End If


   For b = bOffset To bTo

      If wUSMeasPoints(b) < wOutput Then

         wOutput = wUSMeasPoints(b)
      End If
   Next b


   GetUSMin = wOutput
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

            If mTempA = 1 Then

               bMotorWaitTime = bSpeed
            End If

         Case cFFWD:
            mTempA = 1
            mTempB = 0


         Case cBWD:
            mTempA = 0
            Toggle mTempB

            If mTempB = 1 Then

               bMotorWaitTime = bSpeed
            End If

         Case cFBWD:
            mTempA = 0
            mTempB = 1

      End Select


      If bT1 = 1 Then

         qMotorIn1 = mTempA
         qMotorIn2 = mTempB
      ElseIf bT1 = 2 Then

         qMotorIn3 = mTempA
         qMotorIn4 = mTempB
      End If

   Next bT1
End Sub


Sub MotorStop()

   qMotorIn1 = 0
   qMotorIn2 = 0

   qMotorIn3 = 0
   qMotorIn4 = 0

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
   End If


   Call WaitByte(bIsAliveWaitTime)

   Call WaitWord(wUSWaitTime)

   Call WaitByte(bMotorWaitTime)

   Call WaitWord(wMotorDriveTime)


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


Sub Send(text As String)

   Disable Interrupts

   Print text

   Enable Interrupts
End Sub


Serial0charmatch:

   Input strRx10

   Clear Serialin

   Delchars strRx10, 10
   Delchars strRx10, 13

   strRx10 = Trim(strRx10)

Return