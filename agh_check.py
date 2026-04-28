import paramiko
import json

HOST = "192.168.8.1"
PORT = 22
USER = "root"
PASS = "admin"

DOMAINS = {
    "Tuya/Smart Home": [
        "m2.tuyacn.com",
        "a3.tuyaus.com",
        "a1.tuyaus.com",
        "a3.tuyaeu.com",
        "airtake.com",
        "tuya.com",
        "tuyacn.com",
        "tuyaeu.com",
        "tuyaus.com",
    ],
    "Surplife": [
        "surplife.com",
        "app.surplife.com",
        "surplife.net",
    ],
    "KMC": [
        "kmc.com",
        "kmccontrols.com",
        "smart.kmccontrols.com",
    ],
    "Common IoT/Smart Home": [
        "iot.espressif.cn",
        "espressif.com",
        "api.cloudflare.com",
        "connectapi.garmin.com",
        "device.myq-cloud.com",
        "myq-cloud.com",
        "api.particle.io",
        "device.particle.io",
        "api.smartthings.com",
        "client.smartthings.com",
        "hue.com",
        "meethue.com",
        "api.meethue.com",
        "wemo.com",
        "belkin.com",
        "ring.com",
        "api.ring.com",
        "wyze.com",
        "api.wyze.com",
        "tasmota.github.io",
        "home-assistant.io",
        "nabucasa.com",
        "remote.nabucasa.com",
        "shelly.cloud",
        "api.shelly.cloud",
        "ewelink.com",
        "cn-api.coolkit.cc",
        "eu-api.coolkit.cc",
        "us-api.coolkit.cc",
        "iot.1.nz",
    ],
}

STATUS_MAP = {
    "FilteredBlackList":      "BLOCK",
    "NotFilteredWhiteList":   "ALLOW* (whitelisted)",
    "NotFilteredNotFound":    "allow (not blocked)",
    "NotFilteredAllowed":     "allow",
}

def run_cmd(ssh, cmd):
    _, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    return out, err

def check_domain(ssh, domain):
    cmd = f"curl -s 'http://127.0.0.1:3000/control/filtering/check_host?name={domain}&type=A'"
    out, err = run_cmd(ssh, cmd)
    if not out:
        return None, f"no response (err: {err})"
    try:
        data = json.loads(out)
        reason = data.get("reason", "unknown")
        status = STATUS_MAP.get(reason, f"unknown ({reason})")
        rule = data.get("rule", "")
        filter_name = ""
        if data.get("filter_id"):
            filter_name = f" [filter_id={data['filter_id']}]"
        return status, rule + filter_name
    except Exception as e:
        return None, f"parse error: {e} | raw: {out[:100]}"

def get_filtering_status(ssh):
    cmd = "curl -s 'http://127.0.0.1:3000/control/filtering/status'"
    out, err = run_cmd(ssh, cmd)
    if not out:
        return None, f"no response (err: {err})"
    try:
        data = json.loads(out)
        return data, None
    except Exception as e:
        return None, f"parse error: {e} | raw: {out[:200]}"

def main():
    print(f"Connecting to {HOST}:{PORT} as {USER}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, port=PORT, username=USER, password=PASS, timeout=10)
    print("Connected.\n")

    # --- Get current whitelist/user_rules ---
    print("=" * 60)
    print("FETCHING CURRENT FILTERING STATUS (user_rules)")
    print("=" * 60)
    fdata, ferr = get_filtering_status(ssh)
    if ferr:
        print(f"  ERROR: {ferr}")
    else:
        user_rules = fdata.get("user_rules", [])
        if user_rules:
            print(f"  Found {len(user_rules)} user rule(s):")
            for rule in user_rules:
                print(f"    {rule}")
        else:
            print("  No user_rules found (empty).")
        print(f"\n  Filtering enabled: {fdata.get('enabled')}")
        filters = fdata.get("filters", [])
        print(f"  Active filter lists: {len(filters)}")
        for f in filters:
            print(f"    [{f.get('id')}] {f.get('name')} — enabled={f.get('enabled')} rules={f.get('rules_count')}")
    print()

    # --- Check all domains ---
    all_blocked = []
    all_whitelisted = []

    for category, domains in DOMAINS.items():
        print("=" * 60)
        print(f"CATEGORY: {category}")
        print("=" * 60)
        for domain in domains:
            status, detail = check_domain(ssh, domain)
            if status is None:
                print(f"  ERROR   {domain:40s}  ({detail})")
            else:
                marker = ""
                if "BLOCK" in status:
                    marker = "  <<<"
                    all_blocked.append((domain, detail))
                elif "whitelisted" in status:
                    marker = "  ***"
                    all_whitelisted.append((domain, detail))
                rule_str = f"  rule: {detail}" if detail else ""
                print(f"  {status:<26s} {domain}{rule_str}{marker}")
        print()

    # --- Summary ---
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"\nBLOCKED DOMAINS ({len(all_blocked)}):")
    if all_blocked:
        for domain, rule in all_blocked:
            print(f"  BLOCK  {domain:40s}  (rule: {rule})")
    else:
        print("  None found.")

    print(f"\nWHITELISTED DOMAINS ({len(all_whitelisted)}):")
    if all_whitelisted:
        for domain, rule in all_whitelisted:
            print(f"  ALLOW* {domain:40s}  (rule: {rule})")
    else:
        print("  None found.")

    ssh.close()
    print("\nDone.")

if __name__ == "__main__":
    main()
