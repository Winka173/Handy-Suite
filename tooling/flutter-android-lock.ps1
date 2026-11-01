function Enter-HandyAndroidBuild {
  $mutex = New-Object System.Threading.Mutex($false, 'Local\HandySuiteFlutterAndroidBuild')
  try { $null = $mutex.WaitOne() } catch [System.Threading.AbandonedMutexException] { }
  return $mutex
}
