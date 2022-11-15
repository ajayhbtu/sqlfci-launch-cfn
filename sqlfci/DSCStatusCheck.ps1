function DscStatusCheck () {
   $LCMState = (Get-DscLocalConfigurationManager).LCMState
   if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
       Start-DscConfiguration 'C:\cfn\dsc\WSFCNode1Config' -UseExisting -Force -Wait
   } else {
     'Completed'
   }
}
DscStatusCheck

