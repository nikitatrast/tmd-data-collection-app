from pathlib import Path
import json
import datetime
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
    
    @property 
    def durations(self):
        d = {}
        for u in self.existing_users:
            for (mode, duration) in u.durations.items():
                d.setdefault(mode, datetime.timedelta(0))
                d[mode] += duration
        return d

    def print_durations(self):
        #
        def hours(tdelta):
            """ converts timedelta object to number of hours. """
            minutes = tdelta.seconds / 60
            hours = minutes / 60
            return hours + 24*tdelta.days
        #
        total_hours = 0
        for (mode, duration) in self.durations.items():
            if (mode != 'test') and (mode != 'exploration'):
                total_hours += hours(duration)
                print(f'{mode:10} {hours(duration):04.1f}h')
        print(f'{"total":9} {total_hours:.1f}h')

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