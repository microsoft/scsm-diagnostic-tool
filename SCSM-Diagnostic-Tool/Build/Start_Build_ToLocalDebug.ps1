﻿<# TODO: TESTS: 
all files should only have function DECLARATIONS
Write-Output  should never appear
Exit should never appear other than in SelfElevate and comments
#>

#region function declarations
function BuildScript($targetBuildFolderName) {

    #region params
    $sourceStartingScriptFolderName = 'SourceCode'
    $targetScriptFileName = 'SCSM-Diagnostic-Tool.ps1'
    $Output_BuildFolderName = "..\$targetBuildFolderName" # "Output_Build"
    $invalidBuildScriptFileName = "$Output_BuildFolderName\InvalidBuild_$targetScriptFileName"
    $transcriptFileName = "$Output_BuildFolderName\Build_Transcript.txt"
    $targetVersionFolderName = '..'
    $versionFileName = "version.txt"
    #endregion

    #region Starting Transcripting
    $transcriptFilePath = Join-Path -Path $PSScriptRoot -ChildPath $transcriptFileName
    Start-Transcript -Path $transcriptFilePath | Out-Null
    #endregion

    try {
        #region init 
        Set-Location $PSScriptRoot 
        $parentPath = Split-Path -Path (Get-Location) -Parent
        $sourceStartingFolderPath = Join-Path -Path $parentPath -ChildPath $sourceStartingScriptFolderName 
        $versionFilePath = Join-Path -Path $parentPath -ChildPath $versionFileName
        New-Item -ItemType Directory -Force -Path (Join-Path -Path $parentPath -ChildPath $targetBuildFolderName) | Out-Null
        $successFilePath = Join-Path -Path $parentPath -ChildPath $targetBuildFolderName | Join-Path -ChildPath $targetScriptFileName
        $invalidFilePath = Join-Path -Path $PSScriptRoot -ChildPath $invalidBuildScriptFileName

        $currentVersionStr = (Get-Content -Path $versionFilePath | Out-String).Trim()
        Write-Host "Build started for Version $currentVersionStr"
        Write-Host "Source folder: $sourceStartingFolderPath"
        Write-Host "--------------------------------"
        #endregion

        #region build 
        Set-Content -Path $invalidFilePath -Value ""
        $buildResultSB = [System.Text.StringBuilder]::new()
        $buildResultSB.AppendLine( "# This file is generated by a tool. Do not make changes. They will be overridden by the tool." ) | Out-Null
        $buildResultSB.AppendLine( (Get-Content -Path $invalidFilePath | Out-String) ) | Out-Null

            #region Adding Version function
            $versionFunctionStr = "function GetToolVersion() {'$currentVersionStr'}"
            $buildResultSB.AppendLine( $versionFunctionStr ) | Out-Null #endregion

            #region Get all PS1 files
            $allPS1Files = Get-ChildItem -Path $sourceStartingFolderPath -Filter *.ps1 -Recurse -Exclude main.ps1
            $allPS1Files += Get-ChildItem -Path $sourceStartingFolderPath -Filter main.ps1
            foreach ($PS1File in $allPS1Files){
                Write-Host $PS1File.FullName.Replace($sourceStartingFolderPath,''); 
                $buildResultSB.AppendLine( (Get-Content $PS1File.FullName | Out-String) ) | Out-Null  
            }
            #endregion

        $buildResultStr = $buildResultSB.ToString()        
        Set-Content -Path $invalidFilePath -Value $buildResultStr
        #endregion

        #region Post-Build stuff, testing etc. Pass $invalidFilePath or $buildResultStr
        $buildResultStrIsGood = $true
        Write-Host " "
        Write-Host "Post-Build"
        Write-Host "--------------------------------"

        Set-Location $PSScriptRoot 
    
        #Parse and Validate
        $buildResultStrIsGood =  $buildResultStrIsGood -and (ParseAndValidateScript $invalidFilePath)

        if ($buildResultStrIsGood) {

            $buildResultStr = TrimEmptyLinesOutsideOfFunctions $invalidFilePath
            Set-Content -Path $invalidFilePath -Value $buildResultStr        

            #add more testings below as: 
            #$buildResultStrIsGood = $buildResultStrIsGood -and (SomeOtherTestHere $buildResultStr)      
        }
        #endregion

        #region Final stuff
        Write-Host " "
        if ( $Error.Count -eq 0 -and $buildResultStrIsGood) {     
            if (Test-Path $successFilePath) {Remove-Item -Path $successFilePath}        
            Move-Item -Path $invalidFilePath -Destination $successFilePath -Force

            Write-Host "Build SUCCEEDED for Version $currentVersionStr. Result is $successFilePath" -ForegroundColor Yellow
        }
        else {    
            throw "Something wrong happened. Error(s): $Error"
        }
        #endregion
    } 
    catch {
        $_ | fl     # to re-throw
        Write-Error "Build FAILED for Version $currentVersionStr. Check files 'Build_Transcript.txt' and 'InvalidBuild_$targetScriptFileName' in folder: $Output_BuildFolderName"
    }
    finally {
        Stop-Transcript | out-null
    }

}

function ParseAndValidateScript([string]$pScriptFileFullPath) { 

    $result = $false 

    [System.Management.Automation.Language.Token[]]$tokens = $null
    [System.Management.Automation.Language.ParseError[]]$parseErrors = $null
    $p = [System.Management.Automation.Language.Parser]::ParseFile($pScriptFileFullPath,[ref]$tokens,[ref]$parseErrors) 
    if($parseErrors.Count -eq 0){
        Write-Host "Validating: PASS"
        return $true
    }
    else {
       throw "Script is not valid !!! Parse Errors:`n $parseErrors"
    }
}
function TrimEmptyLinesOutsideOfFunctions([string]$pScriptFileFullPath) {
$debug=$false

    Write-Host "TrimEmptyLinesOutsideOfFunctions: " -NoNewline
    [System.Diagnostics.Stopwatch]$sw = [System.Diagnostics.Stopwatch]::StartNew()

    [System.Management.Automation.Language.Token[]]$tokens = $null
    [System.Management.Automation.Language.ParseError[]]$parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($pScriptFileFullPath,[ref]$tokens,[ref]$parseErrors) 
    if ($debug) { write-host "After ParseFile $($sw.Elapsed.TotalSeconds)" }

    # Get only function definition ASTs
    $functionDefinitions = $ast.FindAll({
        param([System.Management.Automation.Language.Ast] $Ast)

        $Ast -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        # Class methods have a FunctionDefinitionAst under them as well, but we don't want them.
        ($PSVersionTable.PSVersion.Major -lt 5 -or
        $Ast.Parent -isnot [System.Management.Automation.Language.FunctionMemberAst])

    }, $true)
    if ($debug) { write-host "After FindAll $($sw.Elapsed.TotalSeconds)" }

    $lineNr=0
    $xNew=0

    [string]$newLines = ""
    $reader = [System.IO.File]::OpenText($pScriptFileFullPath)
    while($null -ne ($line = $reader.ReadLine())) {
        $lineNr++
        if ([string]::IsNullOrEmpty($line.Trim())) {            
      
            $lineExistsInsideFunctionDefinition = $false
            foreach($functionDefinition in $functionDefinitions) {
                if( $lineNr -ge $functionDefinition.Extent.StartLineNumber -and $lineNr -le $functionDefinition.Extent.EndLineNumber) {
                    $lineExistsInsideFunctionDefinition = $true
                    break;
                }
            }
            if (-not $lineExistsInsideFunctionDefinition) {continue}            
        }

        $newLines += "$line`n"
        $xNew++
    }
    if ($debug) { write-host "After Trim loop $($sw.Elapsed.TotalSeconds)" }
    $reader.Close()

    $result = $newLines
    $sw.Stop()
    if ($debug) { Write-Host " -> ended in $($sw.Elapsed.TotalSeconds) secs" }
    
    Write-Host "PASS"
    $result
}
Function Test-IsFileLocked {
#https://mcpmag.com/articles/2018/07/10/check-for-locked-file-using-powershell.aspx
    [cmdletbinding()]
    Param (
        [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName','PSPath')]
        [string[]]$Path
    )
    Process {
        ForEach ($Item in $Path) {
            #Ensure this is a full path
            $Item = Convert-Path $Item
            #Verify that this is a file and not a directory
            If ([System.IO.File]::Exists($Item)) {
                Try {
                    $FileStream = [System.IO.File]::Open($Item,'Open','Write')
                    $FileStream.Close()
                    $FileStream.Dispose()
                    $IsLocked = $False
                } Catch [System.UnauthorizedAccessException] {
                    $IsLocked = 'AccessDenied'
                } Catch {
                    $IsLocked = $True
                }                
                $IsLocked               
            }
        }
    }
}

#endregion

Set-PSDebug -Strict # from now on, all variables must be explicitly declared before they are used  
$Error.Clear();
Set-Location $PSScriptRoot 

BuildScript -targetBuildFolderName 'LocalDebug'

Read-Host " "