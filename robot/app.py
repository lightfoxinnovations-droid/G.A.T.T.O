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
HEAD_COMMANDS = {"head_up", "head_down", "head_left", "head_right", "head_center"}
MOVE_COMMANDS = set(WALK_COMMANDS) | POSE_COMMANDS | HEAD_COMMANDS | {"stop"}
HEAD_PITCH_MIN = -18
HEAD_PITCH_MAX = 14
HEAD_PITCH_STEP = 5
HEAD_PAN_STEP = 14
IMX_MODEL = "/usr/share/imx500-models/imx500_network_ssd_mobilenetv2_fpnlite_320x320_pp.rpk"
IMX_LABELS = "/usr/share/rpi-camera-assets/imx500_mobilenet_ssd.json"
PLANT_LABELS = {"potted plant", "vase", "potted_plant"}
VISION_MODEL = "openrouter/free"
OBSTACLE_CM = 70
FORWARD_STEPS = 1
INSPECT_COOLDOWN = 18
PATROL_SPEED = 3
TURN_SPEED = 8
TURN_STEPS = 10
MANUAL_SPEED = 8
HEAD_SERVO = 15
HEAD_CENTER = 90
HEAD_LEFT = 48
HEAD_RIGHT = 132
LOOK_DOWN = -16
LOOK_DOWN_LOW = -18
SETTLE_S = 1.0
OBSTACLE_LABELS = {
    "person", "chair", "couch", "bed", "dining table", "tv",
    "refrigerator", "bench",
}
head_angle = 90
LOOK_SWEEPS = (
    ("tutto a sinistra", 48),
    ("a sinistra", 68),
    ("davanti", 90),
    ("a destra", 112),
    ("tutto a destra", 132),
)

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
look_pitch = 0
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
    "diagnosis_image": "",
    "eyes": "idle",
}
PLANT_PROMPT = (
    "Analizza questa pianta. Identifica la specie,"
    " individua eventuali problemi (foglie ingiallite, malattie"
    " o parassiti) e fornisci una soluzione pratica per"
    " risolverli. Spiega il ragionamento in italiano, in modo chiaro."
    " Se hai un valore di lux misurato, usalo: non inventarlo"
    " e non contraddirlo. Di' se la luce basta, è poca o è troppa"
    " per quella pianta, e come spostarla o ombreggiarla."
)
BH1750_BUSES = (8, 1)
BH1750_ADDRS = (0x23, 0x5C)
BH1750_POWER_ON = 0x01
BH1750_CONT_HRES = 0x10
light_lock = threading.Lock()
LIGHT = {"lux": None, "ok": False, "ts": 0, "ready": False, "addr": 0x23, "bus": 8}


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


def _smbus():
    try:
        from smbus import SMBus
        return SMBus
    except ImportError:
        from smbus2 import SMBus
        return SMBus


def light_label(lux):
    if lux < 20:
        return "Buio"
    if lux < 100:
        return "Molto scarsa"
    if lux < 300:
        return "Ombra"
    if lux < 800:
        return "Interno"
    if lux < 2500:
        return "Luminoso"
    if lux < 10000:
        return "Molto luminoso"
    return "Sole diretto"


def read_light():
    with light_lock:
        now = time.time()
        if LIGHT["ok"] and now - LIGHT["ts"] < 0.8:
            return dict(LIGHT)
        SMBus = _smbus()
        last_error = None
        for bus_n in BH1750_BUSES:
            if not os.path.exists(f"/dev/i2c-{bus_n}"):
                continue
            for addr in BH1750_ADDRS:
                bus = None
                try:
                    bus = SMBus(bus_n)
                    if not LIGHT["ready"] or LIGHT["addr"] != addr or LIGHT["bus"] != bus_n:
                        bus.write_byte(addr, BH1750_POWER_ON)
                        time.sleep(0.02)
                        bus.write_byte(addr, BH1750_CONT_HRES)
                        time.sleep(0.18)
                    data = bus.read_i2c_block_data(addr, BH1750_CONT_HRES, 2)
                    bus.close()
                    lux = ((data[0] << 8) + data[1]) / 1.2
                    LIGHT.update(
                        lux=round(lux, 1),
                        ok=True,
                        ts=now,
                        ready=True,
                        addr=addr,
                        bus=bus_n,
                    )
                    return dict(LIGHT)
                except Exception as error:
                    last_error = error
                    if bus is not None:
                        try:
                            bus.close()
                        except Exception:
                            pass
        was_ok = LIGHT["ok"]
        LIGHT.update(lux=None, ok=False, ts=now, ready=False)
        if last_error and was_ok:
            print("luce:", last_error)
        return dict(LIGHT)


def light_public():
    data = read_light()
    if not data["ok"] or data["lux"] is None:
        return {"ok": False, "lux": None, "label": "Non collegato"}
    lux = int(round(data["lux"]))
    return {"ok": True, "lux": lux, "label": light_label(data["lux"])}


def light_context():
    data = light_public()
    if not data["ok"]:
        return (
            "Sensore luce GY-302 non disponibile: non inventare un valore"
            " di lux e non dare consigli di luce come se l'avessi misurata."
        )
    return (
        f"Luce ambiente misurata ora dal GY-302: {data['lux']} lux"
        f" ({data['label']}). Usa questo valore insieme alla foto per"
        " capire se la pianta ha troppa o troppa poca luce e consigliare"
        " spostamento, ombreggiatura o più ore di sole."
    )


def plant_prompt(extra=""):
    parts = []
    if extra and extra.strip():
        parts.append(extra.strip())
    parts.append(PLANT_PROMPT)
    parts.append(light_context())
    return "\n\n".join(parts)


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


def set_gait_speed(value):
    try:
        get_dog().speed = value
    except Exception:
        pass


def set_head(angle, settle=0.9):
    global head_angle
    target = max(40, min(150, int(angle)))
    try:
        servo = get_dog().servo
        current = head_angle
        step = 3 if target >= current else -3
        pos = current
        while pos != target:
            nxt = pos + step
            if (step > 0 and nxt > target) or (step < 0 and nxt < target):
                nxt = target
            servo.setServoAngle(HEAD_SERVO, nxt)
            pos = nxt
            time.sleep(0.045)
        head_angle = target
        if settle > 0:
            time.sleep(settle)
    except Exception as error:
        print("testa:", error)


def set_look_down(pitch=LOOK_DOWN, settle=0.3):
    global look_pitch
    look_pitch = max(HEAD_PITCH_MIN, min(HEAD_PITCH_MAX, int(pitch)))
    try:
        get_dog().attitude(roll, look_pitch, 0)
        if settle > 0:
            time.sleep(settle)
    except Exception as error:
        print("sguardo:", error)


def reset_head_and_body():
    global look_pitch
    look_pitch = 0
    set_head(HEAD_CENTER, 0.2)
    try:
        get_dog().attitude(0, 0, 0)
    except Exception:
        pass


def apply_head_step(direction):
    global look_pitch
    if direction == "head_up":
        look_pitch = min(HEAD_PITCH_MAX, look_pitch + HEAD_PITCH_STEP)
        apply_pose()
        return
    if direction == "head_down":
        look_pitch = max(HEAD_PITCH_MIN, look_pitch - HEAD_PITCH_STEP)
        apply_pose()
        return
    if direction == "head_left":
        set_head(head_angle - HEAD_PAN_STEP, 0.08)
        return
    if direction == "head_right":
        set_head(head_angle + HEAD_PAN_STEP, 0.08)
        return
    if direction == "head_center":
        look_pitch = 0
        set_head(HEAD_CENTER, 0.15)
        apply_pose()


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
        return None


def closest_distance():
    samples = []
    for _ in range(5):
        value = get_distance_cm()
        if value is not None and 3 < value < 300:
            samples.append(value)
        time.sleep(0.05)
    if not samples:
        return 100
    samples.sort()
    return samples[len(samples) // 2]


def is_blocked(distance, detections=None):
    if distance is not None and 5 <= distance < OBSTACLE_CM:
        return True
    for item in detections or []:
        label = str(item.get("label") or "").lower()
        if label in PLANT_LABELS:
            continue
        centered = abs(item.get("cx", 0.5) - 0.5) < 0.28
        large = item.get("area", 0) > 0.18
        labeled = label in OBSTACLE_LABELS
        if centered and large and labeled:
            return True
    return False


def apply_stop():
    get_dog().stop()


def apply_pose():
    global height_offset, roll
    control = get_dog()
    height_offset = max(-28, min(24, height_offset))
    roll = max(-18, min(18, roll))
    control.upAndDown(height_offset)
    control.attitude(roll, look_pitch, 0)


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


def turn(side, times=TURN_STEPS):
    control = get_dog()
    previous = control.speed
    try:
        apply_stop()
        try:
            control.attitude(0, 0, 0)
        except Exception:
            pass
        apply_stop()
        control.speed = TURN_SPEED
        for index in range(times):
            if robot_mode == "autonomous" and not still_patrolling():
                break
            if side == "left":
                control.turnLeft()
                record_move("turn_left")
            else:
                control.turnRight()
                record_move("turn_right")
            if (index + 1) % 3 == 0:
                if side == "left":
                    control.setpLeft()
                    record_move("left")
                else:
                    control.setpRight()
                    record_move("right")
        apply_stop()
    finally:
        control.speed = previous
        set_look_down(LOOK_DOWN, 0.2)


def replay_move(move):
    if move in WALK_COMMANDS:
        apply_gait(move)
        return
    if move == "turn_left":
        turn("left", times=1)
        return
    if move == "turn_right":
        turn("right", times=1)


def avoid_obstacle(distance, turn_right):
    PATROL["message"] = f"Ostacolo a {distance} cm, giro"
    add_chat("system", f"Ostacolo a {distance} cm, giro.", action="avoid")
    apply_stop()
    set_head(HEAD_CENTER, 0.1)
    try:
        get_dog().attitude(0, 0, 0)
    except Exception:
        pass
    set_gait_speed(PATROL_SPEED)
    get_dog().backWard()
    record_move("backward")
    apply_stop()
    turn("right" if turn_right else "left", times=TURN_STEPS)
    remember("avoid", f"ostacolo a {distance} cm", distance)
    return not turn_right


def inspect_plant(extra=""):
    global last_inspect_at
    now = time.time()
    if now - last_inspect_at < INSPECT_COOLDOWN:
        add_chat("system", "Pianta già vista da poco, continuo.")
        return
    last_inspect_at = now
    apply_stop()
    set_head(HEAD_CENTER, 0.25)
    set_look_down(LOOK_DOWN_LOW, 0.35)
    PATROL["message"] = "Sto analizzando la pianta"
    add_chat("system", "Pianta inquadrata. Avvio l'analisi IA.")
    if not API_KEY or not has_internet():
        PATROL["message"] = "Pianta vista, analisi in attesa di rete"
        add_chat("system", "Niente internet: cammino lo stesso. La diagnosi arriverà quando c'è rete.")
        set_look_down(LOOK_DOWN, 0.2)
        return
    prompt = plant_prompt(extra)
    try:
        diagnosis, photo = ask_vision(prompt)
        PATROL["diagnosis"] = diagnosis
        PATROL["diagnosis_image"] = photo
        PATROL["message"] = "Pianta analizzata, continuo"
        add_chat("ai", diagnosis, action="inspect", image=photo)
    except Exception as error:
        PATROL["message"] = "Analisi non riuscita, continuo"
        add_chat("system", f"Analisi non riuscita: {error}")
    set_look_down(LOOK_DOWN, 0.2)


def walk_forward(steps=FORWARD_STEPS):
    set_head(HEAD_CENTER, 0.1)
    set_look_down(LOOK_DOWN, 0.2)
    for _ in range(steps):
        if not still_patrolling() or patrol_paused:
            break
        distance = closest_distance()
        PATROL["distance"] = distance
        if is_blocked(distance, local_detections()):
            apply_stop()
            set_look_down(LOOK_DOWN, 0.15)
            break
        apply_gait("forward")
        apply_stop()
        set_look_down(LOOK_DOWN, 0.15)
        time.sleep(0.15)
    apply_stop()
    set_look_down(LOOK_DOWN, 0.2)
    time.sleep(SETTLE_S)


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


def scan_view(name, angle):
    set_head(angle, 0.95)
    set_look_down(LOOK_DOWN, 0.15)
    distance = closest_distance()
    detections = local_detections()
    plants = [
        item for item in detections
        if str(item["label"]).lower() in PLANT_LABELS
    ]
    PATROL["distance"] = distance
    PATROL["message"] = f"Guardo {name}, {distance} cm"
    return {
        "name": name,
        "distance": distance,
        "plants": plants,
        "detections": detections,
        "blocked": is_blocked(distance, detections),
    }


def look_around():
    apply_stop()
    time.sleep(0.2)
    set_look_down(LOOK_DOWN, 0.55)
    views = {}
    for name, angle in LOOK_SWEEPS:
        if not still_patrolling():
            set_head(HEAD_CENTER, 0.15)
            break
        views[name] = scan_view(name, angle)
    if still_patrolling():
        set_look_down(LOOK_DOWN_LOW, 0.35)
        views["in basso"] = scan_view("in basso", HEAD_CENTER)
    set_head(HEAD_CENTER, 0.2)
    set_look_down(LOOK_DOWN, 0.2)
    return views


def _best_plant(data):
    plants = data.get("plants") or []
    if not plants:
        return None
    return max(plants, key=lambda item: item["score"] * (item["area"] + 0.05))


def _open_cm(*items):
    values = []
    for item in items:
        distance = (item or {}).get("distance") or 0
        values.append(distance if distance > 0 else 99)
    return min(values) if values else 99


def choose_from_scan(views):
    left_names = ("tutto a sinistra", "a sinistra")
    right_names = ("tutto a destra", "a destra")
    front_names = ("davanti", "in basso")
    front = [views.get(name) for name in front_names]
    if any((item or {}).get("blocked") for item in front) or _open_cm(*front) < OBSTACLE_CM:
        cd = _open_cm(*front)
        ld = _open_cm(*(views.get(name) for name in left_names))
        rd = _open_cm(*(views.get(name) for name in right_names))
        if ld >= rd:
            return "avoid_left", f"Ostacolo a {int(cd)} cm, spazio a sinistra"
        return "avoid_right", f"Ostacolo a {int(cd)} cm, spazio a destra"

    for name in front_names + left_names + right_names:
        data = views.get(name) or {}
        plant = _best_plant(data)
        if not plant:
            continue
        near = 0 < (data.get("distance") or 0) < 65
        if name in front_names and (plant["area"] > 0.08 or near):
            return "inspect", "Pianta davanti, la analizzo"
        if name in left_names:
            return "left", "Vaso a sinistra, giro"
        if name in right_names:
            return "right", "Vaso a destra, giro"

    return "forward", "Libero, avanzo piano"


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
            distance = closest_distance()
            PATROL["distance"] = distance
            if is_blocked(distance, local_detections()):
                avoid_obstacle(distance, True)
                apply_stop()
                time.sleep(SETTLE_S)
                continue
            replay_move(move)
            apply_stop()
            time.sleep(0.12)
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
                    reset_head_and_body()
                    set_gait_speed(MANUAL_SPEED)
                except Exception:
                    pass
            time.sleep(0.2)
            continue
        PATROL["running"] = True
        set_gait_speed(PATROL_SPEED)
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
            PATROL["message"] = "Mi fermo e guardo intorno"
            views = look_around()
            if not still_patrolling():
                continue
            action, message = choose_from_scan(views)
            PATROL["message"] = message
            chatter += 1
            if action != "forward" or chatter >= 2:
                add_chat("system", message, action=action)
                chatter = 0
            remember(action, message, PATROL["distance"])
            if action == "avoid_left":
                turn_right = avoid_obstacle(PATROL["distance"] or 40, False)
            elif action == "avoid_right":
                turn_right = avoid_obstacle(PATROL["distance"] or 40, True)
            else:
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
        "light": light_public(),
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
        set_gait_speed(PATROL_SPEED)
        reset_head_and_body()
        PATROL.update(running=True, message="Guida lenta avviata, guardo intorno")
        add_chat("system", "Cammino piano. Tra un passo e l'altro fermo la testa e guardo sinistra, centro e destra.")
    else:
        PATROL.update(running=False, message="Pattuglia ferma")
        add_chat("system", "Pattuglia ferma.")
        try:
            apply_stop()
            reset_head_and_body()
            set_gait_speed(MANUAL_SPEED)
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
    if direction in HEAD_COMMANDS:
        try:
            apply_head_step(direction)
        except Exception as error:
            return jsonify({"status": "error", "message": str(error)}), 500
        return jsonify({"status": "success", "direction": direction, "mode": robot_mode})
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
        diagnosis, photo = ask_vision(plant_prompt())
        PATROL["diagnosis"] = diagnosis
        PATROL["diagnosis_image"] = photo
        add_chat("ai", diagnosis, action="inspect", image=photo)
        return jsonify({
            "status": "success",
            "diagnosis": diagnosis,
            "image": photo,
            "light": light_public(),
        })
    except Exception as error:
        return jsonify({"status": "error", "message": str(error)}), 500


if __name__ == "__main__":
    try:
        app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
    finally:
        if picam2 is not None:
            picam2.stop()
