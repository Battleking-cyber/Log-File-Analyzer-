# Log-File-Analyzer-
This tool helps system administrators, security testers, and developers quickly identify and analyze sensitive data or login attempts stored in log files.
 Output Report Example

Example saved file: search_results_20251016_143522.txt

===== IPs in /var/log/auth.log =====
192.168.1.10
10.0.0.45

===== IDs in /var/log/auth.log =====
uid=1000
user id=admin

===== Password-related lines in /var/log/auth.log =====
password=12345
pwd: testuser
