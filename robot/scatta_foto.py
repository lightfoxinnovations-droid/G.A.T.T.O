from picamera2 import Picamera2
import time
import os

picam2 = Picamera2()
picam2.start()
time.sleep(2)

# Scegli la cartella di destinazione (cambiala in 'altre_piante' se necessario)
cartella = "/home/gatito/robot_plants/dataset/tulipani"

# Crea un nome file basato sul timestamp
timestamp = int(time.time())
path_file = os.path.join(cartella, f"pianta_{timestamp}.jpg")

picam2.capture_file(path_file)
print(f"Foto salvata in: {path_file}")

picam2.stop()
