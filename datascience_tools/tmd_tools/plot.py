def plot_gps_data(ax, *args, zoom=11, margin=0.1):
    import geotiler
    import numpy as np
    
    if len(args) == 1:
        df = args[0]
        latitudes = df['latitude'].values
        longitudes = df['longitude'].values
    else:
        latitudes = args[0]
        longitudes = args[1]

    extent=[
        longitudes.min(), 
        latitudes.min(), 
        longitudes.max(), 
        latitudes.max()
    ]
    
    region = geotiler.Map(extent=extent, zoom=zoom)
    w, h = region.size
    scale_factor = 1 + margin
    w = max(100, int(scale_factor * w))
    h = max(100, int(scale_factor * h))
    region.size = (w, h)
    img = geotiler.render_map(region)

    points = zip(longitudes, latitudes)
    x, y = zip(*(region.rev_geocode(p) for p in points))

    ax.imshow(img)
    ax.plot(x, y, c='blue')
    return ax, img