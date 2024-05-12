/////////////////////////////////////////////////////////////
//
// Description :
// -------------
//    Generate raw text files from ACSM acquisition software
//
// Copyright (©) 2022:
// -------------------
//     Commissariat à l'énergie atomique et aux énergies alternatives (CEA) ;
//     Centre national de la recherche scientifique (CNRS)
// 
// Author(s) :
// --------
//     CEA/LSCE Jean-Eudes Petit, jean-hyphen-eudes-dot-petit-at-lsce-dot-ipsl-dot-fr
//
// License :
// -------------
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU Affero General Public License as published
//    by the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU Affero General Public License for more details.
//
//    You should have received a copy of the GNU Affero General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
//
// History :
// ---------
//   v4.0.2 : 2022/06/29
//     - first official release
//
//   v4.1 : 2022/07/27
//     - bug correction on PMF input generation
//   v4.2 : 
//     - SoFi RT
//   v4.2.2 : 
//     - CE export (forgot to do it before)
//     - check box variable bug (PMF & SoFi)
//     - correctly naming RT SoFi files (with station name & SN)
//     - extract org m/z only for SoFi
//   v4.2.3 : 
//     - check for airbeam & RIT corrections before starting background task
//   v4.3: 
//     - Pump & Dryer data active
//     - error : quadratic sum replaced by regular sum
//     - added a check for wrong SN
//     - added max mz for org mx
//     - added checking rate variable
//   v4.3.1: 
//     - mz28 in OrgMx for SoFi (forgotten before)
//   v4.3.2: 
//     - CDCE correction for Orgmx (forgot to do it for SoFi, when a file already exists)
//   v4.3.3: 
//     - check fragtable version in order to export the right org mx for PMF
//   v4.3.4: 
//     - corrected bugs from ExportSoFi
//   v4.3.5: 
//     - corrected bugs from ExportSoFi. Compatibility with Igor7
//     - Changed names of 2 functions for dryer data, for AASQA procedure compatibility
//   v4.3.6: 
//     - check for mzbool (sometimes the wave is not saved at the right place, when the acquisition is running)
//    v4.3.7: 
//     - simulate export from previous data.
//    v4.3.8: 
//     - enabled pump data loading & exporting
//     - enabled dryer data loading & exporting
//     - NoteBook
//     - if CEdry=NaN, replaced by 0.5
//    v4.3.9: 
//     - Save Configuration in textfile
//     - Load Configuration from textfile
/////////////////////////////////////////////////////////////

#pragma rtGlobals=1		// Use modern global access method and strict wave access.
#pragma version=4.3

StrConstant ACMCC_Export_version="4.3.9"

///////////////// MENU ////////////////////////////////////////

Menu "ACMCC Q-ACSM Export"
	"Initialize Export",/q,ACMCC_Export_Initialize()
	"Rebuild Panel",/q,ACMCC_Export_Panel()
	"Start",/q,ACMCC_StartTask()
	"Stop",/q,ACMCC_StopTask()
	"Recreate All Files",/q,ACMCC_RecreateAllFiles()
	"Kill NoteBook",/q,ACMCC_KillNoteBook()
	"Update ipf",/q,ACMCC_UpdateIpf()
	"Save Configuration",/q,ACMCC_SaveConfig()
	"Load Configuration from File",/q, ACMCC_Load_Config()
End

///////////////// END OF MENU ////////////////////////////////////////


///////////////// BACKGROUND TASKS ////////////////////////////////////////

 // This is the function that will be called periodically
Function ACMCC_Task(s)   
	STRUCT WMBackgroundStruct &s
	
	NVAR Number=root:ACMCC_Export:Number
	wave/T ToF_QuadW=root:ACMCC_Export:ToF_QuadW
	if(stringmatch(ToF_QuadW[0],"UMR ToF"))
		wave ACSM_time=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
		duplicate/O ACSM_time, root:ACMCC_Export:temp
		SetDataFolder root:ACMCC_Export:
		wave temp
		waveTransform zapnans, temp
		variable result=numpnts(temp)-1
	
		if (Number<result)
			Number=result
			ACMCC_ToF_TriggeredExport()	//Export for ToF
		endif
	elseif(stringmatch(ToF_QuadW[0],"UMR Quad"))
		wave ACSM_time=root:ACSM_Incoming:acsm_utc_time
		if (Number<numpnts(ACSM_time))
			Number=numpnts(ACSM_time)
			ACMCC_Quad_TriggeredExport()	// Export for Quad
		endif
	
	endif
	
	NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
	NVAR/Z Counts=root:ACMCC_Export:Counts
	Counts=RefreshRate
	
	return 0
End

Function ACMCC_StartTask()
	
	NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
	NVAR/Z Counts=root:ACMCC_Export:Counts
	Variable numTicks = RefreshRate*60	//1 tick=1/60 s
	CtrlNamedBackground Test, period=numTicks, proc=ACMCC_Task
	CtrlNamedBackground Test, start
	
	NVAR/Z StartStop_bool=root:ACMCC_Export:StartStop_bool
	StartStop_bool=1
	Button RunButton,title="STOP",size={355,40},fSize=20,fstyle=1,fColor=(65280,16384,16384),proc=LaunchExport,font="Arial",disable=0
	
	CtrlNamedBackground Counting,period=60,proc=ACMCC_Counting
	CtrlNamedBackground Counting, start
	
	UpdateNoteBook("Starting Export")
	
End


Function ACMCC_Counting(s)   
	STRUCT WMBackgroundStruct &s
	NVAR/Z Counts=root:ACMCC_Export:Counts
	NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
	
	Counts-=1
	
	return 0
End Function

Function ACMCC_StopTask()
	CtrlNamedBackground Test, stop
	
	NVAR/Z StartStop_bool=root:ACMCC_Export:StartStop_bool
	StartStop_bool=0
	Button RunButton,title="START",size={355,40},fSize=20,fstyle=1,fColor=(26112,52224,0),proc=LaunchExport,font="Arial",disable=0
	
	CtrlNamedBackground Counting, stop
	NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
	NVAR/Z Counts=root:ACMCC_Export:Counts
	Counts=Refreshrate
	
	UpdateNoteBook("Stopping Export")
	
End

Function ACMCC_Export_Initialize()
	NewDataFolder/O/S root:ACMCC_Export
	Variable/G Number
	//String/G ListOfStations="SIRTA;PuydeDome;Barcelona;Athens;Melpitz;Hyytiala;Kosetice;Other"
	String/G ListOfStations="AthensNOA;AthensDEM;ATOLL;Birkenes;Bologna;Cabauw;CAO;CeSMA;CIAO;Granada;HelsinkiSupersite;Hohenpeissenberg;Hylemossa;Hyytiälä;JFJ;Košetice;KuopioPiojo;Magurele;Manchester;Marseille;Melpitz;MonteCimone;Montseny;PalauReial;ParisBpEst;ParisChatelet;Payerne;PuydeDome;SIRTA;Taunus;UCD;Villum;Zeppelin;Other"
	String/G ToF_Quad_Str="UMR Quad;UMR ToF"
	String/G Lens_Str="PM1 Lens;PM2.5 Lens"
	String/G Vaporizer_Str="Standard Vap.;Capture Vap."
	String/G NextCloud_path="C:Users:acsm:Nextcloud:"
	String/G DryerStat_path="C:ACSM:DryerStats:"
	String/G Pump_path="C:ACSM:PumpData:"
	String/G SN_str=""
	Variable/G StartStop_bool=0
	Variable/G GeneratePMFInput=1
	Variable/G GenerateSoFi=1
	String/G Script_path=""
	Variable/G ApplyMiddlebrook=0
	Variable/G RefreshRate=120
	Variable/G Counts=0
	Variable/G MaxMz=0
	String/G Maxmz_Str="100;120"
	Variable/G DryerBool=0
	Variable/G PumpBool=0
	String/G FragTableVersion=""
	String/G PumpDataFilePrefix="ACSMPumpData_"
	
	Make/N=1/O/T StationNameW,ToF_QuadW,LensW,VaporizerW
	
	NextCloud_path="C:Users:acsm:Nextcloud:"
	ToF_QuadW[0]="UMR Quad"
	wave DAQ=root:ACSM_Incoming:DAQ_Matrix
	string temp_str
	sprintf temp_str, "%6d",DAQ[0][74]
	SN_str=temp_str
	//SN_str=num2str(DAQ[0][74])
	if (stringmatch(SN_str,"0"))
		string SN
		prompt SN, "please enter the serial number of the instrument"
		doprompt "Warning", SN
		SN_str=SN
	endif
	
	//Config waves
	String/G Config_str="Station;Lens;Vaporizer;DryerBool;DryerPath;PumpBool;PumpFilePrefix;PumpPath;CDCE;PMFBool;SoFiBool;MaxMz;SaveFolder"
	Make/T/O/N=(ItemsInList(Config_str, ";")) ConfigW_txt
	ConfigW_txt = StringFromList(p, Config_str, ";")
	Make/T/O/N=(ItemsInList(Config_str, ";")) ConfigW_val
	ConfigW_val={"select","select","select","0",DryerStat_path,"0","select",Pump_path,"0",num2str(GeneratePMFInput),num2str(GenerateSoFi),"select",NextCloud_path}
	
	
	//Checking FragmentationTable version
	SetDataFolder root:frag
	if(waveexists(frag_organic)==1)
		wave/T frag_organic
		if(stringmatch(frag_organic[17],"1*frag_organic[44]") && stringmatch(frag_organic[27],""))
			FragTableVersion="V1"
			DoAlert/T="Just to let you know" 0, "You are using frag table V1 (Allan et al., JAS, 2004). Org_18=Org_44 & Org_28=0"
		endif
		if(stringmatch(frag_organic[17],"0.225*frag_organic[44]") && stringmatch(frag_organic[27],"1*frag_organic[44]"))
			FragTableVersion="V2"
			DoAlert/T="Just to let you know" 0, "You are using frag table V2 (Aiken et al., EST 2008). Org_18=0.225*Org_44 & Org_28=Org_44"
		endif
	else
		if(waveexists(frag_org)==1)
			FragTableVersion="V3"
			DoAlert/T="Just to let you know" 0, "You are using frag table V3. Org_28=Org_44, Org_18=0.225*Org_44"
		endif
	endif
	SetDataFolder root:ACMCC_Export
	
	ACMCC_Export_Panel()
	
End Function

///////////////// END OF BACKGROUND TASKS ////////////////////////////////////////


///////////////// PANEL FUNCTIONS ////////////////////////////////////////

Function ACMCC_Export_Panel()
	dowindow ExportPanel
	if(V_flag==1)
		killwindow ExportPanel
	endif
	
	newpanel/N=ExportPanel/W=(200,10,605,480)/K=1
	modifypanel fixedSize = 1
	
	SetDrawEnv fsize= 30,fstyle= 0,textrgb= (8704,8704,8704)
	DrawText 25,45,"Q-ACSM Export Tool v"+ACMCC_Export_version
	
	GroupBox InstrumentGB,pos={2,45},size={395,110},title="\\f01I/ Instrument Information",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"

		PopupMenu PM_Station, fSize=14, pos={6,70}, size={100,20}, value = "select;"+InputLists("Station"), title="\f01Station Name", proc = StationInput_proc, disable = 0, win=ExportPanel,fstyle=1,font="Arial"	
		wave/T ToF_QuadW=root:ACMCC_Export:ToF_QuadW
		SetVariable PM_Spectro, fSize=14, pos={200,70}, size={180,20}, value = ToF_QuadW[0], title="\f01Spectrometer", disable = 0, win=ExportPanel,fstyle=0,font="Arial",noedit=1

		SVAR/Z SN_str=root:ACMCC_Export:SN_str
		SetVariable Set_SN, fSize=10, pos={230,95}, size={150,20}, value = SN_str, title="\f02Serial Number", win=ExportPanel,fstyle=2,font="Arial"

		if (stringmatch(ToF_QuadW[0],"UMR Quad"))
			SetVariable Set_SN, noedit=1
		elseif (stringmatch(ToF_QuadW[0],"UMR ToF"))
			SetVariable Set_SN, noedit=0
		endif
	
		PopupMenu PM_Lens, fSize=14, pos={6,127}, size={100,20}, value = "select;"+InputLists("Lens"), title="\f01Lens", proc = LensInput_proc, disable = 0, win=ExportPanel,fstyle=1,font="Arial"
		PopupMenu PM_Vap, fSize=14, pos={200,127}, size={100,20}, value = "select;"+InputLists("Vaporizer"), title="\f01Vaporizer", proc = VapInput_proc, disable = 0, win=ExportPanel,fstyle=1,font="Arial"
	
	GroupBox ExternalDataGB,pos={2,155},size={395,80},title="\\f01II/ External Data",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"
	
		NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
		NVAR/Z PumpBool=root:ACMCC_Export:PumpBool
		CheckBox DryerBox, fSize=14, pos={5,180},title="", variable=DryerBool, font="Arial",disable=0, proc=Dryerproc
		CheckBox PumpBox, fSize=14, pos={5,210},title="", variable=PumpBool, font="Arial",disable=0, proc=Pumpproc
	
		String/G DryerStat_path="C:ACSM:DryerStats:"
		String/G Pump_path="C:ACSM:PumpData:"	
		SVAR/Z DryerStat_path=root:ACMCC_Export:DryerStat_path
		SVAR/Z Pump_path=root:ACMCC_Export:Pump_path
		SetVariable Set_DryerPath,title="Dryer Data Folder",pos={30,177},size={293,20},value=DryerStat_path,fSize=12,noedit=1,font="Arial", disable=-2*DryerBool+2
		Button Set_DryerPath_button,title="\\f01SET",pos={336,177},size={50,20},fSize=14,fColor=(39168,39168,39168),font="Arial", proc=SetDryerPath_proc, disable=-2*DryerBool+2
		SetVariable Set_PumpPath,title="Pump Data Folder",pos={30,207},size={293,20},value=Pump_path,fSize=12,noedit=1,font="Arial", disable=-2*PumpBool+2
		Button Set_PumpPath_button,title="\\f01SET",pos={336,207},size={50,20},fSize=14,fColor=(39168,39168,39168),font="Arial", proc=SetPumpPath_proc, disable=-2*PumpBool+2
	
	GroupBox CorrectionsGB,pos={2,240},size={395,50},title="\\f01III/ Corrections",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"

		NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
		CheckBox UseMiddlebrook_CB, title="Use Composition dependant CE", pos={10,265},font="Arial", fsize=14,variable=ApplyMiddlebrook,disable=0,proc=CDCE_proc


	GroupBox PMFGB,pos={2,295},size={395,80},title="\\f01IV/ PMF input",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"

		NVAR/Z GeneratePMFInput=root:ACMCC_Export:GeneratePMFInput
		CheckBox PMFBox, fSize=14, pos={20,315},title="Generate PMF Input ?", variable=GeneratePMFInput, font="Arial",disable=0, proc=PMFgen_proc
	
		NVAR/Z GenerateSoFi=root:ACMCC_Export:GenerateSoFi
		CheckBox SoFiBox, fSize=14, pos={250,315},title="SoFi RT", variable=GenerateSoFi, font="Arial",disable=0, proc=SoFi_proc

		NVAR/Z MaxMz=root:ACMCC_Export:MaxMz
		PopupMenu PM_Maxmz, fSize=14, pos={150,340}, size={90,20}, value = "select;"+InputLists("Maxmz"), title="\f02max mz    ", proc = MaxmzInput_proc, disable = 0, win=ExportPanel,fstyle=1,font="Arial"	

	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	SetVariable Set_ExportPath,title="Save Data Folder",pos={7,380},size={323,19},value=NextCloud_path,fSize=12,noedit=1,font="Arial", disable=0
	Button Set_PathToR_button,title="\\f01SET",pos={336,380},size={50,20},fSize=14,fColor=(39168,39168,39168),font="Arial", proc=SetPath_proc, disable=0
	
	NVAR/Z StartStop_bool=root:ACMCC_Export:StartStop_bool
	if (StartStop_bool==0)
		Button RunButton,title="START",pos={24,405},size={355,40},fSize=20,fstyle=1,fColor=(26112,52224,0),proc=LaunchExport,font="Arial",disable=0
	elseif (StartStop_bool==1)
		Button RunButton,title="STOP",pos={24,405},size={355,40},fSize=20,fstyle=1,fColor=(65280,16384,16384),proc=LaunchExport,font="Arial",disable=0
	endif
	
	NVAR/Z Counts=root:ACMCC_Export:Counts
	NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
	SetVariable Set_Counts, title="\\f02Checking rate (s)   ", pos={10,450}, size={130,20}, fSize=12,noedit=0,value=RefreshRate,disable=0
End

Function Dryerproc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[8]=num2str(checked)

	if (checked==0)
		SetVariable Set_DryerPath, disable=2
		Button Set_DryerPath_button, disable=2
	elseif(checked==1)
		SetVariable Set_DryerPath, disable=0
		Button Set_DryerPath_button, disable=0
	endif

End Function


Function CDCE_proc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	//NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[8]=num2str(checked)

End Function

Function PMFgen_proc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	//NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[9]=num2str(checked)

End Function

Function SoFi_proc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	//NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[10]=num2str(checked)

End Function

Function Pumpproc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	NVAR/Z PumpBool=root:ACMCC_Export:PumpBool
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[5]=num2str(checked)
	
	if (checked==0)
		SetVariable Set_PumpPath, disable=2
		Button Set_PumpPath_button, disable=2
	elseif(checked==1)
		SetVariable Set_PumpPath, disable=0
		Button Set_PumpPath_button, disable=0
		
		SVAR/Z PumpDataFilePrefix=root:ACMCC_Export:PumpDataFilePrefix
		string temp
		temp=PumpDataFilePrefix
		string prompt_str="Please check the prefix of pump file"
		prompt temp, prompt_str
		doprompt "Please verify", temp
		PumpDataFilePrefix=temp
		ConfigW_val[6]=PumpDataFilePrefix
	endif

End Function


Function SetDryerPath_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z DryerStat_path=root:ACMCC_Export:DryerStat_path
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	DryerStat_path = S_path
	ConfigW_val[4]=DryerStat_path
	setdatafolder temp_folder
end


Function SetPumpPath_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z Pump_path=root:ACMCC_Export:Pump_path
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	Pump_path = S_path
	ConfigW_val[7]=Pump_path
	setdatafolder temp_folder
end




Function SetPath_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	NextCloud_path = S_path
	ConfigW_val[12]=NextCloud_path
	setdatafolder temp_folder
end


Function SetScriptPath_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z Script_path=root:ACMCC_Export:Script_path
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	Script_path = S_path
	setdatafolder temp_folder
	
	wave/T StationNameW=root:ACMCC_Export:StationNameW
	//ControlInfo PM_Station
	//string station=S_value
	string station=StationNameW[0]
	string folder=Script_path+"data:"
	NewPath/C/O/Q tempPath folder
	folder=Script_path+"data:"+station
	NewPath/C/O/Q tempPath folder	//create this folder if it does not exits
	folder=Script_path+"data:"+station+":in:"
	NewPath/C/O/Q tempPath folder
	folder=Script_path+"data:"+station+":out:"
	NewPath/C/O/Q tempPath folder

	SVAR/Z DataForPython_path=root:ACMCC_Export:DataForPython_path
	DataForPython_path=Script_path+"data:"+station+":in:"
	
End Function


Function SetPathCS_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z PMFInput_path=root:ACMCC_Export:PMFInput_path
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	PMFInput_path = S_path
	setdatafolder temp_folder
end


Function/S InputLists(option)
	string option
	
	if (stringmatch(option,"Station"))
		SVAR/Z ListOfStations=root:ACMCC_Export:ListOfStations
		return ListOfStations
	endif
	if (stringmatch(option,"Spectro"))
		SVAR/Z ToF_Quad_Str=root:ACMCC_Export:ToF_Quad_Str
		return ToF_Quad_Str
	endif
	if (stringmatch(option,"Lens"))
		SVAR/Z Lens_Str=root:ACMCC_Export:Lens_Str
		return Lens_Str
	endif
	if (stringmatch(option,"Vaporizer"))
		SVAR/Z Vaporizer_Str=root:ACMCC_Export:Vaporizer_Str
		return Vaporizer_Str
	endif
	if (stringmatch(option,"Maxmz"))
		SVAR/Z Maxmz_Str=root:ACMCC_Export:Maxmz_Str
		return Maxmz_Str
	endif
	
End Function


Function MaxmzInput_proc(name,num,str) : PopupMenuControl 
	string name
	variable num
	string str
	
	SetDataFolder root:ACMCC_Export
	
	NVAR/Z MaxMz=root:ACMCC_Export:MaxMz
	SVAR/Z FragTableVersion=root:ACMCC_Export:FragTableVersion
	string mzbool_str
	variable j
	
	if (stringmatch(str,"100"))
		MaxMz=100
		if(stringmatch(FragTableVersion,"V1")) //if V1, no org signal at mz28
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;0;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		else
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		endif
		
		Make/O/N=100 mzbool
		for(j=0;j<itemsinlist(mzbool_str);j+=1)
			mzbool[j]=str2num(stringfromlist(j,mzbool_str))
		endfor
	elseif(stringmatch(str,"120"))
		MaxMz=120
		if(stringmatch(FragTableVersion,"V1")) //if V1, no org signal at mz28
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;0;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		else
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		endif
		Make/O/N=120 mzbool
		for(j=0;j<itemsinlist(mzbool_str);j+=1)
			mzbool[j]=str2num(stringfromlist(j,mzbool_str))
		endfor
	endif
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[11]=num2str(dimsize(mzbool,0))
	
End Function

Function StationInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	SVAR/Z ListOfStations=root:ACMCC_Export:ListOfStations

	wave/T StationNameW=root:ACMCC_Export:StationNameW
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	if (stringmatch(str,"other"))
		string temp
		string prompt_str="Please enter the name of the station. Be consistent with previous files !"
		prompt temp, prompt_str
		doprompt "Please verify", temp
		StationNameW[0]=temp
		ListOfStations+=";"+temp
		ConfigW_val[0]=temp
		
	elseif(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list the name of your station"
	else
		StationNameW[0]=str
		ConfigW_val[0]=str
	endif
	
	
End Function


Function SpectroInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	wave/T ToF_QuadW=root:ACMCC_Export:ToF_QuadW
	if(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list"
	else
		ToF_QuadW[0]=str
		SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
		if(stringmatch(str,"UMR ToF"))
			NextCloud_path="C:Users:TofUser:NextCloud:"
		else
			NextCloud_path="C:Users:acsm:Nextcloud:"
		endif
	endif
End Function

Function LensInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	wave/T LensW=root:ACMCC_Export:LensW
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	if(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list"
	else
		LensW[0]=str
		ConfigW_val[1]=str
	endif
End Function

Function VapInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	wave/T VaporizerW=root:ACMCC_Export:VaporizerW
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	if(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list"
	else
		VaporizerW[0]=str
		ConfigW_val[2]=str
	endif
	
	NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
	
	if(stringmatch(VaporizerW[0],"Capture Vap."))
		ApplyMiddlebrook=0
		CheckBox UseMiddlebrook_CB,disable=2
	elseif(stringmatch(VaporizerW[0],"Standard Vap."))
		ApplyMiddlebrook=1
		CheckBox UseMiddlebrook_CB,disable=0
	endif
	
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	ConfigW_val[8]=num2str(ApplyMiddlebrook)
	
End Function



Function LaunchExport(ctrlName) : ButtonControl
	string CtrlName	
	
	NVAR/Z StartStop_bool=root:ACMCC_Export:StartStop_bool

	if (StartStop_bool==0)


		// Doing preliminary checks	
		SVAR NextCloud_path=root:ACMCC_Export:NextCloud_path
		GetFileFolderInfo/Q/D/Z=1 NextCloud_path
		if(V_flag != 0 && V_flag!=-1)
			DoAlert/T="WARNING" 0,"Folder not found on your computer. Please check."
			Abort
		endif
		
		wave/T StationNameW=root:ACMCC_Export:StationNameW
		ControlInfo/W=ExportPanel PM_Station
		if (stringmatch(S_Value,"select") && stringmatch(StationNameW[0],""))
			DoAlert/T="WARNING" 0,"Please set the name of the station"
			Abort
		endif
		
		wave/T LensW=root:ACMCC_Export:LensW
		ControlInfo/W=ExportPanel PM_Lens
		if (stringmatch(S_Value,"select") && stringmatch(LensW[0],""))
			DoAlert/T="WARNING" 0,"Please set the type of lens"
			Abort
		endif
		
		wave/T VaporizerW=root:ACMCC_Export:VaporizerW
		ControlInfo/W=ExportPanel PM_Vap
		if (stringmatch(S_Value,"select") && stringmatch(VaporizerW[0],""))
			DoAlert/T="WARNING" 0,"Please set the type of vaporizer"
			Abort
		endif
		
		ControlInfo/W=ACSM_ControlWindow an_corr_AB_ck
		wave/Z smCorr_w = root:timeSeries_corrections:smCorr_w
		if (V_value==0 || DataFolderExists("root:TimeSeries_corrections")==0  || waveexists(smCorr_w)==0)
			DoAlert/T="WARNING" 0,"Please set the airbeam correction in acsm_local"
			Abort
		endif
		
		ControlInfo/W=ACSM_ControlWindow an_RIT_Corr_ck
		if (V_value==0)
			DoAlert/T="WARNING" 0,"Please set the RIT correction in acsm_local"
			Abort
		endif
		
		wave/Z w=$"root:ACMCC_Export:mzbool"
		if(waveexists(w)==0)
			DoAlert/T="WARNING" 0,"Pb with mz bool. Can you please try to select max mz again ?"
			Abort
		endif
		// End of preliminary checks

		
		NVAR Number=root:ACMCC_Export:Number
		wave/T ToF_QuadW=root:ACMCC_Export:ToF_QuadW
		if(stringmatch(ToF_QuadW[0],"UMR ToF"))
			wave ACSM_time=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
			duplicate/O ACSM_time, root:ACMCC_Export:temp
			SetDataFolder root:ACMCC_Export:
			wave temp
			waveTransform zapnans, temp
			variable result=numpnts(temp)-1
			Number=result
		elseif(stringmatch(ToF_QuadW[0],"UMR Quad"))
			wave ACSM_time=root:ACSM_Incoming:acsm_utc_time
			Number=numpnts(ACSM_time)	
		endif
		
		Button RunButton,title="STOP",size={355,40},fSize=20,fstyle=1,fColor=(65280,16384,16384),proc=LaunchExport,font="Arial",disable=0
		StartStop_bool=1

		PopupMenu PM_Station disable = 2
		SetVariable PM_Spectro, disable = 2
		SetVariable Set_SN, disable=2
		SetVariable Set_SN, disable=2	
		PopupMenu PM_Lens, disable = 2
		PopupMenu PM_Vap, disable = 2
		CheckBox PMFBox, disable=2
		SetVariable Set_ExportPath,disable=2
		Button Set_PathToR_button,disable=2
		CheckBox UseMiddlebrook_CB,disable=2
		CheckBox SoFiBox,disable=2
		SetVariable Set_DryerPath, disable=2
		Button Set_DryerPath_button, disable=2
		SetVariable Set_PumpPath, disable=2
		Button Set_PumpPath_button, disable=2
		PopupMenu PM_Maxmz,disable=2
		
		NVAR/Z Counts=root:ACMCC_Export:Counts
		NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
		Counts=RefreshRate
		SetVariable Set_Counts, noedit=1, value=Counts


		ACMCC_StartTask()

	elseif(StartStop_bool==1)
		
		StartStop_bool=0
		Button RunButton,title="START",size={355,40},fSize=20,fstyle=1,fColor=(26112,52224,0),proc=LaunchExport,font="Arial",disable=0
		
		PopupMenu PM_Station disable = 0
		SetVariable PM_Spectro, disable = 0
		SetVariable Set_SN, disable=0
		SetVariable Set_SN, disable=0	
		PopupMenu PM_Lens, disable = 0
		PopupMenu PM_Vap, disable = 0
		CheckBox PMFBox, disable=0
		SetVariable Set_ExportPath,disable=0
		Button Set_PathToR_button,disable=0
		CheckBox UseMiddlebrook_CB,disable=0
		CheckBox SoFiBox,disable=0
		SetVariable Set_DryerPath, disable=0
		Button Set_DryerPath_button, disable=0
		SetVariable Set_PumpPath, disable=0
		Button Set_PumpPath_button, disable=0
		PopupMenu PM_Maxmz,disable=0
		
		NVAR/Z Counts=root:ACMCC_Export:Counts
		NVAR/Z RefreshRate=root:ACMCC_Export:RefreshRate
		Counts=RefreshRate
		SetVariable Set_Counts, noedit=0, value=RefreshRate
		
		ACMCC_StopTask()
		
	endif

End Function


///////////////// END OF PANEL FUNCTIONS ////////////////////////////////////////


///////////////// MAIN EXPORT FUNCTIONS ////////////////////////////////////////

Function ACMCC_ToF_TriggeredExport()


End Function


Function ACMCC_Quad_TriggeredExport()
	
	SetDataFolder root:ACMCC_Export
	string AlertTxt=""
	//Get IE, RIE and CE values
	Make/N=1/D/O IE_NO3, RIE_NH4, RIE_SO4, RIE_NO3, RIE_OM, RIE_Cl, CE
	wave RIE_W=root:RIE
	RIE_OM=RIE_W[0]
	RIE_NH4=RIE_W[1]
	RIE_SO4=RIE_W[2]
	RIE_NO3=RIE_W[3]
	RIE_Cl=RIE_W[4]
	wave MC_NO3=root:Masscalib_nitrate
	IE_NO3=MC_NO3[0]
	wave CEW=root:CE
	CE=CEW[0]
	
	//Get Date
	Make/N=1/O/T ACSM_time
	wave DateW=root:ACSM_Incoming:acsm_utc_time
	variable lastrow=numpnts(DateW)-1
	
	string year=ACMCC_ExtractDateInfo(DateW[lastrow],"year")
	string month=ACMCC_ExtractDateInfo(DateW[lastrow],"month")
	string dayOfMonth=ACMCC_ExtractDateInfo(DateW[lastrow],"dayOfMonth")
	string hour=ACMCC_ExtractTimeInfo(DateW[lastrow],"hour")
	string minute=ACMCC_ExtractTimeInfo(DateW[lastrow],"minute")
	string second=ACMCC_ExtractTimeInfo(DateW[lastrow],"second")
	
	ACSM_time=year+"/"+month+"/"+dayofmonth+" "+hour+":"+minute+":"+second
	
	//Get Concentrations
	Make/O/N=1 OM,NO3,SO4,NH4,Cl
	wave OrgW=root:Time_Series:Org
	wave NO3W=root:Time_Series:NO3
	wave SO4W=root:Time_Series:SO4
	wave NH4W=root:Time_Series:NH4
	wave ClW=root:Time_Series:Chl
	OM=OrgW[lastrow]
	NO3=NO3W[lastrow]
	SO4=SO4W[lastrow]
	NH4=NH4W[lastrow]
	Cl=ClW[lastrow]
	
	
	//Apply CE correction
	NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
	if (ApplyMiddlebrook==1)
		Duplicate/o SO4 PredNH4, NH4_MeasToPredict, ANMF
		PredNH4=18*(SO4/96*2+NO3/62+Cl/35.45)
		NH4_MeasToPredict=NH4/PredNH4
		ANMF=(80/62)*NO3/(NO3+SO4+NH4+OM+Cl)
		If (NH4_MeasToPredict[0]<0)
			NH4_MeasToPredict[0]=nan
		EndIf
		//	Nan ANMF points if negative or more than 1
		If (ANMF[0]<0)
			ANMF[0]=nan
		ElseIf (ANMF[0]>1)
			ANMF[0]=nan
		EndIf
			
		If (PredNH4[0]<0.5)
			CE[0]=0.5
		ElseIf (NH4_MeasToPredict[0]>=0.75)
			//	Apply Equation 4
			CE[0]= 0.0833+0.9167*ANMF[0]
		ElseIf (NH4_MeasToPredict[0]<0.75)
			//	Apply Equation 6
			CE[0]= 1-0.73*NH4_MeasToPredict[0]
		EndIf
		
		CE=min(1,(max(0.5,CE)))
		CE=(numtype(CE[p])==2) ? 0.5 : CE[p]
		KillWaves ANMF, PredNH4, NH4_MeasToPredict 
		SO4*=CEW[0]/CE
		NH4*=CEW[0]/CE
		NO3*=CEW[0]/CE
		Cl*=CEW[0]/CE
		OM*=CEW[0]/CE
	endif
	
	
	//Get Diagnostics
	Make/O/N=1 RF, ChamberT, Airbeam, NewStart_Events, InletPClosed, InletPOpen, InletP, VapT
	wave RFW=root:diagnostics:RF
	wave ChamberTW=root:diagnostics:ChamberT
	wave AirbeamW=root:diagnostics:Airbeam
	wave NSE=root:diagnostics:NewStart_Events
	wave IPC=root:diagnostics:InletPClosed
	wave IPO=root:diagnostics:InletPOpen
	wave IP=root:diagnostics:InletP
	wave VapTW=root:diagnostics:VapT
	
	RF=RFW[lastrow]
	ChamberT=ChamberTW[lastrow]
	Airbeam=AirbeamW[lastrow]
	NewStart_Events=NSE[lastrow]
	InletPClosed=IPC[lastrow]
	InletPOpen=IPO[lastrow]
	InletP=IP[lastrow]
	VapT=VapTW[lastrow]
	
	if(Airbeam[0]<8e-08)
		AlertTxt+="Airbeam is too low\t"
	endif
	if(InletP[0]<1)
		AlertTxt+="InletP is too low\t"
	endif
	if(VapT[0]>650)
		AlertTxt+="VapT is too high\t"
	endif
	if(VapT[0]<550)
		AlertTxt+="VapT is too low\t"
	endif
	
	//Get Tuning Var
	Make/O/N=1 EmCurrent, SEMVol, HeaterBias, VapV
	wave DAQ=root:acsm_incoming:DAQ_Matrix
	EmCurrent=DAQ[lastrow][6]
	SEMVol=DAQ[lastrow][7]
	HeaterBias=5 + DAQ[lastrow][2]*200/5
	VapV=DAQ[lastrow][28]
	
	//Get f_Org & f_NO3 values
	Make/O/N=1 OM_f44, OM_f43, OM_f60, NO3_f30, NO3_f46
	NewDataFolder/S/O root:ACMCC_Export:Temp
	wave OrgMx=root:ACSM_Incoming:OrgStickMatrix
	wave NO3Mx=root:ACSM_Incoming:NO3StickMatrix
	
	ACMCC_DoSumOfRow(OrgMx)
	ACMCC_DoSumOfRow(NO3Mx)
	wave OrgStickMatrix_sum
	wave NO3StickMatrix_sum
	OM_f44=OrgMx[lastrow][44]/OrgStickMatrix_sum[lastrow]
	OM_f43=OrgMx[lastrow][43]/OrgStickMatrix_sum[lastrow]
	OM_f60=OrgMx[lastrow][60]/OrgStickMatrix_sum[lastrow]
	NO3_f30=NO3Mx[lastrow][30]/NO3StickMatrix_sum[lastrow]
	NO3_f46=NO3Mx[lastrow][46]/NO3StickMatrix_sum[lastrow]
	KillDataFolder/Z root:ACMCC_Export:Temp
	SetDataFolder root:ACMCC_Export

	//Get general info
	Make/O/N=1/T acsm_local_version
	
	//acsm_local_version=versionStr
	acsm_local_version=stringfromlist(0, ACMCC_getConst_wrapper("ACMCC_getConst_version_acsm"), " ")
	//acsm_local_version=""
	Make/O/N=1/T ACMCC_export_ver
	ACMCC_export_ver=ACMCC_Export_version
	Make/O/N=1/T SerialNumber
	wave DAQ=root:acsm_incoming:DAQ_Matrix
	string temp_str
	sprintf temp_str, "%6d",DAQ[lastrow][74]
	SerialNumber=temp_str
	
	//Get Pump Diagnostics
	SetDataFolder root:ACMCC_Export	
	Make/O/N=1 TP1_S,TP1_W,TP1_T,TP2_S,TP2_W,TP2_T,TP3_S,TP3_W,TP3_T
	NVAR/Z PumpBool=root:ACMCC_Export:PumpBool
	if(PumpBool==1)
		ACMCC_PumpData(lastrow)
		wave TP1_S_avg=root:ACMCC_Export:PumpData:TP1_S_avg
		wave TP1_W_avg=root:ACMCC_Export:PumpData:TP1_W_avg
		wave TP1_T_avg=root:ACMCC_Export:PumpData:TP1_T_avg
		wave TP2_S_avg=root:ACMCC_Export:PumpData:TP2_S_avg
		wave TP2_W_avg=root:ACMCC_Export:PumpData:TP2_W_avg
		wave TP2_T_avg=root:ACMCC_Export:PumpData:TP2_T_avg
		wave TP3_S_avg=root:ACMCC_Export:PumpData:TP3_S_avg
		wave TP3_W_avg=root:ACMCC_Export:PumpData:TP3_W_avg
		wave TP3_T_avg=root:ACMCC_Export:PumpData:TP3_T_avg
		TP1_S=TP1_S_avg
		TP1_W=TP1_W_avg
		TP1_T=TP1_T_avg
		TP2_S=TP2_S_avg
		TP2_W=TP2_W_avg
		TP2_T=TP2_T_avg
		TP3_S=TP3_S_avg
		TP3_W=TP3_W_avg
		TP3_T=TP3_T_avg
	endif

	//Get Dryer Stats
	SetDataFolder root:ACMCC_Export:
	Make/O/N=1 Sampling_Flowrate, RH_In, RH_Out, T_In, T_Out
	NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	if(DryerBool==1)
		ACMCC_DryerStat_avg(lastrow)
		wave FlowR_avg=root:ACMCC_Export:DryerData:FlowR_avg
		wave T_In_avg=root:ACMCC_Export:DryerData:T_In_avg
		wave T_Out_avg=root:ACMCC_Export:DryerData:T_Out_avg
		wave RH_In_avg=root:ACMCC_Export:DryerData:RH_In_avg
		wave RH_Out_avg=root:ACMCC_Export:DryerData:RH_Out_avg
		Sampling_Flowrate=FlowR_avg[0]
		T_In=T_In_avg[0]
		T_Out=T_Out_avg[0]
		RH_In=RH_In_avg[0]
		RH_Out=RH_Out_avg[0]
	endif
	if(RH_Out[0]>40)
		AlertTxt+="RH is too high\t"
	endif
	if(Sampling_Flowrate[0]<2.8 || Sampling_Flowrate[0]>3.2)
		AlertTxt+="Sampling FlowRate out of range\t"
	endif
	
	UpdateNoteBook(AlertTxt)
	
	//Get Concentration Errors
	SetDataFolder root:ACMCC_Export	
	Make/O/N=1 OM_err, NO3_err, SO4_err, NH4_err, Cl_err
	ACMCC_Quad_Error(lastrow)
	wave eChl=root:PMFMats:eChl
	wave eOrg=root:PMFMats:eOrg
	wave eSO4=root:PMFMats:eSO4
	wave eNO3=root:PMFMats:eNO3
	wave eNH4=root:PMFMats:eNH4
	OM_err=eOrg
	NO3_err=eNO3
	SO4_err=eSO4
	NH4_err=eNH4
	Cl_err=eChl
	
	//Create Table & Save
	variable i
	i=0
	
	SetDataFolder root:ACMCC_Export
	string saveWavesList="ACSM_time;OM;NO3;SO4;NH4;Cl;IE_NO3;RIE_OM;RIE_NO3;RIE_SO4;RIE_NH4;RIE_Cl;CE;"
	saveWavesList+="RF;ChamberT;Airbeam;NewStart_Events;InletPClosed;InletPOpen;InletP;VapT;"
	saveWavesList+="EmCurrent;SEMVol;HeaterBias;VapV;"
	saveWavesList+="OM_f44;OM_f43;OM_f60;NO3_f30;NO3_f46;"
	saveWavesList+="acsm_local_version;ACMCC_export_ver;"
	saveWavesList+="TP1_S;TP1_W;TP1_T;TP2_S;TP2_W;TP2_T;TP3_S;TP3_W;TP3_T;"
	saveWavesList+="Sampling_Flowrate;RH_In;RH_Out;T_In;T_Out;"
	saveWavesList+="OM_err;NO3_err;SO4_err;NH4_err;Cl_err;"
	saveWavesList+="Tof_QuadW;LensW;VaporizerW;"
	
	SetDataFolder root:ACMCC_Export
	wave/T VaporizerW,LensW,ToF_QuadW
	for (i=0;i<itemsInList(saveWavesList);i+=1)
		wave w = $stringFromList(i,saveWavesList)
		if (i==0)
			Edit /N=ExportTable w
		else
			AppendToTable /W=ExportTable w
		endif
	endfor
	
	SetDataFolder root:ACMCC_Export
	Wave/T SerialNumber
	Wave/T StationNameW
	
	string FileName=StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_"
	FileName+=year+month+dayofmonth+hour+minute+".txt"
	
	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	string DataPathbis=NextCloud_path
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+="ACMCC_Export:"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+=year+":"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+=month+":"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+=dayOfMonth+":"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	
	ModifyTable/W=ExportTable format(ACSM_time)=8
	saveTableCopy/O/T=1/W=ExportTable/P=SaveDataFilePathbis as FileName
	
	
	//NASA-AMES Script
//	SVAR/Z DataForPython_path=root:ACMCC_Export:DataForPython_path
//	string DataConverterPath=DataForPython_path
//	NewPath/Q/O/C SaveDataConverterPath, DataConverterPath
//	saveTableCopy/O/T=1/W=ExportTable/P=SaveDataConverterPath as FileName
//	
//	string FlagFileName=StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_FLAGS_"
//	FlagFileName+=year+month+dayofmonth+hour+minute+".txt"
//	Make/O/N=1 numflag_OM, numflag_NO3, numflag_SO4, numflag_NH4, numflag_Cl
//	Edit /N=FlagTable ACSM_time
//	AppendToTable /W=FlagTable numflag_OM, numflag_NO3, numflag_SO4, numflag_NH4, numflag_Cl
//	ModifyTable/W=FlagTable format(ACSM_time)=8
//	saveTableCopy/O/T=1/W=FlagTable/P=SaveDataConverterPath as FlagFileName
//	KillWindow FlagTable
//	NasGen(FileName,FlagFileName)
	//
	
	KillWindow ExportTable
	
	
	NVAR/Z GeneratePMFInput=root:ACMCC_Export:GeneratePMFInput
	if (GeneratePMFInput==1)
		SetDataFolder root:ACMCC_Export
		duplicate/O root:PMFMats:Org_Specs Org_Specs
		duplicate/O root:PMFMats:Orgspecs_err Orgspecs_err
		duplicate/O root:PMFMats:amus amus
		
		if (ApplyMiddlebrook==1)
			Org_Specs*=CEW[0]/CE
			Orgspecs_err*=CEW[0]/CE
		endif
		
		Edit/N=PMFExportTable ACSM_time
		AppendToTable /W=PMFExportTable amus
		AppendToTable /W=PMFExportTable Orgspecs_err
		AppendToTable /W=PMFExportTable Org_Specs
		ModifyTable/W=PMFExportTable format(ACSM_time)=8
		
		FileName=StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_"+"PMF_"+year+month+dayofmonth+hour+minute+".txt"
		saveTableCopy/O/T=1/W=PMFExportTable/P=SaveDataFilePathbis as FileName
		KillWindow PMFExportTable
	endif
	
	NVAR/Z GenerateSoFi=root:ACMCC_Export:GenerateSoFi
	if (GenerateSoFi==1)
		ACMCC_ExportSoFi()	
	endif
	
End Function


Function ACMCC_ExportSoFi()

	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	string DataPathbis=NextCloud_path
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+="SoFi:"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	
	NewDataFolder/O/S root:ACMCC_Export:SoFi
	wave DateW=root:ACSM_Incoming:acsm_utc_time
	variable lastrow=numpnts(DateW)-1
	wave aut = root:acsm:file_fpfile_list_dat
	duplicate/O aut alt
	wave DAQ_Matrix = root:acsm_incoming:DAQ_Matrix
	alt = -1*(DAQ_Matrix[p][51] * 3600) + aut
	
	wave mzbool=root:ACMCC_Export:mzbool
	
	wave chT = root:diagnostics:chamberT
	wave ab = root:diagnostics:airbeam
	wave ip = root:diagnostics:inletP
	wave vt = root:diagnostics:vapT
	wave/Z Org_pt = root:Time_Series:Org
	wave/Z SO4_pt = root:Time_Series:SO4
	wave/Z NO3_pt = root:Time_Series:NO3
	wave/Z NH4_pt = root:Time_Series:NH4
	wave/Z Chl_pt = root:Time_Series:Chl
	wave/Z Masscalib_nitrate_pt = root:Masscalib_nitrate
	
	wave Org_Specs_pt=root:PMFMats:Org_Specs
	wave amus_pt=root:PMFMats:amus
	wave Orgspecs_err_pt=root:PMFMats:Orgspecs_err
	
	string wlStr = "org_specs;orgSpecs_err;amus;acsm_utc_time;acsm_local_time;chamberT;airbeam;inletP;vapT;CE;Masscalib_nitrate;Org;SO4;NO3;NH4;Chl"

	wave/T StationNameW=root:ACMCC_Export:StationNameW
	wave/T SerialNumber=root:ACMCC_Export:SerialNumber
	
	wave CEW=root:CE
	wave CE_ACMCC=root:ACMCC_Export:CE
	
	string dstr
	dstr = secs2date(aut[lastrow], -2)
	dstr = StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_RTdata_" + dstr[0,3]+"_"+dstr[5,6]+"_"+dstr[8,9] + ".itx"
	//dstr = "RTdata_" + dstr[0,3]+"_"+dstr[5,6]+"_"+dstr[8,9] + ".itx"
	GetFileFolderInfo /Z/Q/P=SaveDataFilePathbis dstr
	
	if(V_flag != 0) //file doesn't exist- create waves for it and write them
		
		duplicate/O Org_Specs_pt Org_Specs
		duplicate/O Orgspecs_err_pt Orgspecs_err
		duplicate/O amus_pt amus
		
		Extract/O Orgspecs_err, Orgspecs_err, mzbool==1
		Extract/O amus, amus, mzbool==1
		Extract/O Org_Specs, Org_Specs, mzbool==1
		
		NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
		
		if (ApplyMiddlebrook==1)
			Org_Specs*=CEW[0]/CE_ACMCC[0]
			Orgspecs_err*=CEW[0]/CE_ACMCC[0]
		endif
		
		MatrixOp /O Org_Specs = Org_Specs^t
		MatrixOp /O Orgspecs_err = Orgspecs_err^t
		
		make/D/O/N=1 acsm_utc_time; acsm_utc_time[0] = aut[lastrow]
		make/D/O/N=1 acsm_local_time; acsm_local_time[0] = alt[lastrow]
		make/D/O/N=1 ChamberT; chamberT[0] = chT[lastrow]
		make/D/O/N=1 airbeam; airbeam[0] = ab[lastrow]
		make/O/N=1 inletP; inletP[0] = ip[lastrow]
		make/O/N=1 vapT; vapT[0] = vt[lastrow]
		make/O/N=1 CE; CE[0] = CE_ACMCC[0]
		make/O/N=1 Masscalib_nitrate; Masscalib_nitrate[0] = Masscalib_nitrate_pt[0]
	
		make/O/N=1 Org; Org[0] = Org_pt[lastrow]
		make/O/N=1 SO4; SO4[0] = SO4_pt[lastrow]
		make/O/N=1 NO3; NO3[0] = NO3_pt[lastrow]
		make/O/N=1 NH4; NH4[0] = NH4_pt[lastrow]
		make/O/N=1 Chl; Chl[0] = Chl_pt[lastrow]
		
		Save /B/P=SaveDataFilePathbis /T wlStr as dstr
		
	
	else //file exists - load in the data and append to it
		
		duplicate/O Org_Specs_pt Org_Specs_temp
		duplicate/O Orgspecs_err_pt Orgspecs_err_temp
		//duplicate/O amus_pt amus
		
		Extract/O Orgspecs_err_temp, Orgspecs_err_temp, mzbool==1
		Extract/O amus, amus, mzbool==1
		Extract/O Org_Specs_temp, Org_Specs_temp, mzbool==1
		
		NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
		
		if (ApplyMiddlebrook==1)
			Org_Specs_temp*=CEW[0]/CE_ACMCC[0]
			Orgspecs_err_temp*=CEW[0]/CE_ACMCC[0]
		endif
		
		MatrixOp /O Org_Specs_temp = Org_Specs_temp^t
		MatrixOp /O Orgspecs_err_temp = Orgspecs_err_temp^t
		
		loadwave/O/Q/T/P=SaveDataFilePathbis dstr

		wave/Z org_specs, orgSpecs_err,  acsm_utc_time, acsm_local_time, ChamberT, airbeam, inletP, vapT, CE
		variable n = numpnts(acsm_utc_time)
		insertPoints n, 1, org_specs, orgSpecs_err, acsm_utc_time, acsm_local_time, ChamberT, airbeam, inletP, vapT, CE, Masscalib_nitrate
		org_specs[n][] = Org_Specs_temp[0][q]
		orgSpecs_err[n][] = Orgspecs_err_temp[0][q]
		acsm_utc_time[n] = aut[lastrow]
		acsm_local_time[n] = alt[lastrow]
		ChamberT[n] = chT[lastrow]
		airbeam[n] = ab[lastrow]
		inletP[n] = ip[lastrow]
		vapT[n] = vt[lastrow]
		CE[n] = CE_ACMCC[0]
		Masscalib_nitrate[n] = Masscalib_nitrate_pt[0]

		wave/Z Org, SO4, NO3, NH4, Chl
		insertPoints n, 1, Org, SO4, NO3, NH4, Chl
		Org[n] = Org_pt[lastrow]
		SO4[n] = SO4_pt[lastrow]
		NO3[n] = NO3_pt[lastrow]
		NH4[n] = NH4_pt[lastrow]
		Chl[n] = Chl_pt[lastrow]
//Francesco end

		save /B/O/P=SaveDataFilePathbis /T wlStr as dstr
	
	
	endif

End Function


/////////////////END OF MAIN EXPORT FUNCTIONS ////////////////////////////////////////


/////////////////ERROR FUNCTIONS ////////////////////////////////////////

Function ACMCC_Quad_Error(lastrow)
	variable lastrow

	variable a = 1.2
	string sf = getDatafolder(1); ACMCC_MakeAndOrSetDF( "root:PMFMats" )
	//Get Gain
	variable Gain = 2e4
	variable dwellTMissingFlag = 0
	//Get m/z for electronic noise
	variable DwellTime = 1.2
	variable massForElectronicNoise = 140
	variable electronicNoise = 0
	// Open and closed haven't been RIT (Tm/z) corrected.
	wave OpenMat = root:acsm_incoming:mssopen_mzcorr
	wave ClosedMat = root:acsm_incoming:mssClosed_mzcorr
	wave daq_Matrix = root:acsm_incoming:DAQ_matrix
	wave smCorr_w = root:timeSeries_corrections:smCorr_w
	
	Make/O/N=(1,dimsize(OpenMat,1)) OpenMat_LR,ClosedMat_LR,daq_Matrix_LR
	OpenMat_LR[0][]=OpenMat[lastrow][q]
	ClosedMat_LR[0][]=ClosedMat[lastrow][q]
	daq_Matrix_LR[0][]=daq_Matrix_LR[lastrow][q]
	
	make/O/N=1 dwellTW, gainW, eNoiseWave, minErrorW
	make/O/N=(dimsize(OpenMat,0)) eNoiseWave_temp
	variable ACMCC_ka_amu_window=0.05
	dwellTW = 2*ACMCC_ka_amu_window * daq_matrix[lastrow][54] * 0.001*daq_matrix[lastrow][75]
	dwellTMissingFlag = 1
	gainW = (gain / smCorr_w[lastrow])*(daq_matrix[lastrow][85]/daq_matrix[lastrow][1])
	
	// calculate electronic noise based on closed data for a m/z with no real signal
	if (massForElectronicNoise != 0)
		 eNoiseWave_temp = closedMat[p][massForElectronicNoise]
		wavestats /Q  eNoiseWave_temp
		// factors here are to convert to counts...
		eNoiseWave = 6.24e18 * DwellTW[0] * V_Sdev / gainW[0]
	endif
	
	
	make/O/N=(1, dimsize(OpenMat,1)) openMatCts = OpenMat[lastrow][q]*6.24e18*DwellTW[0]/GainW[0]
	make/O/N=(1, dimsize(ClosedMat,1)) ClosedMatCts = ClosedMat[lastrow][q]*6.24e18*DwellTW[0]/GainW[0]
	
	//Apply RIT Correction to open and closed (in counts)
	MatrixOp/O openMatCts = openMatCts^t
	MatrixOp/O closedMatCts = closedMatCts^t
	//These were commented out for V1.5.3.5 b/c it reverts to default
	//ACSM_correctIonTransmission(openMatCts)
	//ACSM_correctIonTransmission(closedMatCts)
	// Move these in 1.5.14.0 to after calculating the counting error per comment from Jay Slowik.
	//ACSM_PMF_correctIonTransmission(openMatCts)
	//ACSM_PMF_correctIonTransmission(closedMatCts)
	MatrixOp/O openMatCts = openMatCts^t
	MatrixOp/O closedMatCts = closedMatCts^t
	//Calculate difference and its error in cts
	MatrixOp/O eOpenMatCts = a*powr(OpenMatCts,0.5)
	MatrixOp/O eClosedMatCts = a*powr(ClosedMatCts,0.5)
	MatrixOp/O openMatCts = openMatCts^t
	MatrixOp/O closedMatCts = closedMatCts^t
	MatrixOp/O eOpenMatCts = eOpenMatCts^t
	MatrixOp/O eClosedMatCts = eClosedMatCts^t
	ACMCC_correctIonTransmission(eOpenMatCts)
	ACMCC_correctIonTransmission(eClosedMatCts)
	ACMCC_correctIonTransmission(openMatCts)
	ACMCC_correctIonTransmission(closedMatCts)
	MatrixOp/O openMatCts = openMatCts^t
	MatrixOp/O closedMatCts = closedMatCts^t
	MatrixOp/O eOpenMatCts = eOpenMatCts^t
	MatrixOp/O eClosedMatCts = eClosedMatCts^t
	MatrixOp/O diffMatCts = OpenMatCts - ClosedMatCts 
	MatrixOp/O eDiffMatCts = powr((powr(eOpenMatCts,2) + powr(eClosedMatCts,2)),0.5)
	//Trim the first column from the matrices (this is a dummy column so p = amu typically)
	deletepoints /M=1 0,1,eDiffMatCts, diffMatCts
	// add electronic Noise
	redimension /N=(dimSize(eDiffMatCts,0), dimSize(eDiffMatCts,1)) eNoiseWave
	enoiseWave = enoiseWave[p][0]
	MatrixOp/O eDiffMatCts = powr((powr(eDiffMatCts,2) + powr(eNoiseWave,2)),0.5)
	//Remove NaNs
	eDiffMatCts = ACMCC_Deluxe_nan2zero(eDiffMatCts)
	DiffMatCts = ACMCC_Deluxe_nan2zero(diffMatCts)
	// These guys push the data through the matrix math
	ACMCC_PMF_ReSpeciateWholeTS(DiffMatCts,"Org","Org_Specs")
	ACMCC_PMFErr_ReSpeciateWholeTS(eDiffMatCts,"Org","OrgSpecs_err")
	wave org_specs = root:PMFMats:org_specs
	wave orgSpecs_err = root:PMFMats:orgSpecs_err
	ACMCC_PMFErr_ReSpeciateWholeTS(eDiffMatCts,"NO3","NO3Specs_err")
	wave NO3Specs_err = root:PMFMats:NO3Specs_err
	ACMCC_PMFErr_ReSpeciateWholeTS(eDiffMatCts,"SO4","SO4Specs_err")
	wave SO4Specs_err = root:PMFMats:SO4Specs_err
	ACMCC_PMFErr_ReSpeciateWholeTS(eDiffMatCts,"NH4","NH4Specs_err")
	wave NH4Specs_err = root:PMFMats:NH4Specs_err
	ACMCC_PMFErr_ReSpeciateWholeTS(eDiffMatCts,"Chl","ChlSpecs_err")
	wave ChlSpecs_err = root:PMFMats:ChlSpecs_err
	
	//Convert back to amps
	org_specs *= (GainW[0]/(6.24e18*DwellTW[0]))
	orgSpecs_err *= (GainW[0]/(6.24e18*DwellTW[0]))
	
	NO3Specs_err *= (GainW[0]/(6.24e18*DwellTW[0]))
	
	SO4Specs_err *= (GainW[0]/(6.24e18*DwellTW[0]))
	
	NH4Specs_err *= (GainW[0]/(6.24e18*DwellTW[0]))
	
	ChlSpecs_err *= (GainW[0]/(6.24e18*DwellTW[0]))
	
	// Replace low errors with min error really tiny errors can cause problems in PMF 
	minErrorW = ACMCC_Calc_MinError(GainW,DwellTW)
	orgSpecs_err = ACMCC_Replace_lessThan_withVal(orgSpecs_err[p][q],minErrorW[p],minErrorW[p])
	NO3Specs_err = ACMCC_Replace_lessThan_withVal(NO3Specs_err[p][q],minErrorW[p],minErrorW[p])
	SO4Specs_err = ACMCC_Replace_lessThan_withVal(SO4Specs_err[p][q],minErrorW[p],minErrorW[p])
	NH4Specs_err = ACMCC_Replace_lessThan_withVal(NH4Specs_err[p][q],minErrorW[p],minErrorW[p])
	ChlSpecs_err = ACMCC_Replace_lessThan_withVal(ChlSpecs_err[p][q],minErrorW[p],minErrorW[p])
	
	// Create an AMU wave
	make /O/N=(dimsize(org_specs,1)) amus = p+1
	// Convert data and error to ug/m3
	ACMCC_ApplyCalFactors(org_specs, "org")
	ACMCC_ApplyCalFactors(orgspecs_err, "org")
	ACMCC_ApplyCalFactors(NO3specs_err, "NO3")
	ACMCC_ApplyCalFactors(SO4specs_err, "SO4")
	ACMCC_ApplyCalFactors(NH4specs_err, "NH4")
	ACMCC_ApplyCalFactors(Chlspecs_err, "Chl")
	
	// Pull times wave to keep with the data...UTC! 
	Duplicate /O root:acsm_incoming:acsm_utc_time acsm_utc_time
	Duplicate /O root:acsm_incoming:acsm_local_time acsm_local_time
	//Make flag variables that we'll put up if we've applied downweighting so we don't do it twice!
	NVAR /Z weakDownWeightFlag
	if (!NVAR_Exists(weakDownweightFlag))
		variable /G weakDownweightFlag
	endif	
	weakDownWeightFlag = 0
	NVAR /Z m44relDownWeightFlag
	if (!NVAR_Exists(m44relDownweightFlag))
		variable /G m44relDownweightFlag
	endif
	m44relDownWeightFlag = 0
		NVAR /Z abCorrFlag
	if (!NVAR_Exists(abCorrFlag))
		variable /G abCorrFlag
	endif	
	abCorrFlag = 0
	// Find columns that are zero and remove them 
	// Remove m/z 19 and 20 since they are small and calculated from 44 (would require more downweighting to keep them)
	//remove_zero_columns_19and20()
	
	ACMCC_ApplyCorrectionForPMF()
	ACMCC_TrimPMFMats()
	
	MatrixOp/O Org_Specs = Org_Specs^t
	MatrixOp/O Orgspecs_err = Orgspecs_err^t
	MatrixOp/O NO3specs_err = NO3specs_err^t
	MatrixOp/O SO4specs_err = SO4specs_err^t
	MatrixOp/O NH4specs_err = NH4specs_err^t
	MatrixOp/O Chlspecs_err = Chlspecs_err^t
	
	Make/O/N=1 eOrg, eNO3, eSO4, eNH4, eChl
	
	string NO3str="13;29;30;31;45;46;47;62"
	string SO4str="15;16;17;18;19;23;31;32;33;47;48;49;51;63;64;65;79;80;81;82;83;84;97;98;99;101"
	string NH4str="14;15;16"
	string Clstr="34;35;36;37"
	
	Extract/O NO3specs_err,NO3specs_err, (p==13 || p==29 || p==30 || p==31 || p==45 || p==46 || p==47 || p==62)
	Extract/O NH4specs_err,NH4specs_err, (p==14 || p==15 || p==16)
	Extract/O Chlspecs_err,Chlspecs_err, (p==34 || p==35 || p==36 || p==37)
	Extract/O SO4specs_err,SO4specs_err, (p==15 || p==16 || p==17 || p==18 || p==19 || p==23 || p==31 || p==32 || p==33 || p==47 || p==48 || p==49 || p==51 || p==63 || p==64 || p==65 || p==79 || p==80 || p==81 || p==82 || p==83 || p==84 || p==97 || p==98 || p==99)
	
	
	//eOrg=ACMCC_quadraticSum(Orgspecs_err)
	//eNO3=ACMCC_quadraticSum(NO3specs_err)
	//eSO4=ACMCC_quadraticSum(SO4specs_err)
	//eNH4=ACMCC_quadraticSum(NH4specs_err)
	//eChl=ACMCC_quadraticSum(Chlspecs_err)
	
	eOrg=sum(Orgspecs_err)
	eNO3=sum(NO3specs_err)
	eSO4=sum(SO4specs_err)
	eNH4=sum(NH4specs_err)
	eChl=sum(Chlspecs_err)

End Function


Function ACMCC_Calc_MinError(gain, dwell_time)
variable gain
variable dwell_time
	variable a = 1.2
	variable error
	variable EperS = 6.24e18
	error = a * sqrt(2)*gain/(dwell_time*EperS)
return error
End

Function ACMCC_Deluxe_nan2zero(num)
//& Returns the number is real, 0 if not
    variable num
    return numtype(num)!=0?(0):(num)
End

Function ACMCC_ApplyCalFactors(waveToScale, speciesStr)
wave waveToScale
string speciesStr
if (numpnts(waveToScale) > 1)
	wave/T specNames = root:specname
	wave RIE = root:RIE
	wave CE = root:CE
	wave MassCalib_nitrate = root:massCalib_nitrate
	variable i, scalingFactor
	for (i=0; i< numpnts(RIE); i+=1)
		if (stringmatch(speciesStr, specNames[i]))
			scalingFactor = 1/(CE[i]*RIE[i]*massCalib_nitrate[0])
		endif	
	endfor	
	waveToScale *= scalingFactor
endif
End		


Function ACMCC_Replace_lessThan_withVal(num, val, lessThanVal)
variable num
variable val
variable lessThanVal
	return num < lessThanVal?(val):(num)
End


Function ACMCC_correctIonTransmission(msMat)
	Wave msMat
	string sf=getDataFolder(1)
	string ACMCC_ksa_ACSMPanelName="ACSM_ControlWindow"
	ControlInfo/W=$ACMCC_ksa_ACSMPanelName	an_RIT_Corr_ck
	switch(V_Value)
		case 0:
			wave itc = root:acsm:ion_transmission_correction
			break
		case 1:
			wave itc = root:RIT:averageRITFit
			break
	endswitch			
	msMat	/= itc(x)	
	setDataFolder $sf
End



Function ACMCC_PMF_ReSpeciateWholeTS(diffMat, specName, destStr)
wave diffMat
string SpecName,destStr
	string fragMatStr = "root:ms_mats:" + specName + "_mat"
	wave FragMat = $fragMatStr
	duplicate /O diffMat diffMatno1s
	// trim matrices to same amus as data and turn everything in the right direction
	variable amus = dimsize(diffMatNo1s,1)
	make /O/N=(amus,amus) tempFragMat = fragMat[p][q]
	matrixOp /O tempFragMat = tempFragMat^t
	MatrixOp /O tempDiffMat = diffMatNo1s^t
	// Do the multiplication then flip around again
	MatrixOp /O result = tempFragMat x tempDiffMat
	MatrixOp /O result = result^t
	// put the result where we want to
	duplicate /O result $destStr
	// kill the stuff we don't need
	killWaves tempFragMat, tempDiffMat, result
End


Function ACMCC_PMFErr_ReSpeciateWholeTS(diffMat, specName, destStr)
wave diffMat
string SpecName,destStr
	string fragMatStr = "root:ms_mats:" + specName + "_mat"
	wave FragMat = $fragMatStr
	duplicate /O diffMat diffMatno1s
	// trim matrices to same amus as data and turn everything in the right direction
	variable amus = dimsize(diffMatNo1s,1)
	make /O/N=(amus,amus) tempFragMat = fragMat[p][q]
	matrixOp /O tempFragMat = tempFragMat^t
	MatrixOp /O tempDiffMat = diffMatNo1s^t
	// Do the multiplication then flip around again
	MatrixOp/O tempFragMat = powr(tempFragMat,2)
	MatrixOp/O tempDiffMat = powr(tempDiffMat,2)
	MatrixOp /O result = tempFragMat x tempDiffMat
	MatrixOp /O result = result^t
	MatrixOp/O result = powr(result,0.5)
	// put the result where we want to
	duplicate /O result $destStr
	// kill the stuff we don't need
	killWaves tempFragMat, tempDiffMat, result
End



Function ACMCC_ApplyCorrectionForPMF()

	NVAR abCorrFlag = root:PMFMats:abCorrFlag


	wave org_specs = root:pmfmats:org_specs
	wave orgSpecs_err = root:pmfmats:orgSpecs_err
	//wave NO3_specs = root:pmfmats:NO3_specs
	wave NO3Specs_err = root:pmfmats:NO3Specs_err
	//wave SO4_specs = root:pmfmats:SO4_specs
	wave SO4Specs_err = root:pmfmats:SO4Specs_err
	//wave NH4_specs = root:pmfmats:NH4_specs
	wave NH4Specs_err = root:pmfmats:NH4Specs_err
	//wave Chl_specs = root:pmfmats:Chl_specs
	wave ChlSpecs_err = root:pmfmats:ChlSpecs_err
	
	
	
	wave/Z corrW = root:TimeSeries_corrections:smCorr_w
	duplicate /O corrW root:PMFMats:corrW

	org_specs[][] *= corrW[p]
	orgSpecs_err[][] *= corrW[p]
	//NO3_specs[][] *= corrW[p]
	NO3Specs_err[][] *= corrW[p]
	//SO4_specs[][] *= corrW[p]
	SO4Specs_err[][] *= corrW[p]
	//NH4_specs[][] *= corrW[p]
	NH4Specs_err[][] *= corrW[p]
	//Chl_specs[][] *= corrW[p]
	ChlSpecs_err[][] *= corrW[p]

end


Function ACMCC_TrimPMFMats()
	wave amus = root:pmfmats:amus
	NVAR/Z MaxMz=root:ACMCC_Export:MaxMz
	variable maxAMU=MaxMz
	wave org_specs = root:pmfmats:org_specs
	wave orgSpecs_err = root:pmfmats:orgSpecs_err
	//wave NO3_specs = root:pmfmats:NO3_specs
	wave NO3Specs_err = root:pmfmats:NO3Specs_err
	//wave SO4_specs = root:pmfmats:SO4_specs
	wave SO4Specs_err = root:pmfmats:SO4Specs_err
	//wave NH4_specs = root:pmfmats:NH4_specs
	wave NH4Specs_err = root:pmfmats:NH4Specs_err
	//wave Chl_specs = root:pmfmats:Chl_specs
	wave ChlSpecs_err = root:pmfmats:ChlSpecs_err
	variable pt = binarySearch(amus, maxAMU)
	variable n = numPnts(amus)
	deletepoints pt+1, n-pt, amus
	deletePoints /M=1 pt+1, n-pt, org_specs, orgSpecs_err ,NO3Specs_err,SO4Specs_err,NH4Specs_err,ChlSpecs_err
	
End


Function ACMCC_quadraticSum(wavetosum)
	wave wavetosum
	duplicate/O wavetosum temp
	temp*=temp
	return sqrt(sum(temp))
	killwaves/z temp
end function


Function ACMCC_ToF_Error()



End Function

/////////////////END OF ERROR FUNCTIONS ////////////////////////////////////////


Function ACMCC_DoSumOfRow(mx)
	wave mx
	variable i,j,nbrows,nbcols
	nbrows=dimsize(mx,0)
	nbcols=dimsize(mx,1)
	Make/O/N=(nbrows) $(Nameofwave(mx)+"_sum")
	wave rowSums=$(Nameofwave(mx)+"_sum")
	for (i=0;i<nbrows;i+=1)
		for(j=1;j<nbcols;j+=1)
			rowSums[i]+=mx[i][j]
		endfor
	endfor
End Function

Function ACMCC_PumpData(lastrow)
	variable lastrow
	
	SVAR/Z PumpDataFilePath=root:ACMCC_Export:Pump_path
	SVAR/Z PumpDataFilePrefix=root:ACMCC_Export:PumpDataFilePrefix
	
	string PumpDataFileName
	
	Wave ACSM_UTC_Time=root:acsm_incoming:acsm_utc_time
	string DateFromTime=secs2date(acsm_utc_time[lastrow],-2)
	PumpDataFileName=PumpDataFilePrefix+DateFromTime[0,3]+DateFromTime[5,6]+DateFromTime[8,9]+".txt"
	
	Make/O/N=1 TP3_T_avg,TP3_W_avg,TP3_S_avg,TP2_T_avg,TP2_W_avg,TP2_S_avg,TP1_T_avg,TP1_W_avg,TP1_S_avg
	
	GetFileFolderInfo/Q/Z=1  (PumpDataFilePath + PumpDataFileName)
	
	if (V_flag!=0)
		UpdateNoteBook("Pump file not found")
		TP1_S_avg=0
		TP1_W_avg=0
		TP1_T_avg=0
		TP2_S_avg=0
		TP2_W_avg=0
		TP2_T_avg=0
		TP3_S_avg=0
		TP3_W_avg=0
		TP3_T_avg=0
		return 0
	endif
	
	NewDataFolder/O/S root:ACMCC_Export:PumpData
	
	if (V_flag==0 && V_isfile)
		NewPath/Q/O filePath, PumpDataFilePath
		LoadWave /A/J/P=filePath/W/L={0,1,0,0,16}/K=1/O/Q PumpDataFileName
		killPath filePath
		// get rid of any NaNs caused by newStarts writing header lines
		string waveListStr = waveList("*",";","")
		variable i,j
		string wName = stringFromList(0,waveListStr)
		wave w = $wName
		for (i=0; i<numpnts(w); i+=1)
			if (numType(w[i]) == 2)
				for (j=0;j<itemsInList(wavelistStr); j+=1)
					string wName2 = stringfromList(j,wavelistStr) 
					wave ww = $wName2
					deletepoints i,1,ww
				endfor
				i-=1
			endif
		endfor
		
		//SetDataFolder root:ACSM_Incoming
		//wave acsm_utc_time
//		duplicate/O acsm_local_time, root:ACMCC_Export:PumpData:timeline
//		SetDataFolder root:ACMCC_Export:PumpData
//		wave timeline,P_DateTime,P1_S,P1_W,P1_T,P2_S,P2_W,P2_T,P3_S,P3_W,P3_T
//	
//		ACMCC_Avg_WaveList(P_DateTime,"P1_S;P1_W;P1_T;P2_S;P2_W;P2_T;P3_S;P3_W;P3_T",timeline)
//		wave P1_S_avg,P1_W_avg,P1_T_avg,P2_S_avg,P2_W_avg,P2_T_avg,P3_S_avg,P3_W_avg,P3_T_avg
//		
//		TP1_S=P1_S_avg[-2]
//		TP1_W=P1_W_avg[-2]
//		TP1_T=P1_T_avg[-2]
//		TP2_S=P2_S_avg[-2]
//		TP2_W=P2_W_avg[-2]
//		TP2_T=P2_T_avg[-2]
//		TP3_S=P3_S_avg[-2]
//		TP3_W=P3_W_avg[-2]
//		TP3_T=P3_T_avg[-2]

		wave P_DateTime,P1_S,P1_W,P1_T,P2_S,P2_W,P2_T,P3_S,P3_W,P3_T
		Make/O/N=1 TP3_T_avg,TP3_W_avg,TP3_S_avg,TP2_T_avg,TP2_W_avg,TP2_S_avg,TP1_T_avg,TP1_W_avg,TP1_S_avg
		i=BinarySearch(P_DateTime,ACSM_UTC_Time[lastrow])
		j=BinarySearch(P_DateTime,ACSM_UTC_Time[lastrow-1])
		j=max(0,j)
		TP3_T_avg=mean(P3_T,j,i)
		TP3_S_avg=mean(P3_S,j,i)
		TP3_W_avg=mean(P3_W,j,i)
		TP2_T_avg=mean(P2_T,j,i)
		TP2_S_avg=mean(P2_S,j,i)
		TP2_W_avg=mean(P2_W,j,i)
		TP1_T_avg=mean(P1_T,j,i)
		TP1_S_avg=mean(P1_S,j,i)
		TP1_W_avg=mean(P1_W,j,i)

	endif
	
End


Function ACMCC_avg(Conc_Wave, Date_Wave,Timeline)
	wave Conc_Wave,Date_Wave,Timeline
	
	duplicate/O Conc_wave temp_conc
	duplicate/O Date_Wave, temp_date
	
	temp_date[]=(numtype(temp_conc[p])==2) ? NaN : temp_date[p]
	
	WaveTransform zapNaNs temp_date
	WaveTransform zapNaNs temp_conc
	
	string ConcWaveName=NameOfWave(Conc_Wave)+"_avg"
	Make/O/N=(numpnts(Timeline)) temp_avg
	variable i,j,k
	for (i=0;i<numpnts(Timeline)-1;i+=1)
		j=BinarySearch(temp_date,Timeline[i])
		k=BinarySearch(temp_date,Timeline[i+1])
		if (j==k)
			temp_avg[i]=nan
			continue
		endif
		temp_avg[i]=mean(temp_conc,j,k-1)
	endfor
	duplicate/O temp_avg $ConcWaveName
	KillWaves temp_avg,temp_conc,temp_date
End Function


Function ACMCC_Avg_WaveList(Date_Wave,ListOfWaves,Timeline)
	wave Date_Wave, Timeline
	string ListOfWaves
	
	variable nbelemlist=ItemsInList(ListofWaves)
	variable i
	string WaveNameToUse
	
	for(i=0;i<nbelemlist;i+=1)
		WaveNameToUse=StringFromList(i,ListofWaves)
		wave temp=$WaveNameToUse
		ACMCC_avg(temp, Date_Wave,Timeline)
	endfor
End Function



Function ACMCC_Determinehour(dt)
	Variable dt					// Input date/time value
	Variable time = mod(dt, 24*60*60)	// Get the time component of the date/time
	return trunc(time/(60*60))
End




Function ACMCC_DryerStat_avg(lastrow)
	variable lastrow

	string file_prefix="DryerStats_"
	Wave ACSM_UTC_Time=root:acsm_incoming:acsm_utc_time
	string DateFromTime=secs2date(acsm_utc_time[lastrow],-2)
	string DryerFileName=file_prefix+DateFromTime[0,3]+DateFromTime[5,6]+DateFromTime[8,9]+".txt"
	
	SVAR/Z DryerStat_path=root:ACMCC_Export:DryerStat_path
	NewPath/O/Q/Z DryerDataDir, DryerStat_path	
	KillDataFolder/Z root:ACMCC_Export:DryerData
	NewDataFolder/O/S root:ACMCC_Export:DryerData
	Make/O/N=1 RH_In_avg,T_In_avg,Dp_In_avg,RH_Out_Avg,T_Out_avg,Dp_Out_avg,FlowR_avg,P_Drop_avg
	GetFileFolderInfo/P=DryerDataDir/Q/Z DryerFileName
	if (V_flag!=0)
		UpdateNoteBook("Dryer file not found")
		return 0
	endif
	
	
	LoadWave /J/A/B="F=-2,N=DateTimeW;F=0,N=InletP;F=0,N=CounterP;F=0,N=PDrop;F=0,N=FlowRate;F=0,N=RHIn;F=0,N=TIn;F=0,N=RHDry;F=0,N=TDry;"/L={0,1,0,0,0}/D/O/P=DryerDataDir/Q DryerFileName
	wave DateTimeW
	ACMCC_TextWavesToDateTimeWave(dateTimeW, "DateTimeWave")
	wave DateTimeWave
	wave InletP,CounterP,PDrop,FlowRate,RHIn,TIn,RHDry,TDry
	concatenate /NP/KILL {DateTimeWave}, datW
	concatenate /NP/KILL {InletP}, InletPW
	concatenate /NP/KILL {CounterP}, CounterPW
	concatenate /NP/KILL {PDrop}, PDropW
	concatenate /NP/KILL {FlowRate}, FlowRateW
	concatenate /NP/KILL {RHIn}, RHInW
	concatenate /NP/KILL {TIn}, TInW		
	concatenate /NP/KILL {RHDry}, RHDryW
	concatenate /NP/KILL {TDry}, TDryW
	variable i,j
	string DateFromTimeBefore=secs2date(acsm_utc_time[lastrow-1],-2)
	string DryerFileNameBefore=file_prefix+DateFromTimeBefore[0,3]+DateFromTimeBefore[5,6]+DateFromTimeBefore[8,9]+".txt"
	
	if (!stringmatch(DryerFileName,DryerFileNameBefore))
		GetFileFolderInfo/P=DryerDataDir/Q/Z DryerFileNameBefore
		if (V_flag==0)
			LoadWave /J/A/B="F=-2,N=DateTimeW;F=0,N=InletP;F=0,N=CounterP;F=0,N=PDrop;F=0,N=FlowRate;F=0,N=RHIn;F=0,N=TIn;F=0,N=RHDry;F=0,N=TDry;"/L={0,1,0,0,0}/D/O/P=DryerDataDir/Q DryerFileNameBefore
			wave DateTimeW
			ACMCC_TextWavesToDateTimeWave(dateTimeW, "DateTimeWave")
			wave DateTimeWave
			wave InletP,CounterP,PDrop,FlowRate,RHIn,TIn,RHDry,TDry
			concatenate /NP/KILL {DateTimeWave}, datW
			concatenate /NP/KILL {InletP}, InletPW
			concatenate /NP/KILL {CounterP}, CounterPW
			concatenate /NP/KILL {PDrop}, PDropW
			concatenate /NP/KILL {FlowRate}, FlowRateW
			concatenate /NP/KILL {RHIn}, RHInW
			concatenate /NP/KILL {TIn}, TInW		
			concatenate /NP/KILL {RHDry}, RHDryW
			concatenate /NP/KILL {TDry}, TDryW
		endif
	endif
	make/O/N=(numpnts(RHInW)) dewPtInW = ACMCC_Calculate_Dp(RHInW, TInW)
	make/O/N=(numpnts(RHDryW)) dewPtDryW = ACMCC_Calculate_Dp(RHDryW, TDryW)
	duplicate/O dewPtInW dDewPtW
	dDewPtW -= dewPtDryW
	
	Make/O/N=1 RH_In_avg,T_In_avg,Dp_In_avg,RH_Out_Avg,T_Out_avg,Dp_Out_avg,FlowR_avg,P_Drop_avg
	i=BinarySearch(datW,acsm_utc_time[lastrow])
	j=BinarySearch(datW,acsm_utc_time[lastrow-1])
	
	if (i!=j)
		RH_In_avg=mean(RHInW,j,i)
		T_In_avg=mean(TInW,j,i)
		Dp_In_avg=mean(dewPtInW,j,i)
		RH_Out_Avg=mean(RHDryW,j,i)
		T_Out_avg=mean(TDryW,j,i)
		Dp_Out_avg=mean(dewPtDryW,j,i)
		FlowR_avg=mean(FlowRateW,j,i)
		P_Drop_avg=mean(PDropW,j,i)
	endif
	
	
	KillWaves/Z DatetimeW, datW, InletPW,CounterPW,PDropW,FlowRateW,RHInW,RHDryW,TInW,TDryW,dewPtInW,dewPtDryW,dDewPtW

	
End Function

Function ACMCC_Calculate_Dp(RH,T)
	variable RH, T
	variable dewPt
	DewPt = 243.04*(LN(RH/100)+((17.625*T)/(243.04+T)))/(17.625-LN(RH/100)-((17.625*T)/(243.04+T))) 
return dewPt
End

Function/S ACMCC_ExtractDateInfo(dt,dateinfo)
	variable dt					// Input date/time value
 	string dateinfo
 	
	String shortDateStr = Secs2Date(dt, -1)		// <day-of-month>/<month>/<year> (<day of week>)
 
	Variable dayOfMonth, month, year, dayOfWeek
	sscanf shortDateStr, "%d/%d/%d (%d)", dayOfMonth, month, year, dayOfWeek
 	
 	string year_txt, month_txt, dayOfMonth_txt
 	
 	if (stringmatch(dateinfo,"year"))
 		year_txt=num2str(year)
 		return year_txt
 	elseif (stringmatch(dateinfo,"month"))
 		if (month<10)
 			month_txt="0"+num2str(month)
 		else
 			month_txt=num2str(month)
 		endif
 		return month_txt
 	elseif (stringmatch(dateinfo,"dayOfMonth"))
 		if (dayOfMonth < 10)
 			dayOfMonth_txt="0"+num2str(dayOfMonth)
 		else
 			dayOfMonth_txt=num2str(dayOfMonth)
 		endif
 		return dayOfMonth_txt
 	endif
End

Function/S ACMCC_ExtractTimeInfo(dt,timeinfo)
	variable dt
	string timeinfo
	
	variable time
	string hour, minute, second
	
	if (stringmatch(timeinfo,"hour"))
		time = mod(dt,24*60*60)
		if (trunc(time/3600) < 10)
			hour="0"+num2str(trunc(time/3600))
		else
			hour=num2str(trunc(time/3600))
		endif
 		return hour
 	elseif (stringmatch(timeinfo,"minute"))
 		time = mod(dt,3600)
 		if (trunc(time/60) < 10)
 			minute="0"+num2str(trunc(time/60))
 		else
 			minute=num2str(trunc(time/60))
 		endif
 		return minute
 	elseif (stringmatch(timeinfo,"second"))
 		time = mod(dt,60)
 		if (trunc(time) < 10)
 			second="0"+num2str(trunc(time))
 		else
 			second=num2str(trunc(time))
 		endif
 		return second
 	endif
	
End Function

Function ACMCC_ConvertTextToDateTime(datetimeAsText)
    String datetimeAsText       // Assumed in YYYY-MM-DD format
   
    Variable dt
    Variable year, month, day, hour, minute, second
    sscanf datetimeAsText, "%d/%d/%d %d:%d:%d", month, day, year, hour, minute, second
    dt = Date2Secs(year, month, day)
    Variable timeOfDay
    timeOfDay = 3600*hour + 60*minute + second
   
    dt += timeOfDay
   
    return dt
End



Function/WAVE ACMCC_TextWavesToDateTimeWave(datetimeAsTextWave, outputWaveName)
    WAVE/T datetimeAsTextWave       // Assumed in YYYY-MM-DD format
    String outputWaveName

    Variable numPoints = numpnts(datetimeAsTextWave)
    Make/O/D/N=(numPoints) $outputWaveName
    WAVE wOut = $outputWaveName
    SetScale d, 0, 0, "dat", wOut
   
    Variable i
    for(i=0; i<numPoints; i+=1)
        String datetimeAsText = datetimeAsTextWave[i]
        Variable dt = ACMCC_ConvertTextToDateTime(datetimeAsText)
        wOut[i] = dt   
    endfor 
   
    return wOut
End

macro ACMCC_getConst_version_acsm()
	string/G root:ACMCC_Export:tempStr = versionStr
endmacro


Function/t ACMCC_getConst_wrapper(exCall)
	//wrapper function for retrieving constants that may not exist (depending on which ipfs are present)
	string exCall //name of retrieval macro
	
	execute exCall+"()"
	svar tempStr = root:ACMCC_Export:tempStr
	string destStr = tempStr
	killstrings tempStr
	return destStr
end


Function/T ACMCC_MakeAndOrSetDF( data_folder )
	string data_folder
	
	string old_DF = GetDataFolder(1)
	setdatafolder root:
	if( !DataFolderExists( data_folder ) )
		NewDataFolder $data_folder
	endif
	SetDataFolder $data_folder
	return old_DF
End


Function NasGen(filenameStr,FlagfilenameStr)
	string filenameStr, FlagfilenameStr
	
	SVAR/Z Script_path=root:ACMCC_Export:Script_path
	SVAR/Z DataForPython_path=root:ACMCC_Export:DataForPython_path
	
	string ParsedScript_path=ParseFilePath(5,Script_path,"\\",0,0)
	
	wave/T StationNameW=root:ACMCC_Export:StationNameW
	string station=StationNameW[0]
	
	string Batch_str=""
	Batch_str+="@echo off;"
	Batch_str+="REM set conda_root='C:\Users\jepetit\Anaconda3\';"
	Batch_str+="REM echo '- load conda env -';"
	Batch_str+="REM call %conda_root%\Scripts\activate.bat %conda_root%;"
	Batch_str+="echo '- start process -';"
	Batch_str+="cd " + ParsedScript_path+";"
	Batch_str+="python src\\rawto012.py data\\" +station
	Batch_str+="\\in\\" + filenameStr
	Batch_str+=" data\\" +station
	Batch_str+="\\in\\" + FlagfilenameStr
	Batch_str+=" data\\" +station
	Batch_str+="\\out\\;"
	
	Batch_str+="pause;"
	
	Make/T/O/N=(ItemsInList(batch_str, ";")) batch_txt
	batch_txt = StringFromList(p, batch_str, ";")
	
	Newpath/O/Q BatchPath, Script_path
	Save/T/G/O/M="\r\n"/P=BatchPath Batch_txt as "ACSM_converter.bat"
	
	string batch_path=ParsedScript_path+"ACSM_converter.bat"
	string batch_txt1
	sprintf batch_txt1, "cmd.exe /C \"%s\"", batch_path
	//executescripttext/Z/B batch_txt1
	

End Function


Function ACMCC_RecreateAllFiles()

	wave DateW=root:ACSM_Incoming:acsm_utc_time
	variable i
	for(i=0;i<numpnts(DateW);i+=1)
		ACMCC_Quad_ExportOneRow(i)
	endfor
End Function



Function ACMCC_Quad_ExportOneRow(lastrow)
	
	variable lastrow
	
	SetDataFolder root:ACMCC_Export
	
	//Get IE, RIE and CE values
	Make/N=1/D/O IE_NO3, RIE_NH4, RIE_SO4, RIE_NO3, RIE_OM, RIE_Cl, CE
	wave RIE_W=root:RIE
	RIE_OM=RIE_W[0]
	RIE_NH4=RIE_W[1]
	RIE_SO4=RIE_W[2]
	RIE_NO3=RIE_W[3]
	RIE_Cl=RIE_W[4]
	wave MC_NO3=root:Masscalib_nitrate
	IE_NO3=MC_NO3[0]
	wave CEW=root:CE
	CE=CEW[0]
	
	//Get Date
	Make/N=1/O/T ACSM_time
	wave DateW=root:ACSM_Incoming:acsm_utc_time
	//variable lastrow=numpnts(DateW)-1
	
	string year=ACMCC_ExtractDateInfo(DateW[lastrow],"year")
	string month=ACMCC_ExtractDateInfo(DateW[lastrow],"month")
	string dayOfMonth=ACMCC_ExtractDateInfo(DateW[lastrow],"dayOfMonth")
	string hour=ACMCC_ExtractTimeInfo(DateW[lastrow],"hour")
	string minute=ACMCC_ExtractTimeInfo(DateW[lastrow],"minute")
	string second=ACMCC_ExtractTimeInfo(DateW[lastrow],"second")
	
	ACSM_time=year+"/"+month+"/"+dayofmonth+" "+hour+":"+minute+":"+second
	
	//Get Concentrations
	Make/O/N=1 OM,NO3,SO4,NH4,Cl
	wave OrgW=root:Time_Series:Org
	wave NO3W=root:Time_Series:NO3
	wave SO4W=root:Time_Series:SO4
	wave NH4W=root:Time_Series:NH4
	wave ClW=root:Time_Series:Chl
	OM=OrgW[lastrow]
	NO3=NO3W[lastrow]
	SO4=SO4W[lastrow]
	NH4=NH4W[lastrow]
	Cl=ClW[lastrow]
	
	
	//Apply CE correction
	NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
	if (ApplyMiddlebrook==1)
		Duplicate/o SO4 PredNH4, NH4_MeasToPredict, ANMF
		PredNH4=18*(SO4/96*2+NO3/62+Cl/35.45)
		NH4_MeasToPredict=NH4/PredNH4
		ANMF=(80/62)*NO3/(NO3+SO4+NH4+OM+Cl)
		If (NH4_MeasToPredict[0]<0)
			NH4_MeasToPredict[0]=nan
		EndIf
		//	Nan ANMF points if negative or more than 1
		If (ANMF[0]<0)
			ANMF[0]=nan
		ElseIf (ANMF[0]>1)
			ANMF[0]=nan
		EndIf
			
		If (PredNH4[0]<0.5)
			CE[0]=0.5
		ElseIf (NH4_MeasToPredict[0]>=0.75)
			//	Apply Equation 4
			CE[0]= 0.0833+0.9167*ANMF[0]
		ElseIf (NH4_MeasToPredict[0]<0.75)
			//	Apply Equation 6
			CE[0]= 1-0.73*NH4_MeasToPredict[0]
		EndIf
		
		CE=min(1,(max(0.5,CE)))
		KillWaves ANMF, PredNH4, NH4_MeasToPredict 
		SO4*=CEW[0]/CE
		NH4*=CEW[0]/CE
		NO3*=CEW[0]/CE
		Cl*=CEW[0]/CE
		OM*=CEW[0]/CE
	endif
	
	
	//Get Diagnostics
	Make/O/N=1 RF, ChamberT, Airbeam, NewStart_Events, InletPClosed, InletPOpen, InletP, VapT
	wave RFW=root:diagnostics:RF
	wave ChamberTW=root:diagnostics:ChamberT
	wave AirbeamW=root:diagnostics:Airbeam
	wave NSE=root:diagnostics:NewStart_Events
	wave IPC=root:diagnostics:InletPClosed
	wave IPO=root:diagnostics:InletPOpen
	wave IP=root:diagnostics:InletP
	wave VapTW=root:diagnostics:VapT
	
	RF=RFW[lastrow]
	ChamberT=ChamberTW[lastrow]
	Airbeam=AirbeamW[lastrow]
	NewStart_Events=NSE[lastrow]
	InletPClosed=IPC[lastrow]
	InletPOpen=IPO[lastrow]
	InletP=IP[lastrow]
	VapT=VapTW[lastrow]
	
	//Get Tuning Var
	Make/O/N=1 EmCurrent, SEMVol, HeaterBias, VapV
	wave DAQ=root:acsm_incoming:DAQ_Matrix
	EmCurrent=DAQ[lastrow][6]
	SEMVol=DAQ[lastrow][7]
	HeaterBias=5 + DAQ[lastrow][2]*200/5
	VapV=DAQ[lastrow][28]
	
	//Get f_Org & f_NO3 values
	Make/O/N=1 OM_f44, OM_f43, OM_f60, NO3_f30, NO3_f46
	NewDataFolder/S/O root:ACMCC_Export:Temp
	wave OrgMx=root:ACSM_Incoming:OrgStickMatrix
	wave NO3Mx=root:ACSM_Incoming:NO3StickMatrix
	
	ACMCC_DoSumOfRow(OrgMx)
	ACMCC_DoSumOfRow(NO3Mx)
	wave OrgStickMatrix_sum
	wave NO3StickMatrix_sum
	OM_f44=OrgMx[lastrow][44]/OrgStickMatrix_sum[lastrow]
	OM_f43=OrgMx[lastrow][43]/OrgStickMatrix_sum[lastrow]
	OM_f60=OrgMx[lastrow][60]/OrgStickMatrix_sum[lastrow]
	NO3_f30=NO3Mx[lastrow][30]/NO3StickMatrix_sum[lastrow]
	NO3_f46=NO3Mx[lastrow][46]/NO3StickMatrix_sum[lastrow]
	KillDataFolder/Z root:ACMCC_Export:Temp
	SetDataFolder root:ACMCC_Export

	//Get general info
	Make/O/N=1/T acsm_local_version
	
	//acsm_local_version=versionStr
	acsm_local_version=stringfromlist(0, ACMCC_getConst_wrapper("ACMCC_getConst_version_acsm"), " ")
	//acsm_local_version=""
	Make/O/N=1/T ACMCC_export_ver
	ACMCC_export_ver=ACMCC_Export_version
	Make/O/N=1/T SerialNumber
	wave DAQ=root:acsm_incoming:DAQ_Matrix
	string temp_str
	sprintf temp_str, "%6d",DAQ[lastrow][74]
	SerialNumber=temp_str
	
	//Get Pump Diagnostics
	SetDataFolder root:ACMCC_Export	
	Make/O/N=1 TP1_S,TP1_W,TP1_T,TP2_S,TP2_W,TP2_T,TP3_S,TP3_W,TP3_T
	NVAR/Z PumpBool=root:ACMCC_Export:PumpBool
	if(PumpBool==1)
		ACMCC_PumpData(lastrow)
		wave TP1_S_avg=root:ACMCC_Export:PumpData:TP1_S_avg
		wave TP1_W_avg=root:ACMCC_Export:PumpData:TP1_W_avg
		wave TP1_T_avg=root:ACMCC_Export:PumpData:TP1_T_avg
		wave TP2_S_avg=root:ACMCC_Export:PumpData:TP2_S_avg
		wave TP2_W_avg=root:ACMCC_Export:PumpData:TP2_W_avg
		wave TP2_T_avg=root:ACMCC_Export:PumpData:TP2_T_avg
		wave TP3_S_avg=root:ACMCC_Export:PumpData:TP3_S_avg
		wave TP3_W_avg=root:ACMCC_Export:PumpData:TP3_W_avg
		wave TP3_T_avg=root:ACMCC_Export:PumpData:TP3_T_avg
		TP1_S=TP1_S_avg
		TP1_W=TP1_W_avg
		TP1_T=TP1_T_avg
		TP2_S=TP2_S_avg
		TP2_W=TP2_W_avg
		TP2_T=TP2_T_avg
		TP3_S=TP3_S_avg
		TP3_W=TP3_W_avg
		TP3_T=TP3_T_avg
	endif

	//Get Dryer Stats
	SetDataFolder root:ACMCC_Export:
	Make/O/N=1 Sampling_Flowrate, RH_In, RH_Out, T_In, T_Out
	NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	if(DryerBool==1)
		ACMCC_DryerStat_avg(lastrow)
		wave FlowR_avg=root:ACMCC_Export:DryerData:FlowR_avg
		wave T_In_avg=root:ACMCC_Export:DryerData:T_In_avg
		wave T_Out_avg=root:ACMCC_Export:DryerData:T_Out_avg
		wave RH_In_avg=root:ACMCC_Export:DryerData:RH_In_avg
		wave RH_Out_avg=root:ACMCC_Export:DryerData:RH_Out_avg
		Sampling_Flowrate=FlowR_avg[0]
		T_In=T_In_avg[0]
		T_Out=T_Out_avg[0]
		RH_In=RH_In_avg[0]
		RH_Out=RH_Out_avg[0]
	endif
	
	//Get Concentration Errors
	SetDataFolder root:ACMCC_Export	
	Make/O/N=1 OM_err, NO3_err, SO4_err, NH4_err, Cl_err
	ACMCC_Quad_Error(lastrow)
	wave eChl=root:PMFMats:eChl
	wave eOrg=root:PMFMats:eOrg
	wave eSO4=root:PMFMats:eSO4
	wave eNO3=root:PMFMats:eNO3
	wave eNH4=root:PMFMats:eNH4
	OM_err=eOrg
	NO3_err=eNO3
	SO4_err=eSO4
	NH4_err=eNH4
	Cl_err=eChl
	
	//Create Table & Save
	variable i
	i=0
	
	SetDataFolder root:ACMCC_Export
	string saveWavesList="ACSM_time;OM;NO3;SO4;NH4;Cl;IE_NO3;RIE_OM;RIE_NO3;RIE_SO4;RIE_NH4;RIE_Cl;CE;"
	saveWavesList+="RF;ChamberT;Airbeam;NewStart_Events;InletPClosed;InletPOpen;InletP;VapT;"
	saveWavesList+="EmCurrent;SEMVol;HeaterBias;VapV;"
	saveWavesList+="OM_f44;OM_f43;OM_f60;NO3_f30;NO3_f46;"
	saveWavesList+="acsm_local_version;ACMCC_export_ver;"
	saveWavesList+="TP1_S;TP1_W;TP1_T;TP2_S;TP2_W;TP2_T;TP3_S;TP3_W;TP3_T;"
	saveWavesList+="Sampling_Flowrate;RH_In;RH_Out;T_In;T_Out;"
	saveWavesList+="OM_err;NO3_err;SO4_err;NH4_err;Cl_err;"
	saveWavesList+="Tof_QuadW;LensW;VaporizerW;"
	
	SetDataFolder root:ACMCC_Export
	wave/T VaporizerW,LensW,ToF_QuadW
	for (i=0;i<itemsInList(saveWavesList);i+=1)
		wave w = $stringFromList(i,saveWavesList)
		if (i==0)
			Edit /N=ExportTable w
		else
			AppendToTable /W=ExportTable w
		endif
	endfor
	
	SetDataFolder root:ACMCC_Export
	Wave/T SerialNumber
	Wave/T StationNameW
	
	string FileName=StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_"
	FileName+=year+month+dayofmonth+hour+minute+".txt"
	
	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	string DataPathbis=NextCloud_path
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+="ACMCC_Export:"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+=year+":"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+=month+":"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+=dayOfMonth+":"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	
	ModifyTable/W=ExportTable format(ACSM_time)=8
	saveTableCopy/O/T=1/W=ExportTable/P=SaveDataFilePathbis as FileName
	
	
	//NASA-AMES Script
//	SVAR/Z DataForPython_path=root:ACMCC_Export:DataForPython_path
//	string DataConverterPath=DataForPython_path
//	NewPath/Q/O/C SaveDataConverterPath, DataConverterPath
//	saveTableCopy/O/T=1/W=ExportTable/P=SaveDataConverterPath as FileName
//	
//	string FlagFileName=StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_FLAGS_"
//	FlagFileName+=year+month+dayofmonth+hour+minute+".txt"
//	Make/O/N=1 numflag_OM, numflag_NO3, numflag_SO4, numflag_NH4, numflag_Cl
//	Edit /N=FlagTable ACSM_time
//	AppendToTable /W=FlagTable numflag_OM, numflag_NO3, numflag_SO4, numflag_NH4, numflag_Cl
//	ModifyTable/W=FlagTable format(ACSM_time)=8
//	saveTableCopy/O/T=1/W=FlagTable/P=SaveDataConverterPath as FlagFileName
//	KillWindow FlagTable
//	NasGen(FileName,FlagFileName)
	//
	
	KillWindow ExportTable
	
	
	NVAR/Z GeneratePMFInput=root:ACMCC_Export:GeneratePMFInput
	if (GeneratePMFInput==1)
		SetDataFolder root:ACMCC_Export
		duplicate/O root:PMFMats:Org_Specs Org_Specs
		duplicate/O root:PMFMats:Orgspecs_err Orgspecs_err
		duplicate/O root:PMFMats:amus amus
		
		if (ApplyMiddlebrook==1)
			Org_Specs*=CEW[0]/CE
			Orgspecs_err*=CEW[0]/CE
		endif
		
		Edit/N=PMFExportTable ACSM_time
		AppendToTable /W=PMFExportTable amus
		AppendToTable /W=PMFExportTable Orgspecs_err
		AppendToTable /W=PMFExportTable Org_Specs
		ModifyTable/W=PMFExportTable format(ACSM_time)=8
		
		FileName=StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_"+"PMF_"+year+month+dayofmonth+hour+minute+".txt"
		saveTableCopy/O/T=1/W=PMFExportTable/P=SaveDataFilePathbis as FileName
		KillWindow PMFExportTable
	endif
	
	NVAR/Z GenerateSoFi=root:ACMCC_Export:GenerateSoFi
	if (GenerateSoFi==1)
		ACMCC_ExportSoFiOneRow(lastrow)
	endif
	
End Function


Function ACMCC_ExportSoFiOneRow(lastrow)

	variable lastrow

	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	string DataPathbis=NextCloud_path
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+="SoFi:"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	
	NewDataFolder/O/S root:ACMCC_Export:SoFi
	wave DateW=root:ACSM_Incoming:acsm_utc_time
	//variable lastrow=numpnts(DateW)-1
	wave aut = root:acsm:file_fpfile_list_dat
	duplicate/O aut alt
	wave DAQ_Matrix = root:acsm_incoming:DAQ_Matrix
	alt = -1*(DAQ_Matrix[p][51] * 3600) + aut
	
	wave mzbool=root:ACMCC_Export:mzbool
	
	wave chT = root:diagnostics:chamberT
	wave ab = root:diagnostics:airbeam
	wave ip = root:diagnostics:inletP
	wave vt = root:diagnostics:vapT
	wave/Z Org_pt = root:Time_Series:Org
	wave/Z SO4_pt = root:Time_Series:SO4
	wave/Z NO3_pt = root:Time_Series:NO3
	wave/Z NH4_pt = root:Time_Series:NH4
	wave/Z Chl_pt = root:Time_Series:Chl
	wave/Z Masscalib_nitrate_pt = root:Masscalib_nitrate
	
	wave Org_Specs_pt=root:PMFMats:Org_Specs
	wave amus_pt=root:PMFMats:amus
	wave Orgspecs_err_pt=root:PMFMats:Orgspecs_err
	
	string wlStr = "org_specs;orgSpecs_err;amus;acsm_utc_time;acsm_local_time;chamberT;airbeam;inletP;vapT;CE;Masscalib_nitrate;Org;SO4;NO3;NH4;Chl"

	wave/T StationNameW=root:ACMCC_Export:StationNameW
	wave/T SerialNumber=root:ACMCC_Export:SerialNumber
	
	wave CEW=root:CE
	wave CE_ACMCC=root:ACMCC_Export:CE
	
	string dstr
	dstr = secs2date(aut[lastrow], -2)
	dstr = StationNameW[0]+"_ACSM-"+SerialNumber[0]+"_RTdata_" + dstr[0,3]+"_"+dstr[5,6]+"_"+dstr[8,9] + ".itx"
	//dstr = "RTdata_" + dstr[0,3]+"_"+dstr[5,6]+"_"+dstr[8,9] + ".itx"
	GetFileFolderInfo /Z/Q/P=SaveDataFilePathbis dstr
	
	if(V_flag != 0) //file doesn't exist- create waves for it and write them
		
		duplicate/O Org_Specs_pt Org_Specs
		duplicate/O Orgspecs_err_pt Orgspecs_err
		duplicate/O amus_pt amus
		
		Extract/O Orgspecs_err, Orgspecs_err, mzbool==1
		Extract/O amus, amus, mzbool==1
		Extract/O Org_Specs, Org_Specs, mzbool==1
		
		NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
		
		if (ApplyMiddlebrook==1)
			Org_Specs*=CEW[0]/CE_ACMCC[0]
			Orgspecs_err*=CEW[0]/CE_ACMCC[0]
		endif
		
		MatrixOp /O Org_Specs = Org_Specs^t
		MatrixOp /O Orgspecs_err = Orgspecs_err^t
		
		make/D/O/N=1 acsm_utc_time; acsm_utc_time[0] = aut[lastrow]
		make/D/O/N=1 acsm_local_time; acsm_local_time[0] = alt[lastrow]
		make/D/O/N=1 ChamberT; chamberT[0] = chT[lastrow]
		make/D/O/N=1 airbeam; airbeam[0] = ab[lastrow]
		make/O/N=1 inletP; inletP[0] = ip[lastrow]
		make/O/N=1 vapT; vapT[0] = vt[lastrow]
		make/O/N=1 CE; CE[0] = CE_ACMCC[0]
		make/O/N=1 Masscalib_nitrate; Masscalib_nitrate[0] = Masscalib_nitrate_pt[0]
	
		make/O/N=1 Org; Org[0] = Org_pt[lastrow]
		make/O/N=1 SO4; SO4[0] = SO4_pt[lastrow]
		make/O/N=1 NO3; NO3[0] = NO3_pt[lastrow]
		make/O/N=1 NH4; NH4[0] = NH4_pt[lastrow]
		make/O/N=1 Chl; Chl[0] = Chl_pt[lastrow]
		
		Save /B/P=SaveDataFilePathbis /T wlStr as dstr
		
	
	else //file exists - load in the data and append to it
		
		duplicate/O Org_Specs_pt Org_Specs_temp
		duplicate/O Orgspecs_err_pt Orgspecs_err_temp
		//duplicate/O amus_pt amus
		
		Extract/O Orgspecs_err_temp, Orgspecs_err_temp, mzbool==1
		Extract/O amus, amus, mzbool==1
		Extract/O Org_Specs_temp, Org_Specs_temp, mzbool==1
		
		NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
		
		if (ApplyMiddlebrook==1)
			Org_Specs_temp*=CEW[0]/CE_ACMCC[0]
			Orgspecs_err_temp*=CEW[0]/CE_ACMCC[0]
		endif
		
		MatrixOp /O Org_Specs_temp = Org_Specs_temp^t
		MatrixOp /O Orgspecs_err_temp = Orgspecs_err_temp^t
		
		loadwave/O/Q/T/P=SaveDataFilePathbis dstr

		wave/Z org_specs, orgSpecs_err,  acsm_utc_time, acsm_local_time, ChamberT, airbeam, inletP, vapT, CE
		variable n = numpnts(acsm_utc_time)
		insertPoints n, 1, org_specs, orgSpecs_err, acsm_utc_time, acsm_local_time, ChamberT, airbeam, inletP, vapT, CE, Masscalib_nitrate
		org_specs[n][] = Org_Specs_temp[0][q]
		orgSpecs_err[n][] = Orgspecs_err_temp[0][q]
		acsm_utc_time[n] = aut[lastrow]
		acsm_local_time[n] = alt[lastrow]
		ChamberT[n] = chT[lastrow]
		airbeam[n] = ab[lastrow]
		inletP[n] = ip[lastrow]
		vapT[n] = vt[lastrow]
		CE[n] = CE_ACMCC[0]
		Masscalib_nitrate[n] = Masscalib_nitrate_pt[0]

		wave/Z Org, SO4, NO3, NH4, Chl
		insertPoints n, 1, Org, SO4, NO3, NH4, Chl
		Org[n] = Org_pt[lastrow]
		SO4[n] = SO4_pt[lastrow]
		NO3[n] = NO3_pt[lastrow]
		NH4[n] = NH4_pt[lastrow]
		Chl[n] = Chl_pt[lastrow]
//Francesco end

		save /B/O/P=SaveDataFilePathbis /T wlStr as dstr
	
	
	endif

End Function

Function CheckPumpSoftVersion()

	SVAR/Z Pump_path=root:ACMCC_Export:Pump_path
	NewPath/O/Q pumppath,pump_path
	string listoffiles=IndexedFile(pumppath,-1,".exe")
	//print listoffiles

End Function


Function CreateNotebookOrBringToFront()
	//string ListOfNB=WinList("ACSMExportNoteBook",";","WIN:16")
	
	if (WinType("ACSMExportNoteBook")==5)
		DoWindow/F ACSMExportNoteBook
	else
		NewNoteBook /F=0/K=2/N=ACSMExportNoteBook
	endif
End Function

Function UpdateNoteBook(text)
	string text
	CreateNotebookOrBringToFront()
	string NoteBookTxt=secs2date(datetime,-2,"/")+" "+secs2time(datetime,3)+"\t"
	NoteBookTxt+=text+"\r"
	NoteBook ACSMExportNoteBook, text=NoteBookTxt
End Function

Function ACMCC_KillNoteBook()
	if (WinType("ACSMExportNoteBook")==5)
		DoAlert/T="Warning" 1, "This will clear the notebook. Are you sure ?"
		if(V_flag==1)
			KillWindow ACSMExportNoteBook
		endif
	endif
end Function



Function ACMCC_SaveConfig()

	wave/T ConfigW_txt=root:ACMCC_Export:ConfigW_txt
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	
	Edit /N=Config ConfigW_txt
	AppendToTable /W=Config ConfigW_val

	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	string DataPathbis=NextCloud_path
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	saveTableCopy/O/T=1/W=Config/P=SaveDataFilePathbis as "ACSM_config.txt"
	KillWindow Config

End Function

Function ACMCC_Load_Config()
	wave/T ConfigW_txt=root:ACMCC_Export:ConfigW_txt
	wave/T ConfigW_val=root:ACMCC_Export:ConfigW_val
	
	SetDataFolder root:ACMCC_Export
	
	LoadWave/J/L={0,1,0,1,1}/O/V={"\t","",0,0}/K=2/N=ConfigW_val_Load
	
	wave/T ConfigW_val_Load0=root:ACMCC_Export:ConfigW_val_Load0
	ConfigW_val=ConfigW_val_Load0
	
	//Updating Station Name and PopUpMenu display
	wave/T StationNameW=root:ACMCC_Export:StationNameW
	StationNameW[0]=ConfigW_val_Load0[0]
	SVAR/Z ListOfStations=root:ACMCC_Export:ListOfStations
	variable PositionInList=whichlistitem(StationNameW[0],ListOfStations)
	if(PositionInList==-1)
		ListOfStations+=";"+StationNameW[0]
		PositionInList=whichlistitem(StationNameW[0],ListOfStations)
	endif
	PopupMenu PM_Station, win=ExportPanel, mode=(PositionInList+2)
	
	//Updating Lens Type and PopUpMenu display
	wave/T LensW=root:ACMCC_Export:LensW
	LensW[0]=ConfigW_val_Load0[1]
	SVAR/Z Lens_Str=root:ACMCC_Export:Lens_Str
	PositionInList=whichlistitem(LensW[0],Lens_Str)
	PopupMenu PM_Lens, win=ExportPanel, mode=(PositionInList+2)
	
	//Updating Vaporizer Type and PopUpMenu display
	wave/T VaporizerW=root:ACMCC_Export:VaporizerW
	VaporizerW[0]=ConfigW_val_Load0[2]
	SVAR/Z Vaporizer_Str=root:ACMCC_Export:Vaporizer_Str
	PositionInList=whichlistitem(VaporizerW[0],Vaporizer_Str)
	PopupMenu PM_Vap, win=ExportPanel, mode=(PositionInList+2)
	
	//Updating Dryer CheckBox
	NVAR/Z DryerBool=root:ACMCC_Export:DryerBool
	DryerBool=str2num(ConfigW_val_Load0[3])
	
	//Updating Pump CheckBox
	NVAR/Z PumpBool=root:ACMCC_Export:PumpBool
	PumpBool=str2num(ConfigW_val_Load0[5])
	
	//Updating Path for Dryer data
	SVAR/Z DryerStat_path=root:ACMCC_Export:DryerStat_path
	DryerStat_path=ConfigW_val_Load0[4]
	
	//Updating Path for Pump data
	SVAR/Z Pump_path=root:ACMCC_Export:Pump_path
	Pump_path=ConfigW_val_Load0[7]
	
	//Updating Prefix for Pump Data Files
	SVAR/Z PumpDataFilePrefix=root:ACMCC_Export:PumpDataFilePrefix
	PumpDataFilePrefix=ConfigW_val_Load0[6]
	
	//Updating CDCE CheckBox
	NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
	ApplyMiddlebrook=str2num(ConfigW_val_Load0[8])
	
	//Updating PMF CheckBox
	NVAR/Z GeneratePMFInput=root:ACMCC_Export:GeneratePMFInput
	GeneratePMFInput=str2num(ConfigW_val_Load0[9])
	
	//Updating SoFi CheckBox
	NVAR/Z GenerateSoFi=root:ACMCC_Export:GenerateSoFi
	GenerateSoFi=str2num(ConfigW_val_Load0[10])
	
	//Updating Path Of Saving Folder 
	SVAR/Z NextCloud_path=root:ACMCC_Export:NextCloud_path
	NextCloud_path=ConfigW_val_Load0[12]
	
	NVAR/Z MaxMz=root:ACMCC_Export:MaxMz
	MaxMz=str2num(ConfigW_val_Load0[11])
	SVAR/Z FragTableVersion=root:ACMCC_Export:FragTableVersion
	string mzbool_str
	variable j
	
	if (MaxMz==100)
		if(stringmatch(FragTableVersion,"V1")) //if V1, no org signal at mz28
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;0;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		else
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		endif
		
		Make/O/N=100 mzbool
		for(j=0;j<itemsinlist(mzbool_str);j+=1)
			mzbool[j]=str2num(stringfromlist(j,mzbool_str))
		endfor
	elseif(MaxMz==120)
		if(stringmatch(FragTableVersion,"V1")) //if V1, no org signal at mz28
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;0;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		else
			mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		endif
		Make/O/N=120 mzbool
		for(j=0;j<itemsinlist(mzbool_str);j+=1)
			mzbool[j]=str2num(stringfromlist(j,mzbool_str))
		endfor
	endif
	
	SVAR/Z Maxmz_Str=root:ACMCC_Export:Maxmz_Str
	PositionInList=whichlistitem(num2str(MaxMz),Maxmz_Str)
	PopupMenu PM_Maxmz, win=ExportPanel, mode=(PositionInList+2)
	
	
End Function


Function ACMCC_UpdateIpf()
	
	if (WinType("ExportPanel") == 7)
		KillWindow ExportPanel
	endif
	
	KillDataFolder/Z root:ACMCC_Export

End Function