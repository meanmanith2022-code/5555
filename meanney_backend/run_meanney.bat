@echo off
title MeanNey AI System
echo đangចាប់ផ្តើម Python Backend...
start cmd /k "python main.py"

echo កំពុងរង់ចាំ Python Server ដំណើរការ...
timeout /t 3 > nul

echo កំពុងបើកកម្មវិធី MeanNey Windows App...
cd /d "%~dp0"
flutter run -d chrome 
pause