# Fixture that MUST NOT trigger.
import requests
requests.get("https://example.com", verify="/etc/ssl/certs/ca-bundle.crt")
s = requests.Session()
s.verify = True
