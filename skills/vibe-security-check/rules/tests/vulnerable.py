# Fixture that MUST trigger the python TLS rule.
import requests
requests.get("https://example.com", verify=False)
s = requests.Session()
s.verify = False

# model-output-into-sink-python
def summarise(client, cur):
    r = client.chat.completions.create(model="gpt-4", messages=[])
    cur.execute(r.choices[0].message.content)
