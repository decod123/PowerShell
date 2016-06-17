<# 
.SYNOPSIS 
   This file demonstrates the use of Windows PowerShell cmdlets to create and configure containers
   on Windows Server 2016. 
.   
.DESCRIPTION | USAGE
   This file is a series of cmdlets that are meant to be run one after the other. 
   
   IMPORTANT: This file is not intended to be run as a script.

   To step through the cmdlets, select the first line, right-click the selected line,
   and then click Run Selection. 
   
   If a cmdlet requires input, you will be prompted for it. 
   
#> 


#Create and enter a remote session with Windows Server 2016 "Nano" server.
$s=New-PSsession -computername "192.168.1.100" -Credential Administrator
Enter-PSSession -Session $s

#####################################################
#EXERCISE 1: BASIC CONTAINER MANAGEMENT WITH POWERSHELL

#Show the PowerShell cmdlets related to containers.
Get-Command -Module containers

#Show the network configuration of Server. 
ipconfig

#Show default container image. You will need to know the name to create a new container.
Get-ContainerImage

#Use the Get-VMSwitch to show available VM Switches you can use to create the new container.
Get-VMSwitch

# Create the new container and save the output in a variable for use later. 
$container = New-Container -Name "MyContainer" -ContainerImageName WindowsServerCore -SwitchName "Virtual Switch"

#Start the new container
Start-Container -Name "MyContainer"

#Enter a remote PowerShell session with the new container.
Enter-PSSession -ContainerId $container.ContainerId -RunAsAdministrator

#Run a command within the container and store the output in file in the container.
ipconfig > c:\ipconfig.txt 
type c:\ipconfig.txt

#Exit the remote PowerShell session and stop container
Exit-PSSession
Stop-Container -Name "MyContainer"

#Create a new container image that uses the modified container as the basis for the image
$newimage = New-ContainerImage -ContainerName MyContainer -Publisher Demo -Name newimage -Version 1.0

#Display properties of newimage
Get-ContainerImage newimage | fl

#Create a new container using the container image as the template
$newcontainer = New-Container -Name "newcontainer" -ContainerImageName newimage -SwitchName "Virtual Switch"
Start-Container $newcontainer

#Display properties of containers
Get-Container

#Enter a remote session with this new container and verify presence of file created earlier
Enter-PSSession -ContainerId $newcontainer.ContainerId -RunAsAdministrator
type c:\ipconfig.txt

#Exit the remote PowerShell session
Exit-PSSession

#Stop all running containers and then remove containers
Get-Container | Stop-Container
Get-Container | Remove-Container -Force

#Remove the container image you created earlier
Get-ContainerImage -Name newimage | Remove-ContainerImage -Force

#####################################################
#EXERCISE 2: HOST A WEB SERVER IN A CONTAINER

#Create and start a new container using the default Container image.
$container = New-Container -Name webbase -ContainerImageName WindowsServerCore -SwitchName "Virtual Switch"
Start-Container $container

# Enter a remote session with new container and download nginx web server binaries
Enter-PSSession -ContainerId $container.ContainerId -RunAsAdministrator
wget -uri 'http://nginx.org/download/nginx-1.9.3.zip' -OutFile "c:\nginx-1.9.3.zip"
Expand-Archive -Path C:\nginx-1.9.3.zip -DestinationPath c:\ -Force
Exit-PSSession
Stop-Container $container

#Create new container image based on the Container with the nginx web server binaries
$webserverimage = New-ContainerImage -Container $container -Publisher Demo -Name nginxwindows -Version 1.0

#Create new container from container image and start nginx web server.
$webservercontainer = New-Container -Name webserver1 -ContainerImageName nginxwindows -SwitchName "Virtual Switch"
Start-Container $webservercontainer
Enter-PSSession -ContainerId $webservercontainer.ContainerId -RunAsAdministrator
cd c:\nginx-1.9.3\
start nginx
Exit-PSSession

#Add a static port mapping from Container host to container. 
Add-NetNatStaticMapping -NatName "ContainerNat" -Protocol TCP -ExternalIPAddress 0.0.0.0 -InternalIPAddress 172.16.0.2 -InternalPort 80 -ExternalPort 80

# Create an inbound Firewall rule for configured port.
if (!(Get-NetFirewallRule | where {$_.Name -eq "TCP80"})) {New-NetFirewallRule -Name "TCP80" -DisplayName "HTTP on TCP/80" -Protocol tcp -LocalPort 80 -Action Allow -Enabled True}

#Update the web server content
Enter-PSSession -ContainerId $webservercontainer.ContainerId -RunAsAdministrator
wget -uri 'https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/master/doc-site/virtualization/windowscontainers/quick_start/SampleFiles/index.html' -OutFile "C:\nginx-1.9.3\html\index.html"