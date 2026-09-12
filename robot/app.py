import base64
import math
import os
import subprocess
import sys
import threading
import time
from flask import Flask, jsonify, request
from flask_cors import CORS
from picamera2 import Picamera2
import requests

app = Flask(__name__)
CORS(app)

API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
IMAGE_PATH = "/home/gatito/test_imx500.jpg"
HOTSPOT_SSID = "G.A.T.T.O."
CONNECT_STATE = {"busy": False, "ok": False, "message": "", "ssid": ""}
DOG_SERVER = "/home/gatito/Freenove_Robot_Dog_Kit_for_Raspberry_Pi/Code/Server"
WALK_COMMANDS = {
    "forward": "forWard",
    "backward": "backWard",
}
POSE_COMMANDS = {"up", "down", "tilt_left", "tilt_right", "level"}
MOVE_COMMANDS = set(WALK_COMMANDS) | POSE_COMMANDS | {"stop"}

picam2 = None
robot_mode = "autonomous"
dog = None
move_direction = "stop"
move_lock = threading.Lock()
height_offset = 0
roll = 0


def run(cmd, timeout=40):
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def get_camera():
    global picam2
    if picam2 is None:
        picam2 = Picamera2()
        picam2.start()
        time.sleep(2)
    return picam2


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
    # Se l'hotspot è già in onda non lo riavviare: sul chip brcmfmac
    # distruggere ap0 fa cadere anche la Wi-Fi di casa.
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


def walk_cycle(control, reverse=False):
    # Il passo Freenove di default alza poco le zampe e sembra uno strisciare.
    # Y sotto "height" = zampa sollevata; alziamo di più il passo.
    speed = 8
    height = control.height
    lift = 20
    stride = 12
    angles = range(450, 89, -speed) if reverse else range(90, 451, speed)
    name = "backWard" if reverse else "forWard"
    for angle in angles:
        rad = angle * math.pi / 180
        x1 = stride * math.cos(rad)
        y1 = lift * math.sin(rad) + height
        x2 = stride * math.cos(rad + math.pi)
        y2 = lift * math.sin(rad + math.pi) + height
        if y1 > height:
            y1 = height
        if y2 > height:
            y2 = height
        control.changeCoordinates(name, x1, y1, 0, x2, y2, 0)


def apply_gait(direction):
    control = get_dog()
    walk_cycle(control, reverse=(direction == "backward"))


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


threading.Thread(target=move_loop, daemon=True).start()


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
        "connect": CONNECT_STATE,
    })


@app.route("/api/mode", methods=["POST"])
def set_mode():
    global robot_mode, move_direction
    data = request.get_json(silent=True) or {}
    mode = str(data.get("mode") or "").strip().lower()
    if mode not in ("autonomous", "manual"):
        return jsonify({"status": "error", "message": "Usa autonomous oppure manual."}), 400
    with move_lock:
        robot_mode = mode
        if mode != "manual":
            move_direction = "stop"
    return jsonify({"status": "success", "mode": robot_mode})


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


@app.route("/api/analyze", methods=["GET"])
def analyze_plant():
    try:
        if not API_KEY:
            return jsonify({
                "status": "error",
                "message": "Chiave OpenRouter mancante sul robot.",
            }), 500

        cam = get_camera()
        cam.capture_file(IMAGE_PATH)

        with open(IMAGE_PATH, "rb") as handle:
            base64_image = base64.b64encode(handle.read()).decode("utf-8")

        headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
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

        response = requests.post(ENDPOINT, headers=headers, json=payload)
        if response.status_code == 200:
            diagnosis = response.json()["choices"][0]["message"]["content"]
            return jsonify({"status": "success", "diagnosis": diagnosis})
        return jsonify({
            "status": "error",
            "message": f"Errore API OpenRouter: {response.text}",
        }), 500
    except Exception as error:
        return jsonify({"status": "error", "message": str(error)}), 500


if __name__ == "__main__":
    try:
        app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
    finally:
        if picam2 is not None:
            picam2.stop()
