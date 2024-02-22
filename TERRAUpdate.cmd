@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

Title TERRA Setup Update

REM ## check if git is accessible
Set "URL=https://github.com/ARQPDataTeam"

color 07
echo Checking for git access... 

Curl -m 3 -I -s "%URL%" | find /I "200">nul 2>&1 && (
    color 0A
    echo(
    echo(      "%URL%" ==^> is OK

	REM ## loop over different doc folder locations
	FOR %%d IN ( 

		"%userprofile%\My Documents"
		"%OneDrive%\Documents"

	) DO (
		REM ## LOOP THROUGH ALL VERSIONS OF IGOR
		FOR %%v IN ( 6 7 8 9 ) DO (
			
			SET IGOR_DIR=%%d\WaveMetrics\"Igor Pro %%v User Files"
			
			REM ## full path sting without quotes
			SET DIR_STRING=!IGOR_DIR:"=!
			
			REM ## User folder on disk
			IF EXIST !IGOR_DIR! (
				
				REM ## Git pull and copy over flaglist
				cd !IGOR_DIR!\"User Procedures"\TERRA_Setup
				ECHO Updating for Igor version %%v	
				git pull --recurse-submodules		

			) 
			
		 )  
		 REM END Igor version LOOP
		 
	 )
	 REM END oneDrive LOOP

 ) || (
    color 0C
    echo(
    echo(      "%URL%" ==^> Not accessible.  Connect to VPN and try again
)

