Build InangoplugComponent:
===================
bitbake inangoplug-mngm


Dmcli Commands:
==============

Check using dbus Path
=====================
dmcli eRT getv com.cisco.spvtg.ccsp.inangoplugcomponent.

To get List of Paramters:
========================
dmcli eRT getv Device.Device.X\_INANGO\_Inangoplug.

Get & Set a Parameter:
=====================
dmcli eRT getv Device.X\_INANGO\_Inangoplug.InangoplugLogin
dmcli eRT setv Device.X\_INANGO\_Inangoplug.InangoplugLogin string mylogin
