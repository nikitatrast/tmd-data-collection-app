from fastapi import FastAPI, Form, File, UploadFile, HTTPException

import datetime
import logging
import shutil
import json
from pathlib import Path

import security

app = FastAPI()


@app.get("/hello")
def hello():
    return "Server v1. Hello."


@app.post("/register")
def register(uid: str = Form(...), info: str = Form(...)):
    uids = load_uids()
    token = security.make_uid(uid)
    candidate = find_new_candidate(token, uids.keys())
    infoData = json.loads(info)
    infoData['app_name'] = uid
    uids[candidate] = infoData
    dumpUIDs(uids)   
    logging.info(f'New registration: {candidate}: {uid}')
    return {'uid':candidate} 


@app.post("/upload")
async def upload(
    *,
    mode: str = Form(...),
    start: int = Form(...),
    end: int = Form(...),
    uid: str = Form(...),
    data: UploadFile = File(...),
    ):
    
    uids = load_uids()
    if uid not in uids.keys():
        logging.warning(f'Unknown UID: `{uid}`')
        raise HTTPException(status_code=401, detail="Unknown UID")

    fpath = filepath(uid, mode, start, end, data.filename)
    logging.info(f'Receiving data: {fpath}')
    writeToDisk(data.file, fpath)

    return {
        "mode": mode,
        "start": format(start),
        "end": format(end), 
        #"content_type": data.content_type,
    }


#-------------------------------------------------------------------


def format(milliseconds):
    datetime.datetime.fromtimestamp(float(milliseconds)/1000).strftime('%Y-%m-%d %H:%M:%S.%f')


UID_FILEPATH = '/app/data/uids.json'


def load_uids():
    try:
        return json.load(open(UID_FILEPATH, 'r'))
    except FileNotFoundError:
        return {}


def dumpUIDs(uids):
    json.dump(uids, open(UID_FILEPATH, 'w'))


def find_new_candidate(token, uids):
    if token not in uids:
        return token
    #
    for i in range(1000*1000):
        candidate = f'{token}{i}'
        if candidate not in uids:
            return candidate
    #
    logging.error(f'Could not find candidate for token {token}')
    return token


def filename(mode, start, end, tag):
    return f"{mode}_{start}_{tag}_{end}.csv"


def filepath(uid, mode, start, end, tag):
    fname = filename(mode, start, end, tag)
    return f"/app/data/{uid}/{fname}"


def writeToDisk(data: UploadFile, dest: str):
    Path(dest).parent.mkdir(exist_ok=True)
    shutil.copyfileobj(data, open(dest, 'wb'))
