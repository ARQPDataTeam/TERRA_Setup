#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "KrigData" 

Function getAllAreas()
	Variable i, A
	String item, corn, fnum
	
	String list = WaveList("Corner_F*", ";", "")
	Variable num = ItemsinList(list)
	Make/D/N=(num)/O boxAreas
	Make/T/N=(num)/O boxNames
	String format = "%7s%s"

	for (i = 0; i < num; i += 1)
		item = StringFromList(i, list)
		Deg2Meters($item)
		Wave Fit_m
		sscanf item, format, corn, fnum
		Duplicate/O Fit_m, $("Corner_m_" + fnum)
		A = calcArea($("Corner_m_" + fnum))
		boxAreas[i] = A
		boxNames[i] = fnum
	endfor
		
End

Function calcArea(Corner_m)
	Wave Corner_m
	Variable i
	Variable num = dimSize(Corner_m,0)
	Variable A, Atot
	Variable xtemp, ytemp
	
	if (num == 4)
		xtemp = Corner_m[2][0]
		ytemp = Corner_m[2][1]
		Corner_m[2][0] = Corner_m[3][0]
		Corner_m[2][1] = Corner_m[3][1]
		Corner_m[3][0] = xtemp
		Corner_m[3][1] = ytemp
	else
		xtemp = Corner_m[3][0]
		ytemp = Corner_m[3][1]
		Corner_m[3][0] = Corner_m[4][0]
		Corner_m[3][1] = Corner_m[4][1]
		Corner_m[4][0] = xtemp
		Corner_m[4][1] = ytemp
	endif
	
	for (i = 0; i < num; i += 1)
		if (i >= num -1) 
			A = (Corner_m[i][1] + Corner_m[0][1])/2*(Corner_m[i][0] - Corner_m[0][0])
		else
			A = (Corner_m[i][1] + Corner_m[i+1][1])/2*(Corner_m[i][0] - Corner_m[i+1][0])		//77819.68219
		endif
		Atot = Atot + A
	endfor

	return Atot

End

function Deg2Meters(C)
  Wave C
  variable i, np
  variable/g EarthR = 6.36313e+6 // From \Flight12_Aug24\EarthRadius.pxp
  variable/g LatRef = 56.655, LonRef=-111.237 // Fort McMurray Airport
  variable dx, dy
  
  np = dimsize(C,0)
  
  make/d/o/n=(np,2) Fit_m=nan
  make/d/o/n=(np) Dist=nan
  
  for(i=0; i<np; i+=1)
    Fit_m[i][1] = (C[i][0]-LatRef)*EarthR*pi/180
    Fit_m[i][0] = (C[i][1]-LonRef)*EarthR*pi*cos(C[i][0]*pi/180)/180
//    lat = (180*ScreenPosXY_Suncor1[i][1])/(EarthR*pi) + LatRef
//    lon = (180*ScreenPosXY_Suncor1[i][0])/(EarthR*pi*cos(lat*pi/180)) + LonRef
  endfor

  for(i=1; i<np; i+=1)
    Dist[i] = sqrt((Fit_m[i][0]-Fit_m[i-1][0])^2 + (Fit_m[i][1]-Fit_m[i-1][1])^2)
  endfor

end

Function calcEairm ()
	Wave/T boxList, boxNames
	Wave boxStart, boxEnd
	Wave boxAreas
	Variable i, j, k, l, startt, endt, startTemp, endTemp, startP, endP, Ar, zdiff
	Wave aVals, bVals, nzVals, zminVals
	Wave PresS, PresE
//	Variable TK = 273.14
	Wave TempE, TempS
	
	Variable num = dimSize(boxList,0)
	Make/O/D/N=(num) Eairm
	
	for (i = 0; i < num; i += 1)
	
		endt = boxEnd[i]
		startt = boxStart[i]
		
		startTemp = TempS[i]
		endTemp = TempE[i]
		startP = PresS[i]
		endP = PresE[i]

		for (l = 0; l < dimSize(boxNames,0); l += 1)
			if (CmpStr(boxNames[l], boxList[i]) == 0)
				Ar = boxAreas[l]
			endif
		endfor
		
		zdiff = nzVals[i] - zminVals[i]
		Eairm[i] = Ar/(endt/3600 - startt/3600)*((endP - startP)/((endP + startP)*0.5) - (endTemp - startTemp)/((endTemp + startTemp)*0.5))*(aVals[i]*zdiff + 0.5*bVals[i]*zdiff^2)

	endfor

End

Function loadAirPosW ()
	Wave/T boxList
	Variable i
	String item
	
	Variable num = dimSize(boxList,0)
	
	NewPath/O/Q OS "\\\\sdow04rdaqrd1\\OS_Archive\\Level_1_INTERIM\\AIRCRAFT\\Flight_Screen_Variables"
	
	for (i = 0; i < num; i += 1)
		item = boxList[i]
		LoadWave/H/O/Q/P=OS (":" + item + ":PositionSZA_" + item + ".ibw")
		Wave PositionSZA
		Duplicate/O PositionSZA, $("PositionSZA_" + item)
	endfor

End

Function loadnzW ()
	Wave/T boxList
	Variable i
	String item
	
	Variable num = dimSize(boxList,0)
	Make/O/D/N=(num) nzVals
	
	NewPath/O/Q OS "\\\\sdow04rdaqrd1\\OS_Archive\\Level_1_INTERIM\\AIRCRAFT\\Flight_Screen_Variables"
	
	for (i = 0; i < num - 5; i += 1)
		item = boxList[i]
		LoadWave/H/O/Q/P=OS (":" + item + ":varValues_" + item + ".ibw")
		Wave varValues
		nzVals[i] = varValues[1]
	endfor

End

Function loadScreens ()
	Wave/T boxList
	Variable i
	String item
	
	Variable num = dimSize(boxList,0)
	
	NewPath/O/Q OS "\\\\sdow04rdaqrd1\\OS_Archive\\Level_1_INTERIM\\AIRCRAFT\\Flight_Screen_Variables"
	
	for (i = 0; i < num; i += 1)
		item = boxList[i]
		LoadWave/H/O/Q/P=OS (":" + item + ":ScreenAirf_" + item + ".ibw")
		Wave ScreenAirf
		Duplicate ScreenAirf, $("ScreenAirf_" + item)
	endfor

End

Function fitAirDensity()
	Wave/T boxList
	Variable i
	String item
	
	Variable num = dimSize(boxList,0)
	Make/O/D/N=(num) aVals, bVals, zminVals
	
	for (i = 0; i < num; i += 1)
		item = boxList[i]
		Wave PositionSZA = $("PositionSZA_" + item)
//		Display PositionSZA[][2] vs PositionSZA[][1]
		CurveFit/W=0 line, PositionSZA[*][2]/X=PositionSZA[*][1]
		Wave W_coef
		aVals[i] = W_coef[0]
		bVals[i] = W_coef[1]
		Duplicate/O/R=(0,dimSize(PositionSZA,0))(1,1) PositionSZA, ztest
		zminVals[i] = wavemin(ztest)
	endfor
	
End

Function calcECm2 ()
	Wave/T boxList, fltNum, boxNames
	Wave Start__GMT_, Stop__GMT_, DatetimeSt, DatetimeEnd
	Wave avgT, boxAreas
	Variable z, s, j, k, l, startt, endt, startTemp, endTemp, startP, endP, Ar, zdiff, rho, avgC, integral, n
	Wave aVals, bVals, nzVals, zminVals
	Variable i = 2
	Variable dz = 20
	Variable ratioP = 1.000208
	Variable TK = 273.14
	Wave ScreenAirf
	Wave ScreenF
	
	Variable ns = dimsize(ScreenAirf,0)
	Variable nz = dimsize(ScreenAirf,1)
	Variable ECm
	
	for (j = 0; j < dimSize(fltNum,0); j += 1)
		if (CmpStr(fltNum[j], boxList[i]) == 0)
			startt = Start__GMT_[j]
			endt = Stop__GMT_[j]
		endif
	endfor
	
	for (k = 0; k < dimSize(DatetimeSt,0); k += 1)
		if (startt >= DatetimeSt[k] && startt <= DatetimeEnd[k])
			startTemp = avgT[k] + TK
		elseif (endt >= DatetimeSt[k] && endt <= DatetimeEnd[k])
			endTemp = avgT[k] + TK
		endif
	endfor

	for (l = 0; l < dimSize(boxNames,0); l += 1)
		if (CmpStr(boxNames[l], boxList[i]) == 0)
			Ar = boxAreas[l]
		endif
	endfor
	
	for (z = 0; z < nz; z += 1)
		rho = 0
		avgC = 0
		 n = 0
		 for (s = 0; s < ns; s += 1)
		 	if (numtype(ScreenAirf[s][z]) == 0 && numtype(ScreenF[s][z]) == 0)
		 		rho = rho + ScreenAirf[s][z]
		 		avgC = avgC + ScreenF[s][z]*10^(-9)
		 		n = n + 1
		 	endif
		 endfor
		 
		 if (n > 0)
		 	rho = rho/n
		 	avgC = avgC/n
		 	integral = integral + avgC*rho*dz
		 endif
	endfor
	print startTemp, endTemp
	ECm = Ar/(endt/3600 - startt/3600)*64.07/28.97*integral*(startTemp/endTemp*ratioP - 1)

End

Function exportMassEmisWvs ()
	Wave/T boxList
	Wave PresE, PresS, TempS, TempE, boxAreas
	Variable i
	String item
	Wave Eairm
	
	Variable num = dimSize(boxList,0)
	
	for (i = 0; i < num; i += 1)
		item = boxList[i]
		Make/O/N=5 massInfo
		massInfo[0] = TempS[i]
		massInfo[1] = TempE[i]
		massInfo[2] = boxAreas[i]
		massInfo[3] = PresS[i]
		massInfo[4] = PresE[i]
		Save/C massInfo as "massInfo.ibw"
		
		Make/D/N=1/O totalAirFM
		totalAirFM = Eairm[i]
		Save/C totalAirFM as "totalAirFM.ibw"
	endfor

End

Function calcEllipseArea()
	Wave axis1, axis2
	Variable i
	
	Make/D/N=5 ellipseArea
	for (i = 0; i < 5; i += 1)
		ellipseArea[i] = axis1[i]*axis2[i]*pi
	endfor

End

Function exportEairM()
	Wave Eairm
	Variable i

	for (i = 0; i < dimSize(Eairm,0); i += 1)
		Make/D/N=1/O totalAirFM
		totalAirFM = Eairm[i]
		Save/C totalAirFM as "totalAirFM.ibw"
	endfor

End