#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "DateTimeConversions"
#include "Covariance_Kriging"
#include <XYZToMatrix>

//Get the start and end index of the box or screen
Function getIndex(BorS, name, dt)
	String BorS, name
	Wave dt

	NewPath/O/Q terra "\\\\econm3hwvasp010.ncr.int.ec.gc.ca\\OSM_2018\\AIRCRAFT\\Data_v1_INTERIM\\TERRA"
	
	//Load the flight start and stop times
	LoadWave/H/O/Q/P=terra "T_Takeoff.ibw"
	LoadWave/H/O/Q/P=terra "T_Landing.ibw"
	LoadWave/H/O/Q/P=terra "FlightIDNum.ibw"
	
	
	//Load the box or screen start and stop times
	if (CmpStr(BorS, "box") == 0)
		LoadWave/H/O/Q/P=terra "Box_End.ibw"
		LoadWave/H/O/Q/P=terra "Box_Start.ibw"
		LoadWave/H/O/Q/P=terra "BoxNum.ibw"
		LoadWave/H/O/Q/P=terra "Description_Box.ibw"
		LoadWave/H/O/Q/P=terra "FlightNum_Box.ibw"
		Wave startw = Box_Start
		Wave endw = Box_End
		Wave/T num = BoxNum
	else
		LoadWave/H/O/Q/P=terra "Screen_End.ibw"
		LoadWave/H/O/Q/P=terra "Screen_Start.ibw"
		LoadWave/H/O/Q/P=terra "ScreenNum.ibw"
		LoadWave/H/O/Q/P=terra "Description_Screen.ibw"
		LoadWave/H/O/Q/P=terra "FlightNum_Screen.ibw"	
		Wave startw = Screen_Start
		Wave endw = Screen_End
		Wave/T num = ScreenNum		
	endif
	
	Variable/G stIndex, endIndex
	
	//Find the start and end time for the selected box or screen
	FindValue/S=0/TEXT=name num
	if (V_Value == -1)
		Abort "Error: That box/screen name was not found."
	endif
	
	//Find the indices in the date/time wave where the box/screen starts and ends
	stIndex = BinarySearch (dt, startw[V_value])
	endIndex = BinarySearch (dt, endw[V_value])

End

//Split the flight box up into 4 sides
Function sectionBox (lat, long, dt)
	Wave lat, long, dt
	NVAR stIndex, endIndex
	Variable i, j, k, n
	Variable BottomAvg, TopAvg, LeftAvg, RightAvg

	//Create a 1 minute timestamp every second to create running values
	Make/O/N=(dimSize(dt,0) - 1) dlat, dlong
	Make/D/O/N=(dimSize(dt,0) - 1) dtStart, dtEnd
	
	for (i = 0; i < dimSize(dt,0) - 1; i += 1)
		dlat[i] = abs(lat[i] - lat[i + 1])
		dlong[i] = abs(long[i] - long[i + 1])
		
		dtStart[i] = dt[i]
		dtEnd[i] = dt[i] + 60
	endfor
	
	Make/D/O/N=61 minuteLat = NaN
	Make/D/O/N=61 minuteLong = NaN	
	Make/D/O/N=(dimSize(lat,0) - 1) longMin = NaN
	Make/D/O/N=(dimSize(lat,0) - 1) latMax = NaN
	Make/D/O/N=(dimSize(lat,0) - 1) longMax = NaN
	Make/D/O/N=(dimSize(lat,0) - 1) latMin = NaN
	Make/D/O/N=(dimSize(lat,0) - 1) latDir = NaN
	Make/D/O/N=(dimSize(lat,0) - 1) longDir = NaN
	
	for (k = stIndex; k < endIndex + 1; k += 1)
		n = 0

		for (j = k; j < endIndex + 1; j += 1)
			if (dt[j] >= dtStart[k] && dt[j] <= dtEnd[k])
				minuteLat[n] = lat[j]
				minuteLong[n] = long[j]
				n = n + 1
			else
				break
			endif
		endfor
		
		latMax[k] = wavemax(minuteLat)
		longMax[k] = wavemax(minuteLong)
		latDir[k] = minuteLat[60] - minuteLat[0]
		latMin[k] = wavemin(minuteLat)
		longMin[k] = wavemin(minuteLong)
		longDir[k] = minuteLong[60] - minuteLong[0]
	endfor
	
	Make/D/O/N=(dimSize(lat,0)) TopLat = NaN
	Make/D/O/N=(dimSize(lat,0)) BottomLat = NaN
	Make/D/O/N=(dimSize(lat,0)) LeftLat = NaN
	Make/D/O/N=(dimSize(lat,0)) RightLat = NaN
	Make/D/O/N=(dimSize(lat,0)) TopLong = NaN
	Make/D/O/N=(dimSize(lat,0)) BottomLong = NaN
	Make/D/O/N=(dimSize(lat,0)) LeftLong = NaN
	Make/D/O/N=(dimSize(lat,0)) RightLong = NaN
	
	for (i = stindex; i < endindex; i += 1)
		if (latMax[i] - latMin[i] <= 0.01)
			if (longDir[i] < 0)
				BottomLong[i] = long[i + 30]
				BottomLat[i] = lat[i + 30]
			elseif (longDir[i] > 0)
				TopLong[i] = long[i + 30]
				TopLat[i] = lat[i + 30]
			endif
		endif
		if (longMax[i] - longMin[i] <= 0.01)
			if (latDir[i] < 0)
				RightLong[i] = long[i + 30]
				RightLat[i] = lat[i + 30]
			elseif (latDir[i] > 0)
				LeftLong[i] = long[i + 30]
				LeftLat[i] = lat[i + 30]
			endif
		endif	
	endfor
	
	WaveStats/Q BottomLat
	BottomAvg = V_avg
	WaveStats/Q TopLat
	TopAvg = V_avg	
	if (BottomAvg > TopAvg)
		Duplicate/O TopLat, temp
		Duplicate/O BottomLat, TopLat
		Duplicate/O temp, BottomLat
		Duplicate/O TopLong, temp
		Duplicate/O BottomLong, TopLong
		Duplicate/O temp, BottomLong
	endif
	
	WaveStats/Q LeftLong
	LeftAvg = V_avg
	WaveStats/Q RightLong
	RightAvg = V_avg
	if (RightAvg < LeftAvg)
		Duplicate/O LeftLong, temp
		Duplicate/O RightLong, LeftLong
		Duplicate/O temp, RightLong
		Duplicate/O LeftLat, temp
		Duplicate/O RightLat, LeftLat
		Duplicate/O temp, RightLat
	endif
	
	Display/N=boxFit TopLat vs TopLong
	AppendToGraph/W=boxFit RightLat vs RightLong
	AppendToGraph/W=boxFit BottomLat vs BottomLong
	AppendToGraph/W=boxFit LeftLat vs LeftLong
	ModifyGraph/W=boxFit mode=3,marker=19,msize=1
	ModifyGraph/W=boxFit rgb(TopLat)=(1,16019,65535),rgb(RightLat)=(3,52428,1),rgb(BottomLat)=(65535,65535,0)
	
End

Function chooseSection(lat, long, section)
	Wave lat, long
	String section
	Variable i
	
	GetMarquee left, bottom
	
	String secLat = section + "Lat"
	String secLong = section + "Long"
	Make/D/O/N=(dimSize(lat,0)) $secLat = NaN
	Make/D/O/N=(dimSize(lat,0)) $secLong = NaN
	Wave sectionLat = $secLat
	Wave sectionLong = $secLong
	
	Variable n = 0
	for (i = 0; i < dimSize(lat,0);i += 1)
		if (lat[i] <= V_top && lat[i] >= V_bottom)
			if (long[i] <= V_right && long[i] >= V_left)
				sectionLat[n] = lat[i]
				sectionLong[n] = long[i]
				n = n + 1
			endif
		endif
	endfor
	
End

//Fit the 4 sides of the flight box
Function fitBox (lat, long)
	Wave lat, long
	Variable i, MaxLat, MinLat, MaxLong, MinLong
	NVAR stIndex, endIndex
	Variable/G TopM, TopB, BottomM, BottomB, LeftM, LeftB, RightM, RightB
	
	Wave TopLat = root:TopLat
	Wave TopLong = root:TopLong
	Wave BottomLat = root:BottomLat
	Wave BottomLong = root:BottomLong
	Wave RightLat = root:RightLat
	Wave RightLong = root:RightLong
	Wave LeftLat = root:LeftLat
	Wave LeftLong = root:LeftLong
	
	Make/O/N=2 LatRange = NaN
	Make/O/N=2 LongRange = NaN
	Make/O/N=2 latTopFit = NaN
	Make/O/N=2 latBotFit = NaN
	Make/O/N=2 longLeftFit = NaN
	Make/O/N=2 longRightFit = NaN
	Make/O/N=(4,2) Corner = NaN
	
	LatRange[1] = wavemax(lat ,stIndex, endIndex)
	LatRange[0] = wavemin(lat ,stIndex, endIndex)
	LongRange[1] = wavemax(long ,stIndex, endIndex)
	LongRange[0] = wavemin(long ,stIndex, endIndex)
	
	//Top Fit
	CurveFit/Q/NTHR=0 line  TopLat /X=TopLong
	Wave W_coef = root:W_coef
	TopM = W_coef[1]
	TopB = W_coef[0]
	latTopFit[0] = TopM*LongRange[0] + TopB
	latTopFit[1] = TopM*LongRange[1] + TopB
	
	//Bottom Fit
	CurveFit/Q/NTHR=0 line  BottomLat /X=BottomLong
	Wave W_coef = root:W_coef
	BottomM = W_coef[1]
	BottomB = W_coef[0]
	latBotFit[0] = BottomM*LongRange[0] + BottomB
	latBotFit[1] = BottomM*LongRange[1] + BottomB
	
	//Left Fit
	CurveFit/Q/NTHR=0 line  LeftLong /X=LeftLat
	Wave W_coef = root:W_coef
	LeftM = W_coef[1]
	LeftB = W_coef[0]
	longLeftFit[0] = LeftM*LatRange[0] + LeftB
	longLeftFit[1] = LeftM*LatRange[1] + LeftB
	
	//Right Fit
	CurveFit/Q/NTHR=0 line  RightLong /X=RightLat
	Wave W_coef = root:W_coef
	RightM = W_coef[1]
	RightB = W_coef[0]
	longRightFit[0] = RightM*LatRange[0] + RightB
	longRightFit[1] = RightM*LatRange[1] + RightB
	
	Corner[0][0] = (LeftB + TopB/TopM)/(1/TopM - LeftM)
	Corner[0][1] = LeftM*Corner[0][0] + LeftB
	Corner[1][0] = (LeftB + BottomB/BottomM)/(1/BottomM - LeftM)
	Corner[1][1] = LeftM*Corner[1][0] + LeftB
	Corner[2][0] = (RightB + TopB/TopM)/(1/TopM - RightM)
	Corner[2][1] = RightM*Corner[2][0] + RightB
	Corner[3][0] = (RightB + BottomB/BottomM)/(1/BottomM - RightM)
	Corner[3][1] = RightM*Corner[3][0] + RightB
	
	AppendToGraph/W=boxFit LatRange vs longRightFit
	AppendToGraph/W=boxFit LatRange vs longLeftFit
	AppendToGraph/W=boxFit latTopFit vs LongRange
	AppendToGraph/W=boxFit latBotFit vs LongRange
	ModifyGraph/W=boxFit rgb(LatRange)=(3,52428,1),rgb(latTopFit)=(1,16019,65535),rgb(latBotFit)=(65535,65535,0)
	AppendToGraph/W=boxFit Corner[][0] vs Corner[][1]
	ModifyGraph/W=boxFit mode(Corner)=3,marker(Corner)=19,msize(Corner)=5,rgb(Corner)=(0,0,0)
	
End

Function fitBox5 (lat, long)
	Wave lat, long
	Variable i, MaxLat, MinLat, MaxLong, MinLong
	NVAR stIndex, endIndex
	Variable/G TopM, TopB, BottomM, BottomB, LeftM, LeftB, RightM, RightB
	Variable/G BotLeftM, BotLeftB, LeftBotM, LeftBotB
	
	Wave TopLat = root:TopLat
	Wave TopLong = root:TopLong
	Wave BottomLat = root:BottomLat
	Wave BottomLong = root:BottomLong
	Wave RightLat = root:RightLat
	Wave RightLong = root:RightLong
	Wave LeftLat = root:LeftLat
	Wave LeftLong = root:LeftLong
	
	Wave BotLeftLat = root:BotLeftLat
	Wave BotLeftLong = root:BotLeftLong
//	Wave LeftBotLat = root:LeftBotLat
//	Wave LeftBotLong = root:LeftBotLong
	
	Make/O/N=2 LatRange = NaN
	Make/O/N=2 LongRange = NaN
	Make/O/N=2 latTopFit = NaN
	Make/O/N=2 latBotFit = NaN
	Make/O/N=2 longLeftFit = NaN
	Make/O/N=2 longRightFit = NaN
	Make/O/N=2 latLeftBotFit = NaN
	Make/O/N=2 longBotLeftFit = NaN
	
	Make/O/N=(5,2) Corner = NaN
	
	LatRange[1] = wavemax(lat ,stIndex, endIndex)
	LatRange[0] = wavemin(lat ,stIndex, endIndex)
	LongRange[1] = wavemax(long ,stIndex, endIndex)
	LongRange[0] = wavemin(long ,stIndex, endIndex)
	
	//Top Fit
	CurveFit/Q/NTHR=0 line  TopLat /X=TopLong
	Wave W_coef = root:W_coef
	TopM = W_coef[1]
	TopB = W_coef[0]
	latTopFit[0] = TopM*LongRange[0] + TopB
	latTopFit[1] = TopM*LongRange[1] + TopB
	
	//Bottom Fit
	CurveFit/Q/NTHR=0 line  BottomLat /X=BottomLong
	Wave W_coef = root:W_coef
	BottomM = W_coef[1]
	BottomB = W_coef[0]
	latBotFit[0] = BottomM*LongRange[0] + BottomB
	latBotFit[1] = BottomM*LongRange[1] + BottomB
	
	//Left Fit
	CurveFit/Q/NTHR=0 line  LeftLong /X=LeftLat
	Wave W_coef = root:W_coef
	LeftM = W_coef[1]
	LeftB = W_coef[0]
	longLeftFit[0] = LeftM*LatRange[0] + LeftB
	longLeftFit[1] = LeftM*LatRange[1] + LeftB
	
	//Right Fit
	CurveFit/Q/NTHR=0 line  RightLong /X=RightLat
	Wave W_coef = root:W_coef
	RightM = W_coef[1]
	RightB = W_coef[0]
	longRightFit[0] = RightM*LatRange[0] + RightB
	longRightFit[1] = RightM*LatRange[1] + RightB
	
	//Bottom Left Fit
	CurveFit/Q/NTHR=0 line  BotLeftLat /X=BotLeftLong
	Wave W_coef = root:W_coef
	BotLeftM = W_coef[1]
	BotLeftB = W_coef[0]
	longBotLeftFit[0] = (LatRange[0] - BotLeftB)/BotLeftM
	longBotLeftFit[1] = (LatRange[1] - BotLeftB)/BotLeftM
	
//	CurveFit/Q/NTHR=0 line  BotLeftLong /X=BotLeftLat
//	Wave W_coef = root:W_coef
//	LeftBotM = W_coef[1]
//	LeftBotB = W_coef[0]
//	latLeftBotFit[0] = LeftBotM*LongRange[0] + LeftBotB
//	latLeftBotFit[1] = LeftBotM*LongRange[1] + LeftBotB
	
	Corner[0][0] = (LeftB + TopB/TopM)/(1/TopM - LeftM)
	Corner[0][1] = LeftM*Corner[0][0] + LeftB
	Corner[1][0] = (LeftB + BotLeftB/BotLeftM)/(1/BotLeftM - LeftM)
	Corner[1][1] = LeftM*Corner[1][0] + LeftB
	Corner[2][0] = (LeftBotB + BottomB/BottomM)/(1/BottomM - LeftBotM)
	Corner[2][1] = LeftBotM*Corner[2][0] + LeftBotB
	Corner[3][0] = (RightB + TopB/TopM)/(1/TopM - RightM)
	Corner[3][1] = RightM*Corner[3][0] + RightB
	Corner[4][0] = (RightB + BottomB/BottomM)/(1/BottomM - RightM)
	Corner[4][1] = RightM*Corner[4][0] + RightB
	
	AppendToGraph/W=boxFit LatRange vs longRightFit
	AppendToGraph/W=boxFit LatRange vs longLeftFit
	AppendToGraph/W=boxFit latTopFit vs LongRange
	AppendToGraph/W=boxFit latBotFit vs LongRange
	AppendToGraph/W=boxFit latRange vs longBotLeftFit
	ModifyGraph/W=boxFit rgb(LatRange)=(3,52428,1),rgb(latTopFit)=(1,16019,65535),rgb(latBotFit)=(65535,65535,0),rgb(LatRange#2)=(36873,14755,58982)
	AppendToGraph/W=boxFit Corner[][0] vs Corner[][1]
	ModifyGraph/W=boxFit mode(Corner)=3,marker(Corner)=19,msize(Corner)=5,rgb(Corner)=(0,0,0)
	
End

//Run all the functions required to do the box setup after importing the csv file exported from ArcGIS analysis by Julie
Function updateBoxPath(perpDist, parDist, lat, lon, dt) 
	Variable perpDist, parDist
	Wave lat, lon, dt
	Variable i

	downSamplePath()
	getBestFitPath(perpDist, parDist, lat, lon, dt)
	upSamplePath(lat, lon)


End

//Down sample from 1 m to 100 m along the input path
//Down sample from 0.5 m to 50 m along the input path
Function downSamplePath()
	Variable st = 0
	Variable en = 99
	Variable i
	
	if (exists("switchpathY") == 0)
		Wave POINT_X, POINT_Y
	
		Make/N=(dimSize(POINT_X,0)/100,2)/O/D fullpath
		
		for (i = 0; i < dimSize(fullpath,0); i += 1)
			WaveStats/Q/R=[st,en] POINT_X
			fullpath[i][1] = V_avg
			WaveStats/Q/R=[st,en] POINT_Y
			fullpath[i][0] = V_avg		
			st += 100
			en += 100
		endfor
	
	else
		Wave switchpathX, switchpathY
	
		Make/N=(dimSize(switchpathX,0)/100,2)/O/D fullpath
		
		for (i = 0; i < dimSize(fullpath,0); i += 1)
			WaveStats/Q/R=[st,en] switchpathX
			fullpath[i][1] = V_avg
			WaveStats/Q/R=[st,en] switchpathY
			fullpath[i][0] = V_avg		
			st += 100
			en += 100
		endfor	
	endif
	
	//Make path counter clockwise
//	Duplicate/O fullpath, fullpath_temp
//	
//	for (i = 0; i < dimSize(fullpath_temp,0); i += 1)
//		fullpath[i][0] = fullpath_temp[dimSize(fullpath,0) - 1 - i][0]
//		fullpath[i][1] = fullpath_temp[dimSize(fullpath,0) - 1 - i][1]
//	endfor

End

Function switchDirection()
	Variable i
	Wave POINT_Y, POINT_X
	Make/N=(dimSize(POINT_Y,0))/O/D switchpathY, switchpathX
	
	for (i = 0; i < dimSize(switchpathY,0); i += 1)
		switchpathY[i] = POINT_Y[dimSize(switchpathY,0) - 1 - i]
		switchpathX[i] = POINT_X[dimSize(switchpathX,0) - 1 - i]
	endfor

End

//Up sample from 50 m to 1 m along the input path
Function upSamplePath(lat, lon)
	Wave lat, lon
	Wave fitpath
	Variable i, m, b, xdist
	Variable count, count_each
	Variable R = 6371000
	Variable bear, totdist
	
	Make/N=(dimSize(fitpath,0)*100 + 10000,2)/O/D fitpath_1m = NaN
	
	for (i = 0; i < dimSize(fitpath,0) - 1; i += 1)
		count_each = 0
	//	m = (fitpath[i + 1][0] - fitpath[i][0])/(fitpath[i + 1][1] - fitpath[i][1])
	//	b = fitpath[i + 1][0] - m*fitpath[i + 1][1]
		fitpath_1m[count][0] = fitpath[i][0]
		fitpath_1m[count][1] = fitpath[i][1]
		totdist = distance(fitpath[i][0], fitpath[i][1], fitpath[i+1][0], fitpath[i+1][1])
		bear = bearing(fitpath[i][0], fitpath[i][1], fitpath[i+1][0], fitpath[i+1][1])
		do
			count += 1
			count_each += 1
			xdist = 1
		//	fitpath_1m[count][1] = fitpath_1m[count-1][1] + xdist
		//	fitpath_1m[count][0] = m*fitpath_1m[count][1] + b
			fitpath_1m[count][0] = destPtLat(fitpath_1m[count-1][0],fitpath_1m[count-1][1],xdist,bear)
			fitpath_1m[count][1] = destPtLon(fitpath_1m[count-1][0],fitpath_1m[count-1][1],xdist,bear,fitpath_1m[count][0])
		//while(fitpath_1m[count][1] < fitpath[i+1][1])
		while(count_each < totdist)
	endfor
	
	count_each = 0
//	m = (fitpath[0][0] - fitpath[i][0])/(fitpath[0][1] - fitpath[i][1])
//	b = fitpath[0][0] - m*fitpath[0][1]
	fitpath_1m[count][0] = fitpath[i][0]
	fitpath_1m[count][1] = fitpath[i][1]
	totdist = distance(fitpath[i][0], fitpath[i][1], fitpath[0][0], fitpath[0][1])
	bear = bearing(fitpath[i][0], fitpath[i][1], fitpath[0][0], fitpath[0][1])

		do
			count += 1
			count_each += 1
			xdist = 1
		//	fitpath_1m[count][1] = fitpath_1m[count-1][1] + xdist
		//	fitpath_1m[count][0] = m*fitpath_1m[count][1] + b
			fitpath_1m[count][0] = destPtLat(fitpath_1m[count-1][0],fitpath_1m[count-1][1],xdist,bear)
			fitpath_1m[count][1] = destPtLon(fitpath_1m[count-1][0],fitpath_1m[count-1][1],xdist,bear,fitpath_1m[count][0])
		//while(fitpath_1m[count][1] < fitpath[i+1][1])
		while(count_each < totdist)
	
	DeletePoints count, dimSize(fitpath_1m,0), fitpath_1m
	
	Wave fitpath_1m
	Display lat vs lon
	AppendToGraph fitpath_1m[][0] vs fitpath_1m[][1]
	AppendToGraph fitpath[][0] vs fitpath[][1]
	ModifyGraph mode=3,marker=19,msize=1.5,rgb(fitpath_1m)=(0,0,0),rgb(fitpath)=(2,39321,1)
	
	Make/O/N=(dimSize(fitpath_1m,0))/D path_lat
	Make/O/N=(dimSize(fitpath_1m,0))/D path_long
	
	for (i = 0; i < dimSize(fitpath_1m,0); i += 1)
		path_lat[i] = fitpath_1m[i][0]
		path_long[i] = fitpath_1m[i][1]	
	endfor
	
	
End

Function getBestFitPath(perpDist, parDist, lat, lon, dt)
	Variable perpDist, parDist
	Wave lat, lon, dt
	Wave fullpath
	Variable i, j, k, fullbearing, databearing, datadist
	NVAR stindex, endindex
	
	Make/N=(dimSize(fullpath,0),2)/O/D fitpath = NaN
	
//	Variable nthreads = ThreadProcessorCount
//	Variable threadGroupID = ThreadGroupCreate(nthreads)
	
//Shift the box 100 points so that the function does not start/end on a corner
//	if (exists("fullpath_temp") == 0)
//		Duplicate/O fullpath, fullpath_temp
//		Variable offset = 100
//		Variable np = dimSize(fullpath,0)
//		
//		for(i=0; i<np; i+=1)
//			if(i-offset>=0)
//				fullpath[i-offset][0] = fullpath_temp[i][0]
//				fullpath[i-offset][1] = fullpath_temp[i][1]
//			else
//				fullpath[i-offset+np][0] = fullpath_temp[i][0]
//				fullpath[i-offset+np][1] = fullpath_temp[i][1]
//			endif
//		endfor	
//	endif

	Duplicate/O lat, lat_temp
	Duplicate/O lon, lon_temp
	Variable stind, endind
	
	if (exists("exc_st") != 0)
		Wave exc_st, exc_end
		
		for (j = 0; j < dimSize(exc_st,0); j += 1)
			stind = BinarySearch (dt, exc_st[j])
			endind = BinarySearch (dt, exc_end[j])
		
			for (i = stind; i <= endind; i += 1)
				lat_temp[i] = NaN
				lon_temp[i] = NaN
			endfor
		endfor	
		
	endif
	
	for (i = 0; i < dimSize(fullpath,0) - 1;)
//	for (i = 387; i < 389; i += 1)

		fullbearing = bearing(fullpath[i][0], fullpath[i][1], fullpath[i+1][0], fullpath[i+1][1])

		//for (k = 0; k < nthreads; k += 1)
			//ThreadStart threadGroupID, k, 
			ellipsePt(i, lat_temp, lon_temp, perpDist, parDist, fullbearing, stindex, endindex)
			i += 1
			if (i >= dimSize(fullpath,0))
				break
			endif
		//endfor
		
		//do
		//	Variable threadGroupStatus = ThreadGroupWait(threadGroupID,100)
		//while (threadGroupStatus != 0)
	endfor
		
	//Variable dummy = ThreadGroupRelease(threadGroupID)
	
	fullbearing = bearing(fullpath[i][0], fullpath[i][1], fullpath[0][0], fullpath[0][1])
	ellipsePt(i, lat_temp, lon_temp, perpDist, parDist, fullbearing, stindex, endindex)


End

Function bearing(lat1,lon1,lat2,lon2)
	Variable lat1,lon1,lat2,lon2
	Variable bear
	
	Variable lat1rad, lon1rad, lat2rad, lon2rad
	lat1rad = lat1*pi/180
	lon1rad = lon1*pi/180
	lat2rad = lat2*pi/180
	lon2rad = lon2*pi/180
	
	Variable deltalat = lat2rad - lat1rad
	Variable deltalon = lon2rad - lon1rad
	
	bear = atan2(sin(deltalon)*cos(lat2rad),cos(lat1rad)*sin(lat2rad) - sin(lat1rad)*cos(lat2rad)*cos(deltalon))
	bear = bear*180/pi
	
	Return bear

End


//Get the distance between 2 points on the Earth
ThreadSafe Function distanceTS (lat1, long1, lat2, long2)
	Variable lat1, long1, lat2, long2
	Variable latRad1, latRad2, longRad1, longRad2, deltaLat, deltaLong, a, c, d
	Variable R = 6371000
	
	latRad1 = lat1*pi/180
	longRad1 = long1*pi/180
	latRad2 = lat2*pi/180
	longRad2 = long2*pi/180
	deltaLat = latRad2 - latRad1
	deltaLong = longRad2 - longRad1
	a = (sin(deltaLat/2))^2 + cos(latRad1)*cos(latRad2)*(sin(deltaLong/2))^2
	c = 2*atan2(sqrt(a), sqrt(1-a))
	d= R*c
	
//	Variable c2 = d/R
//	Variable a2 = tan(c^2)
//	Variable deltaLong2 = 2*asin(sqrt((a2 - (sin(deltaLat/2))^2)/(cos(latRad1)*cos(latRad2))))
//	Variable long22 = (longRad1 - deltaLong2)*180/pi
	
	return d
	
End

Function destPtLat(lat,lon,dist,bear)
	Variable lat,lon,dist,bear
	Variable R = 6371000
	
//	if (bear < 180)
//		bear = bear + 180
//	else
//		bear = bear - 180
//	endif
	
	Variable latr = lat*pi/180
	Variable lonr = lon*pi/180
	Variable bearr = bear*pi/180
	
	Variable latDestr = asin(sin(latr)*cos(dist/R) + cos(latr)*sin(dist/R)*cos(bearr))
	Variable latDest = latDestr*180/pi	
	
	Return latDest

End

Function destPtLon(lat,lon,dist,bear,latDest)
	Variable lat,lon,dist,bear,latDest
	Variable R = 6371000
	
//	if (bear < 180)
//		bear = bear + 180
//	else
//		bear = bear - 180
//	endif	
	
	Variable latr = lat*pi/180
	Variable lonr = lon*pi/180
	Variable latDestr = latDest*pi/180
	Variable bearr = bear*pi/180
	
	Variable lonDestr = lonr + atan2(sin(bearr)*sin(dist/R)*cos(latr), cos(dist/R) - sin(latr)*sin(latDestr))
	Variable lonDest = lonDestr*180/pi	
	
	Return lonDest

End

ThreadSafe Function ellipsePt(i, lat, lon, perpDist, parDist, fullbearing, stindex, endindex)
	Variable i
	Wave lat, lon
	Variable perpDist, parDist, fullbearing, stindex, endindex
	
	Wave fullpath
	Wave fitpath
	Variable datadist, j, parDist_deg, perpDist_deg, term1, term2
	Variable latsum = 0
	Variable lonsum = 0
	Variable test
	Variable R = 6371000	
	Variable count = 0
	Variable count2 = 0
	
	Make/N=2000/O/D tempLat = NaN
	Make/N=2000/O/D tempLon = NaN

	//Compare the bearing between this point and the next point on the fullpath
	//with the bearing between this point and the data point
	for (j = stindex; j <= endindex; j += 1)
//	for (j = 387; j <= 389; j += 1)
		datadist = distanceTS(fullpath[i][0], fullpath[i][1], lat[j], lon[j])
		
		if (datadist <= perpDist)
			parDist_deg = parDist/(pi*R)*180
			perpDist_deg = perpDist/(pi*R)*180
			term1 = (cos(fullbearing*pi/180)*(lon[j] - fullpath[i][1]) + sin(fullbearing*pi/180)*(lat[j] - fullpath[i][0]))^2
			term2 = (sin(fullbearing*pi/180)*(lon[j] - fullpath[i][1]) - cos(fullbearing*pi/180)*(lat[j] - fullpath[i][0]))^2
			test = term1/perpDist_deg^2 + term2/parDist_deg^2
			
			if (test <= 1)
				latsum = latsum + lat[j]
				lonsum = lonsum + lon[j]
				tempLat[count2] = lat[j]
				tempLon[count2] = lon[j]
				//lat2avg[count] = lat[j]
				//lon2avg[count] = lon[j]
				count += 1
				count2 += 1
			endif
		endif 
		
	endfor

	Variable avglat = latsum/count
	Variable avglon = lonsum/count
	fitpath[i][0] = avglat
	fitpath[i][1] = avglon
	
	return 0

End


//Create a path around the flight box
Function createPath ()
	Wave Corner = root:Corner
	Variable latprev, longprev, bearing, bearing2, lat0, long0, lat1, long1, x0, x1, y0, y1
	Variable i = 0
	Variable latRad1, latRad2, longRad1, longRad2, deltaLat, deltaLong, a, c, r, j
	Variable RE = 6371000
	Variable d = 2
	NVAR LeftM, LeftB, TopM, TopB, RightM, RightB, BottomM, BottomB
	
	Make/D/O/N=2000000 path_lat = NaN
	Make/D/O/N=2000000 path_long = NaN
	Make/D/O/N=2000000 path_dist = NaN
	
	Wave BottomLat = root:BottomLat
	Wave BottomLong = root:BottomLong
	Wave TopLat = root:TopLat
	Wave TopLong = root:TopLong
	Wave LeftLat = root:LeftLat
	Wave LeftLong = root:LeftLong
	Wave RightLat = root:RightLat
	Wave RightLong = root:RightLong
	
	Variable leftMin = WaveMin(LeftLat)
	Variable leftMax = WaveMax(LeftLat)
	Variable bottomMin = WaveMin(BottomLong)
	Variable bottomMax = WaveMax(BottomLong)
	Variable rightMin = WaveMin(RightLat)
	Variable rightMax = WaveMax(RightLat)
	Variable topMax = WaveMax(TopLong)
	Variable topMin = WaveMin(TopLong)
	
	//LEFT SIDE
	path_lat[0] = leftMax
	path_long[0] = LeftM*path_lat[0] + LeftB
	path_dist[0] = 0
	
	latRad1 = Corner[0][0]*pi/180
	longRad1 = Corner[0][1]*pi/180
	latRad2 = Corner[1][0]*pi/180
	longRad2 = Corner[1][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	//Get point where line should stop
	Variable LatRef = Corner[1][0]
	Variable LonRef = Corner[1][1]
	
	lat0 = leftMin
	long0 = LeftM*lat0 + LeftB
	long1 = bottomMin
	lat1 = BottomM*long1 + BottomB
	
	x0 = 0
	x1 = distance(Corner[1][0], Corner[1][1], lat1, long1)
	y0 = 0
	y1 = distance(Corner[1][0], Corner[1][1], lat0, long0)
	
	if (y1 > x1)
		r = y1
	else
		r = x1
	endif
	
	leftMin = (180*r)/(RE*pi) + LatRef
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_lat[i] >= leftMin)

	//BOTTOM-LEFT CORNER
	lat0 = path_lat[i]
	long0 = LeftM*lat0 + LeftB
	long1 = bottomMin
	lat1 = BottomM*long1 + BottomB
	
	Variable n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = y1
	
	Variable theta = 0
	Variable theta_lim = theta + pi/2

	do
		path_x[n] = path_x[n-1] + 2*sin(theta)
		path_y[n] = path_y[n-1] - 2*cos(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef 
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef - 0.0014
		if (path_long[j+i] < path_long[j+i-1])
			path_long[j+i] = path_long[j+i-1]
		endif
	endfor
	
	//BOTTOM SIDE
	i = i + j - 1	
	latRad1 = Corner[1][0]*pi/180
	longRad1 = Corner[1][1]*pi/180
	latRad2 = Corner[3][0]*pi/180
	longRad2 = Corner[3][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong)) + 0.0048
	
	//Get point where line should stop
	LatRef = Corner[3][0]
	LonRef = Corner[3][1]
	
	long0 = bottomMax
	lat0 = BottomM*long0 + BottomB
	lat1 = rightMin
	long1 = RightM*lat1 + RightB
	
	x0 = 0
	y1 = distance(Corner[3][0], Corner[3][1], lat1, long1)
	y0 = 0
	x1 = distance(Corner[3][0], Corner[3][1], lat0, long0)
	
	if (abs(y1) < abs(x1))
		r = abs(y1)
	else
		r = abs(x1)
	endif

	bottomMax = -(180*r)/(RE*pi*cos(LatRef*pi/180)) + LonRef + 0.00045
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_long[i] <= bottomMax)

	//BOTTOM-RIGHT CORNER
	long0 = path_long[i]
	lat0 = BottomM*long0 + BottomB
	lat1 = rightMin
	long1 = RightM*lat1 + RightB
	
	LatRef = lat0
	LonRef = long0

	n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = 0
	
	theta = 0
	theta_lim = theta + pi/2

	do
		path_x[n] = path_x[n-1] + 2*cos(theta)
		path_y[n] = path_y[n-1] + 2*sin(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
		if (path_long[j+i] < path_long[j+i-1])
			path_long[j+i] = path_long[j+i-1]
		endif
	endfor
	
	//RIGHT SIDE
	i = i + j - 1	
	latRad1 = Corner[3][0]*pi/180
	longRad1 = Corner[3][1]*pi/180
	latRad2 = Corner[2][0]*pi/180
	longRad2 = Corner[2][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	//Get point where line should stop
	LatRef = Corner[2][0]
	LonRef = Corner[2][1]
	
	lat0 = rightMax
	long0 = RightM*lat0 + RightB
	long1 = topMax
	lat1 = TopM*long1 + TopB
	
	x0 = 0
	x1 = distance(Corner[2][0], Corner[2][1], lat1, long1)
	y0 = 0
	y1 = distance(Corner[2][0], Corner[2][1], lat0, long0)
	
	if (abs(y1) < abs(x1))
		r = abs(y1)
	else
		r = abs(x1)
	endif

	rightMax = -(180*r)/(RE*pi) + LatRef + 0.00022
	
	do 
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_lat[i] <= rightMax)
	
//	//TOP-RIGHT CORNER
	LatRef = rightMax
	lat0 = path_lat[i]
	long0 = RightM*lat0 + RightB
	long1 = topMax
	lat1 = TopM*long1 + TopB
	
	n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = 0
	
	theta = 0
	theta_lim = theta + pi/2

	do
		path_x[n] = path_x[n-1] - 2*sin(theta)
		path_y[n] = path_y[n-1] + 2*cos(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
		if (path_long[j+i] > path_long[j+i-1])
			path_long[j+i] = path_long[j+i-1]
		endif
	endfor

	//TOP SIDE
	i = i + j - 1	
	latRad1 = Corner[2][0]*pi/180
	longRad1 = Corner[2][1]*pi/180
	latRad2 = Corner[0][0]*pi/180
	longRad2 = Corner[0][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong)) - 0.0022
	
	//Get point where line should stop
	LatRef = Corner[0][0]
	LonRef = Corner[0][1]
	
	long0 = topMin
	lat0 = TopM*long0 + TopB
	lat1 = leftMax
	long1 = LeftM*lat1 + LeftB
	
	x0 = 0
	y1 = distance(Corner[0][0], Corner[0][1], lat1, long1)
	y0 = 0
	x1 = distance(Corner[0][0], Corner[0][1], lat0, long0)
	
	if (abs(y1) > abs(x1))
		r = abs(y1)
	else
		r = abs(x1)
	endif

	topMin = (180*r)/(RE*pi*cos(LatRef*pi/180)) + LonRef - 0.00022
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_long[i] >= topMin)
	
	//TOP-LEFT CORNER
	long0 = path_long[i]
	lat0 = TopM*long0 + TopB
	lat1 = leftMax
	long1 = LeftM*lat1 + LeftB
	
	LatRef = lat0
	LonRef = long0

	n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = 0
	
	theta = 0
	theta_lim = theta + 1.215*pi/3

	do
		path_x[n] = path_x[n-1] - 2*cos(theta)
		path_y[n] = path_y[n-1] - 2*sin(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
//		if (path_long[j+i] < path_long[j+i-1])
//			path_long[j+i] = path_long[j+i-1]
//		endif
	endfor
	
	//LEFT SIDE
	i = i + j - 1	
	latRad1 = Corner[0][0]*pi/180
	longRad1 = Corner[0][1]*pi/180
	latRad2 = Corner[1][0]*pi/180
	longRad2 = Corner[1][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_lat[i] >= path_lat[0])

	DeletePoints i + 1, (dimSize(path_lat,0) - i -1), path_lat, path_long, path_dist
	
	AppendToGraph/W=boxFit path_lat vs path_long
	ModifyGraph/W=boxFit rgb(path_lat)=(0,0,0)
	
End

Function createPath5 ()
	Wave Corner = root:Corner
	Variable latprev, longprev, bearing, bearing2, lat0, long0, lat1, long1, x0, x1, y0, y1
	Variable i = 0
	Variable latRad1, latRad2, longRad1, longRad2, deltaLat, deltaLong, a, c, r, j, xtemp
	Variable RE = 6371000
	Variable d = 2
	NVAR LeftM, LeftB, TopM, TopB, RightM, RightB, BottomM, BottomB, BotLeftM, BotLeftB, LeftBotM, LeftBotB
	
	Make/D/O/N=2000000 path_lat = NaN
	Make/D/O/N=2000000 path_long = NaN
	Make/D/O/N=2000000 path_dist = NaN
	
	Wave BottomLat = root:BottomLat
	Wave BottomLong = root:BottomLong
	Wave TopLat = root:TopLat
	Wave TopLong = root:TopLong
	Wave LeftLat = root:LeftLat
	Wave LeftLong = root:LeftLong
	Wave RightLat = root:RightLat
	Wave RightLong = root:RightLong
	Wave BotLeftLat = root:BotLeftLat
	Wave BotLeftLong = root:BotLeftLong
	
	Variable leftMin = WaveMin(LeftLat)
	Variable leftMax = WaveMax(LeftLat)
	Variable bottomMin = WaveMin(BottomLong)
	Variable bottomMax = WaveMax(BottomLong)
	Variable rightMin = WaveMin(RightLat)
	Variable rightMax = WaveMax(RightLat)
	Variable topMax = WaveMax(TopLong)
	Variable topMin = WaveMin(TopLong)
	Variable botleftMin = WaveMin(BotLeftLat)
	Variable botleftMax = WaveMax(BotLeftLat)
	
	//LEFT SIDE
	path_lat[0] = leftMax
	path_long[0] = LeftM*path_lat[0] + LeftB
	path_dist[0] = 0
	
	latRad1 = Corner[0][0]*pi/180
	longRad1 = Corner[0][1]*pi/180
	latRad2 = Corner[1][0]*pi/180
	longRad2 = Corner[1][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	//Get point where line should stop
	Variable LatRef = Corner[1][0]
	Variable LonRef = Corner[1][1]
	
	lat0 = leftMin
	long0 = LeftM*lat0 + LeftB
	lat1 = botleftMax
	long1 = LeftBotM*lat1 + LeftBotB
	
	x0 = 0
	x1 = distance(Corner[1][0], Corner[1][1], lat1, long1)
	y0 = 0
	y1 = distance(Corner[1][0], Corner[1][1], lat0, long0)
	
	if (y1 > x1)
		r = y1
	else
		r = x1
	endif
	
	leftMin = (180*r)/(RE*pi) + LatRef
//	leftMin = LatRef
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
//	while (path_lat[i] >= leftMin)
	while (path_lat[i] >= Corner[1][0])

//	//LEFT-BOTTOM-LEFT CORNER
//	lat0 = path_lat[i]
//	long0 = LeftM*lat0 + LeftB
//	lat1 = botleftMax
//	long1 = LeftBotM*lat1 + LeftBotB
//	
	Variable n = 1
//	
//	Make/O/D/N=100000 path_x = NaN
//	Make/O/D/N=100000 path_y = NaN
//	
//	path_x[0] = 0
//	path_y[0] = y1
//
	Variable theta = 0
	Variable theta_lim = theta + pi/4
//
//	do
//		path_x[n] = path_x[n-1] + 2*sin(theta) 
//		path_y[n] = path_y[n-1] - 4*cos(theta) 
//		xtemp = path_x[n]
////		path_x[n] = xtemp*cos(30*pi/180) - path_y[n]*sin(30*pi/180)
////		path_y[n] = xtemp*sin(30*pi/80) + path_y[n]*cos(30*pi/180)
//		theta = theta + 2/r
//		n = n + 1
////		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
//	while(theta < theta_lim) //&& y0 <= path_lat[i])
//	
//	for (j = 0; j < n; j += 1)
//		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef + 0.004
//		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
//		if (path_long[j+i] < path_long[j+i-1])
//			path_long[j+i] = path_long[j+i-1]
//		endif
//	endfor
//	
	//BOTTOM-LEFT SIDE
	i = i + j - 1	
	latRad1 = Corner[1][0]*pi/180
	longRad1 = Corner[1][1]*pi/180
	latRad2 = Corner[2][0]*pi/180
	longRad2 = Corner[2][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	//Get point where line should stop
	LatRef = Corner[2][0]
	LonRef = Corner[2][1]
	
	lat0 = botleftMin
	long0 = LeftBotM*lat0 + LeftBotB
	long1 = bottomMin
	lat1 = BottomM*long1 + BottomB
	
	x0 = 0
	x1 = distance(Corner[2][0], Corner[2][1], lat1, long1)
	y0 = 0
	y1 = distance(Corner[2][0], Corner[2][1], lat0, long0)
	
	if (y1 > x1)
		r = y1
	else
		r = x1
	endif
//	print botleftMin
	botleftMin = (180*r)/(RE*pi) + LatRef
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_lat[i] >= Corner[2][0])
//	while (path_lat[i] >= botleftMin)

//	//BOTTOM-LEFT-LEFT CORNER
//	lat0 = path_lat[i]
//	long0 = LeftBotM*lat0 + LeftBotB
//	long1 = bottomMin
//	lat1 = BottomM*long1 + BottomB
//	
//	n = 1
//	
//	Make/O/D/N=100000 path_x = NaN
//	Make/O/D/N=100000 path_y = NaN
//	
//	path_x[0] = 0
//	path_y[0] = y1
//	
//	theta = 0
//	theta_lim = theta + pi/2
//
//	do
//		path_x[n] = path_x[n-1] + 2*sin(theta)
//		path_y[n] = path_y[n-1] - 2*cos(theta)
//		theta = theta + 2/r
//		n = n + 1
////		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
//	while(theta < theta_lim) //&& y0 <= path_lat[i])
//	
//	for (j = 0; j < n; j += 1)
//		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef + 0.004
////		print path_lat[j+i], j+i
//		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
//		if (path_long[j+i] < path_long[j+i-1])
//			path_long[j+i] = path_long[j+i-1]
//		endif
//	endfor
	
	//BOTTOM SIDE
//	i = i + j - 1	
	latRad1 = Corner[2][0]*pi/180
	longRad1 = Corner[2][1]*pi/180
	latRad2 = Corner[4][0]*pi/180
	longRad2 = Corner[4][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong)) + 0.0022
	
	//Get point where line should stop
	LatRef = Corner[4][0]
	LonRef = Corner[4][1]
	
	long0 = bottomMax
	lat0 = BottomM*long0 + BottomB
	lat1 = rightMin
	long1 = RightM*lat1 + RightB
	
	x0 = 0
	y1 = distance(Corner[4][0], Corner[4][1], lat1, long1)
	y0 = 0
	x1 = distance(Corner[4][0], Corner[4][1], lat0, long0)
	
	if (abs(y1) < abs(x1))
		r = abs(y1)
	else
		r = abs(x1)
	endif

	bottomMax = -(180*r)/(RE*pi*cos(LatRef*pi/180)) + LonRef + 0.00022
	print bottomMax, i
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_long[i] <= bottomMax)

	//BOTTOM-RIGHT CORNER
	long0 = path_long[i]
	lat0 = BottomM*long0 + BottomB
	lat1 = rightMin
	long1 = RightM*lat1 + RightB
	
	LatRef = lat0
	LonRef = long0

	n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = 0
	
	theta = 0
	theta_lim = theta + pi/2

	do
		path_x[n] = path_x[n-1] + 2*cos(theta)
		path_y[n] = path_y[n-1] + 2*sin(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
		if (path_long[j+i] < path_long[j+i-1])
			path_long[j+i] = path_long[j+i-1]
		endif
	endfor
	
	//RIGHT SIDE
	i = i + j - 1	
	latRad1 = Corner[4][0]*pi/180
	longRad1 = Corner[4][1]*pi/180
	latRad2 = Corner[3][0]*pi/180
	longRad2 = Corner[3][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	//Get point where line should stop
	LatRef = Corner[3][0]
	LonRef = Corner[3][1]
	
	lat0 = rightMax
	long0 = RightM*lat0 + RightB
	long1 = topMax
	lat1 = TopM*long1 + TopB
	
	x0 = 0
	x1 = distance(Corner[3][0], Corner[3][1], lat1, long1)
	y0 = 0
	y1 = distance(Corner[3][0], Corner[3][1], lat0, long0)
	
	if (abs(y1) < abs(x1))
		r = abs(y1)
	else
		r = abs(x1)
	endif

	rightMax = -(180*r)/(RE*pi) + LatRef + 0.00022
	
	do 
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_lat[i] <= rightMax)
	
	//TOP-RIGHT CORNER
	LatRef = rightMax
	lat0 = path_lat[i]
	long0 = RightM*lat0 + RightB
	long1 = topMax
	lat1 = TopM*long1 + TopB
	
	n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = 0
	
	theta = 0
	theta_lim = theta + pi/2

	do
		path_x[n] = path_x[n-1] - 2*sin(theta)
		path_y[n] = path_y[n-1] + 2*cos(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
		if (path_long[j+i] > path_long[j+i-1])
			path_long[j+i] = path_long[j+i-1]
		endif
	endfor

	//TOP SIDE
	i = i + j - 1	
	latRad1 = Corner[3][0]*pi/180
	longRad1 = Corner[3][1]*pi/180
	latRad2 = Corner[0][0]*pi/180
	longRad2 = Corner[0][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong)) - 0.0022
	
	//Get point where line should stop
	LatRef = Corner[0][0]
	LonRef = Corner[0][1]
	
	long0 = topMin
	lat0 = TopM*long0 + TopB
	lat1 = leftMax
	long1 = LeftM*lat1 + LeftB
	
	x0 = 0
	y1 = distance(Corner[0][0], Corner[0][1], lat1, long1)
	y0 = 0
	x1 = distance(Corner[0][0], Corner[0][1], lat0, long0)
	
	if (abs(y1) > abs(x1))
		r = abs(y1)
	else
		r = abs(x1)
	endif

	topMin = (180*r)/(RE*pi*cos(LatRef*pi/180)) + LonRef - 0.00022
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_long[i] >= topMin)
	
	//TOP-LEFT CORNER
	long0 = path_long[i]
	lat0 = TopM*long0 + TopB
	lat1 = leftMax
	long1 = LeftM*lat1 + LeftB
	
	LatRef = lat0
	LonRef = long0

	n = 1
	
	Make/O/D/N=100000 path_x = NaN
	Make/O/D/N=100000 path_y = NaN
	
	path_x[0] = 0
	path_y[0] = 0
	
	theta = 0
	theta_lim = theta + pi/2

	do
		path_x[n] = path_x[n-1] - 2*cos(theta)
		path_y[n] = path_y[n-1] - 2*sin(theta)
		theta = theta + 2/r
		n = n + 1
//		y0 = BottomM*path_long[i] - BottomM*sin(theta)/2750 - cos(theta)/2750 + BottomB
	while(theta < theta_lim) //&& y0 <= path_lat[i])
	
	for (j = 0; j < n; j += 1)
		path_lat[j+i] = (180*path_y[j])/(RE*pi) + LatRef
		path_long[j+i] = (180*path_x[j])/(RE*pi*cos(path_lat[j+i]*pi/180)) + LonRef
//		if (path_long[j+i] < path_long[j+i-1])
//			path_long[j+i] = path_long[j+i-1]
//		endif
	endfor
	
	//LEFT SIDE
	i = i + j - 1	
	latRad1 = Corner[0][0]*pi/180
	longRad1 = Corner[0][1]*pi/180
	latRad2 = Corner[1][0]*pi/180
	longRad2 = Corner[1][1]*pi/180
	deltaLong = longRad2 - longRad1
	
	bearing = atan2(sin(deltaLong)*cos(latRad2), cos(latRad1)*sin(latRad2) - sin(latRad1)*cos(latRad2)*cos(deltaLong))
	
	do
		i = i + 1
		latRad1 = path_lat[i-1]*pi/180
		longRad1 = path_long[i-1]*pi/180
		latRad2 = asin(sin(latRad1)*cos(d/RE) + cos(latRad1)*sin(d/RE)*cos(bearing))
		longRad2 = longRad1 + atan2(sin(bearing)*sin(d/RE)*cos(latRad1), cos(d/RE) - sin(latRad1)*sin(latRad2))
	
		path_lat[i] = latRad2*180/pi
		path_long[i] = longRad2*180/pi
		path_dist[i] = path_dist[i-1] + 1
	while (path_lat[i] >= path_lat[0])

	DeletePoints i + 1, (dimSize(path_lat,0) - i -1), path_lat, path_long, path_dist
	
	AppendToGraph/W=boxFit path_lat vs path_long
	ModifyGraph/W=boxFit rgb(path_lat)=(0,0,0)
	
End

//Get the distance between 2 points on the Earth
Function distance (lat1, long1, lat2, long2)
	Variable lat1, long1, lat2, long2
	Variable latRad1, latRad2, longRad1, longRad2, deltaLat, deltaLong, a, c, d
	Variable R = 6371000
	
	latRad1 = lat1*pi/180
	longRad1 = long1*pi/180
	latRad2 = lat2*pi/180
	longRad2 = long2*pi/180
	deltaLat = latRad2 - latRad1
	deltaLong = longRad2 - longRad1

	a = (sin(deltaLat/2))^2 + cos(latRad1)*cos(latRad2)*(sin(deltaLong/2))^2
	c = 2*atan2(sqrt(a), sqrt(1-a))
	d= R*c
	
	Variable c2 = d/R
	Variable a2 = tan(c^2)
	Variable deltaLong2 = 2*asin(sqrt((a2 - (sin(deltaLat/2))^2)/(cos(latRad1)*cos(latRad2))))
	Variable long22 = (longRad1 - deltaLong2)*180/pi
	
	return d
	
End

//Shift box so that it starts at the South-East corner of the box
function Shift(offset, lat, lon)

	// Note the switch to (Lon, Lat) for ScreenPosXY
	variable offset
	Wave lat, lon
	variable i, np
	Wave path_lat, path_long
	Concatenate/O {path_lat, path_long}, Fit_import
	//wave Fit_import
	
	//Concatenate longitude and latitude into one wave
	Concatenate/O {lon, lat}, Flight_positions_deg

	np = dimsize(Fit_import,0)

	make/d/o/n=(np,2) ScreenPosXY_deg=nan
	setscale/p x, 0, 2, ScreenPosXY_deg

	for(i=0; i<np; i+=1)
		if(i-offset>=0)
			ScreenPosXY_deg[i-offset][0] = Fit_import[i][1]
			ScreenPosXY_deg[i-offset][1] = Fit_import[i][0]
		else
			ScreenPosXY_deg[i-offset+np][0] = Fit_import[i][1]
			ScreenPosXY_deg[i-offset+np][1] = Fit_import[i][0]
		endif
	endfor
	
	Deg2Meters()
	Display lat vs lon
	AppendToGraph ScreenPosXY_deg[][1] vs ScreenPosXY_deg[][0]
	ModifyGraph rgb(ScreenPosXY_deg)=(0,0,0)
	ModifyGraph mode=3,marker=19,msize=1.5
	
//	RemoveFromGraph/Z/W=boxFit path_lat
//	AppendToGraph/W=boxFit ScreenPosXY_deg[][1] vs ScreenPosXY_deg[][0]
//	ModifyGraph/W=boxFit rgb(ScreenPosXY_deg)=(0,0,0)

End

//Convert degrees to meters
function Deg2Meters()

	string wname
	variable i, np
	variable/g EarthR = 6.36313e+6 
	variable/g LatRef = 56.655, LonRef=-111.237 // Fort McMurray Airport
	variable dx, dy

	wname = "ScreenPosXY_deg"
	duplicate/o $wname, Fit_deg
  
	np = dimsize(Fit_deg,0)
  
	make/d/o/n=(np,2) Fit_m=nan
	make/d/o/n=(np) Dist=nan
  
	for(i=0; i<np; i+=1)
		Fit_m[i][0] = (Fit_deg[i][0]-LonRef)*EarthR*pi*cos(Fit_deg[i][1]*pi/180)/180
		Fit_m[i][1] = (Fit_deg[i][1]-LatRef)*EarthR*pi/180
		//    lat = (180*ScreenPosXY_Suncor1[i][1])/(EarthR*pi) + LatRef
		//    lon = (180*ScreenPosXY_Suncor1[i][0])/(EarthR*pi*cos(lat*pi/180)) + LonRef
	endfor

	for(i=1; i<np; i+=1)
		Dist[i] = sqrt((Fit_m[i][0]-Fit_m[i-1][0])^2 + (Fit_m[i][1]-Fit_m[i-1][1])^2)
	endfor

End

//Make a frame that will be displayed to separate different sides of the screen
Function MakeFrame(SE, NE, NW, SW, SE2)
	Variable SE, NE, NW, SW, SE2
  
	String name = "Frame"
	make/o/n=(5,2) $name
	wave Frame = $name

	Frame[0][0] = SE				//index of first point
	Frame[1][0] = NE	
	Frame[2][0] = NW
	Frame[3][0] = SW
	Frame[4][0] = SE2		//index of last point

	Frame[*][1] = 2000			//height of frame lines

End  

//Make a frame that will be displayed to separate different sides of the screen
Function MakeFrame5(SE, NE, NW, W, SW, SE2)
	Variable SE, NE, NW, W, SW, SE2
  
	String name = "Frame"
	make/o/n=(6,2) $name
	wave Frame = $name

	Frame[0][0] = SE				//index of first point
	Frame[1][0] = NE	
	Frame[2][0] = NW
	Frame[3][0] = W
	Frame[4][0] = SW
	Frame[5][0] = SE2		//index of last point

	Frame[*][1] = 2000			//height of frame lines

End 

//Load elevations and get ground elevation below the flight path
Function loadElevations()
	
	NewPath/O terra "\\\\econm3hwvasp010.ncr.int.ec.gc.ca\\OSM_2018\\AIRCRAFT\\Data_v1_INTERIM\\TERRA"
	Load1()
	Load2()
	FlightElev()
	Wave ElevationArray_m
	KillWaves/Z ElevationArray_m

End

//Load digital elevation model
Function Load1()

  killwaves/z wave0
  LoadWave/P=terra/J/M/A=wave/K=0/V={"\t, "," $",0,0}/L={0,6,0,0,0} "os2018_nrcan_dem_fullextent.txt"

End

//Scale the elevation model to proper latitude and longitude values
Function Load2()

  wave/z wave0
  duplicate/o wave0, ElevationArray_m
  setscale/i x, 58.4999, 52.9999, ElevationArray_m
  setscale/i y, -113.5, -108, ElevationArray_m
  killwaves/z wave0
   
End

//Calculate the elevation below the flight path and below the best fit flight box
Function FlightElev()

	variable i, np, k, nk
	variable xi, yi
	wave ElevationArray_m
  
	//Cacluate ground elevation below the flight path
	Wave flightpos = Flight_positions_deg
	
	np = dimsize(flightpos,0)
	
	make/o/n=(np) GndElev
	setscale/p x, 0, 1, GndElev
	
	for(i=0; i<np; i+=1)
		xi = (flightpos[i][0] - DimOffset(ElevationArray_m,1))/DimDelta(ElevationArray_m,1)
		yi = (flightpos[i][1] - DimOffset(ElevationArray_m,0))/DimDelta(ElevationArray_m,0)
		GndElev[i] = ElevationArray_m[yi][xi]
	endfor

	//Cacluate ground elevation below the best fit flight box
	Wave ScreenPosXY_deg
	
	np = dimsize(ScreenPosXY_deg,0)
	
	make/o/n=(np) ScreenPosZ
	setscale/p x, 0, 1, ScreenPosZ
	
	for(i=0; i<np; i+=1)
		xi = (ScreenPosXY_deg[i][0] - DimOffset(ElevationArray_m,1))/DimDelta(ElevationArray_m,1)
		yi = (ScreenPosXY_deg[i][1] - DimOffset(ElevationArray_m,0))/DimDelta(ElevationArray_m,0)
		ScreenPosZ[i] = ElevationArray_m[yi][xi]
	endfor
  
End


Function MapPosition2Screens(flight, lat, lon, alt, dt)
	variable flight
	Wave lat, lon, alt, dt
	variable/g EarthR = 6.36313e+6 
	variable/g LatRef = 56.655, LonRef=-111.237 // Fort McMurray Airport

	variable i, np, n, s, ns, k
	variable z, d, dmin, smin
	variable t0, t1
	variable/g PercDone
	string folder, folderwave
	
	if (CmpStr(NameOfWave(lat), "Lat") != 0)
		Duplicate/O lat, root:Lat
	endif
	if (CmpStr(NameOfWave(lon), "Lon") != 0)
		Duplicate/O lon, root:Lon
	endif
	if (CmpStr(NameOfWave(alt), "Alt") != 0)
		Duplicate/O alt, root:Alt
	endif
	if (CmpStr(NameOfWave(dt), "timestamp") != 0)
		Duplicate/O dt, root:timestamp
	endif

	setdatafolder root:
	wave T_Takeoff, T_Landing
	Wave ID = FlightIDNum
//	wave/t BoxFlightList, BoxScreenName, BoxFlight

	killwaves/z PositionTime, PositionXYZz

	Variable ind = BinarySearch(ID, flight)

	t0 = T_Takeoff[ind]
	t1 = T_Landing[ind]

//	folder = "root:Flight" + BoxFlight[box-1]

//	setdatafolder $folder
	Wave GndElev

	np = numpnts(dt)

	make/d/o/n=(np) PositionTime
	SetScale/P x 0, 1, "dat", PositionTime
	SetScale d 0, 0, "dat", PositionTime
	make/o/n=(np,4) PositionXYZz = NaN  // lon[m], lat[m], Altitude[m], Elevation[m]

	n = 0
	for(i=0; i<np; i+=1)
		if(dt[i]>=t0 && dt[i]<t1)
			PositionTime[n] = dt[i]
			if(numtype(Lat[i])==0 && numtype(Lon[i])==0 && numtype(Alt[i])==0 && numtype(GndElev[i])==0)
				PositionXYZz[i][0] = EarthR*pi/180*(Lon[i]-LonRef)*cos(Lat[i]*pi/180)
				PositionXYZz[i][1] = EarthR*pi/180*(Lat[i]-LatRef)
				PositionXYZz[i][2] = Alt[i]
				PositionXYZz[i][3] = GndElev[i]
				n += 1
			endif
		endif
	endfor

//	deletepoints (n), (np-n), PositionTime, PositionXYZz
//	folderwave = folder + ":PositionTime"
//	movewave $folderwave, root:
//	folderwave = folder + ":PositionXYZz"
//	movewave $folderwave, root:

//	np = n // number of points in all Position waves

	setdatafolder root:

	//    folderwave = "ScreenPosXY_" + BoxScreenName[box-1] + "_F" + BoxFlight[box-1] + "_deg"
	//folderwave = "ScreenPosXY_F" + num2str(flight) + "_deg"
	//duplicate/o $folderwave, ScreenPosXY
	Wave ScreenPosXY_deg
	Duplicate/O ScreenPosXY_deg, ScreenPosXY
	ns = dimsize(ScreenPosXY,0) // number of points in Screen wave

	for(s=0; s<ns; s+=1)
		ScreenPosXY[s][0] = EarthR*pi/180*(ScreenPosXY_deg[s][0]-LonRef)*cos(ScreenPosXY_deg[s][1]*pi/180)
		ScreenPosXY[s][1] = EarthR*pi/180*(ScreenPosXY_deg[s][1]-LatRef)
	endfor

	make/o/n=(np,3) PositionSZ   //  s[m], z[m], dist[m]
	PositionSZ = nan
	
	Variable nthreads = ThreadProcessorCount
	Variable threadGroupID = ThreadGroupCreate(nthreads)

	for(i=0; i<np;)
		for (k = 0; k < nthreads; k += 1)
			ThreadStart threadGroupID, k, mapPoint(i, PositionXYZz, ScreenPosXY, PositionSZ, np, ns)
			i += 1
			
			if (i >= np)
				break
			endif
		
		endfor
		do
			Variable threadGroupStatus = ThreadGroupWait(threadGroupID, 100)
		while (threadGroupStatus != 0)
	endfor
	
	Variable dummy = ThreadGroupRelease(threadGroupID)


//	if(box<10)
//		folderwave = "PositionSZ_B0" + num2istr(box) + "_" + BoxFlightList[box-1]
//	else
//		folderwave = "PositionSZ_B" + num2istr(box) + "_" + BoxFlightList[box-1]
//	endif    
//	duplicate/o PositionSZ, $folderwave

//	killwaves/z ScreenPosXY, PositionTime, PositionXYZz, PositionSZ

	//  endfor

End

ThreadSafe Function mapPoint(i, PositionXYZz, ScreenPosXY, PositionSZ, np, ns)
	Variable i
	Wave PositionXYZz, ScreenPosXY, PositionSZ
	Variable np, ns
	Variable smin, s, d
	
	Variable PercDone = i/np*100
	Variable dmin = 9e99
	for(s=0; s<ns; s+=1)
		d = (PositionXYZz[i][0]-ScreenPosXY[s][0])*(PositionXYZz[i][0]-ScreenPosXY[s][0])
		d += (PositionXYZz[i][1]-ScreenPosXY[s][1])*(PositionXYZz[i][1]-ScreenPosXY[s][1])
		if(d<dmin)
			dmin = d
			smin = s
		endif
	endfor
	PositionSZ[i][0] = smin
	PositionSZ[i][1] = PositionXYZz[i][2]
	PositionSZ[i][2] = sqrt(dmin)	

End

//Set values of global variables for the flight box
Function Variables(flt)
	Variable flt//, height

	variable/g flight, lim
	variable/g delta, ns, nz
	wave ScreenPosZ

	flight = flt
	lim = 1000 // Position must be within 1000m of screen to count

	delta = 10 // Screen resolution [m] (Distance between points [m])
//	nz = height  // Height of screen [m]
	ns = numpnts(ScreenPosZ)  // Length of screen [m]
  
 	Variable ds, dz, range 
	ds = 40 // Horizontal Screen resolution [m]
	dz = 20 //Vertical screen resolution [m]
  
	range = 300 // Kriging range [m]

End

//Flag points that are part of the box
Function Flag(fltStr)
	String fltStr
	Wave dt = root:timestamp

	variable/g lim//, nz
	variable i, j, np, t0, t1
	wave PositionSZ
	
	Variable/G stIndex, endIndex

	np = dimsize(dt,0)
	make/o/t/n=(np) PositionFlag

	//Start and end time of the box
	t0 = dt[stIndex]
	t1 = dt[endIndex]
	  
	PositionFlag = ""
	for(i=0; i<np; i+=1)
	
		if(dt[i]>t0 && dt[i]<t1)							//if point is within box time
			if(PositionSZ[i][2]<lim) 						//if point is close enough to box
				PositionFlag[i] = fltStr
			endif
		endif
		
	endfor
	
	//Check if some time periods should be excluded
	if (exists("exc_st") != 0 && exists("exc_end") != 0)
		Wave exc_st, exc_end
		Variable stind, endind
		
		for (j = 0; j < dimSize(exc_st,0); j += 1)
			stind = BinarySearch (dt, exc_st[j])
			endind = BinarySearch (dt, exc_end[j])
		
			for (i = stind; i <= endind; i += 1)
				PositionFlag[i] = ""
			endfor
		endfor
	endif

End

Function Wind(fltStr, windSpd, windDir)
	String fltStr
	Wave windSpd, windDir
	
	if (CmpStr(NameOfWave(windSpd),"WindSpeed") != 0)
		Duplicate/O windSpd, root:WindSpeed
	endif
	if (CmpStr(NameOfWave(windDir),"WindDir") != 0)
		Duplicate/O windDir, root:WindDir
	endif

	// To go back:
	//   WDir = atan2(WE,WN)*180/pi - (abs(WE)/WE - 1)*180
	//   WS = sqrt(WN^2 + WE^2)

	variable i, np, nsz, z, zl
	variable/g flight, lim
	variable/g delta, ns, nz
	wave PositionSZ  // 2D array with 's' and 'z' coordinates listed by second
	wave/t PositionFlag
	wave ScreenPosZ  // 1D wave with elevation in 'z' listed by 's' coordinate

	np = numpnts(windSpd)
	nsz = dimsize(PositionSZ,0)

	make/o/n=(nsz,3) PositionSZWN=nan, PositionSZWE=nan

	for(i=0; i<np; i+=1)
		if(cmpstr(PositionFlag[i],fltStr)==0)
			PositionSZWN[i][0] = PositionSZ[i][0]
			PositionSZWN[i][1] = PositionSZ[i][1]
			PositionSZWN[i][2] = windSpd[i]*cos(windDir[i]*pi/180) // North Wind
			PositionSZWE[i][0] = PositionSZ[i][0]
			PositionSZWE[i][1] = PositionSZ[i][1]
			PositionSZWE[i][2] = windSpd[i]*sin(windDir[i]*pi/180) // East Wind
		endif
	endfor

End

//Get rid of the kriged data below the flight path and fill it with the wind profile fitting to the ground
Function FillWind(fNum)
	Variable fNum
	variable i, np, s, z, si, zi
	variable si_l, si_r, si_diff
	variable w, width, nans, zref, sref, d, f, ustar, uref, zsur
	variable/g ds, dz, ns, nz
	wave ScreenWindN, ScreenWindE
	//  wave ScreenWindNu, ScreenWindEu
	wave PositionSZWN, PositionSZWE
	wave ScreenPosZ

	width = 10  // Averaging width for connecting flight dots
	
	//Load wind profile fit parameters
	LoadWave/O/P=terra/A/J/D/W/K=0/L={0,1,0,0,0}/R={English,2,2,2,2,"Year-Month-DayOfMonth",40} "WindProfiles_2018.csv"
	Wave Flight_ID

	// Wind Profile fit parameters: U = u*/k ln(z - d) + f
	Wave fitd, fita
	d = fitd[fNum - 1]
	f = fita[fNum - 1]

	for(w=0; w<2; w+=1)

		// ** Removal of points below lowest flight height **
		make/o/n=(ns/ds,nz/dz) ScreenTemp=0

		if(w==0)
			duplicate/o PositionSZWN, PositionSZC
			duplicate/o ScreenWindN, ScreenTempu
		else
			duplicate/o PositionSZWE, PositionSZC
			duplicate/o ScreenWindE, ScreenTempu
		endif

		np = dimsize(PositionSZC,0)

		// Project the flight path onto a screen array 
		for(i=0; i<np; i+=1)
			si = floor(PositionSZC[i][0]/ds)
			zi = floor(PositionSZC[i][1]/dz)
			if(zi>0 && zi<floor(nz/dz))
				for(s=-width; s<=width; s+=1)
					if(si+s>=0 && si+s<floor(ns/ds))
						ScreenTemp[si+s][zi] = 1
					elseif(si+s<0)
						ScreenTemp[si+s+floor(ns/ds)][zi] = 1
					else
						ScreenTemp[si+s-floor(ns/ds)][zi] = 1
					endif
				endfor
			endif
		endfor
		
		//Check that each horizontal grid column has a row (z value) with the number 1 in ScreenTemp
		for(si=0; si<floor(ns/ds); si+=1)
			ScreenTemp[si][floor(nz/dz)-1] = 1
		endfor
  
		// Delete points up to the bottom of the screen array
		for(si=0; si<dimSize(ScreenTempu,0); si+=1)
			zi = 0
			do
				ScreenTempu[si][zi] = nan
				zi += 1
			while(ScreenTemp[si][zi]==0)
		endfor
  
		if(w==0)
			duplicate/o ScreenTempu, ScreenWindNu
		else
			duplicate/o ScreenTempu, ScreenWindEu
		endif

		killwaves/z PositionSZC, ScreenTemp, ScreenTempu

		// ** Filling of points at sides and below **
		if(w==0)
			duplicate/o ScreenWindNu, ScreenWindTemp
		else
			duplicate/o ScreenWindEu, ScreenWindTemp
		endif

		//Accounts for gaps at the beginning and end of the screen in the horizontal
		// Horizontal fill at Ends
		//  for(zi=0; zi<nz/dz; zi+=1)
		//    si_r = floor(ns/ds)-1
		//    do
		//      si_r -= 1
		//    while(numtype(ScreenWindTemp[si_r][zi])==2 && si_r>0)
		//    si_l = 0
		//    do
		//      si_l += 1
		//    while(numtype(ScreenWindTemp[si_l][zi])==2 && si_l<floor(ns/ds)-1)
		//    sref = (ScreenWindTemp[si_l][zi] + ScreenWindTemp[si_r][zi])/2
		//    si_diff = si_l + si_r-(floor(ns/ds)-1)
		//    if(si_diff<500)
		//      for(si=0; si<si_l; si+=1)
		//        ScreenWindTemp[si][zi] = sref
		//      endfor
		//      for(si=si_r; si<floor(ns/ds); si+=1)
		//        ScreenWindTemp[si][zi] = sref
		//      endfor
		//    endif
		//  endfor

		// Vertical Fill at Top and Bottom
		for(s=0; s<floor(ns/ds)*ds; s+=ds)
			si = floor(s/ds)
			if (si >= dimSize(ScreenWindTemp,0))
				break
			endif
			zsur = ScreenPosZ[s]

			// Find lowest data point
			zi = 0
			do
				uref = ScreenWindTemp[si][zi]
				zi += 1
			while(numtype(uref)!=0 && zi<nz/dz)
			zref = (zi+0.5)*dz - zsur
			ustar = (uref - f)*0.4/ln(zref-d)

			// Apply log-profile below lowest data 
			for(z=zsur+dz; z<zsur+zref+dz; z+=dz)
				zi = floor(z/dz)
				if (zi >= dimSize(ScreenWindTemp,1))
					break
				endif
				ScreenWindTemp[si][zi] = ustar/0.4*ln((z-zsur)-d) + f
			endfor

		endfor

		if(w==0)
			duplicate/o ScreenWindTemp, ScreenWindNf
		else
			duplicate/o ScreenWindTemp, ScreenWindEf
		endif

	endfor
  
	killwaves/z ScreenWindTemp
	
	//Plot Screens
	Wave ScreenPosZ = root:ScreenPosZ
	WaveStats/Q ScreenWindEf
	Display/W=(30,53,860.25,558.5) PositionSZWE[][1] vs PositionSZWE[][0]
	ModifyGraph mode=3,marker=19,msize=2,zColor(PositionSZWE)={PositionSZWE[*][2],V_min,V_max,Rainbow,1}
	AppendImage ScreenWindEf
	ModifyImage ScreenWindEf ctab= {*,*,Rainbow,1}
	AppendToGraph ScreenPosZ
	ModifyGraph mode(ScreenPosZ)=7,hbFill(ScreenPosZ)=2,rgb(ScreenPosZ)=(39321,39321,39321)
	ColorScale/C/N=text0/A=MC/X=-45.31/Y=-34.77 image=ScreenWindEf, heightPct=30
	ColorScale/C/N=text0 width=15
	
	WaveStats/Q ScreenWindNf
	Display/W=(30,53,860.25,558.5) PositionSZWN[][1] vs PositionSZWN[][0]
	ModifyGraph mode=3,marker=19,msize=2,zColor(PositionSZWN)={PositionSZWN[*][2],V_min,V_max,Rainbow,1}
	AppendImage ScreenWindNf
	ModifyImage ScreenWindNf ctab= {*,*,Rainbow,1}
	AppendToGraph ScreenPosZ
	ModifyGraph mode(ScreenPosZ)=7,hbFill(ScreenPosZ)=2,rgb(ScreenPosZ)=(39321,39321,39321)
	ColorScale/C/N=text0/A=MC/X=-45.31/Y=-34.77 image=ScreenWindNf, heightPct=30
	ColorScale/C/N=text0 width=15	
  
End

Function AirDensity(fltStr, StaticP, StaticT, DewPoint)
	String fltStr
	Wave StaticP, StaticT, DewPoint
	
	if (CmpStr(NameOfWave(StaticP),"StaticP") != 0)
		Duplicate/O StaticP, root:StaticP
	endif
	if (CmpStr(NameOfWave(StaticT),"StaticT") != 0)
		Duplicate/O StaticT, root:StaticT
	endif
	if (CmpStr(NameOfWave(DewPoint),"DewPoint") != 0)
		Duplicate/O DewPoint, root:DewPoint
	endif

	Wave timestamp
	variable i, np, nsz
	variable MR
	variable/g ns, nz
	wave PositionSZ  // 2D array with 's' and 'z' coordinates listed by second
	wave/t PositionFlag

	np = numpnts(timestamp)
	nsz = dimsize(PositionSZ,0)

	make/o/n=(nsz,3) PositionSZA=nan

	for(i=0; i<np; i+=1)
		if(cmpstr(PositionFlag[i],fltStr)==0)
			PositionSZA[i][0] = PositionSZ[i][0]
			PositionSZA[i][1] = PositionSZ[i][1]
			MR = 0.622*3.41e9/(StaticP[i]*100)*exp(-5420/(DewPoint[i]+273.13))
			PositionSZA[i][2] = StaticP[i]*100/(287.1*(1+0.6*MR)*(StaticT[i]+273.13)) // Density [kg/m3]
		endif
	endfor

End

Function FillAir()

	variable i, np, s, z, si, zi
	variable si_l, si_r, si_diff, sref
	variable width, nans, a, b, uref, zsur, zref
	variable/g ds, dz, ns, nz
	wave ScreenKrig
	//  wave ScreenAiru
	wave PositionSZA
	wave ScreenPosZ

	width = 10  // Averaging width for connecting flight dots

	// Air density profile fit parameters: rho = a + b z
	Wave W_coef
	a = W_coef[0]
	b = W_coef[1]

	// ** Removal of points below lowest flight height **
	make/o/n=(ns/ds,nz/dz) ScreenTemp=0

	duplicate/o ScreenKrig, ScreenTempu

	np = dimsize(PositionSZA,0)

	// Project the flight path onto a screen array 
	for(i=0; i<np; i+=1)
		si = floor(PositionSZA[i][0]/ds)
		zi = floor(PositionSZA[i][1]/dz)
		if(zi>0 && zi<floor(nz/dz))
			for(s=-width; s<=width; s+=1)
				if(si+s>=0 && si+s<floor(ns/ds))
					ScreenTemp[si+s][zi] = 1
				elseif(si+s<0)
					ScreenTemp[si+s+floor(ns/ds)][zi] = 1
				else
					ScreenTemp[si+s-floor(ns/ds)][zi] = 1
				endif
			endfor
		endif
	endfor

	// Delete points up to the bottom of the screen array
	for(si=0; si<dimSize(ScreenTempu,0); si+=1)
		zi = 0
		if (si >= dimSize(ScreenTemp,0))
			break
		endif
		do
			ScreenTempu[si][zi] = nan
			zi += 1
			if (zi >= dimSize(ScreenTemp,1))
				break
			endif
		while(ScreenTemp[si][zi]==0)
	endfor
  
	duplicate/o ScreenTempu, ScreenAiru

	killwaves/z ScreenTemp, ScreenTempu

	// ** Filling of points at sides and below **
	duplicate/o ScreenAiru, ScreenTemp

	// Horizontal fill at Ends
	//  for(zi=0; zi<nz/dz; zi+=1)
	//    si_r = floor(ns/ds)-1
	//    do
	//      si_r -= 1
	//    while(numtype(ScreenTemp[si_r][zi])==2 && si_r>0)
	//    si_l = 0
	//    do
	//      si_l += 1
	//    while(numtype(ScreenTemp[si_l][zi])==2 && si_l<floor(ns/ds)-1)
	//    sref = (ScreenTemp[si_l][zi] + ScreenTemp[si_r][zi])/2
	//    si_diff = si_l + si_r-(floor(ns/ds)-1)
	//    if(si_diff<500)
	//      for(si=0; si<si_l; si+=1)
	//        ScreenTemp[si][zi] = sref
	//      endfor
	//      for(si=si_r; si<floor(ns/ds); si+=1)
	//        ScreenTemp[si][zi] = sref
	//      endfor
	//    endif
	//  endfor

	// Vertical Fill at Top and Bottom
	for(s=0; s<floor(ns/ds)*ds; s+=ds)
		si = floor(s/ds)
		zsur = ScreenPosZ[s]

		// Find lowest data point
		zi = 0
		if (si >= dimSize(ScreenTemp,0))
			break
		endif
		do
			uref = ScreenTemp[si][zi]
			zi += 1
		while(numtype(uref)!=0 && zi<nz/dz)
		zref = zi*dz - zsur

		// Apply linear profile below lowest data 
		for(z=zsur+dz; z<zsur+zref+dz; z+=dz)
			zi = floor(z/dz)
			ScreenTemp[si][zi] = a + b*(floor(z/dz)+0.5)*dz
		endfor

	endfor

	duplicate/o ScreenTemp, ScreenAirf
  
	killwaves/z ScreenTemp
	
	//Plot Screen
	Wave ScreenPosZ = root:ScreenPosZ
	WaveStats/Q ScreenAirf
	Display/W=(30,53,860.25,558.5) PositionSZA[][1] vs PositionSZA[][0]
	ModifyGraph mode=3,marker=19,msize=2,zColor(PositionSZA)={PositionSZA[*][2],V_min,V_max,Rainbow,1}
	AppendImage ScreenAirf
	ModifyImage ScreenAirf ctab= {*,*,Rainbow,1}
	AppendToGraph ScreenPosZ
	ModifyGraph mode(ScreenPosZ)=7,hbFill(ScreenPosZ)=2,rgb(ScreenPosZ)=(39321,39321,39321)
	ColorScale/C/N=text0/A=MC/X=-45.31/Y=-34.77 image=ScreenAirf, heightPct=30
	ColorScale/C/N=text0 width=15		
  
End

Function FluxCalcSetup()

	variable/g ds, dz, Total
	variable s, nsi, z, nzi
	variable ux, uy, vx, vy, ws, zsur
	variable avg, rms, tot_in, tot_out
	wave ScreenWindNf, ScreenWindEf
	wave ScreenAirf
	wave ScreenPosXY, ScreenPosZ

	nsi = dimsize(ScreenWindNf,0)
	nzi = dimsize(ScreenWindNf,1)

	Total = 0

	make/o/n=(nsi,nzi) ScreenFlux
	make/o/n=(nsi) ScreenFlux_s
	make/o/n=(nzi) ScreenFlux_z, ScreenFlux_zc
	setscale/p x, 0, ds, ScreenFlux, ScreenFlux_s
	setscale/p y, 0, dz, ScreenFlux
	setscale/p x, 0, ds, ScreenFlux_z
	ScreenFlux_s = 0
	ScreenFlux_z = 0
	ScreenFlux_zc = 0

//	for(s=0; s<nsi-1; s+=1)
//		zsur = ScreenPosZ[s/2*ds]/dz
//		for(z=0; z<nzi; z+=1)
//			ws = sqrt(ScreenWindEf[s][z]^2 + ScreenWindNf[s][z]^2)
//			if(s==0 || s==nsi-1)
//				ux = (ScreenPosXY[5][0] - ScreenPosXY[nsi/2*ds-5][0]) // Lon Difference 
//				uy = (ScreenPosXY[5][1] - ScreenPosXY[nsi/2*ds-5][1]) // Lat Difference
//			else
//				ux = (ScreenPosXY[s/2*ds+5][0] - ScreenPosXY[s/2*ds-5][0]) // Lon Difference 
//				uy = (ScreenPosXY[s/2*ds+5][1] - ScreenPosXY[s/2*ds-5][1]) // Lat Difference
//			endif
//			vx = ScreenWindEf[s][z]/ws  // East Wind
//			vy = ScreenWindNf[s][z]/ws  // North Wind
//			ScreenFlux[s][z] = (ux*vy - uy*vx)/sqrt(ux*ux+uy*uy) // normal vector
//			ScreenFlux[s][z] *= ScreenAirf[s][z]                 // kg/m3
//			ScreenFlux[s][z] *= ws                               // kg/m2/s
//			if(numtype(ScreenFlux[s][z])==0)
//				ScreenFlux_s[s] += ScreenFlux[s][z]
//				ScreenFlux_z[floor(z-zsur)] += ScreenFlux[s][z]
//				ScreenFlux_zc[floor(z-zsur)] += 1
//				Total += (ScreenFlux[s][z]*ds*dz) // kg/s
//			endif
//		endfor
//	endfor

	for(s=0; s<nsi-1; s+=1)
		zsur = ScreenPosZ[s*ds]/dz
		for(z=0; z<nzi; z+=1)
			ws = sqrt(ScreenWindEf[s][z]^2 + ScreenWindNf[s][z]^2)
			if(s==0 || s==nsi-1)
				ux = (ScreenPosXY[5][0] - ScreenPosXY[nsi*ds-5][0]) // Lon Difference 
				uy = (ScreenPosXY[5][1] - ScreenPosXY[nsi*ds-5][1]) // Lat Difference
			else
				ux = (ScreenPosXY[s*ds+5][0] - ScreenPosXY[s*ds-5][0]) // Lon Difference 
				uy = (ScreenPosXY[s*ds+5][1] - ScreenPosXY[s*ds-5][1]) // Lat Difference
			endif
			vx = ScreenWindEf[s][z]/ws  // East Wind
			vy = ScreenWindNf[s][z]/ws  // North Wind
			ScreenFlux[s][z] = (ux*vy - uy*vx)/sqrt(ux*ux+uy*uy) // normal vector
			ScreenFlux[s][z] *= ScreenAirf[s][z]                 // kg/m3
			ScreenFlux[s][z] *= ws                               // kg/m2/s
			if(numtype(ScreenFlux[s][z])==0)
				ScreenFlux_s[s] += ScreenFlux[s][z]
				ScreenFlux_z[floor(z-zsur)] += ScreenFlux[s][z]
				ScreenFlux_zc[floor(z-zsur)] += 1
				Total += (ScreenFlux[s][z]*ds*dz) // kg/s
			endif
		endfor
	endfor

	ScreenFlux_s *= dz // kg/m/s
	ScreenFlux_z *= ds*abs(ScreenFlux_zc)/ScreenFlux_zc // kg/m/s

	print "Total emissions are ", Total*3600, " kg/hr = ", Total*3600*24/1000, "T/d"
  
	make/o/n=2 ScreenFlux_s_avg
	setscale/p x, 0, nsi*ds, ScreenFlux_s_avg
	avg = 0; rms = 0; tot_in = 0; tot_out = 0
	for(s=0; s<nsi; s+=1)
		avg += ScreenFlux_s[s]
		rms += ScreenFlux_s[s]^2
		if(ScreenFlux_s[s]<0)
			tot_in += -ScreenFlux_s[s]
		else
			tot_out += ScreenFlux_s[s]
		endif
	endfor
	ScreenFlux_s_avg[*] = avg/nsi
	print "Flux in = ", tot_in*ds, " kg/s"
	print "Flux out = ", tot_out*ds, " kg/s"
	print "Flux loss = ", (tot_in-tot_out)/tot_in*100, " %"
	print "Ratio of avg to rms = ", (avg/nsi)/sqrt(rms/nsi)*100, " %"

	tot_in = 0
	tot_out = 0
	for(s=0; s<nsi; s+=1)
		for(z=0; z<nzi; z+=1)
			if(numtype(ScreenFlux[s][z])==0)
				if(ScreenFlux[s][z]<0)
					tot_in += -ScreenFlux[s][z]
				else
					tot_out += ScreenFlux[s][z]
				endif
			endif
		endfor
	endfor
	print " "
	print "Flux in = ", tot_in*ds, " kg/s"
	print "Flux out = ", tot_out*ds, " kg/s"
	print "Flux loss = ", (tot_in-tot_out)/tot_in*100, " %"

End   

//Export the waves needed for TERRA to be run elsewhere
Function exportTERRAWaves(fltStr)
	String fltStr
	NVAR ns, nz, ds, dz
	
	Make/N=4/O varValues
	varValues[0] = ns
	varValues[1] = nz
	varValues[2] = ds
	varValues[3] = dz
	
	NVAR total
	Make/N=1/O totalAirF = total

	NewPath/O FltFolder
	Wave ScreenFlux, PositionSZA, ScreenAirf, ScreenPosXY, ScreenPosXY_deg, ScreenPosZ, ScreenWindEf, ScreenWindNf, fltGridPts, timestamp
	Wave Lat, Lon, Alt, WindSpeed, WindDir, StaticT, StaticP, DewPoint
	Save/P=FltFolder/O ScreenFlux as "ScreenAirFlux_" + fltStr + ".ibw"
	Save/P=FltFolder/O PositionSZA as "PositionSZA_" + fltStr + ".ibw" 
	Save/P=FltFolder/O ScreenAirf as "ScreenAirf_" + fltStr + ".ibw"
	Save/P=FltFolder/O ScreenPosXY as "ScreenPosXY_" + fltStr + ".ibw" 
	Save/P=FltFolder/O ScreenPosXY_deg as "ScreenPosXY_deg_" + fltStr + ".ibw" 
	Save/P=FltFolder/O ScreenPosZ as "ScreenPosZ_" + fltStr + ".ibw" 
	Save/P=FltFolder/O ScreenWindEf as "ScreenWindEf_" + fltStr + ".ibw" 
	Save/P=FltFolder/O ScreenWindNf as "ScreenWindNf_" + fltStr + ".ibw" 
	Save/P=FltFolder/O fltGridPts as "fltGridPts_" + fltStr + ".ibw" 
	Save/P=FltFolder/O Lat as "Lat_" + fltStr + ".ibw" 
	Save/P=FltFolder/O Lon as "Lon_" + fltStr + ".ibw" 
	Save/P=FltFolder/O Alt as "Alt_" + fltStr + ".ibw" 
	Save/P=FltFolder/O WindSpeed as "WindSpeed_" + fltStr + ".ibw" 
	Save/P=FltFolder/O WindDir as "WindDir_" + fltStr + ".ibw" 
	Save/P=FltFolder/O StaticT as "StaticT_" + fltStr + ".ibw" 
	Save/P=FltFolder/O StaticP as "StaticP_" + fltStr + ".ibw" 
	Save/P=FltFolder/O DewPoint as "DewPoint_" + fltStr + ".ibw" 
	Save/P=FltFolder/O varValues as "varValues_" + fltStr + ".ibw" 
	Save/P=FltFolder/O totalAirF as "totalAirF_" + fltStr + ".ibw" 
	Save/P=FltFolder/O timestamp as "timestamp_" + fltStr + ".ibw"
	
	if (exists("Frame") != 0)
		Wave Frame
		Save/P=FltFolder/O Frame as "Frame_" + fltStr + ".ibw" 
	endif

End
