import base64
import io
import json
import os
import subprocess
import sys
import threading
import time
from flask import Flask, Response, jsonify, request
from flask_cors import CORS
from picamera2 import Picamera2
import requests

app = Flask(__name__)
CORS(app)

API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
IMAGE_PATH = "/home/gatito/test_imx500.jpg"
LIVE_PATH = "/tmp/gatto-live.jpg"
TOUR_PATH = "/home/gatito/.config/gatto-tour.json"
HOTSPOT_SSID = "G.A.T.T.O."
CONNECT_STATE = {"busy": False, "ok": False, "message": "", "ssid": ""}
DOG_SERVER = "/home/gatito/Freenove_Robot_Dog_Kit_for_Raspberry_Pi/Code/Server"
WALK_COMMANDS = {
    "forward": "forWard",
    "backward": "backWard",
    "left": "setpLeft",
    "right": "setpRight",
}
POSE_COMMANDS = {"up", "down", "tilt_left", "tilt_right", "level"}
MOVE_COMMANDS = set(WALK_COMMANDS) | POSE_COMMANDS | {"stop"}
IMX_MODEL = "/usr/share/imx500-models/imx500_network_ssd_mobilenetv2_fpnlite_320x320_pp.rpk"
IMX_LABELS = "/usr/share/rpi-camera-assets/imx500_mobilenet_ssd.json"
PLANT_LABELS = {"potted plant", "vase", "potted_plant"}
VISION_MODEL = "openrouter/free"
OBSTACLE_CM = 28
FORWARD_STEPS = 10
INSPECT_COOLDOWN = 18

picam2 = None
imx500_device = None
imx500_labels = []
robot_mode = "manual"
dog = None
sonic = None
move_direction = "stop"
move_lock = threading.Lock()
camera_lock = threading.Lock()
chat_lock = threading.Lock()
height_offset = 0
roll = 0
patrol_active = False
patrol_paused = False
last_inspect_at = 0
last_camera_request = 0
LIVE_JPEG = b""
CHAT = []
CHAT_ID = 0
CHAT_MAX = 40
PENDING_ORDERS = []
MEMORY = []
TOUR = {"recording": False, "playing": False, "current": [], "stops": []}
PATROL = {
    "running": False,
    "distance": 0,
    "message": "In attesa",
    "diagnosis": "",
    "eyes": "idle",
}
PLANT_PROMPT = (
    "Analizza questa pianta. Identifica la specie,"
    " individua eventuali problemi (foglie ingiallite, malattie"
    " o parassiti) e fornisci una soluzione pratica per"
    " risolverli. Spiega il ragionamento in italiano, in modo chiaro."
)


def run(cmd, timeout=40):
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def load_tour():
    try:
        with open(TOUR_PATH, encoding="utf-8") as handle:
            data = json.load(handle)
        TOUR["stops"] = list(data.get("stops") or [])
    except Exception:
        TOUR["stops"] = []


def persist_tour():
    folder = os.path.dirname(TOUR_PATH)
    os.makedirs(folder, exist_ok=True)
    with open(TOUR_PATH, "w", encoding="utf-8") as handle:
        json.dump({"stops": TOUR["stops"]}, handle, ensure_ascii=True, indent=2)


def tour_public():
    return {
        "recording": TOUR["recording"],
        "playing": TOUR["playing"],
        "paused": patrol_paused,
        "current_steps": len(TOUR["current"]),
        "stops": [item.get("name") or "Fermata" for item in TOUR["stops"]],
    }


def _init_camera_unlocked():
    global picam2, imx500_device, imx500_labels
    if picam2 is not None:
        return
    try:
        from picamera2.devices import IMX500
        imx500_device = IMX500(IMX_MODEL)
        with open(IMX_LABELS, encoding="utf-8") as handle:
            imx500_labels = json.load(handle)["imx500_object_detection"]["classes"]
        picam2 = Picamera2(imx500_device.camera_num)
        config = picam2.create_preview_configuration(
            main={"size": (640, 480)},
            controls={"FrameRate": 15},
            buffer_count=6,
        )
        picam2.start(config)
        try:
            imx500_device.set_auto_aspect_ratio()
        except Exception:
            pass
        time.sleep(1.2)
        PATROL["eyes"] = "imx500"
        print("camera: IMX500 pronto")
        return
    except Exception as error:
        print("imx500 init:", error)
        imx500_device = None
        imx500_labels = []
    picam2 = Picamera2()
    picam2.start()
    time.sleep(1.2)
    PATROL["eyes"] = "camera"
    print("camera: fallback Picamera2")


def get_camera():
    if picam2 is not None:
        return picam2
    with camera_lock:
        _init_camera_unlocked()
        return picam2


def make_thumb_bytes(raw, max_w=400, quality=45):
    try:
        from PIL import Image
        image = Image.open(io.BytesIO(raw))
        image.thumbnail((max_w, max_w))
        if image.mode != "RGB":
            image = image.convert("RGB")
        buf = io.BytesIO()
        image.save(buf, format="JPEG", quality=quality)
        return buf.getvalue()
    except Exception as error:
        print("miniatura:", error)
        return raw


def make_thumb_b64(raw):
    return base64.b64encode(make_thumb_bytes(raw)).decode("ascii")


def refresh_live():
    global LIVE_JPEG
    try:
        with camera_lock:
            if picam2 is None:
                _init_camera_unlocked()
            picam2.capture_file(LIVE_PATH)
        with open(LIVE_PATH, "rb") as handle:
            LIVE_JPEG = make_thumb_bytes(handle.read(), max_w=480, quality=50)
    except Exception as error:
        print("live:", error)


def capture_jpeg_bytes():
    with camera_lock:
        if picam2 is None:
            _init_camera_unlocked()
        picam2.capture_file(IMAGE_PATH)
        with open(IMAGE_PATH, "rb") as handle:
            return handle.read()


def ask_vision(prompt, timeout=55):
    if not API_KEY:
        raise RuntimeError("Chiave OpenRouter mancante sul robot.")
    if not has_internet():
        raise RuntimeError("Niente internet: l'analisi IA è in pausa.")
    raw = capture_jpeg_bytes()
    full_b64 = base64.b64encode(raw).decode("ascii")
    thumb_b64 = make_thumb_b64(raw)
    response = requests.post(
        ENDPOINT,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": VISION_MODEL,
            "messages": [{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{full_b64}"},
                    },
                ],
            }],
        },
        timeout=timeout,
    )
    if response.status_code != 200:
        raise RuntimeError(f"Errore API OpenRouter: {response.text}")
    text = response.json()["choices"][0]["message"]["content"]
    return text, thumb_b64


def add_chat(role, text, action="", image=""):
    global CHAT_ID
    with chat_lock:
        CHAT_ID += 1
        item = {
            "id": CHAT_ID,
            "role": role,
            "text": text,
            "action": action,
            "image": image or "",
            "ts": int(time.time()),
        }
        CHAT.append(item)
        while len(CHAT) > CHAT_MAX:
            CHAT.pop(0)
        return item


def chat_since(after_id):
    with chat_lock:
        if after_id <= 0:
            return list(CHAT[-16:])
        return [item for item in CHAT if item["id"] > after_id]


def take_orders():
    with chat_lock:
        orders = list(PENDING_ORDERS)
        PENDING_ORDERS.clear()
        return orders


def remember(action, reason, distance):
    MEMORY.append({"action": action, "reason": reason, "distance": distance})
    while len(MEMORY) > 8:
        MEMORY.pop(0)


def record_move(kind):
    if TOUR["recording"] and not TOUR["playing"]:
        TOUR["current"].append(kind)


def save_stop(name):
    label = (name or "").strip() or f"Fermata {len(TOUR['stops']) + 1}"
    TOUR["stops"].append({
        "name": label,
        "moves": list(TOUR["current"]),
    })
    TOUR["current"] = []
    if len(TOUR["stops"]) > 6:
        TOUR["stops"] = TOUR["stops"][-6:]
    persist_tour()
    add_chat("system", f"Fermata salvata: {label}.")
    return label


def home_ssid():
    result = run(["nmcli", "-t", "-f", "ACTIVE,SSID", "device", "wifi"])
    for line in result.stdout.splitlines():
        parts = line.split(":", 1)
        if len(parts) == 2 and parts[0] == "yes" and parts[1] and parts[1] != HOTSPOT_SSID:
            return parts[1]
    return ""


def has_internet():
    result = run(["ping", "-c", "1", "-W", "2", "1.1.1.1"], timeout=6)
    return result.returncode == 0


def realign_hotspot():
    check = run(["/usr/sbin/iw", "dev", "ap0", "info"], timeout=5)
    if check.returncode == 0 and "type AP" in check.stdout:
        return
    if run(["systemctl", "is-enabled", "gatto-hotspot.service"], timeout=5).returncode == 0:
        run(["sudo", "-n", "systemctl", "restart", "gatto-hotspot.service"], timeout=30)
        return
    script = "/home/gatito/gatto-hotspot/start.sh"
    if os.path.isfile(script):
        run(["sudo", "-n", script], timeout=30)


def get_dog():
    global dog
    if dog is not None:
        return dog
    if DOG_SERVER not in sys.path:
        sys.path.insert(0, DOG_SERVER)
    here = os.getcwd()
    os.chdir(DOG_SERVER)
    try:
        from Control import Control
        dog = Control()
    finally:
        os.chdir(here)
    return dog


def apply_gait(direction):
    control = get_dog()
    getattr(control, WALK_COMMANDS[direction])()
    record_move(direction)


def get_distance_cm():
    global sonic
    try:
        if sonic is None:
            if DOG_SERVER not in sys.path:
                sys.path.insert(0, DOG_SERVER)
            from Ultrasonic import Ultrasonic
            sonic = Ultrasonic()
        return int(sonic.get_distance())
    except Exception as error:
        print("ultrasuoni:", error)
        return 80


def apply_stop():
    get_dog().stop()


def apply_pose():
    global height_offset, roll
    control = get_dog()
    height_offset = max(-28, min(24, height_offset))
    roll = max(-18, min(18, roll))
    control.upAndDown(height_offset)
    control.attitude(roll, 0, 0)


def apply_pose_step(direction):
    global height_offset, roll
    if direction == "up":
        height_offset += 6
    elif direction == "down":
        height_offset -= 6
    elif direction == "tilt_left":
        roll -= 5
    elif direction == "tilt_right":
        roll += 5
    elif direction == "level":
        height_offset = 0
        roll = 0
    apply_pose()


def move_loop():
    global move_direction
    last = "stop"
    while True:
        with move_lock:
            direction = move_direction
            mode = robot_mode
        if mode != "manual" or direction == "stop":
            if last in WALK_COMMANDS:
                try:
                    apply_stop()
                except Exception as error:
                    print("stop motori:", error)
            last = "stop"
            time.sleep(0.05)
            continue
        try:
            if direction in WALK_COMMANDS:
                apply_gait(direction)
                last = direction
            elif direction in POSE_COMMANDS:
                apply_pose_step(direction)
                last = direction
                if direction == "level":
                    with move_lock:
                        if move_direction == "level":
                            move_direction = "stop"
                else:
                    time.sleep(0.18)
            else:
                time.sleep(0.05)
        except Exception as error:
            print("movimento:", error)
            time.sleep(0.1)


def still_patrolling():
    return patrol_active and robot_mode == "autonomous"


def local_detections():
    if imx500_device is None or picam2 is None:
        return []
    try:
        import numpy as np
        with camera_lock:
            metadata = picam2.capture_metadata()
            outputs = imx500_device.get_outputs(metadata, add_batch=True)
        if not outputs:
            return []
        boxes = np.squeeze(outputs[0])
        scores = np.squeeze(outputs[1])
        classes = np.squeeze(outputs[2])
        if boxes.ndim == 1:
            boxes = boxes.reshape(-1, 4)
        if boxes.shape[-1] != 4 and boxes.shape[0] == 4:
            boxes = boxes.T
        found = []
        count = min(len(scores), len(classes), len(boxes))
        for index in range(count):
            score = float(scores[index])
            if score < 0.42:
                continue
            cls = int(classes[index])
            label = imx500_labels[cls] if 0 <= cls < len(imx500_labels) else str(cls)
            y0, x0, y1, x1 = [float(value) for value in boxes[index][:4]]
            vals = [x0, y0, x1, y1]
            if max(vals) > 1.5:
                x0, y0, x1, y1 = x0 / 320.0, y0 / 320.0, x1 / 320.0, y1 / 320.0
            xa, xb = sorted((x0, x1))
            ya, yb = sorted((y0, y1))
            found.append({
                "label": label,
                "score": score,
                "cx": (xa + xb) / 2,
                "cy": (ya + yb) / 2,
                "area": max(0.0, xb - xa) * max(0.0, yb - ya),
            })
        return found
    except Exception as error:
        print("detect:", error)
        return []


def plants_ahead():
    return [
        item for item in local_detections()
        if str(item["label"]).lower() in PLANT_LABELS
    ]


def turn(side):
    if side == "left":
        get_dog().turnLeft()
        record_move("turn_left")
        return
    get_dog().turnRight()
    record_move("turn_right")


def replay_move(move):
    if move in WALK_COMMANDS:
        apply_gait(move)
        return
    if move == "turn_left":
        get_dog().turnLeft()
        return
    if move == "turn_right":
        get_dog().turnRight()


def avoid_obstacle(distance, turn_right):
    PATROL["message"] = f"Ostacolo a {distance} cm, giro"
    add_chat("system", f"Ostacolo a {distance} cm, giro.", action="avoid")
    get_dog().backWard()
    record_move("backward")
    for _ in range(3):
        if not still_patrolling():
            return not turn_right
        turn("right" if turn_right else "left")
    remember("avoid", f"ostacolo a {distance} cm", distance)
    return not turn_right


def inspect_plant(extra=""):
    global last_inspect_at
    now = time.time()
    if now - last_inspect_at < INSPECT_COOLDOWN:
        add_chat("system", "Pianta già vista da poco, continuo.")
        return
    last_inspect_at = now
    PATROL["message"] = "Sto analizzando la pianta"
    add_chat("system", "Pianta inquadrata. Avvio l'analisi IA.")
    if not API_KEY or not has_internet():
        PATROL["message"] = "Pianta vista, analisi in attesa di rete"
        add_chat("system", "Niente internet: cammino lo stesso. La diagnosi arriverà quando c'è rete.")
        return
    prompt = PLANT_PROMPT
    if extra:
        prompt = extra.strip() + "\n\n" + PLANT_PROMPT
    try:
        diagnosis, photo = ask_vision(prompt)
        PATROL["diagnosis"] = diagnosis
        PATROL["message"] = "Pianta analizzata, continuo"
        add_chat("ai", diagnosis, action="inspect", image=photo)
    except Exception as error:
        PATROL["message"] = "Analisi non riuscita, continuo"
        add_chat("system", f"Analisi non riuscita: {error}")


def walk_forward(steps=FORWARD_STEPS):
    for _ in range(steps):
        if not still_patrolling() or patrol_paused:
            break
        distance = get_distance_cm()
        PATROL["distance"] = distance
        if 0 < distance < OBSTACLE_CM:
            break
        apply_gait("forward")


def apply_local_action(action):
    if action == "inspect":
        inspect_plant()
        if still_patrolling() and not patrol_paused:
            turn("right")
        return
    if action == "left":
        turn("left")
        return
    if action == "right":
        turn("right")
        return
    if action == "backward":
        apply_gait("backward")
        return
    if action == "stop":
        apply_stop()
        time.sleep(0.4)
        return
    walk_forward()


def handle_orders(orders):
    global patrol_paused
    acted = False
    for text in orders:
        low = text.lower().strip()
        if not low:
            continue
        if any(word in low for word in ("fermati", "ferma", "stop", "pausa")):
            patrol_paused = True
            apply_stop()
            add_chat("system", "Ok, mi fermo. Scrivi «continua» per ripartire.")
            acted = True
            continue
        if any(word in low for word in ("continua", "riparti", "riprende")):
            patrol_paused = False
            add_chat("system", "Riparto.")
            acted = True
            continue
        if "fermata" in low or low.startswith("salva "):
            name = text
            for prefix in ("salva fermata", "salva", "fermata"):
                if low.startswith(prefix):
                    name = text[len(prefix):].strip(" :")
                    break
            save_stop(name)
            acted = True
            continue
        if any(word in low for word in ("analizza", "analisi", "scansione", "diagnosi")):
            inspect_plant(text)
            acted = True
            continue
        if "destra" in low:
            add_chat("system", "Giro a destra.")
            turn("right")
            if "vaso" in low or "pianta" in low:
                walk_forward(6)
            acted = True
            continue
        if "sinistra" in low:
            add_chat("system", "Giro a sinistra.")
            turn("left")
            if "vaso" in low or "pianta" in low:
                walk_forward(6)
            acted = True
            continue
        if "indietro" in low:
            add_chat("system", "Faccio un passo indietro.")
            apply_gait("backward")
            acted = True
            continue
        if low in ("avanti", "vai avanti") or low.startswith("vai avanti"):
            add_chat("system", "Avanzo.")
            walk_forward()
            acted = True
            continue
        inspect_plant(text)
        acted = True
    return acted


def choose_local_action(distance):
    plants = plants_ahead()
    if plants:
        best = max(plants, key=lambda item: item["score"] * (item["area"] + 0.05))
        if best["area"] > 0.12 or (0 < distance < 55 and abs(best["cx"] - 0.5) < 0.22):
            return "inspect", "Pianta vicina, la analizzo"
        if best["cx"] < 0.38:
            return "left", "Vaso a sinistra, giro"
        if best["cx"] > 0.62:
            return "right", "Vaso a destra, giro"
        return "forward", "Vaso davanti, mi avvicino"
    if 0 < distance < 45:
        return "forward", "Libero, avanzo piano"
    return "forward", "Libero, avanzo"


def play_tour():
    stops = list(TOUR["stops"])
    if not stops:
        add_chat("system", "Nessuna fermata salvata. Insegnane una dal balcone.")
        TOUR["playing"] = False
        return
    add_chat("system", f"Ripeto il giro: {len(stops)} fermate.")
    for stop in stops:
        if not still_patrolling():
            break
        name = stop.get("name") or "Fermata"
        PATROL["message"] = f"Verso {name}"
        add_chat("system", f"Vado verso {name}.")
        for move in stop.get("moves") or []:
            if not still_patrolling() or patrol_paused:
                TOUR["playing"] = False
                return
            distance = get_distance_cm()
            PATROL["distance"] = distance
            if 0 < distance < OBSTACLE_CM:
                avoid_obstacle(distance, True)
                continue
            replay_move(move)
        if still_patrolling():
            inspect_plant(f"Sei fermo alla fermata «{name}».")
    TOUR["playing"] = False
    if still_patrolling():
        PATROL["message"] = "Giro finito"
        add_chat("system", "Giro finito.")


def patrol_loop():
    turn_right = True
    chatter = 0
    while True:
        if not still_patrolling():
            if PATROL["running"]:
                PATROL.update(running=False, message="Pattuglia ferma")
                TOUR["playing"] = False
                try:
                    apply_stop()
                except Exception:
                    pass
            time.sleep(0.2)
            continue
        PATROL["running"] = True
        try:
            orders = take_orders()
            if orders:
                handle_orders(orders)
            if patrol_paused:
                PATROL["message"] = "In pausa, in attesa di un ordine"
                time.sleep(0.2)
                continue
            if TOUR["playing"]:
                play_tour()
                continue
            distance = get_distance_cm()
            PATROL["distance"] = distance
            if 0 < distance < OBSTACLE_CM:
                turn_right = avoid_obstacle(distance, turn_right)
                continue
            action, message = choose_local_action(distance)
            PATROL["message"] = message
            chatter += 1
            if action != "forward" or chatter >= 2:
                add_chat("system", message, action=action)
                chatter = 0
            remember(action, message, distance)
            apply_local_action(action)
        except Exception as error:
            PATROL["message"] = f"Pausa: {error}"
            add_chat("system", f"Pausa: {error}")
            time.sleep(0.4)


def camera_loop():
    while True:
        want = patrol_active or (time.time() - last_camera_request < 10)
        if want:
            refresh_live()
            time.sleep(0.4)
        else:
            time.sleep(0.6)


def camera_boot():
    try:
        get_camera()
        if PATROL.get("eyes") == "imx500":
            add_chat("system", "Occhi IMX500 pronti: cerco vasi in locale.")
        else:
            add_chat("system", "Camera pronta. Guida con ultrasuono.")
    except Exception as error:
        print("camera boot:", error)


def forget_wifi_networks():
    result = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"])
    for line in result.stdout.splitlines():
        name, _, kind = line.partition(":")
        if kind.startswith("802-11-wireless") and name:
            run(["sudo", "-n", "nmcli", "connection", "delete", "id", name])


def connect_wifi(ssid, password):
    CONNECT_STATE.update(busy=True, ok=False, message="Connessione in corso...", ssid=ssid)
    cmd = ["sudo", "-n", "nmcli", "device", "wifi", "connect", ssid]
    if password:
        cmd.extend(["password", password])
    result = run(cmd, timeout=45)
    if result.returncode == 0:
        time.sleep(2)
        realign_hotspot()
        CONNECT_STATE.update(
            busy=False,
            ok=True,
            message="Rete di casa impostata.",
            ssid=ssid,
        )
        return
    error = (result.stderr or result.stdout or "Connessione non riuscita.").strip()
    CONNECT_STATE.update(busy=False, ok=False, message=error, ssid="")


load_tour()
threading.Thread(target=move_loop, daemon=True).start()
threading.Thread(target=patrol_loop, daemon=True).start()
threading.Thread(target=camera_loop, daemon=True).start()
threading.Thread(target=camera_boot, daemon=True).start()


@app.route("/api/status", methods=["GET"])
def robot_status():
    ssid = home_ssid()
    return jsonify({
        "status": "success",
        "name": "G.A.T.T.O.",
        "mode": "home-wifi" if ssid else "setup",
        "configured": bool(ssid),
        "home_ssid": ssid,
        "internet": has_internet(),
        "drive_mode": robot_mode,
        "patrol": PATROL,
        "tour": tour_public(),
        "connect": CONNECT_STATE,
    })


@app.route("/api/camera.jpg", methods=["GET"])
def camera_jpg():
    global last_camera_request
    last_camera_request = time.time()
    if not LIVE_JPEG:
        refresh_live()
    return Response(LIVE_JPEG or b"", mimetype="image/jpeg")


@app.route("/api/mode", methods=["POST"])
def set_mode():
    global robot_mode, move_direction, patrol_active, patrol_paused
    data = request.get_json(silent=True) or {}
    mode = str(data.get("mode") or "").strip().lower()
    if mode not in ("autonomous", "manual"):
        return jsonify({"status": "error", "message": "Usa autonomous oppure manual."}), 400
    with move_lock:
        robot_mode = mode
        move_direction = "stop"
        patrol_active = mode == "autonomous"
        patrol_paused = False
        if mode != "autonomous":
            TOUR["playing"] = False
    if patrol_active:
        PATROL.update(running=True, message="Guida locale avviata")
        add_chat("system", "Guida locale avviata. L'IA cloud interviene solo sulle piante. Puoi darmi ordini.")
    else:
        PATROL.update(running=False, message="Pattuglia ferma")
        add_chat("system", "Pattuglia ferma.")
        try:
            apply_stop()
        except Exception:
            pass
    return jsonify({"status": "success", "mode": robot_mode, "patrol": PATROL, "tour": tour_public()})


@app.route("/api/move", methods=["POST"])
def move_robot():
    global move_direction
    if robot_mode != "manual":
        return jsonify({
            "status": "error",
            "message": "Il robot è in modalità autonoma. Passa a Manuale per guidarlo.",
        }), 400
    data = request.get_json(silent=True) or {}
    direction = str(data.get("direction") or "").strip().lower()
    if direction not in MOVE_COMMANDS:
        return jsonify({"status": "error", "message": "Direzione non valida."}), 400
    with move_lock:
        move_direction = direction
    return jsonify({"status": "success", "direction": direction, "mode": robot_mode})


@app.route("/api/wifi/scan", methods=["GET"])
def wifi_scan():
    result = run(["sudo", "-n", "nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"])
    seen = {}
    for line in result.stdout.splitlines():
        parts = line.split(":")
        if len(parts) < 2:
            continue
        ssid = parts[0].strip()
        if not ssid or ssid == HOTSPOT_SSID:
            continue
        try:
            signal = int(parts[1])
        except ValueError:
            signal = 0
        security = parts[2] if len(parts) > 2 else ""
        prev = seen.get(ssid)
        if not prev or signal > prev["signal"]:
            seen[ssid] = {
                "ssid": ssid,
                "signal": signal,
                "secured": bool(security and security != "--"),
            }
    networks = sorted(seen.values(), key=lambda item: item["signal"], reverse=True)
    return jsonify({"status": "success", "networks": networks})


@app.route("/api/wifi/connect", methods=["POST"])
def wifi_connect():
    data = request.get_json(silent=True) or {}
    ssid = str(data.get("ssid") or "").strip()
    password = str(data.get("password") or "")
    if not ssid:
        return jsonify({"status": "error", "message": "Scegli una rete."}), 400
    if CONNECT_STATE["busy"]:
        return jsonify({"status": "error", "message": "Connessione già in corso."}), 409
    threading.Thread(target=connect_wifi, args=(ssid, password), daemon=True).start()
    return jsonify({"status": "success", "message": "Connessione avviata."})


@app.route("/api/wifi/forget", methods=["POST"])
def wifi_forget():
    forget_wifi_networks()
    CONNECT_STATE.update(busy=False, ok=False, message="", ssid="")
    realign_hotspot()
    return jsonify({"status": "success", "configured": False})


@app.route("/api/patrol/chat", methods=["GET"])
def patrol_chat():
    try:
        after = int(request.args.get("after") or 0)
    except ValueError:
        after = 0
    return jsonify({"status": "success", "messages": chat_since(after)})


@app.route("/api/patrol/say", methods=["POST"])
def patrol_say():
    data = request.get_json(silent=True) or {}
    text = str(data.get("message") or "").strip()
    if not text:
        return jsonify({"status": "error", "message": "Scrivi un comando."}), 400
    with chat_lock:
        PENDING_ORDERS.append(text)
    item = add_chat("user", text)
    return jsonify({"status": "success", "message": item})


@app.route("/api/tour", methods=["GET"])
def tour_get():
    return jsonify({"status": "success", "tour": tour_public()})


@app.route("/api/tour/record", methods=["POST"])
def tour_record():
    data = request.get_json(silent=True) or {}
    enabled = data.get("enabled")
    if enabled is None:
        enabled = not TOUR["recording"]
    TOUR["recording"] = bool(enabled)
    if TOUR["recording"]:
        TOUR["current"] = []
        add_chat("system", "Registrazione giro: portalo alle piante e premi Salva fermata.")
    else:
        add_chat("system", "Registrazione fermata.")
    return jsonify({"status": "success", "tour": tour_public()})


@app.route("/api/tour/save", methods=["POST"])
def tour_save():
    data = request.get_json(silent=True) or {}
    name = str(data.get("name") or "").strip()
    save_stop(name)
    return jsonify({"status": "success", "tour": tour_public()})


@app.route("/api/tour/play", methods=["POST"])
def tour_play():
    global robot_mode, move_direction, patrol_active, patrol_paused
    if not TOUR["stops"]:
        return jsonify({"status": "error", "message": "Nessuna fermata salvata."}), 400
    with move_lock:
        robot_mode = "autonomous"
        move_direction = "stop"
        patrol_active = True
        patrol_paused = False
        TOUR["playing"] = True
        TOUR["recording"] = False
    PATROL.update(running=True, message="Ripeto il giro")
    add_chat("system", "Ripeto il giro insegnato.")
    return jsonify({"status": "success", "tour": tour_public()})


@app.route("/api/tour/clear", methods=["POST"])
def tour_clear():
    TOUR["stops"] = []
    TOUR["current"] = []
    TOUR["recording"] = False
    TOUR["playing"] = False
    persist_tour()
    add_chat("system", "Giro cancellato.")
    return jsonify({"status": "success", "tour": tour_public()})


@app.route("/api/analyze", methods=["GET"])
def analyze_plant():
    try:
        diagnosis, photo = ask_vision(PLANT_PROMPT)
        PATROL["diagnosis"] = diagnosis
        add_chat("ai", diagnosis, action="inspect", image=photo)
        return jsonify({"status": "success", "diagnosis": diagnosis})
    except Exception as error:
        return jsonify({"status": "error", "message": str(error)}), 500


if __name__ == "__main__":
    try:
        app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
    finally:
        if picam2 is not None:
            picam2.stop()
