def rooms_list(payload, kernel=None):
    if kernel is None:
        return {"rooms": []}
    return {"rooms": sorted(list(kernel.rooms.keys()))}
