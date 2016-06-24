using MinimalisticTelnet;
using System;
using System.Threading;

//########################################
//
// https://github.com/dekoch/China2WDuno
//
//########################################

namespace rebootUno
{
    class Program
    {
        static bool bolTimedOut = false;

        static void Main(string[] args)
        {
            Console.Title = "rebootUno v1.0";

            // default IP of ESP module
            string strIP = "192.168.4.1";
            // default Telnet port
            string strPort = "23";
            // wait after server output
            bool bolWait = false;


            string strTemp = "";

            for (int i = 0; i < args.Length; i++)
            {
                args[i] = args[i].ToLower();

                // get ip
                if (args[i].Contains("/ip:"))
                {
                    strTemp = args[i].Replace("/ip:", "");

                    if (strTemp.Length != 0)
                    {
                        strIP = strTemp;
                    }
                }

                // get port
                if (args[i].Contains("/port:"))
                {
                    strTemp = args[i].Replace("/port:", "");

                    if (strTemp.Length != 0)
                    {
                        strPort = strTemp;
                    }
                }

                // wait?
                if (args[i].Contains("/w"))
                {
                    bolWait = true;
                }
            }

            Console.WriteLine("");
            Console.WriteLine("########################################");
            Console.WriteLine("");
            Console.WriteLine(" rebootUno");
            Console.WriteLine("");
            Console.WriteLine(" https://github.com/dekoch/China2WDuno");
            Console.WriteLine("");
            Console.WriteLine("########################################");
            Console.WriteLine("");

            Console.WriteLine(" IP:   " + strIP);
            Console.WriteLine(" Port: " + strPort);
            Console.WriteLine("");

            TelnetConnection tc = new TelnetConnection();

            // try to connect
            if (tc.Connect(strIP, strPort))
            {
                // clear input buffer
                tc.Read();

                Console.WriteLine("TX: reboot");
                // send to server
                tc.WriteLine("reboot\r");


                Timer tTimeOut = new Timer(TimeOut, null, 30000, 0);

                string strInput = "";

                while (tc.IsConnected & (bolTimedOut == false))
                {
                    strInput = tc.Read();

                    if (string.IsNullOrWhiteSpace(strInput) == false)
                    {
                        // reset timeout
                        tTimeOut.Change(30000, 0);

                        // display server output
                        Console.WriteLine("RX: " + strInput);

                        if (strInput.StartsWith("bye"))
                        {
                            tc.Close();
                        }
                    }
                }

                if (bolTimedOut == false)
                {
                    Console.WriteLine("controller is rebooting now");
                }
                else
                {
                    Console.WriteLine("Error TimeOut: controller is not responding");
                    bolWait = true;
                }
            }
            else
            {
                // wait to show error
                bolWait = true;
            }

           
            if (bolWait)
            {
                Console.ReadLine();
            }
        }

        private static void TimeOut(Object o)
        {
            bolTimedOut = true;
        }
    }
}
