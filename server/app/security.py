from slugify import slugify
import time
import hashlib

def make_uid(str):
    # security protocol not committed into git
    # implement your own
    if str == "":
        str = "unknown"
    
    t = f"{time.time()}"
    s = "oaufboaieu1023948./ars"
    e = (str + s + t).encode('utf-8')
    h = hashlib.sha1(e).hexdigest()
    return slugify(h)