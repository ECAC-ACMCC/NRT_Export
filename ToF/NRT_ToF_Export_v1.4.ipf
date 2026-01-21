#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3        // Use modern global access method and strict wave access.
#pragma version=1.1

//#include "twV2_3_18_daq2_instr4_ACSM" version>=40,optional

/////////////////////////////////////////////////////////////
//
// Description :
// -------------
//    Generate raw text files from ACSM acquisition software
//
// Copyright (©) 2022:
// -------------------
//     Université Aix-Marseille I (AMU)
//     Commissariat à l'énergie atomique et aux énergies alternatives (CEA) ;
//     Centre national de la recherche scientifique (CNRS);
// 
// Author(s) :
// --------
//     AMU Benjamin Chazeau, benjamin-dot-chazeau-at-univ-hyphen-amu-dot-fr
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
//   v1.1.0 : 2022/10/27
//     - first official release
//     - compatible only with twV2_3_18_daq2_instr4_ACSM.ipf v40
//   v1.1.1 : 2023/04/28
//     - export of mz28 in SoFi itx (it was missing before)
//   v1.2 : 2023/05/08
//     - new panel
//     - CDCE correction
//     - Dryer data
//   v1.3 : 2025/09/18
//     - change of export variables. Now consistent with Annual textfile
//   v1.4 : 2026/01/21
//     - added export of species in SoFiRT files
//     - corrected counting for checking rate
//
/////////////////////////////////////////////////////////////

StrConstant export_version="1.4"


//Autolycos is a procedure which is set as a background task for ToF-ACSM OA matrix export 

//OrgMx_PathName is the disk path where OA spectra will be stored
//TimeRes must be in seconds and not below the ACSM time resolution 


Menu "Autolycos"
    "Initialize Tool", PrepTool() 
    "Tool Window", Dowindow/F Autolycos_Panel
End    
    
Function Autolycos_Panel()
    PauseUpdate; Silent 1        // building window...
    NewPanel/W=(200,10,605,500)/K=1
    ModifyPanel fixedSize=1
    SetDrawLayer UserBack
    SetDrawEnv fname= "Sylfaen",fstyle= 1,textrgb= (32768,32770,65535)
    DrawText 40,45,"\\Z32\\F'Sylfaen'AUTOLYCOS  v."+export_version
    SetDrawEnv linefgc= (34952,34952,34952),fillpat= 50,fillfgc= (56797,56797,56797),fillbgc= (52428,52428,52428)
    //DrawRect 8,49,396,225
    
    GroupBox InstrumentGB,pos={2,45},size={395,110},title="\\f01I/ Instrument Information",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"
    
    PopupMenu PM_Station, fSize=14, pos={6,60}, size={100,20}, value = "select;"+InputLists("Station"), title="\f01Station Name", proc = StationInput_proc, disable = 0,fstyle=1,font="Arial"
    wave/T ToF_QuadW=root:Autolycos:ToF_QuadW
    //string ToF_str="UMR ToF"
    SetVariable PM_Spectro, fSize=14, pos={200,60}, size={180,20}, value=ToF_QuadW[0], title="\f01Spectrometer", disable = 0,fstyle=0,font="Arial",noedit=1
    
    SVAR/Z SN_str=root:Autolycos:SN_str
    SetVariable Set_SN, fSize=10, pos={230,85}, size={150,20}, value = SN_str, title="\f02Serial Number",fstyle=2,font="Arial",noedit=0
    PopupMenu PM_Lens, fSize=14, pos={6,125}, size={100,20}, value = "select;"+InputLists("Lens"), title="\f01Lens", proc = LensInput_proc, disable = 0,fstyle=1,font="Arial"
    PopupMenu PM_Vap, fSize=14, pos={200,125}, size={100,20}, value = "select;"+InputLists("Vaporizer"), title="\f01Vaporizer", proc = VapInput_proc, disable = 0,fstyle=1,font="Arial"
    
    GroupBox ExternalDataGB,pos={2,155},size={395,50},title="\\f01II/ External Data",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"
    NVAR/Z DryerBool=root:Autolycos:DryerBool
    CheckBox DryerBox, fSize=14, pos={5,180},title="", variable=DryerBool, font="Arial",disable=0, proc=Dryerproc
    String/G DryerStat_path="C:ACSM:DryerStats:"
    SVAR/Z DryerStat_path=root:Autolycos:DryerStat_path
    SetVariable Set_DryerPath,title="Dryer Data Folder",pos={30,177},size={293,20},value=DryerStat_path,fSize=12,noedit=1,font="Arial", disable=-2*DryerBool+2
    Button Set_DryerPath_button,title="\\f01SET",pos={336,177},size={50,20},fSize=14,fColor=(39168,39168,39168),font="Arial", proc=SetDryerPath_proc, disable=-2*DryerBool+2
    
    
    GroupBox CorrectionsGB,pos={2,215},size={395,50},title="\\f01III/ Corrections",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"
    NVAR/Z ApplyMiddlebrook=root:Autolycos:ApplyMiddlebrook
    CheckBox UseMiddlebrook_CB, title="Use Composition dependant CE", pos={10,240},font="Arial", fsize=14,variable=ApplyMiddlebrook,disable=0
    
    
    GroupBox PMFGB,pos={2,280},size={395,80},title="\\f01IV/ PMF input",fSize=12,fColor=(13056,4352,0),labelBack=(64512,64512,60160),frame=0,font="Arial"

		NVAR/Z GeneratePMFInput=root:Autolycos:GeneratePMFInput
		CheckBox PMFBox, fSize=14, pos={20,305},title="Generate PMF Input ?", variable=GeneratePMFInput, font="Arial",disable=0
	
		NVAR/Z GenerateSoFi=root:Autolycos:GenerateSoFi
		CheckBox SoFiBox, fSize=14, pos={250,305},title="SoFi RT", variable=GenerateSoFi, font="Arial",disable=0

		NVAR/Z MaxMz=root:Autolycos:MaxMz
		PopupMenu PM_Maxmz, fSize=14, pos={150,330}, size={90,20}, value = "select;"+InputLists("Maxmz"), title="\f02max mz    ", proc = MaxmzInput_proc, disable = 0,fstyle=1,font="Arial"


	SVAR/Z NextCloud_path=root:Autolycos:NextCloud_path
	SetVariable Set_ExportPath,title="Save Data Folder",pos={7,375},size={323,19},value=NextCloud_path,fSize=12,noedit=1,font="Arial", disable=0
	Button Set_PathToR_button,title="\\f01SET",pos={336,375},size={50,20},fSize=14,fColor=(39168,39168,39168),font="Arial", proc=SetPath_proc, disable=0
	
	NVAR/Z StartStop_bool=root:Autolycos:StartStop_bool
	if (StartStop_bool==0)
		Button RunButton,title="START",pos={24,410},size={355,40},fSize=20,fstyle=1,fColor=(26112,52224,0),proc=LaunchExport,font="Arial",disable=0
	elseif (StartStop_bool==1)
		Button RunButton,title="STOP",pos={24,410},size={355,40},fSize=20,fstyle=1,fColor=(65280,16384,16384),proc=LaunchExport,font="Arial",disable=0
	endif

	
	NVAR/Z Counts=root:Autolycos:Counts
	NVAR/Z RefreshRate=root:Autolycos:RefreshRate
	SetVariable Set_Counts, title="\\f02Checking rate (s)   ", pos={10,465}, size={160,20}, fSize=12,noedit=0,value=RefreshRate,disable=0

// Button Autolycos_Credits,pos={345,15},size={54.60,19.80},proc=Button_Credits,title="Credits"
End Function


//------------------------------------------------------------------------------------------------//

function PrepTool()

	NewDataFolder/O/S root:Autolycos
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
	Variable/G ApplyMiddlebrook=0
	Variable/G MaxMz=0
	String/G Maxmz_Str="100;120"
	Variable/G DryerBool=0
	Variable/G RefreshRate=120
	Variable/G Counts=0

	
	Make/N=1/O/T StationNameW,ToF_QuadW,LensW,VaporizerW
	
	NextCloud_path="C:Users:TofUser:NextCloud:"
	ToF_QuadW[0]="UMR ToF"
	SN_str=""
	
	
	string mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
	Make/O/N=100 mzbool
	variable i
	for(i=0;i<itemsinlist(mzbool_str);i+=1)
	mzbool[i]=str2num(stringfromlist(i,mzbool_str))
	endfor


	Autolycos_Panel()
	string SN
	prompt SN, "please enter the serial number of the instrument"
	doprompt "Warning", SN
	SN_str=SN
	
end

//------------------------------------------------------------------------------------------------//


Function MaxmzInput_proc(name,num,str) : PopupMenuControl 
	string name
	variable num
	string str
	
	NVAR/Z MaxMz=root:Autolycos:MaxMz
	string mzbool_str
	variable j
	
	if (stringmatch(str,"100"))
		MaxMz=100
		mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		Make/O/N=100 mzbool
		for(j=0;j<itemsinlist(mzbool_str);j+=1)
			mzbool[j]=str2num(stringfromlist(j,mzbool_str))
		endfor
	elseif(stringmatch(str,"120"))
		MaxMz=120
		mzbool_str="0;0;0;0;0;0;0;0;0;0;0;1;1;0;1;1;1;1;0;0;0;0;0;1;1;1;1;1;1;1;1;0;0;0;0;0;1;1;0;0;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1"
		Make/O/N=120 mzbool
		for(j=0;j<itemsinlist(mzbool_str);j+=1)
			mzbool[j]=str2num(stringfromlist(j,mzbool_str))
		endfor
	endif
End Function


Function Dryerproc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	NVAR/Z DryerBool=root:Autolycos:DryerBool
	
	if (checked==0)
		SetVariable Set_DryerPath, disable=2
		Button Set_DryerPath_button, disable=2
	elseif(checked==1)
		SetVariable Set_DryerPath, disable=0
		Button Set_DryerPath_button, disable=0
	endif

End Function


Function SetDryerPath_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z DryerStat_path=root:Autolycos:DryerStat_path
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	DryerStat_path = S_path
	setdatafolder temp_folder
end


Function Button_StopTask(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            Button Autolycos_Start fColor=(40960,65280,16384)
            Button Autolycos_Stop fColor=(13056,0,0)
            StopAutolycosTask()
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function Button_StartTask(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            Button Autolycos_Start fColor=(0,13056,0)
            Button Autolycos_Stop fColor=(65280,16384,16384)
            SVAR OrgMx_PathName=root:Autolycos:OrgMx_PathName
            NVAR TimeRes=root:Autolycos:TimeRes
            Autolycos()
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End


Function Button_SetPath(Path_Name) : ButtonControl
String Path_name
    SVar OrgMx_PathName = root:Autolycos:OrgMx_PathName
    String temp_folder
    temp_folder = getdatafolder(1)
    
    //define path
    newpath/O/Q trajpath
    pathinfo trajpath
    OrgMx_PathName = S_path

    print OrgMx_PathName
    setdatafolder temp_folder
End


Function Button_Credits(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    switch( ba.eventCode )
        case 2: // mouse up
            Execute "Credits_Autolycos()"
            break
        case -1: // control being killed
            break
    endswitch

    return 0
End

//------------------------------------------------------------------------------------------------//

Function Autolycos()

    SVAR OrgMx_PathName=root:Autolycos:OrgMx_PathName
    NewPath/O/C/Z PathFolder, OrgMx_PathName
    
    StartAutolycosTask()
end


//------------------------------------------------------------------------------------------------//

Function StartAutolycosTask()
    NVAR TimeRes=root:Autolycos:TimeRes 
    Variable numTicks = TimeRes * 60        // Run every x seconds. 1 tick =1/60 secondes (always seconds*60)
    CtrlNamedBackground Task_Autolycos, period=numTicks, proc=AutoSaveFile
    CtrlNamedBackground Task_Autolycos, start
End

Function StopAutolycosTask()
    CtrlNamedBackground Task_Autolycos, stop
End


//------------------------------------------------------------------------------------------------//

Function AutoSaveFile(s)        // This is the function that will be called periodically
    
    STRUCT WMBackgroundStruct &s
        
    //Date and Time of the wave to save
    
    //Variable/G WaveToSec =modDate(root:test:wave0)
    //Variable/G WaveToSec =CreationDate(root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_org)
    Variable/G WaveToSec =modDate(root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_org)
    //WaveToSec=WaveToSec-Date2Secs(-1,-1,-1)
    String/G TimeOfWave = Secs2Date(WaveToSec,-2) + "_" + Secs2Time(WaveToSec, 3)
    String/G TimeNow=replaceString(":",TimeOfWave,"_")
    print "Last AUTOLYCOS save: "+TimeNow
    
    
    //Calculate the error matrix
    Error_generate()
    
    //Define the name of matrix that will be saved
    String/G Mx_Org= "Mx_Org_"+TimeNow
    String/G Mx_NO3= "Mx_NO3_"+TimeNow
    String/G Mx_NH4= "Mx_NH4_"+TimeNow
    String/G Mx_SO4= "Mx_SO4_"+TimeNow
    String/G Mx_Chl= "Mx_Chl_"+TimeNow
    String/G Mx_Open= "Mx_Open_"+TimeNow
    String/G Mx_Close= "Mx_Close_"+TimeNow
    String/G Mx_Diff= "Mx_Diff_"+TimeNow
    
    //Define the error matrix 
    String/G Mx_Org_err= "Mx_err_Org_"+TimeNow
    String/G Mx_NO3_err= "Mx_err_NO3_"+TimeNow
    String/G Mx_NH4_err= "Mx_err_NH4_"+TimeNow
    String/G Mx_SO4_err= "Mx_err_SO4_"+TimeNow
    String/G Mx_Chl_err= "Mx_err_Chl_"+TimeNow
    
    //Define the Species and Specific Fragments
    String/G S_Org= "Org_"+TimeNow
    String/G S_NO3= "NO3_"+TimeNow
    String/G S_NH4= "NH4_"+TimeNow
    String/G S_SO4= "SO4_"+TimeNow
    String/G S_Chl= "Chl_"+TimeNow
    
    String/G S_f43= "f43_"+TimeNow
    String/G S_f44= "f44_"+TimeNow
    String/G S_f55= "f55_"+TimeNow
    String/G S_f57= "f57_"+TimeNow
    String/G S_f60= "f60_"+TimeNow
    
    
    //Duplicate all matrix
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_org $Mx_Org
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_no3 $Mx_NO3
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_nh4 $Mx_NH4
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_so4 $Mx_SO4
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_chl $Mx_Chl
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSO $Mx_Open
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSC $Mx_Close
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD $Mx_Diff
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_org Frags_Org
    Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop time_stop
    
    //Create Concentrations species + Specific Organic Fragments
    Variable LastTP= numpnts(time_Stop)-1
    Make/N=1/O TimePoint=time_Stop[LastTP]
    Make/N=1/O Org=sum($Mx_Org)
    Make/N=1/O NO3=sum($Mx_NO3)
    Make/N=1/O NH4=sum($Mx_NH4)
    Make/N=1/O SO4=sum($Mx_SO4)
    Make/N=1/O Chl=sum($Mx_Chl)
    
    Make/N=1/O f43=Frags_Org[42]/Org
    Make/N=1/O f44=Frags_Org[43]/Org
    Make/N=1/O f55=Frags_Org[54]/Org
    Make/N=1/O f57=Frags_Org[56]/Org
    Make/N=1/O f60=Frags_Org[59]/Org
    
    //Duplicate Species and Specific Fragments
    Duplicate/O Org $S_Org
    Duplicate/O NO3 $S_NO3
    Duplicate/O NH4 $S_NH4
    Duplicate/O SO4 $S_SO4
    Duplicate/O chl $S_chl
    
    Duplicate/O f43 $S_f43
    Duplicate/O f44 $S_f44
    Duplicate/O f55 $S_f55
    Duplicate/O f57 $S_f57
    Duplicate/O f60 $S_f60
    
    //Duplicate error matrix
    Wave Mx_err_Org, Mx_err_NO3, Mx_err_NH4, Mx_err_SO4, Mx_err_Chl
    Duplicate/O Mx_err_Org $Mx_Org_err
    Duplicate/O Mx_err_NO3 $Mx_NO3_err
    Duplicate/O Mx_err_NH4 $Mx_NH4_err
    Duplicate/O Mx_err_SO4 $Mx_SO4_err
    Duplicate/O Mx_err_Chl $Mx_Chl_err
    
    
    //****Save the data. NEED TO ADD THE TECHNICAL PARAMETERS AND SAVE 2 DIFFERENT FILES
    save/O/T/P=PathFolder $Mx_Org,$Mx_NO3,$Mx_NH4,$Mx_SO4,$Mx_Chl,$Mx_Open,$Mx_Close,$Mx_Diff,$Mx_Org_err,$Mx_NO3_err,$Mx_NH4_err,$Mx_SO4_err,$Mx_Chl_err,$S_Org,$S_NO3,$S_NH4,$S_SO4,$S_chl as TimeNow+".itx"
    //****Save the data in txt.
    save/O/J/W/P=PathFolder TimePoint,Org,NO3,NH4,SO4,chl,f43,f44,f55,f57,f60 as TimeNow+".txt"
    
    Killwaves/Z $Mx_Org,$Mx_NO3,$Mx_NH4,$Mx_SO4,$Mx_Chl,$Mx_Open,$Mx_Close,$Mx_Diff,$Mx_Org_err,$Mx_NO3_err,$Mx_NH4_err,$Mx_SO4_err,$Mx_Chl_err
    Killwaves/Z $S_Org,$S_NO3,$S_NH4,$S_SO4,$S_chl,$S_f43,$S_f44,$S_f55,$S_f57,$S_f60,Org,NO3,NH4,SO4,chl,f43,f44,f55,f57,f60, Frags_Org, time_stop,TimePoint

    return 0    // Continue background task
End

//------------------------------------------------------------------------------------------------//

Function Error_generate()
//**********MSSD WILL HAVE TO BE REPLACED BY THE TOTAL ERROR FOR PMF**********


//Import the required data
Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD MSSD
Duplicate/O root:Packages:tw_IgorDAQ:ACSM:nativeTS:params params
Duplicate/O root:Packages:tw_IgorDAQ:Batch:Chl_sparse Chl_sparse
Duplicate/O root:Packages:tw_IgorDAQ:Batch:NH4_sparse NH4_sparse
Duplicate/O root:Packages:tw_IgorDAQ:Batch:NO3_sparse NO3_sparse
Duplicate/O root:Packages:tw_IgorDAQ:Batch:Org_sparse Org_sparse
Duplicate/O root:Packages:tw_IgorDAQ:Batch:SO4_sparse SO4_sparse

//Define the variables used in the calculations 
Variable LastP=dimsize(params,0)-1

Variable RIE_Chl=params[LastP][9]
Variable RIE_NH4=params[LastP][10]
Variable RIE_NO3=params[LastP][11]
Variable RIE_Org=params[LastP][12]
Variable RIE_SO4=params[LastP][13]
Variable CE=params[LastP][20]
Variable IE=params[LastP][25]
Variable AB=params[LastP][27]
Variable Q_inlet=params[LastP][29]
Variable ABref=params[LastP][26]
Variable Chl_conc=params[LastP][4]


make/O/T/N=5 SparseList={"Chl_sparse","NH4_sparse","NO3_sparse","Org_sparse","SO4_sparse"}
make/O/T/N=5 SpeciesList={"Chl","NH4","NO3","Org","SO4"}
make/O/N=5 RIEList={RIE_Chl,RIE_NH4,RIE_NO3,RIE_Org,RIE_SO4}

Variable j
For (j=0;j<numpnts(SparseList);j=j+1)
    string SparseName= SparseList[j]
    wave Sparse_in = $SparseName

    string SpeciesName= SpeciesList[j]
    wave Species_in = $SpeciesName
    
    Variable RIE_in= RIEList[j]
    
//Application of the fragmentation table to the total mass spectra
    Duplicate/O MSSD MSSD_ion_err
    MSSD_ion_err=0
    
    //******PMF ERROR CALCULATION FROM JAY TO INCLUDE******

    Variable i 
    For (i=0; i<dimsize(Sparse_in,0);i=i+1)
        MSSD_ion_err[Sparse_in[i][1]]+=Sparse_in[i][2]*MSSD[Sparse_in[i][0]]
    endfor

//Convert ion/s to µg/m3
    Duplicate/O MSSD_ion_err MSSD_err

    MSSD_err= MSSD_ion_err * (1/(CE*IE*RIE_in)) * ((ABref)/(AB*Q_inlet))



    string rename_err =  "Mx_err_"+SpeciesName
    Duplicate/O MSSD_err, $rename_err
    print sum(MSSD_err)


endfor

//Clean a bit the folder
Killwaves/Z SparseList, SpeciesList, RIEList, MSSD_ion_err, MSSD_err

//Quick check of the diff between the given conc and the calculated conc for species...
wave Mx_err_Chl
print "Ratio is "
print (sum(Mx_err_Chl)/Chl_Conc)
print "Stop"

end

//------------------------------------------------------------------------------------------------//

//Credits Panel
Window Credits_Autolycos() : Panel
    PauseUpdate; Silent 1        // building window...
    NewPanel /K=1 /W=(112.8,118.8,450.6,309.6) as "Credits"
    ModifyPanel fixedSize=1
    ShowTools/A
    SetDrawLayer UserBack
    DrawLine 10,134,331,134
    TitleBox Credits_dev,pos={49.80,6.00},size={236.40,18.00},title="This toolkit was developped by "
    TitleBox Credits_dev,userdata(ResizeControlsInfo)= A"!!,D;!!#:B!!#B*!!#<Pz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_dev,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_dev,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_dev,font="Arial",fSize=16,frame=0,fStyle=1
    TitleBox Credits_name,pos={144.60,36.60},size={55.80,16.20},title="Example"
    TitleBox Credits_name,userdata(ResizeControlsInfo)= A"!!,C,!!#=o!!#BCJ,hlcz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_name,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_name,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_name,font="Arial",fSize=14,frame=0,fStyle=1
    TitleBox credits_Lab,pos={150.00,66.00},size={45.00,13.80},title="Example"
    TitleBox credits_Lab,userdata(ResizeControlsInfo)= A"!!,D#!!#??!!#B;J,hlSz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox credits_Lab,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox credits_Lab,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox credits_Lab,font="Arial",fSize=12,frame=0
    TitleBox Credits_Team,pos={154.80,87.00},size={34.20,10.20},title="Example"
    TitleBox Credits_Team,userdata(ResizeControlsInfo)= A"!!,A^!!#?i!!#BW!!#<(z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_Team,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_Team,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_Team,font="Arial",frame=0
    TitleBox Credits_Institution,pos={154.80,108.00},size={34.20,10.20},title="Example"
    TitleBox Credits_Institution,userdata(ResizeControlsInfo)= A"!!,F9!!#@<!!#@b!!#<(z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_Institution,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_Institution,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_Institution,font="Arial",frame=0
    TitleBox Credits_contact,pos={150.00,141.00},size={37.80,10.80},title="\\f04\\f01Contacts"
    TitleBox Credits_contact,userdata(ResizeControlsInfo)= A"!!,G#!!#@s!!#>Z!!#<(z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_contact,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_contact,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_contact,font="Arial",frame=0,fColor=(0,0,52224)
    TitleBox Credits_Mail2,pos={150.00,177.00},size={34.20,10.20},title="Example\\JC"
    TitleBox Credits_Mail2,userdata(ResizeControlsInfo)= A"!!,Eb!!#AY!!#A;!!#<(z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_Mail2,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_Mail2,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_Mail2,font="Arial",frame=0,fColor=(0,0,65280)
    TitleBox Credits_Mail1,pos={150.00,162.00},size={34.20,10.20},title="Example\\JC"
    TitleBox Credits_Mail1,userdata(ResizeControlsInfo)= A"!!,E`!!#A3!!#A=!!#<(z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
    TitleBox Credits_Mail1,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
    TitleBox Credits_Mail1,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
    TitleBox Credits_Mail1,font="Arial",frame=0,fColor=(0,0,65280)
    SetWindow kwTopWin,userdata(ResizeControlsInfo)= A"!!*'\"z!!#Bc!!#Aozzzzzzzzzzzzzzzzzzzzz"
    SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzzzzzzzz"
    SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzz!!!"
EndMacro





Function ACMCC_ToF_TriggeredExport()


	SetDataFolder root:Autolycos
	
	//Get Date
	Make/N=1/O/T ACSM_time
	//NVAR lastrow=root:Autolycos:Number
	wave DateW=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
	WaveStats/Q DateW
	variable lastrow=V_maxloc
	
	string year=ACMCC_ExtractDateInfo(DateW[lastrow],"year")
	string month=ACMCC_ExtractDateInfo(DateW[lastrow],"month")
	string dayOfMonth=ACMCC_ExtractDateInfo(DateW[lastrow],"dayOfMonth")
	string hour=ACMCC_ExtractTimeInfo(DateW[lastrow],"hour")
	string minute=ACMCC_ExtractTimeInfo(DateW[lastrow],"minute")
	string second=ACMCC_ExtractTimeInfo(DateW[lastrow],"second")
	
	ACSM_time=year+"/"+month+"/"+dayofmonth+" "+hour+":"+minute+":"+second
	
	wave DataW=root:Packages:tw_IgorDAQ:ACSM:nativeTS:params
	
	//Get IE, RIE and CE values
	Make/N=1/D/O IE_NO3, RIE_NH4, RIE_SO4, RIE_NO3, RIE_OM, RIE_Cl, CE
	
	RIE_OM=DataW[lastrow][12]
	RIE_NO3=DataW[lastrow][11]
	RIE_SO4=DataW[lastrow][13]
	RIE_NH4=DataW[lastrow][10]
	RIE_Cl=DataW[lastrow][9]
	//NVAR IE=root:Packages:tw_IgorDAQ:ACSM:ugConv_ionspg
	IE_NO3=DataW[lastrow][25]
	CE=DataW[lastrow][20]
	
	
	
	//Get Concentrations
	Make/O/N=1 OM,NO3,SO4,NH4,Cl
	OM=DataW[lastrow][7]
	NO3=DataW[lastrow][6]
	SO4=DataW[lastrow][8]
	NH4=DataW[lastrow][5]
	Cl=DataW[lastrow][4]
	
	
	//Apply CE correction
	NVAR/Z ApplyMiddlebrook=root:Autolycos:ApplyMiddlebrook
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
		SO4*=DataW[lastrow][20]/CE[0]
		NH4*=DataW[lastrow][20]/CE[0]
		NO3*=DataW[lastrow][20]/CE[0]
		Cl*=DataW[lastrow][20]/CE[0]
		OM*=DataW[lastrow][20]/CE[0]
	endif
	
	
	
	//Get Diagnostics
	Make/O/N=1 ABref,AB_total,Flow_css,n_total,n_bkgd,baseline,threshold,mzCal_p1,mzCal_p2,ratio40div28,Lens,Pulser,Lens2,IonEx,Lens1,HB,IonChamber
	Make/O/N=1 Filament_Emm,Turbo_speed,Turbo_power,Fore_pc,Press_inlet,Heater_PWM,Heater_I,Heater_V,Heater_T
	ABref=DataW[lastrow][26]
	AB_total=DataW[lastrow][27]
	Flow_css=DataW[lastrow][29]
	n_total=DataW[lastrow][32]
	n_bkgd=DataW[lastrow][33]
	baseline=DataW[lastrow][34]
	threshold=DataW[lastrow][35]
	mzCal_p1=DataW[lastrow][36]
	mzCal_p2=DataW[lastrow][37]
	ratio40div28=DataW[lastrow][38]
	Lens=DataW[lastrow][45]
	Pulser=DataW[lastrow][48]
	Lens2=DataW[lastrow][49]
	IonEx=DataW[lastrow][52]
	Lens1=DataW[lastrow][53]
	HB=DataW[lastrow][54]
	IonChamber=DataW[lastrow][55]
	Filament_Emm=DataW[lastrow][57]
	Turbo_speed=DataW[lastrow][63]
	Turbo_power=DataW[lastrow][64]
	Fore_pc=DataW[lastrow][65]
	Press_inlet=DataW[lastrow][68]
	Heater_PWM=DataW[lastrow][73]
	Heater_I=DataW[lastrow][74]
	Heater_V=DataW[lastrow][75]
	Heater_T=DataW[lastrow][76]


	//Get Dryer Stats
	SetDataFolder root:Autolycos	
	Make/O/N=1 Sampling_Flowrate, RH_In, RH_Out, T_In, T_Out
//	NVAR/Z DryerBool=root:Autolycos:DryerBool
//	if(DryerBool==1)
//		ACMCC_DryerStat_avg(lastrow)
//		wave FlowR_avg=root:Autolycos:DryerData:FlowR_avg
//		wave T_In_avg=root:Autolycos:DryerData:T_In_avg
//		wave T_Out_avg=root:Autolycos:DryerData:T_Out_avg
//		wave RH_In_avg=root:Autolycos:DryerData:RH_In_avg
//		wave RH_Out_avg=root:Autolycos:DryerData:RH_Out_avg
//		Sampling_Flowrate=FlowR_avg[0]
//		T_In=T_In_avg[0]
//		T_Out=T_Out_avg[0]
//		RH_In=RH_In_avg[0]
//		RH_Out=RH_Out_avg[0]
//	endif
	
	
	
	//ACMCC_AutoPMFExport()
	//wave eOrg=root:PMFMats:eOrg
	//wave eNO3=root:PMFMats:eNO3
	//wave eSO4=root:PMFMats:eSO4
	//wave eNH4=root:PMFMats:eNH4
	//wave eChl=root:PMFMats:eChl
	SetDataFolder root:Autolycos	
	Make/O/N=1 OM_err,NO3_err,SO4_err,NH4_err,Cl_err
	OM_err=-999
	NO3_err=-999
	SO4_err=-999
	NH4_err=-999
	Cl_err=-999
	
	wave ToF_QuadW=root:Autolycos:ToF_QuadW
	wave LensW=root:Autolycos:LensW
	wave VaporizerW=root:Autolycos:VaporizerW
	
	//Create Table & Save
	variable i
	i=0
	string saveWavesList="ACSM_time;OM;NO3;SO4;NH4;Cl;IE_NO3;RIE_OM;RIE_NO3;RIE_SO4;RIE_NH4;RIE_Cl;"
	saveWavesList+="ABref;AB_total;Flow_css;n_total;n_bkgd;baseline;threshold;mzCal_p1;mzCal_p2;ratio40div28;Lens;Pulser;Lens2;IonEx;Lens1;HB;IonChamber;"
	saveWavesList+="Filament_Emm;Turbo_speed;Turbo_power;Fore_pc;Press_inlet;Heater_PWM;Heater_I;Heater_V;Heater_T;"
	saveWavesList+="Sampling_Flowrate;RH_In;RH_Out;T_In;T_Out;"
	saveWavesList+="OM_err;NO3_err;SO4_err;NH4_err;Cl_err;"
	saveWavesList+="ToF_QuadW;LensW;VaporizerW;"

	SetDataFolder root:Autolycos
	for (i=0;i<itemsInList(saveWavesList);i+=1)
		wave w = $stringFromList(i,saveWavesList)
		if (i==0)
			Edit /N=ExportTable w
		else
			AppendToTable /W=ExportTable w
		endif
	endfor
	
	wave/T StationNameW=root:Autolycos:StationNameW
	SVAR/Z SN_str=root:Autolycos:SN_str
	
	string FileName=StationNameW[0]+"_ACSM-"+SN_str+"_"
	FileName+=year+month+dayofmonth+hour+minute+".txt"
	
	SVAR/Z NextCloud_path=root:Autolycos:NextCloud_path
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
	SaveTableCopy/O/T=1/W=ExportTable/P=SaveDataFilePathbis as FileName
	KillWindow ExportTable
	
	
	
	NVAR/Z GeneratePMFInput=root:Autolycos:GeneratePMFInput
	if (GeneratePMFInput==1)
		SetDataFolder root:Autolycos
		wave MSSD_orgPMF=root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_orgPMF
		wave MSSD_orgerr=root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_orgerr

		duplicate/O MSSD_orgPMF Org_Specs
		duplicate/O MSSD_orgerr Orgspecs_err
		
		if (ApplyMiddlebrook==1)
			Org_Specs*=DataW[lastrow][20]/CE[0]
			Orgspecs_err*=DataW[lastrow][20]/CE[0]
		endif
		
		Make/O/N=(numpnts(Org_Specs)) amus
		amus=p+1
		
		//wave Org_Specs,Orgspecs_err,amus
				
		Edit/N=PMFExportTable ACSM_time
		AppendToTable /W=PMFExportTable amus
		AppendToTable /W=PMFExportTable Orgspecs_err
		AppendToTable /W=PMFExportTable Org_Specs
		ModifyTable/W=PMFExportTable format(ACSM_time)=8
		
		FileName=StationNameW[0]+"_ACSM-"+SN_str+"_"+"PMF_"+year+month+dayofmonth+hour+minute+".txt"
		saveTableCopy/O/T=1/W=PMFExportTable/P=SaveDataFilePathbis as FileName
		KillWindow PMFExportTable
	endif
	
	NVAR/Z GenerateSoFi=root:Autolycos:GenerateSoFi
	if (GenerateSoFi==1)
		ExportToFSoFi()	
	endif
	
	
	
End Function

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


Function ExportToFSoFi()

	SVAR/Z NextCloud_path=root:Autolycos:NextCloud_path
	string DataPathbis=NextCloud_path
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	DataPathbis+="SoFi:"
	NewPath/Q/O/C SaveDataFilePathbis, DataPathbis
	
	NewDataFolder/O/S root:Autolycos:SoFi
	wave DateW=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
	WaveStats/Q DateW
	variable lastrow=V_maxloc
//	variable lastrow=numpnts(DateW)-1
	wave DataW=root:Packages:tw_IgorDAQ:ACSM:nativeTS:params
	variable CEsetup=DataW[lastrow][20]
	
	
	duplicate/O dateW aut
//	wave DateW=root:ACSM_Incoming:acsm_utc_time
//	variable lastrow=numpnts(DateW)-1
//	wave aut = root:acsm:file_fpfile_list_dat
//	duplicate/O aut alt
//	wave DAQ_Matrix = root:acsm_incoming:DAQ_Matrix
//	alt = -1*(DAQ_Matrix[p][51] * 3600) + aut
//	
	wave mzbool=root:Autolycos:mzbool
//	
//	wave chT = root:diagnostics:chamberT
//	wave ab = root:diagnostics:airbeam
//	wave ip = root:diagnostics:inletP
//	wave vt = root:diagnostics:vapT
	wave/Z Org_pt = root:Autolycos:OM
	wave/Z SO4_pt = root:Autolycos:SO4
	wave/Z NO3_pt = root:Autolycos:NO3
	wave/Z NH4_pt = root:Autolycos:NH4
	wave/Z Chl_pt = root:Autolycos:Cl
//	wave/Z Masscalib_nitrate_pt = root:Masscalib_nitrate
	
	wave MSSD_orgPMF=root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_orgPMF
	wave MSSD_orgerr=root:Packages:tw_IgorDAQ:ACSM:nativeTS:MSSD_orgerr

	duplicate/O/R=(0,99) MSSD_orgPMF Org_Specs
	duplicate/O/R=(0,99) MSSD_orgerr Orgspecs_err
		
	Make/O/N=(numpnts(Org_Specs)) amus
	amus=p+1


//	wave Org_Specs_pt=root:PMFMats:Org_Specs
//	wave amus_pt=root:PMFMats:amus
//	wave Orgspecs_err_pt=root:PMFMats:Orgspecs_err
//	
	string wlStr = "org_specs;orgSpecs_err;amus;acsm_utc_time;Org;SO4;NO3;NH4;Chl"
//
	wave/T StationNameW=root:Autolycos:StationNameW
	SVAR/Z SN_str=root:Autolycos:SN_str
//	
//	
	string dstr
	dstr = secs2date(aut[lastrow], -2)
	dstr = StationNameW[0]+"_ACSM-"+SN_str+"_RTdata_" + dstr[0,3]+"_"+dstr[5,6]+"_"+dstr[8,9] + ".itx"
//	//dstr = "RTdata_" + dstr[0,3]+"_"+dstr[5,6]+"_"+dstr[8,9] + ".itx"
	GetFileFolderInfo /Z/Q/P=SaveDataFilePathbis dstr
	
	NVAR/Z ApplyMiddlebrook=root:ACMCC_Export:ApplyMiddlebrook
//	
	if(V_flag != 0) //file doesn't exist- create waves for it and write them
		
		Extract/O Orgspecs_err, Orgspecs_err, mzbool==1
		Extract/O amus, amus, mzbool==1
		Extract/O Org_Specs, Org_Specs, mzbool==1
		
		if (ApplyMiddlebrook==1)
			wave CE_ACMCC=root:Autolycos:CE
			Org_Specs*=CEsetup/CE_ACMCC[0]
			Orgspecs_err*=CEsetup/CE_ACMCC[0]
		endif
		
		MatrixOp /O Org_Specs = Org_Specs^t
		MatrixOp /O Orgspecs_err = Orgspecs_err^t
		
		make/D/O/N=1 acsm_utc_time; acsm_utc_time[0] = aut[lastrow]
		Duplicate/O Org_pt, Org
		Duplicate/O SO4_pt, SO4
		Duplicate/O NO3_pt, NO3
		Duplicate/O NH4_pt, NH4
		Duplicate/O Chl_pt, Chl
		
		Save /B/P=SaveDataFilePathbis /T wlStr as dstr
		
	
	else //file exists - load in the data and append to it
		
		duplicate/O Org_Specs Org_Specs_temp
		duplicate/O Orgspecs_err Orgspecs_err_temp
		
		Extract/O Orgspecs_err_temp, Orgspecs_err_temp, mzbool==1
		Extract/O amus, amus, mzbool==1
		Extract/O Org_Specs_temp, Org_Specs_temp, mzbool==1
		
		if (ApplyMiddlebrook==1)
			wave CE_ACMCC=root:Autolycos:CE
			Org_Specs_temp*=CEsetup/CE_ACMCC[0]
			Orgspecs_err_temp*=CEsetup/CE_ACMCC[0]
		endif
		
		MatrixOp /O Org_Specs_temp = Org_Specs_temp^t
		MatrixOp /O Orgspecs_err_temp = Orgspecs_err_temp^t
		
		loadwave/O/Q/T/P=SaveDataFilePathbis dstr

		wave/Z org_specs, orgSpecs_err,  acsm_utc_time
		variable n = numpnts(acsm_utc_time)
		insertPoints n, 1, org_specs, orgSpecs_err, acsm_utc_time
		org_specs[n][] = Org_Specs_temp[0][q]
		orgSpecs_err[n][] = Orgspecs_err_temp[0][q]
		acsm_utc_time[n] = aut[lastrow]
		
		wave/Z Org, SO4, NO3, NH4, Chl
		insertPoints n,1,Org, SO4,NO3,NH4,Chl
		Org[n]=Org_pt[0]
		SO4[n]=SO4_pt[0]
		NO3[n]=NO3_pt[0]
		NH4[n]=NH4_pt[0]
		Chl[n]=Chl_pt[0]
		

		save /B/O/P=SaveDataFilePathbis /T wlStr as dstr
	
	
	endif

End Function


Function StationInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	SVAR/Z ListOfStations=root:Autolycos:ListOfStations

	wave/T StationNameW=root:Autolycos:StationNameW
	if (stringmatch(str,"other"))
		string temp
		string prompt_str="Please enter the name of the station. Be consistent with previous files !"
		prompt temp, prompt_str
		doprompt "Please verify", temp
		StationNameW[0]=temp
		ListOfStations+=";"+temp
		
	elseif(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list the name of your station"
	else
		StationNameW[0]=str
	endif
End Function

Function/S InputLists(option)
	string option
	
	if (stringmatch(option,"Station"))
		SVAR/Z ListOfStations=root:Autolycos:ListOfStations
		return ListOfStations
	endif
	if (stringmatch(option,"Spectro"))
		SVAR/Z ToF_Quad_Str=root:Autolycos:ToF_Quad_Str
		return ToF_Quad_Str
	endif
	if (stringmatch(option,"Lens"))
		SVAR/Z Lens_Str=root:Autolycos:Lens_Str
		return Lens_Str
	endif
	if (stringmatch(option,"Vaporizer"))
		SVAR/Z Vaporizer_Str=root:Autolycos:Vaporizer_Str
		return Vaporizer_Str
	endif
	if (stringmatch(option,"Maxmz"))
		SVAR/Z Maxmz_Str=root:Autolycos:Maxmz_Str
		return Maxmz_Str
	endif
	
End Function

Function LensInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	wave/T LensW=root:Autolycos:LensW
	if(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list"
	else
		LensW[0]=str
	endif
End Function

Function VapInput_proc(name,num,str) : PopupMenuControl
	string name
	variable num
	string str

	wave/T VaporizerW=root:Autolycos:VaporizerW
	if(stringmatch(str,"select"))
		DoAlert/T="WARNING" 0,"Please select in the list"
	else
		VaporizerW[0]=str
	endif
	
	NVAR/Z ApplyMiddlebrook=root:Autolycos:ApplyMiddlebrook
	
	if(stringmatch(VaporizerW[0],"Capture Vap."))
		ApplyMiddlebrook=0
		CheckBox UseMiddlebrook_CB,disable=2
	elseif(stringmatch(VaporizerW[0],"Standard Vap."))
		ApplyMiddlebrook=1
		CheckBox UseMiddlebrook_CB,disable=0
	endif
	
End Function

Function SetPath_proc(Path_name) : ButtonControl
	String Path_name
	SVAR/Z NextCloud_path=root:Autolycos:NextCloud_path
	
	String temp_folder
	temp_folder = getdatafolder(1)
	
	//define path
	newpath/O/Q path1
	pathinfo path1
	NextCloud_path = S_path
	setdatafolder temp_folder
end




Function LaunchExport(ctrlName) : ButtonControl
	string CtrlName	
	
	NVAR/Z StartStop_bool=root:Autolycos:StartStop_bool

	if (StartStop_bool==0)


		// Doing preliminary checks	
		SVAR NextCloud_path=root:Autolycos:NextCloud_path
		GetFileFolderInfo/Q/D/Z=1 NextCloud_path
		if(V_flag != 0 && V_flag!=-1)
			DoAlert/T="WARNING" 0,"NextCloud folder was not found on your computer. Please check."
			Abort
		endif
		
		wave/T StationNameW=root:Autolycos:StationNameW
		ControlInfo PM_Station
		if (stringmatch(S_Value,"select") && stringmatch(StationNameW[0],""))
			DoAlert/T="WARNING" 0,"Please set the name of the station"
			Abort
		endif
		
		ControlInfo PM_Lens
		if (stringmatch(S_Value,"select"))
			DoAlert/T="WARNING" 0,"Please set the type of lens"
			Abort
		endif
		
		ControlInfo PM_Vap
		if (stringmatch(S_Value,"select"))
			DoAlert/T="WARNING" 0,"Please set the type of vaporizer"
			Abort
		endif
		// End of preliminary checks

		
		NVAR Number=root:Autolycos:Number
		wave/T ToF_QuadW=root:Autolycos:ToF_QuadW
		wave ACSM_time=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
		WaveStats/Q ACSM_time
		Number=v_max
		
		Button RunButton,title="STOP",fColor=(65280,16384,16384)
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
		PopupMenu PM_Maxmz,disable=2
		
		NVAR/Z Counts=root:Autolycos:Counts
		NVAR/Z RefreshRate=root:Autolycos:RefreshRate
		Counts=RefreshRate
		SetVariable Set_Counts, noedit=1, value=Counts
		



		ACMCC_StartTask()

	elseif(StartStop_bool==1)
		
		StartStop_bool=0
		Button RunButton,title="START",fColor=(26112,52224,0)
		
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
		PopupMenu PM_Maxmz,disable=0
		
		NVAR/Z Counts=root:Autolycos:Counts
		NVAR/Z RefreshRate=root:Autolycos:RefreshRate
		Counts=RefreshRate
		SetVariable Set_Counts, noedit=0, value=RefreshRate
		
		ACMCC_StopTask()
		
	endif

End Function


Function ACMCC_StartTask()
	
	NVAR/Z RefreshRate=root:Autolycos:RefreshRate
	NVAR/Z Counts=root:Autolycos:Counts
	Variable numTicks = RefreshRate*60	//1 tick=1/60 s
	CtrlNamedBackground Test, period=numTicks, proc=ACMCC_Task
	CtrlNamedBackground Test, start
	
	NVAR/Z StartStop_bool=root:Autolycos:StartStop_bool
	StartStop_bool=1
	Button RunButton,title="STOP",fColor=(65280,16384,16384)
	
	CtrlNamedBackground Counting,period=60,proc=ACMCC_Counting
	CtrlNamedBackground Counting, start
	
End


Function ACMCC_Counting(s)   
	STRUCT WMBackgroundStruct &s
	NVAR/Z Counts=root:Autolycos:Counts
	NVAR/Z RefreshRate=root:Autolycos:RefreshRate
	
	Counts-=1
	
	return 0
End Function


Function ACMCC_StopTask()
	CtrlNamedBackground Test, stop
	
	NVAR/Z StartStop_bool=root:Autolycos:StartStop_bool
	StartStop_bool=0
	Button RunButton,title="START",fColor=(26112,52224,0)
	
	CtrlNamedBackground Counting, stop
	NVAR/Z RefreshRate=root:Autolycos:RefreshRate
	NVAR/Z Counts=root:Autolycos:Counts
	Counts=Refreshrate
	
End



Function ACMCC_Task(s)   
	STRUCT WMBackgroundStruct &s
	
	NVAR Number=root:Autolycos:Number
	wave ACSM_time=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
	SetDataFolder root:Autolycos
	duplicate/O ACSM_time temp
	WaveStats/Q temp
	//Number=v_max
	if (number<V_max)
		number=V_max
		ACMCC_ToF_TriggeredExport()
	endif
	
//	if (Number<numpnts(ACSM_time))
//			Number=numpnts(ACSM_time)
//			ACMCC_ToF_TriggeredExport()	//Export for ToF
//	endif

	NVAR/Z RefreshRate=root:Autolycos:RefreshRate
	NVAR/Z Counts=root:Autolycos:Counts
	Counts=Refreshrate
	
	return 0
End


Function ACMCC_DryerStat_avg(lastrow)
	variable lastrow

	string file_prefix="DryerStats_"
	Wave ACSM_UTC_Time=root:Packages:tw_IgorDAQ:ACSM:nativeTS:t_stop
	string DateFromTime=secs2date(acsm_utc_time[lastrow],-2)
	string DryerFileName=file_prefix+DateFromTime[0,3]+DateFromTime[5,6]+DateFromTime[8,9]+".txt"
	
	SVAR/Z DryerStat_path=root:Autolycos:DryerStat_path
	NewPath/O/Q/Z DryerDataDir, DryerStat_path	
	KillDataFolder/Z root:Autolycos:DryerData
	NewDataFolder/O/S root:Autolycos:DryerData
	Make/O/N=1 RH_In_avg,T_In_avg,Dp_In_avg,RH_Out_Avg,T_Out_avg,Dp_Out_avg,FlowR_avg,P_Drop_avg
	GetFileFolderInfo/P=DryerDataDir/Q/Z DryerFileName
	if (V_flag!=0)
		print "Dryer file not found"
		return 0
	endif
	
	
	LoadWave /J/A/B="F=-2,N=DateTimeW;F=0,N=InletP;F=0,N=CounterP;F=0,N=PDrop;F=0,N=FlowRate;F=0,N=RHIn;F=0,N=TIn;F=0,N=RHDry;F=0,N=TDry;"/L={0,1,0,0,0}/D/O/P=DryerDataDir/Q DryerFileName
	wave DateTimeW
	TextWavesToDateTimeWave(dateTimeW, "DateTimeWave")
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
			TextWavesToDateTimeWave(dateTimeW, "DateTimeWave")
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

Function ConvertTextToDateTime(datetimeAsText)
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



Function/WAVE TextWavesToDateTimeWave(datetimeAsTextWave, outputWaveName)
    WAVE/T datetimeAsTextWave       // Assumed in YYYY-MM-DD format
    String outputWaveName

    Variable numPoints = numpnts(datetimeAsTextWave)
    Make/O/D/N=(numPoints) $outputWaveName
    WAVE wOut = $outputWaveName
    SetScale d, 0, 0, "dat", wOut
   
    Variable i
    for(i=0; i<numPoints; i+=1)
        String datetimeAsText = datetimeAsTextWave[i]
        Variable dt = ConvertTextToDateTime(datetimeAsText)
        wOut[i] = dt   
    endfor 
   
    return wOut
End