@echo Off
SET ZIP="C:\Program Files\7-Zip\7z.exe"
SET VERSION="0.6.2"

echo Clearing release folder
del /s /q "../release"
rmdir /s/q "../Blink"
mkdir "../Blink"

lune run version.luau %VERSION%

echo Bundling source code
darklua process ../src/init.luau ./Bundled.luau

echo Building standalone executable
lune build ./Bundled.luau
ren "./Bundled.exe" "blink.exe"

echo Compiling bytecode
lune run compile.luau

echo Zipping files
%ZIP% a "../release/blink-%VERSION%-windows-x86_64.zip" "blink.exe" > nul
%ZIP% a "../release/bytecode.zip" "Bytecode.txt" > nul
%ZIP% a "../release/bytecode.zip" "init.luau" > nul

echo Packaging plugin
cd ../plugin
copy "..\build\.darklua.json" ".\.darklua.json"
darklua process "./src/init.luau" "./bundle/init.server.lua"
rojo build --output "../release/Plugin-%VERSION%.rbxmx"

cd ../build

del "./*.exe"
del "./Bytecode.txt"
rmdir /s/q "../Blink" 

pause