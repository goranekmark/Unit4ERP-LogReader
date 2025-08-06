<#
.SYNOPSIS
   Read-Unit4ERPWebLog reads a Unit4 ERP Web-Api log and outputs it as an object
.DESCRIPTION
    Read-Unit4ERPWebLog returns an object with the properties Time, Category and Msg. The Msg in the log can be on several lines, these are concatenated into one line.
    The log is read in full with Get-Content.
.NOTES
    This function is specifically designed for Unit4 ERP Weblogs.
.EXAMPLE
    $Logpath = "c:\folder\weblog.txt"
    Read-Unit4ERPWeblog -Path $Log 
.EXAMPLE
    $Logpath = "c:\folder\weblog.txt"
    Read-Unit4ERPWeblog -Path $Log | Select-Object -Property Msg | Select-String "login"
#>
function Read-Unit4ERPWebLog {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$LogPath
    )
    begin {
        class Unit4ERPLogItem {
            [string]$Time
            [string]$Category 
            [string]$Msg
        }
        $StartRowPattern = '====== EVENT ======'
        $TimeStampPattern = '^\d\d:\d\d:\d\d \*\* '
        $i = 0
        $Log = Get-Content $LogPath
        $StringBuilder = [System.Text.StringBuilder]::new()
    }
    process {
        $Output = foreach ($l in $Log) {  
            if ($l -match $StartRowPattern -and $l -ne '') {
                $Row = [Unit4ERPLogItem]::new()
            }
            if ($l -match $TimeStampPattern -and $l -ne '') {
                $Time = $l -split ' \*\* ' | Select-Object -First 1
                $Category = $l -split ' \*\* ' | Select-Object -Skip 1
                $Row.Time = $Time
                $Row.Category = $Category
                [void]$StringBuilder.Append($Msg)
                
            }
            if ($l -notmatch $StartRowPattern -and $l -notmatch $TimeStampPattern -and $l -ne '') {
                [void]$StringBuilder.Append($l)
            }

            if (($Log[$i + 1] -match $StartRowPattern) -or ($i -eq $Log.Count)) {
                $Row.Msg = $StringBuilder.ToString()
                [void]$StringBuilder.Clear()
                $Row 
            }
            $i++
        }
    }
    end {
        $Output 
    }
}
<#
.SYNOPSIS
   Read-Unit4ERPLog reads a Unit4 ERP log and outputs it as an object.

.DESCRIPTION
    Read-Unit4ERPLog returns an object with the properties Date, Time, Category, and Msg. The Msg in the log can be on several lines, these are concatenated into one line.
    The log is read in full with Get-Content.

.NOTES
    This function is specifically designed for Unit4 ERP logs.

.EXAMPLE
    $Logpath = "c:\folder\log.txt"
    Read-Unit4ERPLog -Path $Log
#>
function Read-Unit4ERPLog {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$LogPath
    )
    begin {
        class Unit4ERPLogItem {
            [string]$Date
            [string]$Time
            [string]$Category 
            [string]$Msg
        }
        $StartRowPattern = '^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d:*'
        $i = 0
        $Log = Get-Content $LogPath
        $StringBuilder = [System.Text.StringBuilder]::new()
    }
    process {
        $Output = foreach ($l in $Log) {  
            if ($l -match $StartRowPattern -and $l -ne '') {
                $Row = [Unit4ERPLogItem]::new()
                $Date, $Time = $l -split ' ' | Select-Object -First 2 
                $AfterTimeAndDate = $l.Remove(0, 20)
                $Category = $AfterTimeAndDate -split ':' | Select-Object -First 1
                $Msg = $AfterTimeAndDate -replace ($Category + ':')
                $Row.Date = $Date
                $Row.Time = $Time
                $Row.Category = $Category
                [void]$StringBuilder.Append($Msg)
            }
            if ($l -notmatch $StartRowPattern -and $l -ne '') {
                [void]$StringBuilder.Append($l)
            }
            if (($Log[$i + 1] -match $StartRowPattern) -or ($i -eq $Log.Count)) {
                $Row.Msg = $StringBuilder.ToString()
                [void]$StringBuilder.Clear()
                $Row 
            }
            $i++
        }
    }
    end {
        $Output 
    }
}
<#
.SYNOPSIS
   Get-Unit4ERPLogElapsedAndAccumulatedTime calculates the elapsed and accumulated time for each log item in an array of Unit4 ERP logs.

.DESCRIPTION
    This function takes an object containing a collection of Unit4 ERP logs as input, and returns an object with the same properties plus two additional ones: ElapsedSeconds and AccumulatedTimeSeconds.
    The ElapsedSeconds property contains the elapsed time between each log item, while the AccumulatedTimeSeconds property contains the accumulated time since the first log item.
.NOTES
    This function uses the ForEach-Object cmdlet to iterate over each log item in the input object.
.EXAMPLE
    $Unit4ERPLog = Read-Unit4ERPLog -Path "c:\folder\log.txt"
    $Result = Get-Unit4ERPLogElapsedAndAccumulatedTime -InputObject $Unit4ERPLog
#>
function Get-Unit4ERPLogElapsedAndAccumulatedTime {
    param (
        [object]$Unit4ERPLog
    )
    $withElapsedTime = $Unit4ERPLog | ForEach-Object -Begin { $i = 0 } -Process {
        $Preceding = $i - 1
        $ElapsedMs = { (New-TimeSpan -Start ($Unit4ERPLog[$Preceding].Time) -End ($Unit4ERPLog[$i].Time)).TotalSeconds }
        $AccumulatedTimeMs = { (New-TimeSpan -Start ($Unit4ERPLog[0].Time) -End ($Unit4ERPLog[$i].Time)).TotalSeconds }
        Select-Object -InputObject $Unit4ERPLog[$i] -Property Date, Time, Category, Msg, 
        @{
            Name = 'ElapsedSeconds'; Expression = $elapsedMs
        }, 
        @{Name = 'AccumulatedTimeSeconds'; Expression = $AccumulatedTimeMs
        }
        $i++
    } 
    $withElapsedTime[0].ElapsedSeconds = 0
    $withElapsedTime 
}