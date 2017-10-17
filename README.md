# CascLibMacOS

CascLib is An open-source implementation of library for reading CASC storage from Blizzard games since 2014
CascLib is implemented by @ladislav-zezula and can be found here https://github.com/ladislav-zezula/CascLib

The script in this repo, downloads CascLib and generates an x86_64 MacOS framework using CascLib's cmake and make procedure
The script then copies the relevant data file, include libraries and the just-been-built binary framework to a subfolder
Finally, the script opens an Xcode project containing code derived from CascLib's sample test code
