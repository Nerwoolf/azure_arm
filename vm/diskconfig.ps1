Configuration initDisk
{
    Import-DSCResource -ModuleName StorageDsc

    Node localhost
    {
        WaitForDisk Disk2
        {
             DiskId = 2
             RetryIntervalSec = 60
             RetryCount = 60
        }

        Disk GVolume
        {
             DiskId = 2
             DriveLetter = 'F'
             DependsOn = '[WaitForDisk]Disk2'
             FSLabel = 'Data'
        }
        file TestFile{
            DestinationPath = 'F:\test.txt'
            Contents = 'Test data'
            DependsOn = [Disk]'DVolume'
        }
    }
}