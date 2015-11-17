// This file is written in D programming language
/**
*   The example demonstrates basic daemonize features. Described
*   daemon responds to SIGTERM and SIGHUP signals.
*
*   If SIGTERM is received, daemon terminates. If SIGHUP is received,
*   daemon prints "Hello World!" message to logg.
*
*   Daemon will auto-terminate after 5 minutes of running.
*
*   Copyright: © 2014 Anton Gushcha
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module example01;

import std.datetime;
import std.experimental.logger;

import daemonize.d;

// First you need to describe your daemon via template
alias daemon = Daemon!("DaemonizeExample1", // unique name
    // Setting associative map signal -> callbacks
    // dfmt off
    KeyValueList!(
        // You can bind same delegate for several signals by Composition template
        // delegate can take additional argument to know which signal is caught
        Composition!(Signal.Terminate, Signal.Quit, Signal.Shutdown, Signal.Stop), (logger, signal)
        {
            logger.info("Exiting...");
            return false; // returning false will terminate daemon
        },
        Composition!(Signal.HangUp,Signal.Pause,Signal.Continue), (logger)
        {
            logger.info("Hello World!");
            return true; // continue execution
        }
    ),

    // Main function where your code is
    (logger, shouldExit) {
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

    return buildDaemon!daemon.run(new FileLogger(logFilePath));
}
