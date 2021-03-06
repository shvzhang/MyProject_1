$xlfile="C:\backup\Rogers_CTM\test_6.xlsx"
$outfile="C:\backup\Rogers_CTM\test_6.json"

$rowstart=9
$rowend=15


$xl=New-Object -ComObject Excel.Application
$xl.Visible=$false

$wb=$xl.workbooks.open($xlfile)
$ws=$wb.sheets.item("Job Definition Request Form")


$folder="TMP"
$jfolder=@{}

$jjob=[ordered]@{}
$jjob["Type"]="Folder"

for($row = $rowstart ; $row -le $rowend ; $row++)
{
  $waitevents=@()
  $addevents=@()
  $variables=@()
  
  $jobname = $ws.cells.item($row,3).value2
  $application = $ws.cells.item($row,10).value2
  $group = $ws.cells.item($row,11).value2
  $table=$ws.cells.item($row,12).value2
  $owner = $ws.cells.item($row,9).value2
  $nodeid=$ws.cells.item($row,14).value2
  $desc = $ws.cells.item($row,13).value2
  $tasktype = ($ws.cells.item($row,4).value2).ToUpper()
  $memlib=$ws.cells.item($row,6).value2
  $memname=$ws.cells.item($row,5).value2
  $cmdline=$ws.cells.item($row,7).value2
  
  if ( $ws.cells.item($row,22).value2 )
  {
    $inconds=($ws.cells.item($row,22).value2).trim().split("`n")
  }else
  {
    $inconds=''
  }
  if ($inconds -ne '')
  {
    foreach ($incond in $inconds)
     {
       $waitevents+=@{"Event" = ($incond+'_OK')}
     }
   }
  
  
  if ( $ws.cells.item($row,8).value2 )
  {
    $parms=($ws.cells.item($row,8).value2).trim().split("`n")
  }else
  {
    $parms=''
  }
  if ($parms -ne '')
  {
    foreach ($parm in $parms)
    {
        $parmstring=$parm.trim() -split '='
        $parmname=$parmstring[0]
        $parmvalue=$parmstring[1]
        $variables+=@{"$parmname"="$parmvalue"}
    }
  }
  
  if ($tasktype -eq 'AFT'){
    $transfer=@()
    $option=$memname.trim().split("`n")
    $srclist=$memlib.trim().split("`n")
    $destlist=$cmdline.trim().split("`n")
    for ($i=0;$i -le ($option.count-1);$i++)
    {
      $transfer+=@{"Src"=$srclist[$i];"Dest"=$destlist[$i];"TransferOption"=$option[$i]}    
    }
  }
  

  if ($tasktype -eq 'JOB')
  {
    $jjob[$jobname]=[ordered]@{"Type"="Job:Script";"FileName"=$memname;"FilePath"=$memlib}
  }elseif ($tasktype -eq 'COMMAND')
  {
    $jjob[$jobname]=[ordered]@{"Type"="Job:Command";"Command"=$cmdline}
  }elseif ($tasktype -eq 'DUMMY')
  {
    $jjob[$jobname]=[ordered]@{"Type"="Job:Dummy"}
  }elseif ($tasktype -eq 'FW')
  {
    $fwfilenotfound=[ordered]@{"Type"="If";"CompletionStatus"="7"}
    $fwfilefound=[ordered]@{"Type"="If";"CompletionStatus"="0"}

    $fwfilenotfound["DOCOND"]=[ordered]@{"Type"="Event:Add";"Event"=($jobname+'_NOTOK')}
    $fwfilenotfound["DOOK"]=[ordered]@{"Type"="Action:SetToOK"}

    $fwfilefound["DOCOND"]=[ordered]@{"Type"="Event:Add";"Event"=($jobname+'_OK')}

    $jjob[$jobname]=[ordered]@{"Type"="Job:Command";"Command"=$cmdline;"Filenotfound"=$fwfilenotfound;"Filefound"=$fwfilefound}   
  }elseif ($tasktype -eq 'AFT')
  {
    $jjob[$jobname]=[ordered]@{"Type"="Job:FileTransfer";"ConnectionProfileSrc"="LocalConn";"ConnectionProfileDest"=$owner;"FileTransfers"=$transfer}
  }

  $jjob[$jobname]["Application"]=$application 
  $jjob[$jobname]["SubApplication"]=$group
#  $jjob[$jobname]["RunAs"]=$owner
  $jjob[$jobname]["Host"]=$nodeid
  $jjob[$jobname]["Description"]=$desc

  if ($tasktype -ne 'AFT')
  {
    $jjob[$jobname]["RunAs"]=$owner
  }
  
  if ($waitevents.Count -gt 0)
  {
    $jjob[$jobname]["INCOND"]=[ordered]@{"Type"="WaitForEvents";"Events"=$waitevents}
  }
  
  if ($tasktype -ne 'FW')
  {
    $addevents+=@{"Event"=($jobname+'_OK')}
    $jjob[$jobname]["OUTCOND"]=[ordered]@{"Type"="AddEvents";"Events"=$addevents}
  }

  if ($variables.Count -gt 0)
  {
    $jjob[$jobname]["Variables"]=$variables
  }

}

$jfolder[$folder]=$jjob
$jfolder | ConvertTo-Json -Depth 100 | Out-File $outfile

$xl.quit()