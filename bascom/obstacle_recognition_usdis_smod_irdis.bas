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
'Analog-In (Digital) A0 (14)        PC.0              ADC0                 URF01 (HC-SR04 Trig)
'                    A1 (15)        PC.1              ADC1                 URF01 (HC-SR04 Echo)
'                    A2 (16)        PC.2              ADC2
'                    A3 (17)        PC.3              ADC3
'                    A4 (18)        PC.4              ADC4 / SDA (I2C)     IIC
'                    A5 (19)        PC.5              ADC5 / SCL (I2C)     IIC

'Config and Settings
Const cMeasPoints = 6 '6 / 12 / 18
Const cServoOffset = 50
Const cServoRange = 140

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


Config ADC = Single, PRESCALER = AUTO, REFERENCE = AVCC


'Inputs
Config PINC.1 = Input
iUSEcho Alias PINC.1

Config PINC.2 = Input
iServo1 Alias PINC.2

Config PINC.3 = Input
iIRDisR Alias PINC.3

Config PINC.4 = Input
iIRDisM Alias PINC.4

Config PINC.5 = Input
iIRDisL Alias PINC.5


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
Declare Function GetServoPos() As Byte
Declare Sub CompareDirections(byval iL As Integer, byval iM As Integer, byval iR As Integer)

'pseudo multitasking
Dim T As Byte
Dim Task1 As Bit
Dim Task2 As Bit
Dim Task3 As Bit

Dim bTemp As Byte
Dim sTemp As Single
Dim wTemp As Word
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
Dim bNextCompleteMeasPoint As Byte
Dim wMinValue As Word
Dim mLeft As Bit
Dim mRight As Bit

Dim bSpeed As Byte
Dim bLeftMotor As Byte
Dim bRightMotor As Byte
Dim bMotorWaitTime As Byte
Dim wMotorDriveTime As Word

Dim wUServoOffset As Word
Dim sUServoStep As Single

Dim iUIRDisR As Integer
Dim iUIRDisM As Integer
Dim iUIRDisL As Integer
Dim wUIRDisOffsetR As Word
Dim wUIRDisOffsetM As Word
Dim wUIRDisOffsetL As Word


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


'calibrate servo input
wUServoOffset = Getadc(2)

Servo(1) = cServoOffset + cServoRange

Waitms 1000

wTemp = Getadc(2)

sUServoStep = wTemp

sUServoStep = sUServoStep - wUServoOffset

bTemp = cMeasPoints - 1
sUServoStep = sUServoStep / bTemp


Servo(1) = cServoOffset


'calibrate IR distance sensors
wUIRDisOffsetR = Getadc(3)
wUIRDisOffsetM = Getadc(4)
wUIRDisOffsetL = Getadc(5)



Do
   'Start Watchdog

   '-----------------------------
   'movement control
   'If Task1 = 1 Then

      If bFreeDirection > 0 Then

         Min(wUSMeasPoints(1) , wMinValue , bIndex)


         If wMinValue < 150 OR iUIRDisL < -150 OR iUIRDisM < -150 OR iUIRDisR < -150 Then

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

            wMotorDriveTime = 300
         Else

            bLeftMotor = cFWD
            bRightMotor = cFWD
            bSpeed = 1

            wMotorDriveTime = 800

            bTemp = cMeasPoints / 2

            'turn left
            If bFreeDirection > bTemp Then

               mLastDirection = 0

               bLeftMotor = cBREAK
               bRightMotor = cFWD
               bSpeed = 1
               wMotorDriveTime = 300
            End If


            bTemp = cMeasPoints / 2

            'turn right
            If bFreeDirection < bTemp Then

               mLastDirection = 1

               bLeftMotor = cFWD
               bRightMotor = cBREAK
               bSpeed = 1
               wMotorDriveTime = 300
            End If
         End If

         bFreeDirection = 0
      End If



   '-----------------------------
   'communication
   'ElseIf Task2 = 1 Then

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
   'ElseIf Task3 = 1 Then
      'task needs 38ms if no obstacle found

      If wUSWaitTime = 0 Then

         bTemp = GetServoPos()

         If bTemp > 0 Then

            bCurrMeasPoint = bTemp


            'mesure distance and log value into array
            wUSMeasPoints(bCurrMeasPoint) = GetUSDistance()


            'decide which direction for next measuring point
            If mSearchRight = 0 Then

               If bCurrMeasPoint >= cMeasPoints Then

                  mSearchRight = 1
               Else

                  bCurrMeasPoint = bCurrMeasPoint + 1
               End If
            Else

               If bCurrMeasPoint <= 1 Then

                  mSearchRight = 0
               Else

                  bCurrMeasPoint = bCurrMeasPoint - 1
               End If
            End If


            'set servo angle
            'measuring points 1..cMeasPoints = servo signal cServoOffset..cServoOffset + cServoRange = 0..180 degree
            sTemp = cMeasPoints - 1
            sTemp = cServoRange / sTemp

            sOffset = sTemp

            sTemp = sTemp * bCurrMeasPoint
            sTemp = sTemp - sOffset

            Servo(1) = sTemp + cServoOffset


            wUSWaitTime = 50 'wait min. 50ms for servo
         End If
      End If


      iUIRDisR = Getadc(3)
      iUIRDisM = Getadc(4)
      iUIRDisL = Getadc(5)

      iUIRDisR = iUIRDisR - wUIRDisOffsetR
      iUIRDisM = iUIRDisM - wUIRDisOffsetM
      iUIRDisL = iUIRDisL - wUIRDisOffsetL

      'invert signal
      iUIRDisR = 65535 - iUIRDisR
      iUIRDisM = 65535 - iUIRDisM
      iUIRDisL = 65535 - iUIRDisL

      'prefer iUIRDisM
      iUIRDisL = iUIRDisL - 10
      iUIRDisR = iUIRDisR - 10


      'strTemp25 = "IR R: " + str(iUIRDisR)
      'Call Send(strTemp25)

      'strTemp25 = "IR M: " + str(iUIRDisM)
      'Call Send(strTemp25)

      'strTemp25 = "IR L: " + str(iUIRDisL)
      'Call Send(strTemp25)


      'compare all areas and set new direction
      Call CompareDirections(iUIRDisL, iUIRDisM, iUIRDisR)


      bFreeDirection = cMeasPoints / 2

      If mRight = 1 Then

         bFreeDirection = 1
      End If

      If mLeft = 1 Then

         bFreeDirection = cMeasPoints
      End If
   'End If


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


   'Disable Interrupts

   Do

      Pulseout PortC , 0 , 20 'min. 10us pulse

      Pulsein wOutput , PinC , 1 , 1 'read distance, timeout 655.35ms

   Loop Until wOutput > 25

   'Enable Interrupts


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


Function GetServoPos() As Byte

   Local bOutput As Byte
   Local wCurrPos As Word
   Local sCheckPos As Single
   Local wTemp As Word
   Local b As Byte

   bOutput = 0
   sCheckPos = wUServoOffset


   wCurrPos = Getadc(2)


   For b = 1 To cMeasPoints

      wTemp = sCheckPos - 10

      If wCurrPos > wTemp Then

         wTemp = sCheckPos + 10

         If wCurrPos < wTemp Then

            bOutput = b
         End If
      End If

      sCheckPos = sCheckPos + sUServoStep
   Next b


   'strTemp25 = "CurrPos: " + str(wCurrPos)
   'Call Send(strTemp25)


   GetServoPos = bOutput
End Function


Sub CompareDirections(byval iL As Integer, byval iM As Integer, byval iR As Integer)

   mLeft = 0
   mRight = 0


   If iR > iM Then

      mRight = 1
   End If

   If iL > iM Then

      mLeft = 1
   End If


   If mRight = 1 Then

      If iR > iL Then

         mLeft = 0
      End If
   End If

   If mLeft = 1 Then

      If iL > iR Then

         mRight = 0
      End If
   End If
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


   If wMotorDriveTime = 0 Then

      Call MotorStop()
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