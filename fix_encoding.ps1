$file = 'd:\Flutter\anigravityxstich\lib\screens\chat_list_screen.dart'
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

$content = $content.Replace([char]0x00C4 + [char]0x00C3 + [char]0x00A3 + " x" + [char]0x00E1 + [char]0x00BA + [char]0x00A3 + "y ra l" + [char]0x00E1 + [char]0x00BB + [char]0x2014 + "i", [char]0x0110 + [char]0x00E3 + " x" + [char]0x1EA3 + "y ra l" + [char]0x1ED7 + "i")

[System.IO.File]::WriteAllText($file, $content, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Done"
