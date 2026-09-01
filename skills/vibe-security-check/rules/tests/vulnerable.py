# Fixture that MUST trigger the python TLS rule.
import requests
requests.get("https://example.com", verify=False)
s = requests.Session()
s.verify = False
