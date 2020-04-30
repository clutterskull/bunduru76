& .\ps2exe.ps1 -inputFile .\Bunduru76.ps1 -outputFile .\build\Bunduru76.exe -iconFile .\Fallout3.ico -title Bunduru76
cd .\build
cp ..\README.md .
rm .\Bunduru76.zip
zip .\Bunduru76.zip .\Bunduru76.exe .\README.md
cd ..\
