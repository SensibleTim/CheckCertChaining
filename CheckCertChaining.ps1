PARAM ( [switch] $ChainAll = $false, [switch] $ChainOne = $false, [string]$Thumbprint = $null ) 
#***********************************************
# CheckCertChaining.ps1
# Version 1.0
# Date: 03/3/2014 on Technet, 4/17/2023 on Github
# Author: Tim Springston
# Description:  This script searches through the user and computer "personal" 
#  certificate stores and chains certificates in the system context. If a certificate fails 
#  the chaining the failure details are reported at the PowerShell prompt as well as in a text 
#  file. Expired or not yet valid certificates are excluded from chaining. 
# The script can be called with an optional parameter of a thumbprint in case you know which 
#  certificate you'd like to test. 
#If no certificates fail chaining then no results will be reported. 
#Output file is to C:\Users\<username>\AppData\Local\Temp\certchainingchecks.txt 
#http://technet.microsoft.com/en-us/library/cc700843.aspx
#http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509chainstatusflags(v=vs.110).aspx 
#************************************************
cls

function CheckCertChaining 
{  
	$CheckStores = @("My")
	$Counter = 1
	$Now = Get-Date
	$ExportFile =  $env:USERPROFILE + '\CertChainingResults.txt'
	"Certificate chaining results $Now" | Out-File  $ExportFile 
	"Logged on user is $env:USERNAME" | Out-File  $ExportFile -Append 
	"Host being check is $env:COMPUTERNAME" | Out-File  $ExportFile -Append 
	 "*******************************" | Out-File  $ExportFile -Append 
	get-childitem -path cert:\ -recurse | Where-Object {($_.PSParentPath -ne $null)  -and `
	($_.IssuerName.Name -ne "CN=Root Agency") -and (-not($_.NotAfter -lt $Now)) -and (-not($_.NotBefore -gt $Now))} | % {
	  Write-host 'Checking certificate with subject ' $_.Subject ' Thumbprint ' $_.Thumbprint
	  $CertObject = New-Object PSObject 
	  $Store = (Split-Path ($_.PSParentPath) -Leaf)
	  $StorePath = (($_.PSParentPath).Split("\"))     
	  $InformationCollected = new-object PSObject
	  $StoreWorkingContext = $Store
	  $StoreContext = Split-Path $_.PSParentPath.Split("::")[-1] -Leaf
	  if ($Store -match "My")
	  {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Number" -value $Counter
	  if ($_.FriendlyName.length -gt 0)
	  {add-member -inputobject $CertObject -membertype noteproperty -name "Friendly Name" -value $_.FriendlyName}
	  else
	  {add-member -inputobject $CertObject -membertype noteproperty -name "Friendly Name" -value "[None]"}
	  #Determine the context (User or Computer) of the certificate store.
	  $StoreWorkingContext = (($_.PSParentPath).Split("\"))
	  $StoreContext = ($StoreWorkingContext[1].Split(":"))
	  add-member -inputobject $CertObject -membertype noteproperty -name "Path" -value $StoreContext[2]
	  add-member -inputobject $CertObject -membertype noteproperty -name "Store" -value $StorePath[$StorePath.count-1]
	  add-member -inputobject $CertObject -membertype noteproperty -name "Has Private Key" -value $_.HasPrivateKey
	  add-member -inputobject $CertObject -membertype noteproperty -name "Serial Number" -value $_.SerialNumber
	  add-member -inputobject $CertObject -membertype noteproperty -name "Thumbprint" -value $_.Thumbprint
	  add-member -inputobject $CertObject -membertype noteproperty -name "Issuer" -value $_.IssuerName.Name
	  add-member -inputobject $CertObject -membertype noteproperty -name "Not Before" -value $_.NotBefore
	  add-member -inputobject $CertObject -membertype noteproperty -name "Not After" -value $_.NotAfter
	  add-member -inputobject $CertObject -membertype noteproperty -name "Subject Name" -value $_.SubjectName.Name
	  if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}) -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Subject Alternative Name" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Subject Alternative Name" -value "[None]"}
	  if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -like "Key Usage"}) -ne $null) 
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Key Usage" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -like "Key Usage"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Key Usage" -value "[None]"}
	  if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -like "Enhanced Key Usage"}) -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Enhanced Key Usage" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -like "Enhanced Key Usage"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Enhanced Key Usage" -value "[None]"}
	  if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "Certificate Template Information"}) -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Template Information" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "Certificate Template Information"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Template Information" -value "[None]"}

	  $ChainObject = New-Object System.Security.Cryptography.X509Certificates.X509Chain($True)
	  $ChainObject.ChainPolicy.RevocationFlag = "EntireChain" #Possible: EndCertificateOnly, EntireChain, ExcludeRoot (default)
	  $ChainObject.ChainPolicy.VerificationFlags = "NoFlag" #http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509verificationflags.aspx 
	  $ChainObject.ChainPolicy.RevocationMode = "Online" #NoCheck, Online (default), Offline.
	  $ChainResult = $ChainObject.Build($_)
	  $ChainCounter = 1
	  $ChainingProblem = $false
	  $AIAFound = $false
	  $CDPFound = $false
	  $OCSPFound  = $false
	  ForEach ($ChainResult in $ChainObject.ChainStatus)
	        {
			#Chain Results as defined at http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509chainstatusflags(v=vs.110).aspx
	        $ChainResultStatusString = $ChainResult.Status.ToString()
	        $ChainStatusString = "ChainStatus " + $ChainCounter
	        $ChainResultStatusInfoString = $ChainResult.StatusInformation.ToString()
	        $ChainStatusInfoString = "Chain Status Info " + $ChainCounter
			add-member -inputobject $CertObject -membertype noteproperty -name $ChainResultStatusString -value $ChainResultStatusInfoString
			$ChainCounter++
			if ($ChainResultStatusString -eq 'RevocationStatusUnknown')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
	        if ($ChainResultStatusString -eq 'OfflineRevocation')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'UntrustedRoot')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'Revoked')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'PartialChain')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'CtlNotSignatureValid')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'CtlNotTimeValid')
	            {
				$ChainingProblem = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'CtlNotValidForUsage')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'Cyclic')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'HasExcludedNameConstraint')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'HasNotDefinedNameConstraint')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'HasNotPermittedNameConstraint')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'HasNotSupportedNameConstraint')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'InvalidBasicConstraints')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'InvalidExtension')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'InvalidPolicyConstraints')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'NoIssuanceChainPolicy')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'NotSignatureValid')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'NotTimeValid')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}
			if ($ChainResultStatusString -eq 'NotValidForUsage')
	            {
				$ChainingProblem  = $True
				#add root cause string 
				}

	        }
		
	  ForEach ($Extension in $_.Extensions)
	        {
	        if ($Extension.OID.FriendlyName -eq 'Authority Information Access')
	              {
	              #Convert the RawData in the extension to readable form.
	              $FormattedExtension = $Extension.Format(1)
				  $AIAFound = $True
	              add-member -inputobject $CertObject -membertype noteproperty -name "AIA URLs" -value $FormattedExtension
	              }
	        if ($Extension.OID.FriendlyName -eq 'CRL Distribution Points')
	              {
	              #Convert the RawData in the extension to readable form.
	              $FormattedExtension = $Extension.Format(1)
				  $CDPFound = $True
	              add-member -inputobject $CertObject -membertype noteproperty -name "CDP URLs" -value $FormattedExtension
	              }
	        if ($Extension.OID.Value -eq '1.3.6.1.5.5.7.48.1')
	              {
	              #Convert the RawData in the extension to readable form.
	              $FormattedExtension = $Extension.Format(1)
				  $OCSPFound = $True
	              add-member -inputobject $CertObject -membertype noteproperty -name "OCSP URLs" -value $FormattedExtension
	              }
	        }
		
		if ($AIAFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "AIA URLs" -value "[None]"}
		if ($CDPFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "CDP URLs" -value "[None]"}
		if ($OCSPFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "OCSP URLs" -value "[None]"}

	    $CertObject  | Out-File  $ExportFile -Append #-Encoding UTF8
		$CertObject = $null
	 	$Counter++
	  	$ChainingProblem = $False
	  }
	}
}

function CheckSingleCertChain  ($Thumbprint) 
{   
	$CheckStores = @("My")
	$Counter = 1
    $Now = Get-Date
    get-childitem -path cert:\ -recurse | Where-Object {($_.PSParentPath -ne $null)  -and ` 
        ($_.IssuerName.Name -ne "CN=Root Agency") -and (-not($_.NotAfter -lt $Now)) -and (-not($_.NotBefore -gt $Now)) -and ($_.Thumbprint -match $Thumbprint)}  |  % {
        $CertObject = New-Object PSObject 
        $Cert = $_ 
            }

	$ExportFile =  $env:USERPROFILE + '\CheckSingleCertChaining.txt'
	"Certificate chaining results $Now" | Out-File  $ExportFile 
	"Logged on user is $env:USERNAME" | Out-File  $ExportFile -Append 
	"Host being check is $env:COMPUTERNAME" | Out-File  $ExportFile -Append 
    "Checking single certificate " + $Thumbprint  | Out-File  $ExportFile -Append 
	 "*******************************" | Out-File  $ExportFile -Append 
	  Write-host 'Checking certificate with Thumbprint ' $Cert.Thumbprint 
	  $CertObject = New-Object PSObject 
      $InformationCollected = new-object PSObject
      if ($_.FriendlyName.length -gt 0)
      {add-member -inputobject $CertObject -membertype noteproperty -name "Friendly Name" -value $Cert.FriendlyName}
      else
      {add-member -inputobject $CertObject -membertype noteproperty -name "Friendly Name" -value "[None]"}
      add-member -inputobject $CertObject -membertype noteproperty -name "Has Private Key" -value $Cert.HasPrivateKey
      add-member -inputobject $CertObject -membertype noteproperty -name "Serial Number" -value $Cert.SerialNumber
      add-member -inputobject $CertObject -membertype noteproperty -name "Thumbprint" -value $Cert.Thumbprint
      add-member -inputobject $CertObject -membertype noteproperty -name "Issuer" -value $Cert.IssuerName.Name
      add-member -inputobject $CertObject -membertype noteproperty -name "Not Before" -value $Cert.NotBefore
      add-member -inputobject $CertObject -membertype noteproperty -name "Not After" -value $Cert.NotAfter
      add-member -inputobject $CertObject -membertype noteproperty -name "Subject Name" -value $Cert.SubjectName.Name
      if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}) -ne $null)
            {add-member -inputobject $CertObject -membertype noteproperty -name "Subject Alternative Name" -value ($Cert.Extensions | Where-Object {$Cert.Oid.FriendlyName -match "subject alternative name"}).Format(1)
            }
            else
            {add-member -inputobject $CertObject -membertype noteproperty -name "Subject Alternative Name" -value "[None]"}
      if (($_.Extensions | Where-Object {$Cert.Oid.FriendlyName -like "Key Usage"}) -ne $null) 
            {add-member -inputobject $CertObject -membertype noteproperty -name "Key Usage" -value ($Cert.Extensions | Where-Object {$Cert.Oid.FriendlyName -like "Key Usage"}).Format(1)
            }
            else
            {add-member -inputobject $CertObject -membertype noteproperty -name "Key Usage" -value "[None]"}
      if (($_.Extensions | Where-Object {$_CertOid.FriendlyName -like "Enhanced Key Usage"}) -ne $null)
            {add-member -inputobject $CertObject -membertype noteproperty -name "Enhanced Key Usage" -value ($Cert.Extensions | Where-Object {$Cert.Oid.FriendlyName -like "Enhanced Key Usage"}).Format(1)
            }
            else
            {add-member -inputobject $CertObject -membertype noteproperty -name "Enhanced Key Usage" -value "[None]"}
      if (($_.Extensions | Where-Object {$Cert.Oid.FriendlyName -match "Certificate Template Information"}) -ne $null)
            {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Template Information" -value ($Cert.Extensions | Where-Object {$Cert.Oid.FriendlyName -match "Certificate Template Information"}).Format(1)
            }
            else
            {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Template Information" -value "[None]"}

      $ChainObject = New-Object System.Security.Cryptography.X509Certificates.X509Chain($True)
      $ChainObject.ChainPolicy.RevocationFlag = "EntireChain" #Possible: EndCertificateOnly, EntireChain, ExcludeRoot (default)
      $ChainObject.ChainPolicy.VerificationFlags = "NoFlag" #http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509verificationflags.aspx 
      $ChainObject.ChainPolicy.RevocationMode = "Online" #NoCheck, Online (default), Offline.
      $ChainResult = $ChainObject.Build($Cert)
      $ChainCounter = 1
	  $ChainRevocationProblem = $false
	  $ChainOfflineRevocationProblem = $false
	  $ChainUntrustedRootProblem = $false
	  $ChainRevokedProblem = $false
	  $ChainPartialChainProblem = $false
	  $AIAFound = $false
	  $CDPFound = $false
	  $OCSPFound  = $false
      ForEach ($ChainResult in $ChainObject.ChainStatus)
            {
            $ChainResultStatusString = $ChainResult.Status.ToString()
            $ChainStatusString = "ChainStatus " + $ChainCounter
            $ChainResultStatusInfoString = $ChainResult.StatusInformation.ToString()
            $ChainStatusInfoString = "Chain Status Info " + $ChainCounter
			add-member -inputobject $CertObject -membertype noteproperty -name $ChainResultStatusString -value $ChainResultStatusInfoString
			$ChainCounter++
            if ($ChainResultStatusString -eq 'RevocationStatusUnknown')
                  {$ChainRevocationProblem = $True}
            if ($ChainResultStatusString -eq 'OfflineRevocation')
                  {$ChainOfflineRevocationProblem = $True}
			if ($ChainResultStatusString -eq 'UntrustedRoot')
                  {$ChainUntrustedRootProblem = $True}
			if ($ChainResultStatusString -eq 'Revoked')
                  {$ChainRevokedProblem = $True}
			if ($ChainResultStatusString -eq 'PartialChain')
                  {$ChainPartialChainProblem = $True}
            }

		if ($ChainRevocationProblem -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "RevocationStatusUnknown" -value "No Problem Found"}
		if ($ChainOfflineRevocationProblem -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "OfflineRevocation" -value "No Problem Found"}
		if ($ChainUntrustedRootProblem -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "UntrustedRoot" -value "No Problem Found"}
		if ($ChainRevokedProblem -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "Revoked" -value "No Problem Found"}
		if ($ChainPartialChainProblem -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "PartialChain" -value "No Problem Found"}
	
		
      ForEach ($Extension in $_.Extensions)
            {
            if ($Extension.OID.FriendlyName -eq 'Authority Information Access')
                  {
                  #Convert the RawData in the extension to readable form.
                  $FormattedExtension = $Extension.Format(1)
				  $AIAFound = $True
                  add-member -inputobject $CertObject -membertype noteproperty -name "AIA URLs" -value $FormattedExtension
                  }
            if ($Extension.OID.FriendlyName -eq 'CRL Distribution Points')
                  {
                  #Convert the RawData in the extension to readable form.
                  $FormattedExtension = $Extension.Format(1)
				  $CDPFound = $True
                  add-member -inputobject $CertObject -membertype noteproperty -name "CDP URLs" -value $FormattedExtension
                  }
            if ($Extension.OID.Value -eq '1.3.6.1.5.5.7.48.1')
                  {
                  #Convert the RawData in the extension to readable form.
                  $FormattedExtension = $Extension.Format(1)
				  $OCSPFound = $True
                  add-member -inputobject $CertObject -membertype noteproperty -name "OCSP URLs" -value $FormattedExtension
                  }
            }
		
		if ($AIAFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "AIA URLs" -value "[None]"}
		if ($CDPFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "CDP URLs" -value "[None]"}
		if ($OCSPFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "OCSP URLs" -value "[None]"}

     $CertObject  | Out-File  $ExportFile -Append
     $CertObject  | FL
	 $CertObject = $null
     }


If (($ChainOne -eq $true) -and ($Thumbprint -ne $null))
   {CheckSingleCertChain}
if ($ChainAll -eq $true) 
   {CheckCertChaining}
            
