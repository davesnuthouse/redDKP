@echo off
rem PLEASE NOTE THAT DUE TO THE WAY WOW MODIFIES LUA FILES IT IS STRONGLY ADVISED YOU DO NOT PERFORM ANY LUA CHANGES WITH THE GAME OPEN

rem THIS FILE MUST HAS TO BE IN THE SAME DIRECTOR AS YOUR EDITED LUA FILE RedGuild.csv
rem NOTE YOU MUST RENAME THE FILE TO Redguild.csv IF IT IS NOT AND STRICTLY FOLLOW THE FORMATTING OF THE FILE CREATED BY THE OTHER PARSER
rem OUTPUT FILE IS CALLED TOBEPASTED.fakelua
rem YOU ARE THEN REQUIRED TO MANUALLY EDIT THE REAL RedGuild.lua LOCATED IN \World of Warcraft\_anniversary_\WTF\Account\youraccountname\SavedVariables
rem NOTE THAT THE RedGuild.lua FILE HAS MORE SECTIONS THAT JUST THE DATA YOU EXPORTED/EDITED AND WISH TO IMPORT
rem YOU MUST MUST MUST NOT OVERWRITE ANYTHING FROM THE FOLLOWING LINE TO THE BOTTOM OF THE FILE:       RedGuild_Config = {       <<< DO NOT REMOVE ANYTHING FROM HERE ONWARDS
rem ALSO WHEN PASTED DOUBLE CHECK THE FIRST LINE READS :     RedGuild_Data = {             (A BLANK LINE ABOVE THIS IS FINE"
rem ALSO CHECK THAT JUST ABOVE THE RedGuild_Config LINE MENTIONED ABOVE YOU SEE }, ON A LINE AND } ON THE LINE AFTER



@echo off
setlocal enabledelayedexpansion

set "input=RedGuild.csv"
set "output=TOBEPASTED.fakelua"

rem -----------------------------------------
rem   Define the column order (must match CSV)
rem -----------------------------------------
set "cols=name,note,invalid,spent,lastWeek,bench,onTime,balance,osRole,attendance,class,rotated,msRole"

rem Start writing the Lua file
> "%output%" echo RedGuild_Data = {
echo Writing Lua output...

set "firstLine=1"

rem -----------------------------------------
rem   Read CSV rows
rem -----------------------------------------
for /f "usebackq tokens=* delims=" %%A in ("%input%") do (
    set "line=%%A"

    rem Skip header row
    if "!firstLine!"=="1" (
        set "firstLine=0"
        continue
    )

    rem Parse CSV fields into variables
    set i=0
    for %%C in (%cols%) do (
        set /a i+=1
        for /f "tokens=!i! delims=," %%V in ("!line!") do (
            set "%%C=%%V"
        )
    )

    rem -----------------------------------------
    rem   Write one Lua block
    rem -----------------------------------------
    >> "%output%" echo ["!name!"] = {
    for %%C in (%cols%) do (
        if not "%%C"=="name" (
            set "val=!%%C!"

            rem Detect booleans
            if /i "!val!"=="true"  set "val=true"
            if /i "!val!"=="false" set "val=false"

            rem Detect empty fields
            if "!val!"=="" set "val=nil"

            rem Detect numbers (no quotes)
            echo !val! | findstr /r "^[0-9][0-9]*$" >nul
            if !errorlevel!==0 (
                >> "%output%" echo ["%%C"] = !val!,
            ) else (
                rem Strings need quotes
                if "!val!"=="true" (
                    >> "%output%" echo ["%%C"] = true,
                ) else if "!val!"=="false" (
                    >> "%output%" echo ["%%C"] = false,
                ) else if "!val!"=="nil" (
                    >> "%output%" echo ["%%C"] = nil,
                ) else (
                    >> "%output%" echo ["%%C"] = "!val!",
                )
            )
        )
    )
    >> "%output%" echo },
)

>> "%output%" echo }
echo Done. Output written to %output%