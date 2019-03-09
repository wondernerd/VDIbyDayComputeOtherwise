
###
# VDI by day Compute by Night
# version 0.1
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
###

#Import vGPU capacity function
. 'C:\Users\Administrator\Desktop\vGPU System Capacity v1_3.ps1'


#define the paramaters

# VDI Side
$SpareVMcapacity = 1			#How many spare VMs should be able to be powered on

# Compute Side
$ComputeVMbaseName = "Compute"  #The base name of compute VMs, a three digit number will be added at the end
$ComputeCountFormat = "000"		#The preceding zeros in the compute name, so the 6th VM would be Compute006
$MaxComputeVMs = 4				#Total Number of Compute VMs in use
$ComputevGPUtype = "grid_p4-2q"	#Which vGPU is in the Compute VM (later I will detect this)

# Opperations Side Varables
$WorkingCluster = "Horizon"		#Name of the cluster that should be 
$SecondsBetweenScans = 30		#How long will the program wait between scans
$NumberOfScansToPreform = 10		#How many times should the scan be run 



###############################
###############################
# Operational variables do not touch

$vGPUslotsOpen = 0 				#How many vGPU VMs are currently on
$POComputeVMcount = 0			#Number of powered on (PO) compute VMs
$ScanCount = 0					#How Many times the scan has been run
$CurrVMName = ""				#Current VM Name
$ComputeSteadyState = 0
#works on a Last In First Out (LIFO) process 



#see what we already have running in the environment so we can start at the right spot.
#assumes that VMs are on or off in order IE 1,2,3 are all powered on NOT 1,3,4 on
$QuickCount = 0
while($QuickCount -lt $MaxComputeVMs)
{
	$CurrVMName = $ComputeVMbaseName + $QuickCount.ToString($ComputeCountFormat)
	write-Host "Checking VM: " $CurrVMName
	$ComputeName = Get-VM $CurrVMName
	if($ComputeName.powerState -eq "PoweredOn"){ 
		$POComputeVMcount++
		write-Host "VM already running: " $CurrVMName
	}
	$QuickCount++
}


While($ScanCount -le $NumberOfScansToPreform)
{
	while($ComputeSteadyState -eq 0) #Equlibrium while, it will keep going till the system is in the steady state desired
	{
		
		$vGPUslotsOpen = vGPUSystemCapacity $ComputevGPUtype $WorkingCluster "connected" #Make sure there is room to prepare the compute VMs
		Write-Host "vGPU Slots open: " $vGPUslotsOpen
		if($vGPUslotsOpen -lt $SpareVMcapacity -and $POComputeVMcount -ge 0) #suspend to keep capacity till we can't power off any more
		{
			# suspend if the capacity is not sufficent 
			$POComputeVMcount-- #decrease powered on VMs by 1	
			$CurrVMName = $ComputeVMbaseName + $POComputeVMcount.ToString($ComputeCountFormat)
			#$vGPUslotsOpen = vGPUSystemCapacity $ComputevGPUtype $WorkingCluster "connected" #Make sure there is room to prepare the compute VMs
			$ComputeName = Get-VM $CurrVMName
			if($ComputeName.powerState -eq "PoweredOn"){
				Suspend-VMGuest $ComputeName
				Start-Sleep -s 5
				write-Host "Suspend VM: " $ComputeName
			}
			else {write-Host "VM already suspended: " $ComputeName}					
		}
		elseif($vGPUslotsOpen -gt $SpareVMcapacity -and $POComputeVMcount -lt $MaxComputeVMs) #Resume/power on till we reach the maximum number of VMs
		{
			# start or resume next Compute VM
			$CurrVMName = $ComputeVMbaseName + $POComputeVMcount.ToString($ComputeCountFormat)
			$ComputeName = Get-VM $CurrVMName
			if ($ComputeName.powerState -eq "PoweredOff" -or $ComputeName.powerState -eq "Suspended"){
				Start-VM $ComputeName
				write-Host "Resume VM: " $ComputeName
			}
			else {write-Host "VM already started: " $ComputeName}
			$POComputeVMcount++ #decrease powered on VMs by 1 placed here so it moves passed VMs already powered on
			#$vGPUslotsOpen = vGPUSystemCapacity $ComputevGPUtype $WorkingCluster "connected" #Make sure there is room to prepare the compute VMs
		}
		else
		{
			#Cant do anything break the loop
			$ComputeSteadyState = 1
			write-host "Reached Steady State"
		}
	}
	$ComputeSteadyState = 0
	write-Host "Starting Sleep"
	Start-Sleep -s $SecondsBetweenScans #sleep for amount of time then resume
	Write-Host "out of sleep "
	Write-Host "Scan Count: " $ScanCount
	$ScanCount++
}
