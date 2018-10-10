Configuration iissettingup
{   
	param ($MachineName)
	Node $MachineName
	{ 
		WindowsFeature InstallWebServer 
		{ 
			Ensure = "Present"
			Name = "Web-Server" 
		} 
	} 
}
