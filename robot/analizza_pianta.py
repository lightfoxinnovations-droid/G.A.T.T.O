import base64
import os
import time

from picamera2 import Picamera2
import requests

API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
image_path = "/home/gatito/test_imx500.jpg"

print("Scatto della foto in corso...")
picam2 = Picamera2()
picam2.start()
time.sleep(2)
picam2.capture_file(image_path)
picam2.stop()
print("Foto scattata con successo!")


def encode_image(path):
    with open(path, "rb") as handle:
        return base64.b64encode(handle.read()).decode("utf-8")


base64_image = encode_image(image_path)

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
    "HTTP-Referer": "https://github.com/lightfoxinnovations-droid/G.A.T.T.O",
    "X-Title": "G.A.T.T.O.",
}

payload = {
    "model": "openrouter/free",
    "messages": [{
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": (
                    "Analizza questa pianta. Identifica la specie,"
                    " individua eventuali problemi (foglie ingiallite, malattie"
                    " o parassiti) e fornisci una soluzione pratica per"
                    " risolverli."
                ),
            },
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"},
            },
        ],
    }],
}

print("Invio dell'immagine a OpenRouter...")
response = requests.post(ENDPOINT, headers=headers, json=payload)

if response.status_code == 200:
    result = response.json()
    diagnosi = result["choices"][0]["message"]["content"]
    print("\n--- DIAGNOSI DELL'ORTOBOT ---")
    print(diagnosi)
else:
    print(f"Errore nella richiesta API: {response.status_code} - {response.text}")
