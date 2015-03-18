# SRC_VHDL
XILINX - Spartan 6 - Sample Rate Converter

Some code is commented ... most isn't ... If you don't understand it then use at your own peril.

I'm actively setting this up, so don't expect too much just yet

/rtl - Contains all synthesizable code
/rtl/rom - Two coefficient files: one for the SRC, one for a Halfband filter. 
           Both are symetric, so only half are stored, except for the SRC which 
           also contains the centre coefficient
           
/tb - Contains code for HDL testbenches.
/tb/test - Results for MATLAB processing, verification

/ucf - Constraints file for implementation


