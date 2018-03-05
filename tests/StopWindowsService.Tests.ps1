# Find and import source script.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$systemUnderTest = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$srcDir = "$here\.."
. "$srcDir\$systemUnderTest" -dotSourceOnly

# Import vsts sdk.
$vstsSdkPath = Join-Path $PSScriptRoot ..\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1 -Resolve
Import-Module -Name $vstsSdkPath -Prefix Vsts -ArgumentList @{ NonInteractive = $true } -Force

Describe "Main" {
    # General mocks needed to control flow and avoid throwing errors.
    Mock Trace-VstsEnteringInvocation -MockWith {}
    Mock Trace-VstsLeavingInvocation -MockWith {}

    Context "Killing service" {

        It "When trying to stop service, it should be stopped." {
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_to" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "skip" }
            Mock Test-ServiceExists -MockWith { return $true } 
            Mock Stop-WindowsService -MockWith { return $true } 

            # Act
            Main

            # Assert
            Assert-MockCalled Stop-WindowsService -ParameterFilter { ($serviceName -eq "some_name") -and ($timeout -eq "some_to") }
        }

        It "Failing to stop service, and kill flag is true, it should be killed." {
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $true }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_to" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "skip" }
            Mock Test-ServiceExists -MockWith { return $true }
            Mock Stop-WindowsService -MockWith { return $false }
            Mock Kill-WindowsService -MockWith {}

            # Act
            Main

            # Assert
            Assert-MockCalled Kill-WindowsService -ParameterFilter { $serviceName -eq "some_name" }

        }

        It "Failing to stop service and kill flag is false, should throw exception" {
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_to" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "skip" }
            Mock Test-ServiceExists -MockWith { return $true } 
            Mock Stop-WindowsService -MockWith { return $false } 

            # Act
            # Assert
            { Main } | Should -Throw "The service some_name could not be stopped and kill service option was disabled."
        }

        It "When the service does not exists on the target machine and the skip flag is enabled, it should succeed showing a message" {
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_to" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return $true }
            Mock Test-ServiceExists -MockWith { return $false } 
            Mock Write-Host -MockWith { }
            # Act
            Main
            # Assert
            Assert-MockCalled Write-Host -ParameterFilter { $Object -eq "The service some_name does not exist. Skipping this task."} -Scope It

        }

        It "When the service does not exist on the target machine and the skip flag is disabled, it should fail and throw an exception"{
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_to" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return $false }
            Mock Test-ServiceExists -MockWith { return $false } 

            # Act
            # Assert
            { Main } | Should -Throw "The service some_name does not exist. Please check the service name on the task configuration."
            
        }
    }
}

Describe "Stop-WindowsService" {
    $serviceName = "MyService"
    $timeout = "30"
    Context "When service stopped within timeout" {        
        Mock Get-Service { 
            New-Module -AsCustomObject -ScriptBlock {
                Function WaitForStatus {
                    return @{'ReturnValue'= 0}
                }
                Export-ModuleMember -Variable * -Function *
            }
        }

        Mock Stop-Service {}
                
        It "Should return true" {            
            Stop-WindowsService $serviceName $timeout | Should -Be $True 
        }
    }
}