import sys

import frida

host, pid = sys.argv[1], int(sys.argv[2])
device = frida.get_device_manager().add_remote_device(host)
session = device.attach(pid)
messages = []
script = session.create_script("send('attach-ok');")
script.on("message", lambda message, data: messages.append(message))
script.load()
ok = any(message.get("payload") == "attach-ok" for message in messages)
session.detach()
print("attach-ok" if ok else "attach-no-message")
raise SystemExit(0 if ok else 1)
