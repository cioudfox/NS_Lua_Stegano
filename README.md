# NS_Lua_Stegano
Steganography using PNG images. Utilize Docker to create compact C w/ Lua container to run
Goal:
Convert code to Base 64, encrypt value as cipher w/ Naccache Stern Knapsack crypto sys. 
Create an image file that is suitable for Steganography, ex: 50 kb w/ 41 kb of padding = 40000+ bytes to be used to store message
Append Cipher within image in safe spot to avoid damaging integrity. Append relevant info at end. Lump off padding, to ensure image is same size.

10/26, Complete simple example test case in Lua that properly uses and stores as Big Edian Hex value.
Next step, convert to C to utilize Bitwise operation library.
