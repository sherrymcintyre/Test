###########################################################################
# NAME: DNS.Reverse.Lookup
###########################################################################

get-content “C:\temp\IPList.txt” | ForEach-Object {
[System.Net.Dns]::GetHostbyAddress($_) |
Add-Member -Name IP -Value $_ -MemberType NoteProperty -PassThru
} | Select IP, HostName | Tee-Object c:\temp\ReverseLookupResults.txt | write-host
#} | Select IP, HostName | export-csv c:\temp\ReverseLookupResults.csv