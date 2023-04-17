# CheckCertChaining
This is a PowerShell scripted solution for doing validity checks (aka chaining) of certificates on Windows hosts.

How does it work? 
This script searches through the user and computer "personal" certificate stores and chains certificates in the system context. If a certificate fails the chaining the resultant failure details are reported at the PowerShell prompt as well as in a text file. 

The certificates are found using the integrated PowerShell capability of seeing certificate stores as directory paths. The chaining functionality is using the System.Security.Cryptography.X509Certificates Namespace. Public documentation for the namespace can be found at this link https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates?view=net-7.0.


How to use the script
The script uses the interactive context of the signed in user to query the certificate stores and do the chaining.
The script must be ran from an elevated PowerShell prompt.
The script can be used to chain individual certificates in accesible certificate stores which can be useful when testing a certificate to be used in a service. Warning: Export/import the certificates to be tested with public keys only. The private key is not necessary for chaining.
The script can be called with an optional parameter of a thumbprint in case you know which certificate you'd like to test.

Results
Certificate chaining results are output to a file at %root%\Users\<username>\AppData\Local\Temp\certchainingchecks.txt 

Notes
If no certificates fail chaining then no results will be reported in the output file.
Expired or not yet valid certificates are excluded from chaining. 

http://technet.microsoft.com/en-us/library/cc700843.aspx
http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509chainstatusflags(v=vs.110).aspx 
