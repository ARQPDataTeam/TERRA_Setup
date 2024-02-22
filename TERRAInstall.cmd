@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION


REM ## loop over different doc folder locations
FOR %%d IN ( 

	"%userprofile%\My Documents"
	"%OneDrive%\Documents"

) DO (
	REM ## LOOP THROUGH ALL VERSIONS OF IGOR
	FOR %%v IN ( 6 7 8 9 ) DO (
		ECHO Installing for Igor version %%v
		SET IGOR_DIR=%%d\WaveMetrics\"Igor Pro %%v User Files"
		
		SET OLD_IGOR_DIR=%%d\WaveMetrics\OLD_IgorPro%%v_User_Files

		REM ## full path sting without quotes
		SET DIR_STRING=!IGOR_DIR:"=!

		REM ## User folder on disk
		IF EXIST !IGOR_DIR! (
			
			REM ## create folder for old files if needed
			IF EXIST !IGOR_DIR!\"User Procedures"\TERRA_Setup\KrigData.ipf (
				ECHO Moving old TERRA files to !OLD_IGOR_DIR!
				IF NOT EXIST !OLD_IGOR_DIR! MKDIR !OLD_IGOR_DIR!   >nul 2>&1
			) ELSE (
				IF EXIST !IGOR_DIR!\"User Procedures"\KrigData.ipf (
					ECHO Moving old TERRA files to !OLD_IGOR_DIR!
					IF NOT EXIST !OLD_IGOR_DIR! MKDIR !OLD_IGOR_DIR!   >nul 2>&1
				)
			)
			REM ## Move igopro-flagger folder to old folder
			IF EXIST  !IGOR_DIR!\"User Procedures"\TERRA_Setup  (
							MOVE !IGOR_DIR!\"User Procedures"\TERRA_Setup !OLD_IGOR_DIR!\  >nul 2>&1
						) 
			REM ## Move any of files in this list that are located in the root User Procedures folder to the old folder
			IF EXIST !OLD_IGOR_DIR! (
				FOR %%f IN ( 
						FlightFitting.ipf
						DateTimeConversions.ipf
						Covariance_Kriging.ipf
						KrigData.ipf
						KrigData_2013.ipf
						PlumeEmission.ipf
						ExtrapolateUp.ipf
						ReplaceKrigScreenMarquee.ipf
						TERRA.ihf
					) DO ( 
						IF EXIST  !IGOR_DIR!\"User Procedures"\%%f MOVE !IGOR_DIR!\"User Procedures"\%%f !OLD_IGOR_DIR!\  >nul 2>&1
					)
			)


			
			REM ## Clone git repo
			cd !IGOR_DIR!\"User Procedures"
			rmdir /s /q TERRA_Setup
			git clone --recurse-submodules https://github.com/ARQPDataTeam/TERRA_Setup.git
			
			REM ## Move FlaggerLoader to correct folder
			cd !IGOR_DIR!\"User Procedures"\TERRA_Setup
			COPY /y TERRALoader.ipf !IGOR_DIR!\"Igor Procedures"
			COPY /y TERRA.ihf !IGOR_DIR!\"Igor Help Files"			

		) 
		REM ELSE ( ECHO Igor version %%v not found, skipping )
		
		
	 )  
	 REM END Igor version LOOP
	 
 )
 REM END oneDrive LOOP