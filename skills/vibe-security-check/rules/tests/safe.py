# Fixtures that MUST NOT trigger.
import subprocess
import requests

requests.get("https://example.com", verify="/etc/ssl/certs/ca-bundle.crt")
s = requests.Session()
s.verify = True


def summarise(client, cur):
    r = client.chat.completions.create(model="gpt-4", messages=[])
    # Parsed into a model we defined, then used as a parameter, never as the query.
    q = Query.model_validate_json(r.choices[0].message.content)
    cur.execute("SELECT * FROM notes WHERE id = %s", (q.note_id,))


def store(client, cur):
    r = client.chat.completions.create(model="gpt-4", messages=[])
    # A bound parameter, not query text.
    cur.execute("INSERT INTO summaries (text) VALUES (%s)", (r.choices[0].message.content,))


def act(client):
    r = client.messages.create(model="claude", max_tokens=100, messages=[])
    # The response picks an entry; the app supplies the command.
    subprocess.run(ALLOWED_COMMANDS[r.content[0].text.strip()])
