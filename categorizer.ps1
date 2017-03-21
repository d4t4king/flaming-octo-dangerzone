
$smallstr="\small"
$mediumstr="\medium"
$largestr="\large"
$xlargestr="\xlarge"
$smallfile=50001
$mediumfile=1000001
$largefile=6000001
$root_dir="pulls"
$all_files=$root_dir

Get-ChildItem $all_files | Foreach-Object {
	if ((Get-Item $_) -is [System.IO.FileInfo]) {
		$outstring = [char[]](gc $env:windir\)
	}
}