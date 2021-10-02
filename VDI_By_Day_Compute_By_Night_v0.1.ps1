
###
# VDI by day Compute by Night
# version 0.2
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
###

#Assumes you have already connected to the vCenter. If adjust the following line and uncomment.
#Connect-VIServer -server vsa01.YourDomain.local -user administrator@vSphere.local -password Passw0rd!

#UPDATE WITH CORRECT PATH
#Import vGPU capacity function
. 'C:\Users\UserName\Desktop\vGPUcapacity.ps1'


#define the paramaters

# VDI Side
$SpareVMcapacity = 1			#How many spare VMs should be able to be powered on

# Compute Side
$ComputeVMbaseName = "Compute"  #The base name of compute VMs, a three digit number will be added at the end
$ComputeCountFormat = "000"		#The preceding zeros in the compute name, so the 6th VM would be Compute006
$StartingVMnum = 1				#The starting VM number, for example 001 would be the first VM monitored 
$MaxComputeVMs = 4				#Total Number of Compute VMs in use
$ComputevGPUtype = "grid_p4-2q"	#Which vGPU is in the Compute VM (later I will detect this)

# Opperations Side Varables
$WorkingCluster = "Horizon"		#Name of the cluster that should be 
$SecondsBetweenScans = 10		#How long will the program wait between scans
$NumberOfScansToPreform = 10		#How many times should the scan be run 



###############################
###############################
# Operational variables do not touch

$vGPUslotsOpen = 0 							#How many vGPU VMs are currently on
$POComputeVMcount = 0 + $StartingVMnum		#Number of powered on (PO) compute VMs
$ScanCount = 0								#How Many times the scan has been run
$CurrVMName = ""							#Current VM Name
$ComputeSteadyState = 0
#works on a Last In First Out (LIFO) process 




While($ScanCount -le $NumberOfScansToPreform)
{
	#see what we already have running in the environment so we can start at the right spot.
	#assumes that VMs are on or off in order IE 1,2,3 are all powered on NOT 1,3,4 on
	$QuickCount = 0 + $StartingVMnum 
	$POComputeVMcount = 0 + $StartingVMnum 
	while($QuickCount -lt ($MaxComputeVMs + $StartingVMnum))
	{
		$CurrVMName = $ComputeVMbaseName + $QuickCount.ToString($ComputeCountFormat)
		write-Host "Checking VM: " $CurrVMName
		$ComputeName = Get-VM $CurrVMName
		#write-Host "VM power state: " $ComputeName.powerState
		if($ComputeName.powerState -eq "PoweredOn"){ 
			$POComputeVMcount++
			#write-Host "VM already running: " $CurrVMName			
		}
		write-Host "VM " $CurrVMName " power state: " $ComputeName.powerState
		$QuickCount++
	}


	while($ComputeSteadyState -eq 0) #Equlibrium while, it will keep going till the system is in the steady state desired
	{
		$vGPUslotsOpen = vGPUSystemCapacity $ComputevGPUtype $WorkingCluster "connected" #Make sure there is room to prepare the compute VMs
		Write-Host "vGPU Slots open: " $vGPUslotsOpen
		#Eventually add statement of hosts capacity
		
		write-Host "___________________________________________________________"
		write-Host "vGPU Slots Open: " $vGPUslotsOpen " Spare Capacity: "  $SpareVMcapacity
		write-Host "Compute Count: " $POComputeVMcount " Max VMs: " $MaxComputeVMs " Starting VMs: " $StartingVMnum
		write-Host "___________________________________________________________"
		
		if($vGPUslotsOpen -lt $SpareVMcapacity -and $POComputeVMcount -ge (0 + $StartingVMnum)) #suspend to keep capacity till we can't power off any more
		{
			write-Host "-----------------------------------------------------------"
			write-Host "Decreasing running workload VMs"
			write-Host "vGPU slots open: " $vGPUslotsOpen " Required Spare Capacity: " $SpareVMcapacity
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
			else {write-Host "VM " $ComputeName " state: " $ComputeName.powerState}	
			write-Host "-----------------------------------------------------------"			
		}
		elseif($vGPUslotsOpen -gt $SpareVMcapacity -and $POComputeVMcount -lt ($MaxComputeVMs + $StartingVMnum)) #Resume/power on till we reach the maximum number of VMs
		{
			write-Host "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
			write-Host "Increaseing running workload VMs"
			write-Host "vGPU slots open: " $vGPUslotsOpen " Required Spare Capacity: " $SpareVMcapacity
			# start or resume next Compute VM
			$CurrVMName = $ComputeVMbaseName + $POComputeVMcount.ToString($ComputeCountFormat)
			$ComputeName = Get-VM $CurrVMName
			if ($ComputeName.powerState -eq "PoweredOff" -or $ComputeName.powerState -eq "Suspended"){
				write-Host "Changing " $ComputeName " from " $ComputeName.powerState " to PoweredOn"
				Start-VM $ComputeName
				write-Host "Increased running workload VM with: " $ComputeName
			}
			else {write-Host "VM already started: " $ComputeName}
			$POComputeVMcount++ #increase powered on VMs by 1 placed here so it moves passed VMs already powered on
			#$vGPUslotsOpen = vGPUSystemCapacity $ComputevGPUtype $WorkingCluster "connected" #Make sure there is room to prepare the compute VMs
			write-Host "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		}
		else
		{
			#Cant do anything break the loop
			write-Host "==========================================================="
			$ComputeSteadyState = 1
			write-host "Reached Steady State"
			write-Host "==========================================================="
		}
	}
	$ComputeSteadyState = 0
	
	write-Host ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	write-Host "Starting Sleep for: " $SecondsBetweenScans " Seconds"
	Start-Sleep -s $SecondsBetweenScans #sleep for amount of time then resume
	Write-Host "Finished sleep"
	Write-Host "Scan Count: " $ScanCount
	$ScanCount++
}

# clean up and suspend compute VMs
write-Host "***********************************************************"
write-Host "Starting clean up..." $POComputeVMcount
while($POComputeVMcount -gt (0 + $StartingVMnum))
{
	$POComputeVMcount-- #decrease powered on VMs by 1
	# suspend if the capacity is not sufficent 
	write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	$CurrVMName = $ComputeVMbaseName + $POComputeVMcount.ToString($ComputeCountFormat)
	write-Host "Cleaning up: " $CurrVMName	
	$ComputeName = Get-VM $CurrVMName
	if($ComputeName.powerState -eq "PoweredOn"){
		write-Host "Starting suspend of " $ComputeName
		Suspend-VMGuest $ComputeName 
		Start-Sleep -s 5
		write-Host "Suspend VM: " $ComputeName
	}
	else {write-Host "VM already stopped: " $ComputeName}	
	write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
				
}
write-Host "***********************************************************"
Write-Host "Script finished, Good-bye"
