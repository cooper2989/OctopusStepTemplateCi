<#
Copyright 2016 ASOS.com Limited

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

<#
.NAME
    Sync-ScriptModule.Tests
    
.SYNOPSIS
    Pester tests for Sync-ScriptModule  
#>
Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"
. "$here\New-ScriptModule.ps1"
. "$here\..\Internal\Octopus\Invoke-OctopusOperation.ps1"
. "$here\..\Internal\Octopus\ScriptModules\Read-ScriptModule.ps1"
. "$here\..\Internal\Octopus\ScriptModules\Read-ScriptModuleVariableSet.ps1"
. "$here\..\Internal\TeamCity\Write-TeamCityMessage.ps1"
. "$here\..\Internal\PowerShellManipulation\Get-VariableFromScriptText.ps1"
. "$here\..\Internal\PowerShellManipulation\Get-VariableStatementFromScriptText.ps1"
. "$here\..\Internal\PowerShellManipulation\Get-ScriptBodyFromScriptText.ps1"

Describe "Sync-ScriptModule" {

    Mock -CommandName "Get-Content" `
         -MockWith {
             return @'
function test {
    $ScriptModuleName = "name"
    $ScriptModuleDescription = "description"
    write-host "test message"
}
'@;
         };

    Mock -CommandName "Invoke-OctopusOperation" `
         -MockWith {
             throw ("should not be called with parameters @{ Action = '$Action', ObjectType = '$ObjectType'}!");
         };

    Mock Write-TeamCityMessage {} 

    Context "when variable set does not exist" {
    
        It "Should upload the VariableSet for the script module if it does not exist" {

            Mock -CommandName "Invoke-OctopusOperation" `
		 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "LibraryVariableSets") -and ($ObjectId -eq "All") } `
                 -MockWith { return @{ Name = "another name" } } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "New") -and ($ObjectType -eq "LibraryVariableSets") } `
                 -MockWith { return @{ "Links" = @{ "Variables" = "script module" } }; } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith { return @{ "Variables" = @() }; } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Update") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith {} `
                 -Verifiable;

            $result = Sync-ScriptModule -Path "my.scriptmodule.ps1";
            $result.UploadCount | Should Be 2;

            Assert-VerifiableMocks;

        }

    }
    
    Context "when script module does not exist" {

        It "Should upload the script module if it does not exist" {

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "LibraryVariableSets") -and ($ObjectId -eq "All") } `
                 -MockWith {
                     return @{
                         "Name" = "name"
                         "Description" = "description"
                         "Links" = @{ "Variables" = "script module" }
                     };
                  } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith { @{ Variables = @() } } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Update") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith {}  `
                 -Verifiable;

            $result = Sync-ScriptModule -Path "my.scriptmodule.ps1";
            $result.UploadCount | Should Be 1;

            Assert-VerifiableMocks;

        }

    }
    
    Context "when variable set has changed" {

        It "Should upload an updated VariableSet for the script module if it has changed" {

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "LibraryVariableSets") -and ($ObjectId -eq "All") } `
                 -MockWith {
                    return @{
                        "Name" = "name"
                        "Description" = "new description"
                        "Links" = @{ "Variables" = "script module"; "Self" = "variableset" }
                    };
                 } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Update") -and ($ObjectType -eq "UserDefined") -and ($ApiUri -eq "variableset") } `
                 -MockWith {} `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith {
                    return @{
                        "Variables" = @(
                            @{
                                "Value" = @'
function test {
    
    
    write-host "test message"
}
'@
                            }
                        )
                    };
                 } `
                 -Verifiable;

            $result = Sync-ScriptModule -Path "my.scriptmodule.ps1";
            $result.UploadCount | Should Be 1;

            Assert-VerifiableMocks;

        }

    }
    
    Context "when script module has changed" {

        It "Should upload an updated script module if it has changed" {

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "LibraryVariableSets") -and ($ObjectId -eq "All") } `
                 -MockWith {
                     return @{
                        "Name" = "name"
                        "Description" = "description"
                        "Links" = @{ "Variables" = "script module" }
                     };
                  } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and( $ObjectType -eq "UserDefined") }  `
                 -MockWith { return @{ "Variables" = @( @{ "Value" = "a different script" } ) }; } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Update") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith {} `
                 -Verifiable;

            $result = Sync-ScriptModule -Path "my.scriptmodule.ps1";
            $result.UploadCount | Should Be 1;

            Assert-VerifiableMocks;

        }

    }

    Context "when nothing has changed" {

        It "Should not upload if nothing has changed" {

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "LibraryVariableSets") -and ($ObjectId -eq "All") } `
                 -MockWith {
                    return @{
                        "Name" = "name"
                        "Description" = "description"
                        "Links" = @{ "Variables" = "script module"; "Self" = "variableset" }
                    };
                 } `
                 -Verifiable;

            Mock -CommandName "Invoke-OctopusOperation" `
                 -ParameterFilter { ($Action -eq "Get") -and ($ObjectType -eq "UserDefined") } `
                 -MockWith {
                    return @{
                        "Variables" = @(
                            @{
                                "Value" = @'
function test {
    
    
    write-host "test message"
}
'@
                            }
                        )
                    };
                 } `
                 -Verifiable;

            $result = Sync-ScriptModule -Path "my.scriptmodule.ps1";
            $result.UploadCount | Should Be 0;

            Assert-VerifiableMocks;

        }

    }
}