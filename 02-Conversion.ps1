# failsafe
return

#----------------------------------------------------------------------------#
#                      The Conversion Priority Sequence                      #
#----------------------------------------------------------------------------#

<#
Option 1: The Default PS Type Conversion

- Correct Type (noop)
- Language Specific Rules (bool, string, ..)
- Constructor
- TypeConverter
- Implicit & Explicit Cast
- IConvertible
#>

<#
Option 2: Argument Transformation Attribute

- Argument Transformation Attribute
#>

Find-PSMDType -InheritsFrom System.Management.Automation.ArgumentTransformationAttribute

#----------------------------------------------------------------------------#
#                             Parameter Classes                              #
#----------------------------------------------------------------------------#

# Recording: https://www.youtube.com/watch?v=ui_pmyrXgew&ab_channel=PowerShellConferenceEU

class DateTimeParam {
    [DateTime] $Value
    [object] $InputObject

    static [HashTable] $PropertyMapping = @{}

    DateTimeParam([DateTime] $Value) {
        $this.Value = $Value
        $this.InputObject = $Value
    }

    DateTimeParam([string] $Value) {
        $this.Value = $this.ParseDateTime($Value)
        $this.InputObject = $Value
    }

    DateTimeParam([object] $Value) {
        if ($null -eq $Value) { throw 'Hey Gringo, you try converting $null to DateTime!' }

        $this.InputObject = $Value
        $this.Value = $this.ProcessObject($Value)
    }

    hidden [DateTime] ParseDateTime([string] $Value) {
        if (-not $Value) {
            throw "Cannot parse empty string!"
        }

        try { return [DateTime]::Parse($Value, [System.Globalization.CultureInfo]::CurrentCulture) }
        catch { }
        try { return [DateTime]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture) }
        catch { }

        [bool]$positive = -not $Value.Contains('-')
        [string]$tempValue = $Value.Replace("-", "").Trim()
        [bool]$date = $tempValue -like "D *"
        if ($date) { $tempValue = $tempValue.Substring(2) }

        [TimeSpan]$timeResult = New-Object System.TimeSpan

        foreach ($element in $tempValue.Split(' '))
        {
            if ($element -match "^\d+$") {
                $timeResult = $timeResult.Add((New-Object System.TimeSpan(0, 0, $element)))
            }
            elseif ($element -match "^\d+ms$") {
                $timeResult = $timeResult.Add((New-Object System.TimeSpan(0, 0, 0, 0, ([int]([Regex]::Match($element, "(\d+)", "IgnoreCase").Groups[1].Value)))))
            }
            elseif ($element -match "^\d+s$") {
                $timeResult = $timeResult.Add((New-Object System.TimeSpan(0, 0, ([int]([Regex]::Match($element, "(\d+)", "IgnoreCase").Groups[1].Value)))))
            }
            elseif ($element -match "^\d+m$") {
                $timeResult = $timeResult.Add((New-Object System.TimeSpan(0, ([int]([Regex]::Match($element, "(\d+)", "IgnoreCase").Groups[1].Value)), 0)))
            }
            elseif ($element -match "^\d+h$") {
                $timeResult = $timeResult.Add((New-Object System.TimeSpan(([int]([Regex]::Match($element, "(\d+)", "IgnoreCase").Groups[1].Value)), 0, 0)))
            }
            elseif ($element -match "^\d+d$") {
                $timeResult = $timeResult.Add((New-Object System.TimeSpan(([int]([Regex]::Match($element, "(\d+)", "IgnoreCase").Groups[1].Value)), 0, 0, 0)))
            }
            else { throw "Failed to parse as timespan: $Value at $element" }
        }

        [DateTime]$result = [DateTime]::MinValue
        if (-not $positive) { $result = [DateTime]::Now.Add($timeResult.Negate()) }
        else { $result = [DateTime]::Now.Add($timeResult) }

        if ($date) { return $result.Date }
        return $result
    }

    hidden [DateTime] ProcessObject([object] $Value) {
        [PSObject] $object = New-Object PSObject($Value)
        foreach ($name in $object.PSObject.TypeNames) {
            if ([DateTimeParam]::PropertyMapping.ContainsKey($name)) {
                foreach ($property in [DateTimeParam]::PropertyMapping[$name]) {
                    try { return (New-Object DateTimeParam($Value.$property)).Value }
                    catch {}
                }
            }
        }

        throw 'Failed to parse {0} of type <{1}>' -f $Value,$Value.GetType().Name
    }

    [string] ToString() {
        return $this.Value.ToString()
    }
}

function Get-Test {
	[CmdletBinding()]
	param (
		[DateTimeParam]
		$Timestamp
	)

	$Timestamp
}
Get-Test '-1h'
Get-Test (Get-Date)
Get-Test '-1h 30m 45s'


#----------------------------------------------------------------------------#
#                     Argument Transformation Attributes                     #
#----------------------------------------------------------------------------#


# Example: Integer conversion
class NumberTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute
{
    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData)
    {
        if ($inputData -is [int]) {
            return $inputData
        }
        if ($inputData -is [double] -or $inputData -is [decimal]) {
            return [math]::Truncate($inputData)
        }
        
        throw [System.InvalidOperationException]::new("Invalid data: $inputData")
    }
}

function Get-Test2 {
	[CmdletBinding()]
	param (
		[NumberTransform()]
		[int]
		$Number
	)

	$Number
}
Get-Test2 123
Get-Test2 123.456
Get-Test2 '1234' # Default conversion did not happen!
#-> If you MUST use the ArgumentTransformationAttributes,
#   respect native PowerShell type conversion:

class NumberTransform2Attribute : System.Management.Automation.ArgumentTransformationAttribute
{
    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData)
    {
        if ($inputData -is [int]) {
            return $inputData
        }
        if ($inputData -is [double] -or $inputData -is [decimal]) {
            return [math]::Truncate($inputData)
        }

		try { return [System.Management.Automation.LanguagePrimitives]::ConvertTo($inputData, [int]) }
		catch { throw [System.InvalidOperationException]::new("Invalid data: $inputData") }
    }
}
function Get-Test2 {
	[CmdletBinding()]
	param (
		[NumberTransform2()]
		[int]
		$Number
	)

	$Number
}
Get-Test2 '1234'
Trace-ParameterBinding -ScriptBlock { Get-Test2 '1234' }

function Get-Test2 {
	[CmdletBinding()]
	param (
		[int]
		$Number
	)

	$Number
}
Trace-ParameterBinding -ScriptBlock { Get-Test2 '1234' }


#----------------------------------------------------------------------------#
#                      The PowerShell Classes Conondrum                      #
#----------------------------------------------------------------------------#

class Fred {
	[string]$State
	[string]$CurrentAction
}

function Get-Test3 {
	[CmdletBinding()]
	param (
		[Fred]
		$Fred
	)

	"Fred is currently $($Fred.State) doing $($Fred.CurrentAction)"
}
$fred = [Fred]@{State = "Happy"; CurrentAction = "Bragging about his toys"}
Get-Test3 -Fred $fred

class Fred {
	[string]$State
	[string]$CurrentAction
}
function Get-Test3 {
	[CmdletBinding()]
	param (
		[Fred]
		$Fred
	)

	"Fred is currently $($Fred.State) doing $($Fred.CurrentAction)"
}
Get-Test3 -Fred $fred

# PSFramework to the rescue
function Get-Test3 {
	[CmdletBinding()]
	param (
		[PSFramework.Utility.DynamicTransformation([Fred], 'State', 'CurrentAction')]
		[Fred]
		$Fred
	)

	"Fred is currently $($Fred.State) doing $($Fred.CurrentAction)"
}
Get-Test3 -Fred $fred