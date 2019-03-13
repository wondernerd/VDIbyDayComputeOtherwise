# VDIbyDayComputeOtherwise
Script that provides the logic to do VDI by day and Compute by night (Or whenever else resources are free)

You can read more about this script here: https://www.wondernerd.net/blog/scripting-vdi-by-day-and-compute-by-night/

I built and tested this function on VMware PowerCLI 11.0.0 build 10380590 and on PowerShell 5.1.14409.1005. It should be backwards compatible several generations back to the point that the vGPU device backing was added in PowerCLI. Though I’m not sure when that was. 

This is a fairly easy script to use.

It requires the latest push of my vGPU capacity function here: https://github.com/wondernerd/vGPUCapacity
 Set the path to that file on line 11
 
Define your paramaters on lines 16 thourgh 29. Hopefully they are self explainitory.
<pre>
  # VDI Side
  $SpareVMcapacity = 1			#How many spare VMs should be able to be powered on

  # Compute Side
  $ComputeVMbaseName = "Compute"  #The base name of compute VMs, a three digit number will be added at the end
  $ComputeCountFormat = "000"		#The preceding zeros in the compute name, so the 6th VM would be Compute005
  $MaxComputeVMs = 4				#Total Number of Compute VMs in use
  $ComputevGPUtype = "grid_p4-2q"	#Which vGPU is in the Compute VM (later I will detect this)

  # Opperations Side Varables
  $WorkingCluster = "Horizon"		#Name of the cluster that should be 
  $SecondsBetweenScans = 30		#How long will the program wait between scans
  $NumberOfScansToPreform = 10	#How many times should the scan be run 
</pre>

Once those modifications are done, time to prep the VMware environment
Now comes a VERY important part. Licensing!
Take a look at your VMware Horizon licensing agreement. It probably says something like you can only use Horizon for virtual desktop instances...
That means your compute VMs need to be desktops or you need to license your hosts as standard ESXi assets. I can't tell you which is best to do. You should work with the VMware Licensing team to determine the best course of action. It's up to you to make sure you fully comply with the terms of your license agreement. 

Instantiate your compute VMs, in my example I named them "Compute###" 
The script expects them to all follow a common naming state with numbers that will be put in a 000 format starting with VM 000
It is a base 0 on its counting not base 1.

Once you have instantiated them you can leave them off if you want and everything will start automatically or you can power them on and make all of your configurations needed to connnect to your compute enviroment. 
Once everything is configured suspend your compute VMs. You can even stand them up in batches like 5 at a time if need be.

At this point double check that the $ComputevGPUType matches the vGPU type you have defined for your compute VMs.

If everything looks good connect to your vSphere environment and run the script. 

What this will do is check every x seconds to see what the current vGPU load is, if it is beyond the spare capacity it will suspend compute VMs till the spare capacity is met at which point it will resume that VM.
The script uses a last in first out approach to handling VMs. This is because the machines that have been running the longest are probably closest to compleating their work stream. 
This program does not flush the VMs results to compute system though it could be added in the suspend loop if needed. 
