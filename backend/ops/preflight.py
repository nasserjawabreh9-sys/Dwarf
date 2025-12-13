import os,sys
print(">>> PREFLIGHT")
print("python =", sys.version.split()[0])
soft=["STATION_EDIT_KEY"]
opt=["OPENAI_API_KEY","STATION_OPENAI_API_KEY","GITHUB_TOKEN","RENDER_API_KEY"]
miss=[k for k in soft if not os.getenv(k)]
if miss: print("missing soft:", miss)
else: print("soft ok")
print("optional empty allowed")
