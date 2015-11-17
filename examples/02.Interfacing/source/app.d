// This file is written in D programming language
/**
*   The example shows how to send signals to daemons created by
*   daemonize.
*
*   Copyright: © 2014 Anton Gushcha
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module example02;

import std.datetime;
import std.experimental.logger;

import daemonize.d;

// Describing custom signals
enum RotateLogSignal = "RotateLog".customSignal;
enum DoSomethingSignal = "DoSomething".customSignal;

shared string logFilePath;

version (DaemonServer)
{
    // Full description for daemon side
    alias daemon = Daemon!("DaemonizeExample2",

        // dfmt off
        KeyValueList!(
            Composition!(Signal.Terminate, Signal.Quit, Signal.Shutdown, Signal.Stop), (logger)
            {
                logger.info("Exiting...");
                return false;
            },
            Signal.HangUp, (logger)
            {
                logger.info("Hello World!");
                return true;
            },
            RotateLogSignal, (logger)
            {
                logger.info("Rotating log!");
                destroy(logger);

                import std.file;
                rename(logFilePath, logFilePath ~ ".old");
                setLogger(new FileLogger(.logFilePath));

                return true;
            },
            DoSomethingSignal, (logger)
            {
                logger.info("Doing something...");
                return true;
            }
        ),

        (logger, shouldExit)
        {
            // will stop the daemon in 5 minutes
            auto time = MonoTime.currTime + 5.dur!"minutes";
            while(!shouldExit() && time > MonoTime.currTime) {  }
            logger.info("Exiting main function!");

            return 0;
        }
        // dfmt on
    );

    int main()
    {
        // For windows is important to use absolute path for logging
        version (Windows)
            string logFilePath = "C:\\logfile.log";
        else
            string logFilePath = "logfile.log";
        .logFilePath = logFilePath;

        auto logger = new FileLogger(logFilePath);
        return buildDaemon!daemon.run(logger);
    }
}
version (DaemonClient)
{
    import core.thread;
    import core.time;

    // For client you don't need full description of the daemon
    // the truncated description consists only of name and a list of
    // supported signals
    alias client = DaemonClient!("DaemonizeExample2",
        Composition!(Signal.Terminate, Signal.Quit, Signal.Shutdown, Signal.Stop),
        Signal.HangUp, RotateLogSignal, DoSomethingSignal);

    void main()
    {
        auto logger = new FileLogger("client.log");

        alias daemon = buildDaemon!client;
        alias send = daemon.sendSignal;
        alias uninstall = daemon.uninstall;

        send(logger, Signal.HangUp);
        Thread.sleep(50.dur!"msecs");
        send(logger, RotateLogSignal);
        Thread.sleep(50.dur!"msecs");
        send(logger, DoSomethingSignal);
        Thread.sleep(50.dur!"msecs");
        send(logger, Signal.Terminate);

        // For windows services are remain in SC manager until uninstalled manually
        version (Windows)
        {
            Thread.sleep(500.dur!"msecs");
            uninstall(logger);
        }
    }
}
