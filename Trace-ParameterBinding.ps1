#requires -Modules PSFramework
function Trace-ParameterBinding {
	[CmdletBinding()]
	param (
		[scriptblock]
		$ScriptBlock,

		[switch]
		$Raw
	)
	process {
		$file = New-PSFTempFile -Name ParamTrace -ModuleName demo
		$null = Trace-Command -Name '*Param*','TypeConversion' -Expression $scriptblock -FilePath $file -ListenerOption DateTime -ErrorAction Ignore
		$lines = Get-Content -Path $file
		Remove-PSFTempItem -Name ParamTrace -ModuleName demo

		if ($Raw) { return $lines }
		
		$data = @{ }
		$isMainData = $true
		$firstTimestamp = $null
		foreach ($line in $lines) {
			if ($isMainData) {
				$source, $type, $level, $remaining = $line -split " ", 4
				$data = @{
					PSTypeName = 'PSTrace.TraceResult'
					Source  = $source
					Type    = $type -replace '[ :]'
					Level   = $level -as [int]
					Message = $remaining -replace '^[: ]+'
				}
				$isMainData = $false
				continue
			}

			$timeStamp = ($line -replace '^.+DateTime=(\S+).{0,}', '$1') -as [datetime]
			$data.Timestamp = $timeStamp
			if (-not $firstTimestamp) { $firstTimestamp = $timeStamp }
			$data.Delta = $timestamp - $firstTimestamp
			[PSCustomObject]$data
			$isMainData = $true
		}
	}
}