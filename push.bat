@echo off
set message=%*
"C:\Program Files\Git\bin\git.exe" add .
"C:\Program Files\Git\bin\git.exe" commit -m "%message%"
"C:\Program Files\Git\bin\git.exe" push origin main
echo Changes pushed to main successfully! 