# Fixture that MUST NOT trigger.
import requests
requests.get("https://example.com", verify="/etc/ssl/certs/ca-bundle.crt")
s = requests.Session()
s.verify = True

def summarise(client, cur):
    r = client.chat.completions.create(model="gpt-4", messages=[])
    # Parsed into a model we defined, then used as a parameter, never as the query.
    q = Query.model_validate_json(r.choices[0].message.content)
    cur.execute("SELECT * FROM notes WHERE id = %s", (q.note_id,))
