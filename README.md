Grub 0.97 with TPM and UNDI network driver support
==================================================

The TPM trusted boot
-----------------------------
In TPM trusted boot each stage of the boot process, before execution, is checksummed and store-added into a
register called a PCR.
After the system is booted you can inspect the PCRs locally or remotely and securely verify that
the system you have in hand booted and running the software you wish it to run. 
In Conclusion: You can verify that a remote machine is running EXACTLY the software you wish it to run.

Network boot problem
--------------------
When the boot is done from netwok. A NIC with TPM support will download the pxe boot executable
from the assigned server, measure it into the PCRs and run it. 
The problem is that even 2 years after this project was completed most network cards don't
support TPM. Thus break the chain of trust during boot.


Grub 0.97
------------
Grub 0.97 has almost no network support for modern network cards.
But Trusted Computing Group published a patched version of Grub 0.97 with TPM support.

UNDI
-----
Most or all modern network cards have a built-in simple network driver in their ROM. 
This (UNDI) driver has a standard and accessible to software from the very early boot stages.
Solaris x86 has UNDI support and some other features. 

Integration
------------
The result is a port of TCG patches to a Solaris X86 Grub 0.97
