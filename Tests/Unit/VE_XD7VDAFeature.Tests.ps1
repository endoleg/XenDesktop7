[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param ()

$here = Split-Path -Parent $MyInvocation.MyCommand.Path;
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.ps1', '')
$moduleRoot = Split-Path -Path (Split-Path -Path $here -Parent) -Parent;
Import-Module (Join-Path $moduleRoot -ChildPath "\DSCResources\$sut\$sut.psm1") -Force;

InModuleScope $sut {

    Describe 'XenDesktop7\VE_XD7VDAFeature' {

        Context 'ResolveXDVdaSetupArguments' {
            Mock -CommandName Get-CimInstance -MockWith { }

            foreach ($role in @('SessionVDA','DesktopVDA')) {

                foreach ($trueArgument in '/quiet','/logpath','/noreboot','/components VDA','/enable_remote_assistance')
                {
                    It "$role returns default '$trueArgument' argument" {

                        $arguments = ResolveXDVdaSetupArguments -Role $role;
                        $arguments -match $trueArgument | Should Be $true;
                    }
                }

                foreach ($falseArgument in '/optimize','/enable_real_time_transport','/remove','/removeall')
                {
                    It "$role returns default '$falseArgument' argument" {

                        $arguments = ResolveXDVdaSetupArguments -Role $role;
                        $arguments -match $falseArgument | Should Be $false;
                    }
                }

                foreach ($trueArgument in '/quiet','/logpath','/noreboot','/components VDA','/remove')
                {
                    It "$role returns default uninstall '$trueArgument' argument" {

                        $arguments = ResolveXDVdaSetupArguments -Role $role -Uninstall;
                        $arguments -match $trueArgument | Should Be $true;
                    }
                }

                foreach ($falseArgument in '/optimize','/enable_hdx_ports','/enable_real_time_transport','/enable_remote_assistance','/servervdi')
                {
                    It "$role returns default uninstall '$falseArgument' argument" {

                        $arguments = ResolveXDVdaSetupArguments -Role $role -Uninstall;
                        $arguments -match $falseArgument | Should Be $false;
                    }
                }

                It "$role returns /enable_real_time_transport argument when 'EnableRealTimeTransport' specified" {
                    $arguments = ResolveXDVdaSetupArguments -Role $role -EnableRealTimeTransport $true;

                    $arguments -match '/enable_real_time_transport' | Should Be $true;
                }

                It "$role returns /optimize argument when 'Optimize' specified" {
                    $arguments = ResolveXDVdaSetupArguments -Role $role -Optimize $true;

                    $arguments -match '/optimize' | Should Be $true;
                }

                It "$role returns /nodesktopexperience argument when specified" {
                    $arguments = ResolveXDVdaSetupArguments -Role $role -InstallDesktopExperience $false;

                    $arguments -match '/nodesktopexperience' | Should Be $true;
                }

                It "$role returns /components VDA,PLUGINS argument when 'InstallReceiver' specified" {
                    $arguments = ResolveXDVdaSetupArguments -Role $role -InstallReceiver $true;

                    $arguments -match '/components VDA,PLUGINS' | Should Be $true;
                }

            } #end foreach $role

            It 'DesktopVDA returns /servervdi argument on server operating system.' {
                Mock -CommandName Get-CimInstance -MockWith { return @{ Caption = 'Windows Server 2012'; }; }

                $arguments = ResolveXDVdaSetupArguments  -Role DesktopVDA;

                $arguments -match '/servervdi' | Should Be $true;
            }

        } #end context ResolveXDVdaSetupArguments

        Context 'Get-TargetResourece' {
            $testDrivePath = (Get-PSDrive -Name TestDrive).Root;

            It 'Returns a System.Collections.Hashtable.' {
                Mock -CommandName TestXDInstalledRole -MockWith { }

                $targetResource = Get-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath -Ensure 'Present';

                $targetResource -is [System.Collections.Hashtable] | Should Be $true;
            }

            foreach ($role in @('SessionVDA','DesktopVDA')) {

                It "Returns 'Ensure' = 'Present' when '$role' role is installed" {
                    Mock -CommandName TestXDInstalledRole -MockWith { return $true; }

                    $targetResource = Get-TargetResource -Role $role -SourcePath $testDrivePath;

                    $targetResource['Ensure'] | Should Be 'Present';
                }

                It "Returns 'Ensure' = 'Absent' when '$role' role is not installed" {
                    Mock -CommandName TestXDInstalledRole -MockWith { return $false; }

                    $targetResource = Get-TargetResource -Role $role -SourcePath $testDrivePath;

                    $targetResource['Ensure'] | Should Be 'Absent';
                }

            }

        } #end context Get-TargetResource

        Context 'Test-TargetResource' {
            $testDrivePath = (Get-PSDrive -Name TestDrive).Root;

            ## Ensure secure boot is not triggered
            Mock Confirm-SecureBootUEFI -MockWith { return $false; }
            Mock -CommandName ResolveXDSetupMedia { return 'TestDrive' }
            Mock -CommandName Get-Item { return [PSCustomObject] @{ VersionInfo = @{ FileVersion = '7.11' } } }

            It 'Returns a System.Boolean type.' {
                Mock -CommandName GetXDInstalledRole -ParameterFilter { $Role -eq 'DesktopVDA' } -MockWith { }

                $targetResource = Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath -Ensure 'Present';

                $targetResource -is [System.Boolean] | Should Be $true;
            }

            It 'Returns True when "Ensure" = "Present" and role is installed' {
                Mock -CommandName TestXDInstalledRole -MockWith { return $true; }

                $targetResource = Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath -Ensure 'Present';

                $targetResource | Should Be $true;
            }

            It 'Returns False when "Ensure" = "Present" and role is not installed' {
                Mock -CommandName TestXDInstalledRole -MockWith { return $false; }

                $targetResource = Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath -Ensure 'Present';

                $targetResource | Should Be $false;
            }

            It 'Returns False when "Ensure" = "Absent" and role is not installed' {
                Mock -CommandName TestXDInstalledRole -MockWith { return $false; }

                $targetResource = Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath -Ensure 'Absent';

                $targetResource | Should Be $true;
            }

            It 'Returns True when "Ensure" = "Absent" and role is installed' {
                Mock -CommandName TestXDInstalledRole -MockWith { return $true; }

                $targetResource = Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath -Ensure 'Absent';

                $targetResource | Should Be $false;
            }

            It 'Does not throw when VDA version is "7.12" (or later) and "SecureBoot" is enabled' {
                Mock -CommandName Confirm-SecureBootUEFI -MockWith { return $true; }
                Mock -CommandName TestXDInstalledRole -MockWith { return $false; }
                Mock -CommandName ResolveXDSetupMedia { return 'TestDrive' }
                Mock -CommandName Get-Item { return [PSCustomObject] @{ VersionInfo = @{ FileVersion = '7.12' } } }

                { Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath } | Should Not Throw
            }


            It 'Throws when VDA version is "7.11" (or earlier) and "SecureBoot" is enabled' {
                Mock -CommandName Confirm-SecureBootUEFI -MockWith { return $true; }
                Mock -CommandName TestXDInstalledRole -MockWith { return $false; }
                Mock -CommandName ResolveXDSetupMedia { return 'TestDrive' }
                Mock -CommandName Get-Item { return [PSCustomObject] @{ VersionInfo = @{ FileVersion = '7.11' } } }

                { Test-TargetResource -Role 'DesktopVDA' -SourcePath $testDrivePath } | Should Throw 'Secure Boot is not supported. Disable Secure Boot.'
            }

        } #end context Test-TargetResource

        Context 'Set-TargetResource' {
            $testDrivePath = (Get-PSDrive -Name TestDrive).Root

            It 'Throws with an invalid directory path.' {
                Mock -CommandName Test-Path -MockWith { return $false; }

                { Set-TargetResource -Role 'DesktopVDA' -SourcePath 'Z:\HopefullyThisPathNeverExists' } | Should Throw;
            }

            It 'Throws with a valid file path.' {
                [ref] $null = New-Item -Path 'TestDrive:\XenDesktopServerSetup.exe' -ItemType File;

                { Set-TargetResource -Role 'DesktopVDA' -SourcePath "$testDrivePath\XenDesktopServerSetup.exe" } | Should Throw;
            }

            foreach ($state in @('Present','Absent')) {
                foreach ($role in @('DesktopVDA','SessionVDA')) {
                    foreach ($exitCode in @(0, 3010)) {
                        It "Flags reboot when 'Ensure' = '$state', 'Role' = '$role' and exit code = '$exitCode'" {
                            [System.Int32] $global:DSCMachineStatus = 0;
                            Mock -CommandName StartWaitProcess -MockWith { return $exitCode; }
                            Mock -CommandName ResolveXDSetupMedia -MockWith { return $testDrivePath; }
                            Mock -CommandName ResolveXDVdaSetupArguments -MockWith { }
                            Mock -CommandName Test-Path -MockWith { return $true; }

                            Set-TargetResource -Role $role -SourcePath $testDrivePath -Ensure $state;

                            [System.Int32] $global:DSCMachineStatus | Should Be 1
                            Assert-MockCalled -CommandName StartWaitProcess -Exactly 1 -Scope It;
                        }
                    }
                }
            }

        } #end context Set-TargetResource

    } #end describe XD7VDAFeature
} #end inmodulescope
