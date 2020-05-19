from string import Template


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