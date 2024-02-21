#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Programs for converting dates to strings and changing timezones
//Created by Andrea Darlington (andrea.darlington@canada.ca)

//Get a date/time string from IGOR's seconds since 1904
Function/S date2str(dt)		
	Variable dt		//Seconds since Jan 1, 1904
	Variable dt1, dt2, days, count, yrday
	Variable second, minute, hour, leap, year, month, dayofmonth, dayofyear
	String secstr, minstr, hourstr, yearstr, monstr, daystr
	Variable janlen = 31
	Variable feblen = 28
	Variable marlen = 31
	Variable aprlen = 30
	Variable maylen = 31
	Variable junlen = 30
	Variable jullen = 31
	Variable auglen = 31
	Variable seplen = 30
	Variable octlen = 31
	Variable novlen = 30
	Variable declen = 31
	
	//Find number of seconds, minutes, hours and days
	second = round((dt/60 - trunc(dt/60))*60)
	minute = trunc(round(100*(dt/3600 - trunc(dt/3600))*60)/100)
	hour = trunc((dt/(3600*24) - trunc(dt/(3600*24)))*24 + 0.00001)
	days = trunc(dt/(3600*24)) + 1
	
	yrday = 365
	dt2 = 0
	count = -1
	
	if (second > 60)
		second = 0
		minute = minute + 1
	elseif (second == 60)
		second = 0
	endif
	if (minute >= 60)
		minute = 0
		hour = hour + 1
	endif
	if (hour >= 24)
		hour = 0
		days = days + 1
	endif
	
	//Calculate the year accounting for leap years
	do
		count = count + 1
		dt1 = dt2
		if (((count/4) - trunc(count/4)) == 0)
			dt2 = dt1 + yrday + 1
		else
			dt2 = dt1 + yrday
		endif
	while (dt2 < days)
	
	year = 1904 + count
	leap = year/4 - trunc(year/4)
	dayofyear = days - dt1
	
	if (leap == 0)
		feblen = 29
	endif
	
	//Find the day of the month
	if (dayofyear <= janlen)
		month = 1
		dayofmonth = dayofyear
	elseif (dayofyear <= janlen+feblen)
		month = 2
		dayofmonth = dayofyear - janlen
	elseif (dayofyear <= janlen+feblen+marlen)
		month = 3
		dayofmonth = dayofyear - janlen - feblen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen)
		month = 4
		dayofmonth = dayofyear - janlen - feblen - marlen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen)
		month = 5
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen)
		month = 6
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen)
		month = 7
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen)
		month = 8
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen+seplen)
		month = 9
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen+seplen+octlen)
		month = 10
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen - seplen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen+seplen+octlen+novlen)
		month = 11
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen - seplen - octlen
	else
		month = 12
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen - seplen - octlen - novlen
	endif	 
	
	//Convert values to strings
	yearstr = num2str(year)
	monstr = num2str(month)
	daystr = num2str(dayofmonth)
	hourstr = num2str(hour)
	minstr = num2str(minute)
	secstr = num2str(second)
	String join = "0" 
	
	//If numbers are single digit convert them so they display a 0 in front of the value (eg. 7 becomes 07)
	if (month < 10)
		monstr = join + monstr
	endif
	if (dayofmonth < 10)
		daystr = join + daystr
	endif
	if (hour < 10)
		hourstr = join + hourstr
	endif
	if (minute < 10)
		minstr = join + minstr
	endif
	if (second < 10) 
		secstr = join + secstr
	endif
	
	//Return date as a string that can be used in SQL
	String datestr = yearstr + "-" + monstr + "-" + daystr + " " + hourstr + ":" + minstr + ":" + secstr
	Return datestr
	
End

//Convert string date/time into IGOR seconds since Jan 1, 1904
Function str2date (dtStr, [type])			
	String dtStr				//String date/time
	String type				//Format for date/time string
	Variable year, month
	Variable igordat, daysinmon, leap, daysinyear, leapcount
	Variable i
	String temp
	Variable moncount = 1
	Variable yearcount = 0
	Variable daycount = 0
	Variable daycountyr = 0
	String var1, var2, var3, var4, var5, var0
	Variable yr, day, hour, minute, second
	String monStr
	
	if (ParamIsDefault(type) == 1)
		type = "YYYY-MM-DD HH:MM:SS"
	endif

	String scanStr = dateType (type)			//Get sscanf format
	sscanf dtStr, scanStr, var0, var1, var2, var3, var4, var5			//Put date items into temporary variables
	String curr = GetDataFolder(1) + "dtord"
//	print GetDataFolder(1)
	Wave dtord = $curr
	
	//If the user has not entered a time, assume midnight
	if (strlen(var3) == 0)
		var3 = "00"
		var4 = "00"
		var5 = "00"	
	//If the user has not entered a number of minutes, assume they want to start on the hour
	elseif (strlen(var4) == 0)
		var4 = "00"
		var5 = "00"
	//If the user has not entered a number of seconds, assume they want to start on the minute
	elseif (strlen(var5) == 0)
		var5 = "00"
	endif

	//Move date items into properly named variables according to the order found in dtord (created by dateType)
	Variable num = dimSize(dtord, 0)
	for (i = 0; i < num; i += 1)
		if (dtord[i] == 1)			//Year
			if (i == 0)
				yr = str2num(var0)
			elseif (i == 1)
				yr = str2num(var1)
			elseif (i == 2)
				yr = str2num(var2)
			elseif (i == 3)
				yr = str2num(var3)
			elseif (i == 4)
				yr = str2num(var4)
			else
				yr = str2num(var5)
			endif
		elseif (dtord[i] == 2)		//Month
			if (i == 0)
				monStr = var0
			elseif (i == 1)
				monStr = var1
			elseif (i == 2)
				monStr = var2
			elseif (i == 3)
				monStr = var3
			elseif (i == 4)
				monStr = var4
			else
				monStr = var5
			endif
		elseif (dtord[i] == 3)		//Day
			if (i == 0)
				day = str2num(var0)
			elseif (i == 1)
				day = str2num(var1)
			elseif (i == 2)
				day = str2num(var2)
			elseif (i == 3)
				day = str2num(var3)
			elseif (i == 4)
				day = str2num(var4)
			else
				day = str2num(var5)
			endif
		elseif (dtord[i] == 4)		//Hour
			if (i == 0)
				hour = str2num(var0)
			elseif (i == 1)
				hour = str2num(var1)
			elseif (i == 2)
				hour = str2num(var2)
			elseif (i == 3)
				hour = str2num(var3)
			elseif (i == 4)
				hour = str2num(var4)
			else
				hour = str2num(var5)
			endif
		elseif (dtord[i] == 5)		//Minute
			if (i == 0)
				minute = str2num(var0)
			elseif (i == 1)
				minute = str2num(var1)
			elseif (i == 2)
				minute = str2num(var2)
			elseif (i == 3)
				minute = str2num(var3)
			elseif (i == 4)
				minute = str2num(var4)
			else
				minute = str2num(var5)
			endif
		elseif (dtord[i] == 6)		//Second
			if (i == 0)
				second = str2num(var0)
			elseif (i == 1)
				second = str2num(var1)
			elseif (i == 2)
				second = str2num(var2)
			elseif (i == 3)
				second = str2num(var3)
			elseif (i == 4)
				second = str2num(var4)
			else
				second = str2num(var5)
			endif
		endif
	endfor
	
	//If month was entered as text, find month number
	//If month was already a number convert it from a string to a variable
	if (cmpStr(monStr, "JAN") == 0)
		month = 1
	elseif (cmpStr(monStr, "FEB") == 0)
		month = 2
	elseif (cmpStr(monStr, "MAR") == 0)
		month = 3
	elseif (cmpStr(monStr, "APR") == 0)
		month = 4
	elseif (cmpStr(monStr, "MAY") == 0)
		month = 5
	elseif (cmpStr(monStr, "JUN") == 0)
		month = 6
	elseif (cmpStr(monStr, "JUL") == 0)
		month = 7
	elseif (cmpStr(monStr, "AUG") == 0)
		month = 8
	elseif (cmpStr(monStr, "SEP") == 0)
		month = 9
	elseif (cmpStr(monStr, "OCT") == 0)
		month = 10
	elseif (cmpStr(monStr, "NOV") == 0)
		month = 11
	elseif (cmpStr(monStr, "DEC") == 0)
		month = 12
	else
		month = str2num(monStr)
	endif
	
	//Convert 2 digit year to 4 digit year if necessary
	if (yr < 100)
		year = yr + 2000
	else 
		year = yr
	endif
	//Find number of years since 1904
	leap = year - 1904
	
	//Compute the number of days between the beginning of the year and the beginning of the given month
	do
		if (month == 1)
			daysinmon = 0
		elseif (moncount == 2)		
			if ((leap/4 - trunc(leap/4)) == 0)
				daysinmon = 29
			else
				daysinmon = 28
			endif
		elseif (moncount == 4 || moncount == 6 || moncount == 9 || moncount == 11)
			daysinmon = 30
		else
			daysinmon = 31
		endif
		moncount = moncount + 1
		daycount = daycount + daysinmon
	while (moncount < month)
	
	//Compute the number of days between 1904 and the given year
	do
		if (leap == 0)
			daysinyear = 0
		elseif ((yearcount/4 - trunc(yearcount/4)) == 0)
			daysinyear = 366
		else
			daysinyear = 365
		endif
		yearcount = yearcount + 1
		daycountyr = daycountyr + daysinyear
	while (yearcount < leap)
	
	//Calculate date in seconds since 1904
	igordat = second + minute*60 + hour*3600 + (day-1)*24*3600 + daycount*24*3600 + daycountyr*24*3600
	KillWaves dtord
	return igordat
	
End

//Convert given time interval into seconds
Function str2interval (interStr)			
	String interStr
	String unit
	Variable num, numSec
	
	sscanf interStr, "%d %s", num, unit			//Read in input string
	
	if (cmpStr(unit, "days") == 0 || cmpStr(unit, "day") == 0)			//If unit is day
		numSec = num*24*3600
	elseif (cmpStr(unit, "hours") == 0 || cmpStr(unit, "hour") == 0)		//If unit is hour
		numSec = num*3600
	elseif (cmpStr(unit, "minutes") == 0 || cmpStr(unit, "minute") == 0)	//If unit is minute
		numSec = num*60
	elseif (cmpStr(unit, "seconds") == 0 || cmpStr(unit, "second") == 0)	//If unit is second
		numSec = num
	endif
	
	return numSec

End

//Get a date/time string from IGOR's seconds since 1904 formatted to Data Exchange Standard (DES)
Function/S date2strDES(dt)		
	Variable dt		//Seconds since Jan 1, 1904
	Variable dt1, dt2, days, count, yrday
	Variable second, minute, hour, leap, year, month, dayofmonth, dayofyear
	String secstr, minstr, hourstr, yearstr, monstr, daystr
	Variable janlen = 31
	Variable feblen = 28
	Variable marlen = 31
	Variable aprlen = 30
	Variable maylen = 31
	Variable junlen = 30
	Variable jullen = 31
	Variable auglen = 31
	Variable seplen = 30
	Variable octlen = 31
	Variable novlen = 30
	Variable declen = 31
	
	//Find number of days
	days = trunc(dt/(3600*24)) + 1
	
	yrday = 365
	dt2 = 0
	count = -1
	
	//Calculate the year accounting for leap years
	do
		count = count + 1
		dt1 = dt2
		if (((count/4) - trunc(count/4)) == 0)
			dt2 = dt1 + yrday + 1
		else
			dt2 = dt1 + yrday
		endif
	while (dt2 < days)
	
	year = 1904 + count
	leap = year/4 - trunc(year/4)
	dayofyear = days - dt1
	
	if (leap == 0)
		feblen = 29
	endif
	
	//Find the day of the month
	if (dayofyear <= janlen)
		month = 1
		dayofmonth = dayofyear
	elseif (dayofyear <= janlen+feblen)
		month = 2
		dayofmonth = dayofyear - janlen
	elseif (dayofyear <= janlen+feblen+marlen)
		month = 3
		dayofmonth = dayofyear - janlen - feblen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen)
		month = 4
		dayofmonth = dayofyear - janlen - feblen - marlen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen)
		month = 5
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen)
		month = 6
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen)
		month = 7
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen)
		month = 8
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen+seplen)
		month = 9
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen+seplen+octlen)
		month = 10
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen - seplen
	elseif (dayofyear <= janlen+feblen+marlen+aprlen+maylen+junlen+jullen+auglen+seplen+octlen+novlen)
		month = 11
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen - seplen - octlen
	else
		month = 12
		dayofmonth = dayofyear - janlen - feblen - marlen - aprlen - maylen - junlen - jullen - auglen - seplen - octlen - novlen
	endif	 
	
	//Convert values to strings
	yearstr = num2str(year)
	monstr = num2str(month)
	daystr = num2str(dayofmonth)
	String join = "0" 
	
	//If numbers are single digit convert them so they display a 0 in front of the value (eg. 7 becomes 07)
	if (month < 10)
		monstr = join + monstr
	endif
	if (dayofmonth < 10)
		daystr = join + daystr
	endif
	
	//Return date as a string that can be used in DES
	String datestr = yearstr + "-" + monstr + "-" + daystr
	Return datestr
	
End

//Determine input format of date to create a scan string for sscanf
Function/S dateType (format)		
	String format
	Variable yearloc, monloc, dayloc, hrloc, minloc, secloc
	Variable numyr, nummon, slash, colon, space, dash
	Variable diff = 0
	String outStr = ""
	String delimit
	Variable i
	Variable numoth = 2
	Variable loc = 0
	Variable count = 0
	Variable exit = 0
	
	//Make waves for delimiters and delimiter locations
	Make/O delimloc
	Make/O/T delimiter
	
	//Search for day, hour, minute and second locators in string
	dayloc = strsearch(format, "DD", 0)
	hrloc = strsearch(format, "HH", 0)
	minloc = strsearch(format, "MM", hrloc)
	secloc = strsearch(format, "SS", 0)

	//Search for 2 digit or 4 digit year
	yearloc = strsearch(format, "YYYY", 0)
	numyr = 4
	if (yearloc < 0)
		yearloc = strsearch(format, "YY", 0)
		numyr = 2
	endif
	
	//Search for 2 digit or 3 digit month
	if (yearloc < hrloc)
		monloc = strsearch(format, "MMM", 0)
		nummon = 3
		if (monloc < 0)
			monloc = strsearch(format, "MM", 0)
			nummon = 2
		endif
	else
		monloc = strsearch(format, "MMM", 0)
		nummon = 3
		if (monloc < 0)
			monloc = strsearch(format, "MM", secloc)
			nummon = 2
		endif
	endif
	
	//Order year, month, day, hour, minute, second by their appearance in the input string
	Make/O dtform = {yearloc, monloc, dayloc, hrloc, minloc, secloc}
	Make/O dtord = {1, 2, 3, 4, 5, 6}
	sort dtform, dtform, dtord
	
	//Search for delimiters and record their type and location
	do
		slash = strsearch(format, "/", loc)
		colon = strsearch(format, ":", loc)
		space = strsearch(format, " ", loc)
		dash = strsearch(format, "-", loc)
		
		if (slash < 0)
			slash = 100
		endif
		if (colon < 0)
			colon = 100
		endif
		if (space < 0)
			space = 100
		endif
		if (dash < 0)
			dash = 100
		endif
		
		if (slash == 100 && colon == 100 && space == 100 && dash == 100)
			exit = 1
		elseif (slash < colon && slash < space && slash < dash)
			delimloc[count] = slash
			delimiter[count] = "/"
		elseif (colon < space && colon < slash && colon < dash)
			delimloc[count] = colon
			delimiter[count] = ":"
		elseif (space < colon && space < slash && space < dash)
			delimloc[count] = space
			delimiter[count] = " "
		elseif (dash < slash && dash < colon && dash < space)
			delimloc[count] = dash
			delimiter[count] = "-"
		endif
		
		loc = delimloc[count] + 1
		count = count + 1
	while (exit == 0)
	
	count = 0
	
	//Create the string to be exported by adding on elements
	for (i = 0; i <= 5; i += 1)
		if (i != 5)
			diff = dtform[i+1] - dtform[i]
		else 
			diff = 0
		endif
		
		if (dtord[i] == 1)
			if (numyr == 2)
				outStr = outStr + "%2s"
			else
				outStr = outStr + "%4s"
			endif
			if (diff == 3 || diff == 5)
				delimit = delimiter [count]
				outStr = outStr + delimit
				count = count + 1
			endif
		elseif (dtord[i] == 2)
			if (nummon == 2)
				outStr = outStr + "%2s"
			else
				outStr = outStr + "%3s"
			endif
			if (diff == 4 || (diff == 3 && nummon == 2))
				delimit = delimiter [count]
				outStr = outStr + delimit
				count = count + 1
			endif
		else
			outStr = outStr + "%2s"
			if (diff > numoth)
				delimit = delimiter [count]
				outStr = outStr + delimit
				count = count + 1
			endif
		endif
	endfor
	
	KillWaves delimloc, delimiter, dtform
	return outStr

End

//Make sure date/time variable and data file are complete so missing values are visible in plots
Function DateTimeCorrect (dt, data, dtstart, dtend, interval)			
	Wave dt, data
	Variable dtstart, dtend, interval
	Variable predDate
	Variable count = 0
	Variable count2 = 0
	
	Variable dtdiff = dtend - dtstart
	Variable numInt = trunc(dtdiff/interval + 1)
	
	Make/D/O/N=(numInt) CompleteDate
	Make/O/N=(numInt) CompData
	
	do
		predDate = dtstart + interval*count						//Date should be one interval larger than the previous data
		
		if (count2 > (dimSize(dt, 0) -1) || count2 > (dimSize(data, 0) -1))		//If there is no more data in the original data wave data values become NaN
			CompleteDate[count] = predDate
			CompData[count] = NaN
		elseif (dt[count2] == predDate)										//If date is as predicted record data value in new data file
			CompleteDate[count] = dt[count2]
			CompData[count] = data[count2]
			count2 = count2 + 1
		else																//If date is not as predicted data value becomes NaN
			CompleteDate[count] = predDate
			CompData[count] = NaN
		endif
		
		count = count + 1
	while (count < numInt)

	SetScale d 0,0,"dat", CompleteDate						//Format date/time wave
	
	String name = NameofWave (data) + "_comp"
	String namedt = NameofWave (dt) + "_comp"
	Duplicate/O CompData $name								//Rename new data wave
	Duplicate/O CompleteDate $namedt
	
End

Function ButtonChTZ(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			ChangeTZGUI()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//User interface for changing time zones
Function ChangeTZGUI ()
	String timeWvStr, site, instrument, quantity, newTZStr, oldTZStr, format, quant, alttimeWv
	Variable delim, delim2, timeN, i
	
	//Choose timezone to change to
	String list = WaveList("*__datetime", ";", "TEXT:0")
	String userlist = ""
	
	if (strlen(list) == 0)
		Abort "No usable time waves exist."
	endif
	
	for (i = 0; i < ItemsInList(list); i += 1)
		quantity = StringFromList(i, list)
		delim = strsearch(quantity, "__", 0)
		delim2 = strsearch(quantity, "__", delim + 1)
		format = "%" + num2str(delim) + "s__%" + (num2str(delim2 - 2 - delim)) + "s__%s"
		sscanf quantity, format, site, instrument, quant
		userList = userList + site + ", " + instrument + ";"
	endfor
	
	String tzl = tzList()
	Prompt timeN, "Which dataset would you like to change the time zone of?", popup, userList
	Prompt newTZStr, "What time zone do you want to change the data to?", popup, tzl
	DoPrompt "Change Time Zone", timeN, newTZStr
	
	if (V_flag == 1)
		Abort
	endif 
	
	Variable newTZ = str2tz(newTZStr)
	timeWvStr = StringFromList(timeN - 1, list)
	Wave timeWv = $timeWvStr
	
	delim = strsearch(timeWvStr, "__", 0)			//Use wave names to get the instrument and station name
	delim2 = strsearch(timeWvStr, "__", delim + 1)
	format = "%" + num2str(delim) + "s__%" + (num2str(delim2 - 2 - delim)) + "s__%s"
	sscanf timeWvStr, format, site, instrument, quantity

	String tzNm = site + "__" + instrument + "__TimeZone"	//If timezone variable doesn't exist, get current timezone
	if (Exists(tzNm) == 0)
		Prompt oldTZStr, "What time zone is your data currently in?", popup, tzl
		DoPrompt "Time Zone", oldTZStr
		
		if (V_flag == 1)
			Abort
		endif 
		
		Variable oldTZ1 = str2tz(oldTZStr)
		ChangeTZ (oldTZ1, newTZ, timeWv)
		
		alttimeWv = site + "__" + instrument + "__pc_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ1, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__inst_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ1, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__start_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ1, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__end_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ1, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__dt_orig"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ1, newTZ, altTime)
		endif		
	else
		NVAR oldTZ2 = $tzNm
		ChangeTZ (oldTZ2, newTZ, timeWv)
		
		alttimeWv = site + "__" + instrument + "__pc_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ2, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__inst_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ2, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__start_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ2, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__end_dt"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ2, newTZ, altTime)
		endif
		alttimeWv = site + "__" + instrument + "__dt_orig"
		if (exists(alttimeWv) == 1)
			Wave altTime = $alttimeWv
			ChangeTZ (oldTZ2, newTZ, altTime)
		endif		
	endif
	
	Variable/G $tzNm = newTZ
	
End

//Convert between time zone name and numerical value
Function str2tz (tzStr)
	String tzStr
	Variable tz
	String format, tzShort, rest
	
	format = "%3s%s"
	sscanf tzStr, format, tzShort, rest
	
	if (CmpStr(tzShort, "PST") == 0)
		tz = -8
	elseif (CmpStr(tzShort, "PDT") == 0)
		tz = -7
	elseif (CmpStr(tzShort, "MST") == 0)
		tz = -7
	elseif (CmpStr(tzShort, "MDT") == 0)
		tz = -6
	elseif (CmpStr(tzShort, "CST") == 0)
		tz = -6
	elseif (CmpStr(tzShort, "CDT") == 0)
		tz = -5		
	elseif (CmpStr(tzShort, "EST") == 0)
		tz = -5
	elseif (CmpStr(tzShort, "EDT") == 0)
		tz = -4
	elseif (CmpStr(tzShort, "AST") == 0)
		tz = -4
	elseif (CmpStr(tzShort, "ADT") == 0)
		tz = -3	
	elseif (CmpStr(tzShort, "NST") == 0)
		tz = -3.5	
	elseif (CmpStr(tzShort, "NDT") == 0)
		tz = -2.5					
	elseif (CmpStr(tzShort, "GMT") == 0)
		tz = 0
	else
		Abort "Not a valid time zone."
	endif
	
	Return tz
	
End

//Convert between time zone numerical value and name
Function/S tz2str (tz)
	Variable tz
	String tzStr
	
	if (tz == -8)
		tzStr = "PST"
	elseif (tz == -7)
		tzStr = "MST"
	elseif (tz == -6)
		tzStr = "CST"
	elseif (tz == -5)
		tzStr = "EST"
	elseif (tz == -4)
		tzStr = "AST"
	elseif (tz == -3)
		tzStr = "ADT"
	elseif (tz == -3.5)
		tzStr = "NST"
	elseif (tz == -2.5)
		tzStr = "NDT"
	elseif (tz == 0)
		tzStr = "GMT"
	else
		Abort "Not a valid time zone."
	endif
	
	Return tzStr
	
End

//Change time zone for data
Function ChangeTZ (oldTZ, newTZ, timeWv)
	Variable oldTZ, newTZ
	Wave timeWv
	Variable i

	Variable num = dimSize(timeWv, 0)
	for (i = 0; i < num; i += 1)
		timeWv[i] = timeWv[i] - oldTZ*60*60					//Convert time to GMT
		timeWv[i] = timeWv[i] + newTZ*60*60				//Convert time to new time zone
	endfor

End


Function batchChangeTZ (newTZ)
	Variable newTZ
	Variable i, j, num2, delim, delim2
	String curr, format, tzNm, site, instrument, quantity
	
	String inst = WaveList("*__datetime", ";", "")
	Variable num = ItemsInList(inst)
	
	for (i = 0; i < num; i += 1)
		curr = StringFromList(i, inst)
		Wave timeWv = $curr
		num2 = dimSize(timeWv,0)
		delim = strsearch(curr, "__", 0)			//Use wave names to get the instrument and station name
		delim2 = strsearch(curr, "__", delim + 1)
		format = "%" + num2str(delim) + "s__%" + (num2str(delim2 - 2 - delim)) + "s__%s"
		sscanf curr, format, site, instrument, quantity

		tzNm = site + "__" + instrument + "__TimeZone"	//If timezone variable doesn't exist, get current timezone
		NVAR oldTZ = $tzNm
		ChangeTZ (oldTZ, newTZ, timeWv)
		oldTZ = newTZ
	endfor

End

//Adds time zone
Function addTZ (site, instrument)
	String site, instrument
	
	String tzNm = site + "__" + instrument + "__TimeZone"
	String tzStr = "GMT"
	String tzl = tzList()
	Prompt tzStr, "What time zone is your data in?", popup, tzl
	DoPrompt "Time Zone", tzStr
	
	if (V_flag == 1)
		Abort
	endif
	
	Variable/G $tzNm = str2tz(tzStr)

End

Function/S tzList()

	String tzl = "GMT;PST;PDT* (GMT -7 hours);MST;MDT* (GMT -6 hours);CST;CDT* (GMT - 5 hours);EST;EDT* (GMT -4 hours);AST;ADT* (GMT -3 hours);NST;NDT* (GMT -2.5 hours)"
	Return tzl

End

Function DST(timeStamp)
	Variable timeStamp

	Variable day,month,year,dayOfWeek,hours,minutes
	String date_=Secs2Date(timeStamp,-1)
	sscanf date_,"%d/%d/%d (%d)",day,month,year,dayOfWeek
	String time_=Secs2Time(timeStamp,2)
	sscanf time_,"%d:%d",hours,minutes
	switch(month)
		case 1:
		case 2:
			return 0
			break
		case 3:
			Variable minDay=dayOfWeek+7*1 // Second sunday.
			if(day>=minDay && (dayOfWeek!=1 || hours>=2))
				return 1
			else
				return 0
			endif
			break
		case 4:
		case 5:
		case 6:
		case 7:
		case 8:
		case 9:
		case 10:
			return 1
			break
		case 11:
			minDay=dayOfWeek+7*0 // First sunday.
			if(day>=minDay && (dayOfWeek!=1 || hours>=2))
				return 0
			else
				return 1
			endif
			break
			break
		case 12:
			return 0
			break
		default:
			print "No such month:"+num2str(month)
	endswitch
End