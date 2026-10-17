# Fixtures that MUST trigger. See vulnerable.ts for the annotation format.
import os
import requests

# ruleid: tls-verification-disabled-python
requests.get("https://example.com", verify=False)
s = requests.Session()
# ruleid: tls-verification-disabled-python
s.verify = False


def summarise(client, cur):
    r = client.chat.completions.create(model="gpt-4", messages=[])
    # ruleid: model-output-into-sink-python
    cur.execute(r.choices[0].message.content)


def act(client):
    r = client.messages.create(model="claude", max_tokens=100, messages=[])
    # ruleid: model-output-into-sink-python
    os.system(r.content[0].text)
