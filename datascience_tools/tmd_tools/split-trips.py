#!/usr/bin/env python
# coding: utf-8

# In[1]:


import numpy as np
import pandas as pd
import datetime

import pickle

# ## Iter parts with non-aligned index

# In[2]:


def iter_parts(df, masks_df):
    """
    Arguments:
    df --  the dataframe we want to split into parts
    masks_df -- a dataframe or dict of boolean masks with same index as df. For instance: `{'<5': df.speed < 5}`
    """
    bounds = {}
    for c in masks_df:
        mask = masks_df[c]
        if len(mask.index) != len(df.index) or np.any(mask.index != df.index):
            #print(f'Reindexing mask for "{c}"')
            joined_index = np.unique(np.sort(np.concatenate([mask.index, df.index])))
            mask = mask.reindex(joined_index).ffill().loc[df.index].fillna(False)
            assert np.all(mask.index == df.index)
        mask = mask.reset_index(drop=True)
        b = mask[mask != mask.shift()]
        bounds[c] = b
    bounds = pd.DataFrame(bounds).ffill()
    
    # to keep track of the index through the splitting process, add it as a column, and record the new column's name
    idf = df.reset_index()
    columns_diff = set(idf.columns) - set(df.columns)
    assert len(columns_diff) == 1
    index_name = columns_diff.pop()
    
    # split into parts
    parts = np.split(idf.values, bounds.index[1:])
    assert len(bounds) == len(parts)
    
    # the split yields np.array, this utility converts them back to DataFrame with proper columns and index
    wrap = lambda a: pd.DataFrame(a, columns=idf.columns).set_index(index_name)
    
    # yield the parts
    for (i, row), part in zip(bounds.iterrows(), parts):
        for c in bounds.columns:
            if row[c]:
                yield c, wrap(part)
                break
        else: # nobreak
            yield None, wrap(part)


# In[3]:


def filter_groups(mask, min_length):
    """
    Drops groups of consecutive True values in mask whose length are less than min_length.
    
    Parameters:
    mask -- a boolean mask (a series of True/False values)
    min_length -- integer: drop True values if less than min_length consecutive true values
    """
    sm = pd.DataFrame(mask, columns=[mask.name], index=mask.index)
    sm['group'] = (mask != mask.shift()).cumsum()
    sm2 = sm.groupby('group').filter(lambda g: len(g) > min_length)
    sm2 = sm2.reindex(sm.index).fillna(False)
    mask = sm2[mask.name]
    return mask


# In[4]:


def get_data(trip):
    adf = trip.data['accelerometer'].df
    #adf.index = pd.to_datetime(adf.index, unit='ms')
    adf.dropna(inplace=True)
    adf = adf.groupby(adf.index).first()
    adf['norm'] = adf[['x', 'y', 'z']].apply(np.linalg.norm, axis=1)
    
    if 'gps' not in trip.data:
        gdf = None
    else:
        gdf = trip.data['gps'].df
        #gdf.index = pd.to_datetime(gdf.index, unit='ms')
        gdf.dropna(inplace=True)
        gdf = gdf.groupby(gdf.index).first()

    return adf, gdf


# In[5]:


def plot_trip(title, adf, speed, masks):
    fig, ax = plt.subplots(nrows=5, ncols=1, figsize=(20, 5), sharex=True)
    fig.suptitle(title)
    for label, part in iter_parts(adf, masks):
        color = label or 'C0'
        part.x.plot(ax=ax[0], color=color)
        part.y.plot(ax=ax[1], color=color)
        part.z.plot(ax=ax[2], color=color)
        part.norm.plot(ax=ax[3], color=color)

    last = None
    last_color = None
    for label, part in iter_parts(pd.DataFrame(speed), masks):#gdf[['speed']], masks):
        #part.speed.plot(ax=ax[-1], color=label or 'C0')
        ax[-1].plot(part.speed.index, part.speed.values, color=label or 'C0')
        if last is not None and (label == 'black' or last_color == 'black'):
            plt.plot([last.name, part.iloc[0].name], [last.values[0], part.iloc[0].values[0]], color='black', alpha=0.3)
        last = part.iloc[-1]
        last_color = label or 'C0'
    return fig


# In[6]:


def fig_title(trip):
    title = str(trip.data['accelerometer'].filepath)
    title = title[title.rfind('/', 0, title.rfind('/'))+1:title.rfind('_', 0, title.rfind('_'))]
    return title


# In[7]:


def speed_threshold_for(mode):
    if mode in ['walk', 'walking']:
        return 0.5
    elif mode in ['bike', 'biking', 'cycling']:
        return 1
    else:
        return 2


# In[8]:


def fig_output_filename(trip, plot_dir, ext='.svg'):
    fp = trip.data['accelerometer'].filepath
    title = f'{fp.relative_to(fp.parent.parent)}'
    path = (plot_dir / trip.mode / title.replace('/', '_')).with_suffix(ext)
    return path


# In[9]:


def write_fig(trip, adf, speed, color_masks, plot_dir):
    fig = plot_trip(fig_title(trip), adf, speed, color_masks)
    path = fig_output_filename(trip, plot_dir, ext='.png')
    path.parent.mkdir(exist_ok=True, parents=True)
    fig.savefig(path)
    plt.close(fig)


# In[10]:


def write_segments(trip, adf, mode_masks, output_dir):
    fstem = trip.data['accelerometer'].filepath.stem
    for i, (label, part) in enumerate(iter_parts(adf, mode_masks)):
        part = part.reset_index()
        part['ms'] = part['ms'].values.astype(np.int64) // (10**6)
        part = part[['ms', 'x', 'y', 'z']]
        #
        label = label or trip.mode
        output_path = output_dir / label / f'{fstem}-{i:03}.zip'
        output_path.parent.mkdir(exist_ok=True, parents=True)
        #
        part.to_csv(output_path, index=False)


# In[11]:


def write_trip(trip, plot_dir, output_dir, no_gps_trips_file):
    if fig_output_filename(trip, plot_dir, ext='.png').exists():
        return
    if 'gps' not in trip.data:
        fp = trip.data['accelerometer'].filepath
        fp = fp.relative_to(fp.parent.parent)
        with open(no_gps_trips_file, 'w') as f:
            f.write(str(fp))
    else:
        adf, gdf = get_data(trip)
        speed = gdf.speed.resample('1s').first().fillna(-1)

        thr = speed_threshold_for(trip.mode)

        still_mask = filter_groups(mask=(np.abs(speed) < 0.02), min_length=30)
        remove_mask = filter_groups(mask=(speed < thr), min_length=2)
        color_masks = {'C1': still_mask, 'black': remove_mask,}
        mode_masks = {'still': still_mask, 'null': remove_mask,}

        write_segments(trip, adf, mode_masks, output_dir)
        try:
            write_fig(trip, adf, speed, color_masks, plot_dir)
        except Exception as e:
            print(fig_output_filename(trip, plot_dir), e)

# In[12]:


def get_data_trips(min_minutes=5):
    data_trips = []
    for user in data_dir.physical_users:
        if user.data_trips:
           data_trips.extend(user.data_trips)
    data_trips = [t for t in data_trips if t.duration > datetime.timedelta(minutes=min_minutes)]
    return data_trips


# ## Test with real data

# In[13]:


from pathlib import Path
import tmd_tools as tmd
import matplotlib.pyplot as plt
import gc
from tqdm.auto import tqdm
#%matplotlib inline


# In[14]:


datadir = Path('/home/julien/data_collection_app/server/app/data')
data_dir = tmd.DataDirectory(datadir)

plot_dir = plot_dir = Path('./data/plots_v2')
output_dir = Path('./output')
no_gps_trips_file = output_dir / 'to_handle.txt'

user = data_dir.get_by_uid('e631')[0]
trip = user.trips[15]


# In[15]:


#import shutil
#try:
#    shutil.rmtree(plot_dir)
#    shutil.rmtree(output_dir)
#except:
#    pass


# In[16]:


trip


# In[17]:


#write_trip(trip, plot_dir, output_dir, no_gps_trips_file)


# In[18]:


trips = get_data_trips()
trips = tqdm(trips, miniters=1)
errors = []
for trip in trips:
    try:
        trips.set_description(fig_title(trip))
        write_trip(trip, plot_dir, output_dir, no_gps_trips_file)
        gc.collect()
    except Exception as e:
        errors.append((f'{type(e)} - {e}', str(trip.data['accelerometer'].filepath)))
        if not isinstance(e, UnicodeDecodeError):
            raise

with open('errors.pkl', 'wb') as f:
    pickle.dump(errors, f)

# In[ ]:





