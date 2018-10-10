Configuration iissettingup
{   
	param ($MachineName="localhost")
	Node $MachineName
	{ 
		WindowsFeature InstallWebServer 
		{ 
			Ensure = "Present"
			Name = "Web-Server" 
		} 
	} 
}
