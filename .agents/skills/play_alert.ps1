Add-Type -AssemblyName presentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$audioFile = "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\teeetooo.mp3"
$player.Open([System.Uri]$audioFile)
$player.Play()
Start-Sleep -Seconds 3
