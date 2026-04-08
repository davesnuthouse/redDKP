@echo off
rem THIS FILE MUST HAS TO BE IN THE SAME DIRECTOR AS THE LUA FILE RedGuild.lua
rem NOTE THAT IS NOT THE ADDON LUA IT IS THE ONE LOCATED IN \World of Warcraft\_anniversary_\WTF\Account\youraccountname\SavedVariables
rem YOU ARE RECOMMENDED TO COPY REDGUILD.LUA FROM THE DIRECTORY ABOVE TO WHERE THIS PARSES SITS AND RUN IT IN ORDER TO NOT CORRUPT THE ORIGINAL FILE
rem OUTPUT FILE IS CALLED RedGuild.scv

setlocal enabledelayedexpansion

set "input=RedGuild.lua"
set "output=RedGuild.csv"

rem -------------------------------
rem   Define the CSV column order
rem -------------------------------
set "cols=name,note,invalid,spent,lastWeek,bench,onTime,balance,osRole,attendance,class,rotated,msRole"

rem Write CSV header
> "%output%" echo %cols%

set "inBlock=0"
set "currentName="

rem -----------------------------------------
rem   Read the file line-by-line
rem -----------------------------------------
for /f "usebackq tokens=* delims=" %%A in ("%input%") do (
    set "line=%%A"

    rem Detect start of data block
    echo !line! | find "RedGuild_Data" >nul && set "inBlock=1"
    if "!inBlock!"=="0" continue

    rem Detect end of data block
    echo !line! | find "RedGuild_Config" >nul && goto :writeLast

    rem Detect new player entry: ["Name"] = {
    echo !line! | find "[" >nul | find "]" >nul | find "=" >nul >nul && (
        for /f "tokens=2 delims=[]" %%N in ("!line!") do set "currentName=%%N"
        rem Reset all fields for this player
        for %%C in (%cols%) do set "%%C="
        set "name=!currentName!"
    )

    rem Detect key/value lines: ["key"] = value,
    echo !line! | find "[" >nul | find "]" >nul | find "=" >nul >nul && (
        for /f "tokens=2,3 delims=[]=" %%K %%V in ("!line!") do (
            set "key=%%K"
            set "val=%%V"

            rem Clean value
            set "val=!val:,=!"
            set "val=!val:"=!"
            set "val=!val: =!"
            set "val=!val:}=!"
            set "val=!val:{=!"

            rem Assign to variable if key is a known column
            for %%C in (%cols%) do (
                if /i "%%C"=="!key!" set "%%C=!val!"
            )
        )
    )

    rem Detect end of player block: },
    echo !line! | find "}," >nul && (
        call :writeRecord
    )
)

goto :eof

rem -----------------------------------------
rem   Write one CSV record
rem -----------------------------------------
:writeRecord
set "row="
for %%C in (%cols%) do (
    if defined %%C (
        set "row=!row!,!%%C!"
    ) else (
        set "row=!row!,"
    )
)
rem Remove leading comma
set "row=!row:~1!"
>> "%output%" echo !row!
exit /b

rem -----------------------------------------
rem   Final write if needed
rem -----------------------------------------
:writeLast
if defined name call :writeRecord
echo Conversion complete: %output%
exit /b