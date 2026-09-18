from picamera2 import Picamera2
import time

picam2 = Picamera2()
picam2.start()
time.sleep(2)
picam2.capture_file("test_imx500.jpg")
print("Foto scattata con successo usando l'IMX500!")
picam2.stop()
