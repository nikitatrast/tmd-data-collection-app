from fastapi import FastAPI, Form, File, UploadFile, HTTPException, Body
from pydantic import BaseModel
from typing import List

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
    }


@app.post("/trips")
async def trips(
    *,
    uid: str = Form(...),
    ):
    
    uids = load_uids()
    if uid not in uids.keys():
        logging.warning(f'Unknown UID: `{uid}`')
        raise HTTPException(status_code=401, detail="Unknown UID")
    
    dir_path = Path(data_dir_path(uid))

    files = list(dir_path.glob('*.csv'))
    data = {}
    for file in files:
        try:
            print(file.with_suffix('').name)
            parts = file.with_suffix('').name.split('_')
            mode = parts[0]
            start = parts[1]
            sensor = parts[2]
            end = parts[3]
            data.setdefault((mode, start, end), set())
            data[(mode, start, end)].add(sensor)
        except Exception as e:
            logging.exception('ignored')
            
    response = []
    for ((mode, start, end), sensors) in data.items():
        response.append({
            'mode': mode,
            'start': start,
            'end': end,
            'nbSensors': len(sensors)
        })
    return response


class GeoFence(BaseModel):
    latitude: float
    longitude: float
    radiusInMeters: float


@app.post("/geofences")
async def geofencesUpload(
    *,
    uid: str = Body(...),
    data: List[GeoFence],
    ):
    
    uids = load_uids()
    if uid not in uids.keys():
        logging.warning(f'Unknown UID: `{uid}`')
        raise HTTPException(status_code=401, detail="Unknown UID")

    data = [{
        'latitude': obj.latitude,
        'longitude': obj.longitude,
        'radiusInMeters': obj.radiusInMeters
    } for obj in data]

    fpath = fencesPath(uid)
    logging.info(f'Receiving data: {fpath}')
    Path(fpath).parent.mkdir(exist_ok=True)
    with Path(fpath).open('w') as f:
        json.dump(data, f)

    return {
        "status": "ok",
    }


#-------------------------------------------------------------------


def format(milliseconds):
    datetime.datetime.fromtimestamp(float(milliseconds)/1000).strftime('%Y-%m-%d %H:%M:%S.%f')


UID_FILEPATH = Path('/app/data/uids.json')


def load_uids():
    try:
        return json.load(UID_FILEPATH.open('r'))
    except FileNotFoundError:
        return {}


def dumpUIDs(uids):
    UID_FILEPATH.parent.mkdir(exist_ok=True, parents=True)
    json.dump(uids, UID_FILEPATH.open('w'))


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


def data_dir_path(uid):
    return f"/app/data/{uid}"


def filename(mode, start, end, tag):
    return f"{mode}_{start}_{tag}_{end}.csv"


def filepath(uid, mode, start, end, tag):
    fname = filename(mode, start, end, tag)
    return f"{data_dir_path(uid)}/{fname}"


def fencesPath(uid):
    return f"{data_dir_path(uid)}/geofences.json"


def writeToDisk(data: UploadFile, dest: str):
    Path(dest).parent.mkdir(exist_ok=True)
    shutil.copyfileobj(data, open(dest, 'wb'))
