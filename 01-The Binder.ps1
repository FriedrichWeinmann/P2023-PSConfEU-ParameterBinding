# failsafe
return


#----------------------------------------------------------------------------#
#                            The Order of Things                             #
#----------------------------------------------------------------------------#

<#
Binding Order:
- Named Parameters
- Positional Parameters
- Dynamic named Parameters
- Dynamic Positional Parameters

From Pipeline:
- Object of exact same type
- Property of correct name(s) with exact same type (if accepting by PropertyName)
- Object Converted to target type
- Property of correct name(s) converted to target type (if accepting by PropertyName)
#>


#----------------------------------------------------------------------------#
#                             Tool of the Trade                              #
#----------------------------------------------------------------------------#

function Show-Binding {
	[CmdletBinding()]
	param (
		$Param1
	)
}
$null = Trace-Command -Name '*Param*' -Expression {
	Show-Binding -Param1 42
} -PSHost

$null = Trace-Command -Name '*Param*' -Expression {
	Show-Binding -Param1 42 -Param2 23
} -PSHost

code C:\code\GitHub\PSTrace\PSTrace\functions\Trace-ParameterBinding.ps1
Import-Module C:\code\GitHub\PSTrace\PSTrace\PSTrace.psd1 -Force

Trace-ParameterBinding -ScriptBlock {
	Show-Binding -Param1 42
}

#----------------------------------------------------------------------------#
#                                Simple Bind                                 #
#----------------------------------------------------------------------------#

function Show-BindingExtended {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$Param1,

		[Parameter(Position = 1)]
		[string]
		$Param2,

		[string]
		$Param3
	)
}
Trace-ParameterBinding -ScriptBlock {
	Show-BindingExtended -Param1 42
}
# Named over Positional
Trace-ParameterBinding -ScriptBlock {
	Show-BindingExtended 23 -Param1 42
}

# Mandatory unmet
Trace-ParameterBinding -ScriptBlock {
	Show-BindingExtended -Param2 42
}

# Simply Wrong ... in more ways than one
Trace-ParameterBinding -ScriptBlock {
	Show-BindingExtended -Param1
}
#-> Ugh

function Show-DynamicBinding {
	[CmdletBinding()]
	param (
		[Parameter(Position = 0)]
		[string]
		$Param1,

		[Parameter(Position = 3)]
		[string]
		$Param2,

		[string]
		$Param3
	)

	DynamicParam {
		$paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

		if ($PSBoundParameters.Param1 -eq 'Foo') {
			$attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()

			$attrib = [Parameter]::new()
			$attrib.Position = 2
			$attributeCollection.Add($attrib)

			$dynParam = [System.Management.Automation.RuntimeDefinedParameter]::new('Class', [int], $attributeCollection)

			$paramDictionary.Add('Class', $dynParam)
		}

		if ($PSBoundParameters.Param2 -eq 'Bar') {
			$attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()

			$attrib = [Parameter]::new()
			$attributeCollection.Add($attrib)

			$dynParam = [System.Management.Automation.RuntimeDefinedParameter]::new('Type', [string], $attributeCollection)

			$paramDictionary.Add('Type', $dynParam)
		}

		$paramDictionary
	}

	process {
		$PSBoundParameters
	}
}
Trace-ParameterBinding -ScriptBlock {
	Show-DynamicBinding -Param1 foo 42 23
}
#-> Positional Binding does not honor dynamic parameters having a higher priority

Trace-ParameterBinding -ScriptBlock {
	Show-DynamicBinding -Param1 foo -Param2 bar 23 -Type whatever -Param3 42
}
#-> Dynamic Parameters have their own set of processing Named vs. Positional

Trace-ParameterBinding -ScriptBlock {
	Show-DynamicBinding -Param3 42 -Param1 foo -Param2 bar 23 -Type whatever
}
#-> Order of named parameters matters as well (somewhat)

#----------------------------------------------------------------------------#
#                                 Splatting                                  #
#----------------------------------------------------------------------------#

# Direct Bound
Get-ChildItem -Path C:\ -Force

# Splatting
$param = @{
	Path  = 'C:\'
	Force = $true
}
Get-ChildItem @param

$param2 = @{
	File = $true
}
Get-ChildItem @param @param2

Trace-ParameterBinding -ScriptBlock {
	Get-ChildItem -Path C:\ @param2 -Force
}
#-> Nothing about splatting - has exactly no effect on the binding process
#   Is resolved outside and then treated as regular named parameters

# Shameless Plug: PSFramework
$hashtable = @{
	Path     = 'C:\'
	Force    = $true
	Category = 'Red'
}
$hashtable | ConvertTo-PSFHashtable -ReferenceCommand Get-ChildItem


#----------------------------------------------------------------------------#
#                               Pipeline Input                               #
#----------------------------------------------------------------------------#

function Show-PipelineBinding {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		[int]
		$InputObject,

		[string]
		$NormalParameter
	)

	process {
		$InputObject
	}
}

Trace-ParameterBinding -ScriptBlock {
	Show-PipelineBinding -InputObject 42 -NormalParameter 23
}
#-> No change

Trace-ParameterBinding -ScriptBlock {
	1..3 | Show-PipelineBinding -NormalParameter 23
}

# Scriptblock Binding
#----------------------

Get-Item C:\temp\file.txt | Rename-Item -NewName { '00_{0}' -f $_.Name } -WhatIf

Trace-ParameterBinding -ScriptBlock {
	1..3 | Show-PipelineBinding -InputObject { $_ * $_ }
}

# Steppable Pipelines
#----------------------
function Export-CsvCustom {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,

		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)

	process {
		$InputObject | Export-Csv -Path $Path -Append -Delimiter ';' -NoTypeInformation -Force
	}
}
Get-ChildItem -Path C:\Windows | Export-CsvCustom -Path C:\temp\demo\report.csv

function Export-CsvCustom2 {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,

		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)

	begin {
		$command = { Export-Csv -Path $Path -Delimiter ';' -NoTypeInformation -Force }.GetSteppablePipeline()
		$command.Begin($true)
	}
	process {
		$command.Process($InputObject)
	}
	end {
		$command.End()
	}
}
Get-ChildItem -Path C:\Windows | Export-CsvCustom2 -Path C:\temp\demo\report.csv

# Sooo ... what's happening here?
$command = { Show-PipelineBinding }.GetSteppablePipeline()
Trace-ParameterBinding -ScriptBlock { $command.Begin($true) }
Trace-ParameterBinding -ScriptBlock { $command.Process(1) }
Trace-ParameterBinding -ScriptBlock { $command.Process(2) }
Trace-ParameterBinding -ScriptBlock { $command.Process(3) }
Trace-ParameterBinding -ScriptBlock { $command.End() }


#----------------------------------------------------------------------------#
#                               ParameterSets                                #
#----------------------------------------------------------------------------#

function Show-ParameterSet1 {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'One')]
		[string]
		$Param1,

		[Parameter(Mandatory = $true, ParameterSetName = 'One')]
		[Parameter(ParameterSetName = 'Two')]
		[string]
		$Param2,

		[Parameter(Mandatory = $true, ParameterSetName = 'Two')]
		[string]
		$Param3
	)

	$PSCmdlet.ParameterSetName
}
Show-ParameterSet1 -Param2 42
Show-ParameterSet1 -Param2 42 -Param1 23
Trace-ParameterBinding -ScriptBlock {
	Show-ParameterSet1 -Param2 42 -Param1 23
}

# Throw in the Pipeline
function Show-ParameterSet2 {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'File')]
		[System.IO.FileInfo[]]
		$File,

		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'Folder')]
		[System.IO.DirectoryInfo[]]
		$Directory
	)
	Begin {
		"Start set: $($PSCmdlet.ParameterSetName)"
	}
	Process {
		"  Process set: $($PSCmdlet.ParameterSetName)"
	}
	End {
		"End set: $($PSCmdlet.ParameterSetName)"
	}
}
Get-ChildItem C:\temp | Show-ParameterSet2
$items = Get-ChildItem C:\temp | Group-Object PSIsContainer | ForEach-Object { $_.Group[0] }
Trace-ParameterBinding -ScriptBlock {
	$items | Show-ParameterSet2
}
# Values from pipeline are matched to all parameters!

#region Aside: Multibinding in the Pipeline
function Show-PipelineBinding2 {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		[object]
		$InputObject,

		[Parameter(ValueFromPipeline = $true)]
		[string]
		$Name,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]
		$FullName
	)

	process {
		[PSCustomObject]@{
			Object   = $InputObject
			Name     = $Name
			FullName = $FullName
		}
	}
}
Get-Item -Path C:\Windows | Show-PipelineBinding2
$item = Get-Item -Path C:\Windows
Trace-ParameterBinding -ScriptBlock {
	$item | Show-PipelineBinding2
}
#endregion Aside: Multibinding in the Pipeline

#----------------------------------------------------------------------------#
#                            Native Applications                             #
#----------------------------------------------------------------------------#

# The mother of all commandline tools
Trace-ParameterBinding -ScriptBlock { ping 1.1.1.1 -n 1 }

# The good old escape sequence for native applications
Trace-ParameterBinding -ScriptBlock {
	ping --% 1.1.1.1 -n 1
}

# And it really doesn't affect the BINDING
Trace-ParameterBinding -ScriptBlock {
	ping --% "1.1.1.1" -n 1
}

# Pipeline and native apps?
Trace-ParameterBinding -ScriptBlock {
	'microsoft.com' | nslookup
}

# Send input to pipeline capable commands
"SELECT DISK 0", "LIST VOLUME" | diskpart

# Module: PSNative
$diskpart = Start-NativeProcess -Name diskpart
$diskpart.ReadOutput()

$diskpart.Send("SELECT DISK 0")
$diskpart.ReadOutput()

$diskpart.Send("LIST VOLUME")
$diskpart.ReadOutput()