using MinimalisticTelnet;
using System;
using System.Text.RegularExpressions;
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
        // wait after server output
        static bool bolWait = false;
        static bool bolTimedOut = false;

        // default IP of ESP module
        static string strIP = "192.168.4.1";
        // default Telnet port
        static string strPort = "23";

        static void Main(string[] args)
        {
            Console.Title = "rebootUno v1.0";

            Console.WriteLine("");
            Console.WriteLine("########################################");
            Console.WriteLine("");
            Console.WriteLine(" rebootUno");
            Console.WriteLine("");
            Console.WriteLine(" https://github.com/dekoch/China2WDuno");
            Console.WriteLine("");
            Console.WriteLine("########################################");
            Console.WriteLine("");


            bool bolShowHelp = false;

            string strTemp = "";
            bool bolValidOption;

            for (int i = 0; i < args.Length; i++)
            {
                bolValidOption = false;

                args[i] = args[i].ToLower();
                args[i] = args[i].Replace("--", "/");
                args[i] = args[i].Replace("-", "/");

                // get ip
                if (args[i].Contains("/ip:"))
                {
                    strTemp = args[i].Replace("/ip:", "");

                    if (strTemp.Length != 0)
                    {
                        strIP = strTemp;

                        bolValidOption = true;
                    }
                }

                // get port
                if (args[i].Contains("/port:"))
                {
                    strTemp = args[i].Replace("/port:", "");

                    if (strTemp.Length != 0)
                    {
                        strPort = strTemp;

                        bolValidOption = true;
                    }
                }

                // wait?
                if (args[i].Contains("/w") || args[i].Contains("/wait"))
                {
                    bolWait = true;

                    bolValidOption = true;
                }

                // only show help
                if (args[i].Contains("/h") || args[i].Contains("/help") || args[i].Contains("/?"))
                {
                    bolShowHelp = true;

                    bolValidOption = true;
                }


                // if no valid option detected, show help
                if (bolValidOption == false)
                {
                    bolShowHelp = true;

                    Console.WriteLine("invalid option: " + args[i]);
                }
            }


            if (bolShowHelp == false)
            {
                RebootController();
            }
            else
            {
                ShowHelp();

                bolWait = true;
            }


            if (bolWait)
            {
                Console.ReadLine();
            }
        }

        private static void RebootController()
        {
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

                        strInput = strInput.Replace("\n", "");

                        // split messages
                        string[] arrInput = Regex.Split(strInput, "\r");

                        for (int i = 0; i < arrInput.Length - 1; i++)
                        {
                            // display server output
                            Console.WriteLine("RX: " + arrInput[i]);

                            if (arrInput[i].StartsWith("bye"))
                            {
                                tc.Close();
                                Console.WriteLine("controller is rebooting now");
                            }
                        }
                    }
                }

                if (bolTimedOut)
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
        }

        private static void TimeOut(Object o)
        {
            bolTimedOut = true;
        }

        private static void ShowHelp()
        {
            Console.WriteLine("");
            Console.WriteLine("usage: rebootUno.exe [options]");
            Console.WriteLine("options:");
            Console.WriteLine(" /ip:<192.168.4.1>   specify ip of ESP-module (telnet-server)");
            Console.WriteLine(" /port:<23>          specify port of ESP-module (telnet-server)");
            Console.WriteLine(" /w                  wait after bye message");
            Console.WriteLine(" /wait");
            Console.WriteLine("");
            Console.WriteLine(" /h                  show this");
            Console.WriteLine(" /help");
            Console.WriteLine(" /?");
            Console.WriteLine("");
        }
    }
}
