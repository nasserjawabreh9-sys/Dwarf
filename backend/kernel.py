from fastapi import FastAPI

class StationKernel:
    def __init__(self, app: FastAPI):
        self.app = app
        self.rooms = {}
        self.guards = []

    def register_room(self, name, fn):
        self.rooms[name] = fn

    def run_room(self, name, payload=None):
        if name not in self.rooms:
            return {"error": "room not found"}
        return self.rooms[name](payload)

kernel = None
