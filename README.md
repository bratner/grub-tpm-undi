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
support TPM. Thus create a security hole.

Solaris x86 grub has UNDI network driver, TCG Grub supports TPM - here they combined.

To be able to trust a remote kiosk in a hostile network is a problem that is solved
by the TPM module. If every stage of your boot process is measured before execution
into TPM's hashed register (PCRs) and you can get a crypto-signed quote from the module
