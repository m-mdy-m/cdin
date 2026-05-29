in windows

install sdl3 from SDL reppo lik : 
SDL3-devel-3.X.X-mingw.zip

exctract zip file


copy dll file in x86_64-w64-mingw32\bin\SDL3.dll to (project/SDL3.dll)
and run test project like:
gcc main.c -o main.exe -IC:/(foldername for extract)/x86_64-w64-mingw32/include -LC:/(foldername for extract)/x86_64-w64-mingw32/lib -lSDL3
