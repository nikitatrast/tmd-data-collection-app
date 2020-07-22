from string import Template
import matplotlib.pyplot as plt
import matplotlib.dates as mdates


def plot_timeseries(df):
    fig, axes = plt.subplots(nrows=4, ncols=1, figsize=(15, 5), sharex=True)
    colors=["#7aa0c4","#ca82e1" ,"#8bcd50","#e18882"]
    for i, c in enumerate(df.columns):
        df[c].plot(ax=axes[i], color=colors[i])#, legend=True)
    fig.legend(loc=7)
    fig.subplots_adjust(right=0.92)
    #axes[-1].set_xticks(sorted([df.index[i*(len(df) // 4)] for i in range(5)] + [df['norm'].idxmax()]))
    #axes[-1].xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
    plt.xlabel('Time')
    return fig, axes


def strfdelta(tdelta, fmt):
    class DeltaTemplate(Template):
        delimiter = "%"
    d = {"D": tdelta.days}
    d["H"], rem = divmod(tdelta.seconds, 3600)
    d["M"], d["S"] = divmod(rem, 60)
    t = DeltaTemplate(fmt)
    return t.substitute(**d)


def unique(seq):
    """http://www.peterbe.com/plog/uniqifiers-benchmark"""
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]