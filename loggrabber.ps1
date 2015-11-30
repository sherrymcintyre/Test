#v1.1 - 11/1/2015
<#
Usage examples:

.\loggrabber.ps1 hostname

This will grab all logs under \\hostname\g$\localuser\g*, and save a local copy as C:\Temp\Logs-Hostname-All.zip

.\loggrabber.ps1 hostname:XXXXX

(Where XXXXX is the Game Port / aka Instance identifier conversationally used when referenced from Blaze)

This will query the server to map a GamePort to a ServerInstancePath, assumming this instance is RUNNING since it queries real time Commandline parameters,
This will then grab all logs under \\hostname\g$\localuser\gXXXXXX, and save a local copy as C:\Temp\Logs-Hostname-XXXXX.zip


.\loggrabber.ps1 hostname:gXXXXXX

This will grab all logs under \\hostname\g$\localuser\gXXXXXX\Logs , and save a local copy as C:\Temp\Logs-Hostname-gXXXXXX.zip

Note: you can use a hostname OR an FE IP.  The FE IP will only work currently if you are querying from a machine with it's own FE IP I believe

#>

param([Parameter(Mandatory=$True)]$serverinfo=$NULL)


Add-Type -assembly "system.io.compression.filesystem"
#$MyHost = $env:COMPUTERNAME

$Destination = "C:\Temp\"

$instanceinfo = $NULL
$Proceed = $False
If($serverinfo)
{
    #Let's translate the FE IP if it exists, asap.
    #Trying to rely on DNS, if this can't work we'll find another way - kevlar etc
    If($serverinfo -match "\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b")
    {
        $FEIP = [string]$matches.Values
        If(($FEIP -like "159.153.*") -OR ($FEIP -like "175.45*"))
        {
            write-host "WARNING - resolving FE IP to hostname is not working consistently right now..."
            $FECheck = [System.Net.Dns]::GetHostEntry($FEIP)
            If($FECheck){$hosttmp = $FECheck.Hostname.split(".")[0];$serverinfo = $serverinfo.replace($FEIP,$hosttmp);write-host "Resolved $FEIP to $hosttmp"}
            else{write-host "Could not resolve a DNS record of $FEIP - please try again with a friendly hostname";exit}
        }
        else{write-host "Non-EA FE IP space detected - exiting";exit}        
    }


    $ServerFinal = $NULL
    $TempSvr = $NULL

    If($serverinfo.contains(":"))
    {
        #This implies we are pulling logs for a specific instance by port or folder name
        $tempsvr = $serverinfo.split(":")[0]       
        $instanceinfo = $serverinfo.split(":")[1]
        switch -regex ($instanceinfo)
        {
            "game[0-9]+"{write-host "No reason to touch game binary directories, exiting";exit}
            "g[0-9]+$"{write-host "Grabbing a specific set of logs for $instanceinfo";$SpecFolder = $True;break}
            "^[0-9]+$"{write-host "Grabbing a specific set of logs for the instance on port $instanceinfo";$SpecPort = $True;break}
            default{write-host "please check that your parameters are valid:    $serverinfo`n Exiting Script";exit}      
        }

        #If a specific folder was requested - e.g. hostname:g50235
        
        If($SpecFolder)
        {
            If(test-connection $TempSvr)
                {
                    $ServerFinal = "\\" + $TempSvr + "\g`$\localuser\" + $instanceinfo + "\Logs\"
                    If(!(Test-Path $ServerFinal)){write-host "Unable to connect to $ServerFinal - is this the expected path ?"}
                    else{$Proceed = $True}
                }
        }

        If($SpecPort)
        {
            #If a specific gameport instance was requested - e.g. hostname:25450
            If(Test-Connection $TempSvr)
            {
                $myinstance = gwmi win32_process -computer $TempSvr | ?{($_.Name -like "*Race*Main*") -and ($_.CommandLine -like "*GamePort $instanceinfo*")} | select Commandline
                $temp1 = $myinstance.Commandline.split("-")
                foreach($s in $temp1)
                {
                    If($s -like "ServerInstancePath*")
                    {$instancepath = $s.split(" ")[1];$instancepath = $instancepath.split("\")[2];break}
                }
                $ServerFinal = "\\" + $TempSvr + "\g`$\localuser\" + $instancepath + "\Logs\"
                If(!(Test-Path $ServerFinal)){write-host "Unable to connect to $ServerFinal - is this the expected path ?"}
                else{$Proceed = $True}

            }
        }

    }
    else
    {
        #This implies we are pulling all logs        
        If(test-connection $serverinfo)
            {
                $ServerFinal = "\\" + $serverinfo + "\g`$\localuser\"
                If(!(Test-Path $ServerFinal)){write-host "Unable to connect to $ServerFinal - is this the expected path ?"}
                else{$Proceed = $True}
            }
        else
        {write-host "Unable to connect to $serverinfo, please make sure that this name is correct.  You may need to switch to FQDN ?"}
    }  
}



If($Proceed)
{

    write-host "pulling logs from : $ServerFinal `n"

    $MainDir = $ServerFinal
    $DestinationID = [string](get-date).ToFileTimeUtc()
    $Destination2 = $Destination + $DestinationID + "\"


    If($instanceinfo)
    {
        $All = gci $MainDir
            $tempdest = $NULL
            $tempdest = $Destination2 + "\logs\"
            If(!(test-path ($tempdest))){New-Item -ItemType Directory -Force -Path $tempdest | out-null}
        Foreach($x in $All)
        {

            
            cp $x.FullName ($tempdest)
        }

    }
    else
    {
        $All = gci $MainDir | ?{$_.Mode -like "d*"}
        Foreach($x in $All)
        {
            If(($x.Name -notlike "*game*"))
            {
                $temp = $NULL                
                $temp = $MainDir + $x.Name + "\logs"
                If(test-path $temp)
                {
                    $logs = $NULL
                    $logs = gci $temp
                    $tempdest = $NULL
                    $tempdest = $Destination2 + $x.Name + "\logs\"
                    If(!(test-path ($tempdest))){New-Item -ItemType Directory -Force -Path $tempdest | out-null}
                    $logs | %{cp $_.FullName ($tempdest)}            
                }               
            }
        }
    }
    

    #will swap out the : if it exists
    If($instanceinfo)
    {$serverinfo2 = "Logs-" + $serverinfo.replace(":","-") + ".zip"}
    else
    {$serverinfo2 = "Logs-" + $serverinfo + "-All.zip"}

        If(test-path $serverinfo2){write-host "$Destination$serverinfo2 Already Exists !! - please delete this and run the script again !";write-host "`nAlso delete this directory for cleanup, or zip it up with a new unique name ! $Destination2";exit}
        [io.compression.zipfile]::CreateFromDirectory($destination2, ($Destination + $serverinfo2))

        write-host "Deleting $Destination2, the local copy for cleanup purposes"
        ri $Destination2 -Force -Recurse
        write-host "$Destination$serverinfo2 is ready to go"
    }
else{write-host "Something is wrong, please double check your input for errors:   $serverinfo"}