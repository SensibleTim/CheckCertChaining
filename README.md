# CheckCertChaining
This is a PowerShell scripted solution for doing validity checks (aka chaining) of certificates on Windows hosts.

How does it work? 
This script searches through the user and computer "personal" certificate stores and chains certificates in the system context. If a certificate fails the chaining the resultant failure details are reported at the PowerShell prompt as well as in a text file. 

The certificates are found using the integrated PowerShell capability of seeing certificate stores as directory paths. The chaining functionality is using the System.Security.Cryptography.X509Certificates Namespace. Public documentation for the namespace can be found at this link https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates?view=net-7.0.


How to use the script
The script can be used to chain individual certificates in accesible certificate stores which can be useful when testing a certificate to be used in a service. Warning: Export/import the certificates to be tested with public keys only. The private key is not necessary for chaining.
The script can be called with an optional parameter of a thumbprint in case you know which certificate you'd like to test.
If no thumbprint is specified The script uses the interactive context of the signed in user to query the certificate stores and do the chaining.
The script must be ran from an elevated PowerShell prompt.

Results
Certificate chaining results are output to a file at $env:USERPROFILE\certchainingchecks.txt 

Note
Expired or not yet valid certificates are excluded from chaining. 

http://technet.microsoft.com/en-us/library/cc700843.aspx
http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509chainstatusflags(v=vs.110).aspx 

Sample result
Certificate Number               : 3	

Friendly Name                    : [None]

Path                             : CurrentUser

Store                            : My

Has Private Key                  : True

Serial Number                    : <sample>
	
Thumbprint                       : <sample>
	
Issuer                           : O=test2, OU=testCA
	
Not Before                       : 4/16/2022 7:40:23 AM
	
Not After                        : 4/15/2028 7:40:23 AM
	
Subject Name                     : CN=*.test, O=test2, OU=testCA
	
Subject Alternative Name         : DNS Name=*.test.com
	
Key Usage                        : Digital Signature, Key Encipherment, Data Encipherment (b0)
	
Enhanced Key Usage               : Server Authentication (1.3.6.1.5.5.7.3.1)
	
Certificate Template Information : [None]
	
RevocationStatusUnknown          : The revocation function was unable to check revocation for the certificate.     
	
AIA URLs                         : [None]
	
CDP URLs                         : [None]
	
OCSP URLs                        : [None]
	

