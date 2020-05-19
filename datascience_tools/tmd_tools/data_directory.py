from pathlib import Path
import json
import pandas as pd
from . import user_directory as ud

class DataDirectory:
    uids_filename = 'uids.json'
        
    def __init__(self, path):
        self.path = Path(path)
        self.uids = json.load(open(path/DataDirectory.uids_filename))
        
    @property
    def uids_df(self):
        return pd.DataFrame(d.uids).transpose()

    @property
    def users(self):
        return [ud.UserDirectory(self.path, uid, data) for (uid, data) in self.uids.items()]
    
    @property
    def existing_users(self):
        return [u for u in self.users if u.exists]
    
    def get_by_uid(self, uid):
        return [ud.UserDirectory(self.path, u, data) for (u, data) in self.uids.items() if u.startswith(uid)]

    def __getitem__(self, uid):
        return ud.UserDirectory(self.path, uid, self.uids[uid])

    def __repr__(self):
        if self.path.is_dir():
            n_files = sum(1 for _ in self.path.iterdir())
            return f"DataDirectory({n_files} users)"
        else:
            return f"DataDirectory(error)"