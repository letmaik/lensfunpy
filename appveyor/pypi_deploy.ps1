$gitinfo = `git log -n 1 --pretty=format:'%d'`
if (($env:APPVEYOR_REPO_BRANCH -eq "master") -and ($gitinfo -match "tag: v")) {
  (Get-Content appveyor\.pypirc) | Foreach-Object {$_ -replace '%PASS%',$env:PYPI_PASS} | Out-File $env:userprofile\.pypirc
  $env:CMD_IN_ENV python setup.py bdist_wheel upload
}