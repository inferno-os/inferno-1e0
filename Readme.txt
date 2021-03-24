
                        Welcome to Inferno
                        ------------------

This README file contains important, last minute information
about the Inferno operating system Release 1.0 distribution. 

Before you install Inferno, carefully read the installation
instructions in the Inferno documentation AND these release notes.

TABLE OF CONTENTS
-----------------
1. General Information 
   A. Minimum system requirements
   B. How to get help
   C. Installation
   D. The Introduction to Inferno program (DSP)

2. Caveats and Known Problems
   A. General
   B. Compilation
   C. Microsoft Windows Environment
   D. Demo Applications
   E. Limbo
   F. Miscellaneous
 
 
1. GENERAL INFORMATION
======================

A. Minimum System Requirements
==============================
Minimum system requirements are listed on page 2-4 in the Inferno User's Guide.


B. How to get help
==================
If you have any problems with this product, please read this file, the 
documentation and online help first. 

If you still have a question and need assistance, help is available via 
email at the following address:

        infernosupport@lucent.com

When requesting technical support via email, please provide the 
following information:

  o Computer name and model and the name and model of any additional 
    hardware (video adapters, modems, etc.).

  o The specific steps necessary to reproduce the problem you are 
    experiencing.

  o Operating system version number.

  o A description of your operating environment (path variable,
    networking, etc).

  o Your name and phone number.


C. Installation
===============

Installation and setup instructions are provided in the User's Guide. 
The following installation notes add information that is likely to 
change in the future and is not contained in the manual.
----------------

Under Windows, you should not install to the same directory that contains
a Setup.exe.
----------------

Services File:
Inferno requires that a number of entries be added to your system 
Services file. Setup will fail to do this when the user does not have 
Read/Write permissions on the Services file. This typically occurs on 
NT installations where the user does not have Administrator privileges, 
in such cases you will need to have your system administrator update 
the services file. The file <inferno_root>\services.txt contains the 
service entries to be added.
----------------

NTFS Installation:
When installing Inferno on an NTFS partition, it is recommended that 
you have Full Control over either the Inferno target directory, if it 
exists prior to Setup, or its parent directory.

For example, when installing to \users\inferno, you should have
Full Control over \users\inferno (if \users\inferno exists) or \users.
----------------

If you intend to use Charon, the Inferno browser, from behind a
firewall, you must edit the <inferno_root>/services/webget/config
file to include the proxy server name and port number. Enter the 
appropriate httpproxy value according to the example provided in the 
configuration file.
----------------




D. The Introduction to Inferno program (DSP)
============================================

The Introduction to Inferno (DSP) is a simple Inferno program implemented
in the Limbo programming language that illustrates some of the key
features of the Inferno operating system. Because the program requires
that you establish an authenticated connection, an Inferno server must be
running in order to run the program. The will execute on a single machine
as long as it has been set up as a server. (See the documentation sections
about setting up Inferno on a single machine in loopback mode.)

Use the following procedure to run the tutorial:

   1. Start the emulator using the -g800x600 option.

   2. In the Inferno console window of the server machine,
      run lib/srv. By default, DSP assumes that the local
      machine is the server.

   3. Start the window manager with the wm/logon command.

   4. From the Inferno button, select Introduction to Inferno

DSP opens with a series of slides describing Inferno and the DSP
application. Selecting Next and Back, you can navigate through the 
series of slides. From the last slide, the DSP application is launched.

If your Inferno network includes multiple file servers, you can
run DSP in a fully distributed manner. In order to configure
the servers, follow the example profile in

<inferno_root>/demo/dsp/sampleProfile



2. CAVEATS AND KNOWN PROBLEMS
=============================

See the Installation section of this file for problems related to the 
installation process.

A. General 
==========
CAVEATS

The default emu window size is 640x480 in order to accomodate the
widest range of display devices possible. This size is appropriate
for the mux demonstration programs but too small for general use
with the window manager. For better appearance, we recommend that
you start emu with the -g option set to at least 800x600.
----------------

Limbo executables generated by Beta versions of the Limbo compiler will
not run on the Release 1.0 virtual machine. All existing Limbo programs
must be recompiled.
----------------

JPEG files with "progressive huffman encoding" are not supported. Some 
AVI syntax is also not supported.
----------------

The DES interface has been replaced with 40-bit RC4 in this 
distribution to comply with US government export restrictions. The 
DES interface can be ordered by contacting Inferno sales.

Module signing has been disabled in this release for similar reasons.
----------------

KNOWN PROBLEM

Running pwd in a bound directory may produce the following error:

        pwd: file does not exist
---------------


B. Compilation
==============
CAVEAT

The JIT compiler does not schedule threads in the same way as the 
interpreter. That is, quanta can be unpredictable when generated by the 
JIT compiler.
----------------

KNOWN PROBLEMS

Module-specific compilation does not currently allow mixed JIT and 
non-JIT applications using limbo with the -c or -C option. 
To work around this problem, use the -c1 option with emu to compile 
all modules or do not run any JIT-compiling modules.
---------------

When emu is run with the -c1 option (to enable JIT) under Irix 5.3 or
Irix 6.2, the following error will be displayed when "Financial Reports"
is selected in the mux application:

        application protocol error: unknown message 269099172

Pressing "Enter" a second time (i.e., after having selected
"Financial Reports") will cause the mux application to lock;
no further keyboard activity will be recognized by mux and  
emu will have to be restarted.
----------------

When JIT is used under Windows, mathcalc aborts with an error message if you 
try to use any mathematical functions. The program works with JIT off.
----------------


C. Microsoft Windows Environment
================================
CAVEATS

Windows Uninstall:
It is recommended that you delete an Inferno instance via the 
Uninstall program found in the Inferno folder.  Uninstall will 
delete the Inferno files and registry keys that were added by the 
installation. The registry keys are used by Setup to detect a 
previous instance of Inferno.

Inferno Setup adds the following keys to your registry under 
[HKEY_LOCAL_MACHINE]:

\SOFTWARE\Lucent Technologies\Inferno\Release 1.0
\SOFTWARE\Microsoft\Windows\Current Version\App Paths\emu.exe
\SOFTWARE\Microsoft\Windows\Current Version\Uninstall\InfernoDeinstKey
----------------

The names of physical files in the Windows environment are 
case-insensitive. This may cause name collisions and inadvertent 
overwriting of files.
----------------

File ownership under Windows NT:

NT does not support a chown() command, but Inferno needs one when the 
Inferno tree is installed on an NTFS system.

So, Inferno uses the primary group field of the NTFS file to hold the 
owner of the Inferno file.  The primary group field is normally only
used when an application is running under a posix subsystem; Inferno 
runs under the Windows subsystem.

When a file foo is created by Inferno and a chown(uid, foo) is 
executed, foo's NT group field will be set to uid.  When a file is 
stat'd by Inferno, stat() will return the this group field as the 
file's owner.

Note that when viewed from outside of Inferno, NT file ownership does
not change.  When a file is created, the NT owner is that of whomever
started up the emu.

To set a file's Inferno owner outside of Inferno (i.e., set the group
field), there is a separate executable called setown that resides in the 
<inferno_bin>. The syntax is:

        setown [-R] [domain\]username file...

where username may be prefixed with the domain in which username resides.  
If it is not prefixed, the local machine and then the primary domain
is searched for the user. The -R option recursively descends any 
directories on the command line 

So for example, when a new user is added to inferno, we go to the NT 
shell and do the following:

        mkdir $InfernoRoot/usr/bar
        setown bar $InfernoRoot/usr/bar
----------------
 
File ownership under Windows95:

This problem does not exist on Windows 95 since there is no
notion of users owning files.
----------------

When running X-terminal packages under Windows, you must use 
256-color mode set to pseudo or static color, or 24-bit mode set 
to true color. Use:

        Control Panel>>Display>>Settings:Color palette

Do not use 16-bit True Vision when running X-terminal packages
under Windows 95.
----------------


D. Demo Applications
====================
CAVEATS

Running the Inferno Web Browser:
When you invoke the Inferno Web Browser via Inferno's Window 
Manager, the Windows PATH variable will be used to locate 
the Web executable. Your PATH should include the directory where
the Inferno executables are installed, that is,

         <inferno_root>\Nt\386\bin.  
----------------

Running the Othello and Connect4 games under mux requires:

1) that the game marshal be added to the system services file, e.g.,
   add:

        gamed           6702/tcp
           
   to /etc/services on Unix systems
   to c:\windows\services on Windows 95
   to c:\winnt35\system32\drivers\etc\services on Windows NT 3.51
   to c:\winnt\system32\drivers\etc\services on Windows NT 4.0

2) that the game program be added to the basic services file under
   inferno, i.e., add:

        /icons/othello.bit:games:Games

   to the file services/basic.

3) that an instance of the games marshal be running under each
   inferno that wants to participate in the games. The argument
   to gamed is the name of the machine that will serve as the
   master:
                
        pcwork21$ mux/gamed pcwork21 &
        gamed: iamserver 1
                
   The master will say that it is server 1, all others will claim to
   be server 0.
----------------

KNOWN PROBLEMS

Attempting to run the debugger on the animated coffee demo will break 
the coffee window and make it unusable. The coffee window may still 
be deleted through the task manager window.
----------------

Charon:
Viewing graphic intensive web pages may cause a segmentation fault
in Limbo Tk.
----------------

Images which are "too large" may cause Charon to give up on that page.
----------------


E. Limbo 
========
KNOWN PROBLEM

The following is (incorrectly) accepted by the limbo compiler but 
(correctly) produces a runtime error.

A: adt {
        i: int;
        foo: fn(a: self ref A);
};
....
A.foo();  # compiler should reject
          # instead, may get -- OSFault "Bus error" -- at runtime

The adt A is valid for calling a function within that adt but it is not
an instance of the adt and as such can't be supplied to the function as
an argument. The function call A.foo() is therefore illegal.
----------------


F. Miscellaneous
================
KNOWN PROBLEMS

The chmod u-w, chmod g-w, chmod o-w commands do not work properly
and provide a misleading diagnostic.
----------------

The gif2pic command does not work. 
----------------



