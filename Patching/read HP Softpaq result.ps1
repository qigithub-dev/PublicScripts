$array = @();
$text = get-content -Path 'C:\ProgramData\HP\HP SoftPaq Download Manager\Logs\%computername%.htm';
$i = 1;
$start = ($text | Select-string -Pattern 'UpPerformed').Linenumber;
foreach ($line in ($text | Select-Object -Skip $start)) {
    if ($line -match 'Update ' + $i) {
        $line -match '<li>&nbsp;(.+)<\/li>' | Out-Null;
        $array += $matches[1] -replace '\s+', ' ';
        $i++
    }
}
$array;