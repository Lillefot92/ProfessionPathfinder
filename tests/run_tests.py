"""Runs every test in this folder against the addon one level up.
Needs Python 3 and lupa (pip install lupa)."""
import glob, os, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
failed = []
for t in sorted(glob.glob(os.path.join(here, "*_*.py"))):
    if os.path.basename(t) == "run_tests.py":
        continue
    r = subprocess.run([sys.executable, t], capture_output=True, text=True, cwd=here)
    ok = r.returncode == 0
    print(("ok    " if ok else "FAIL  ") + os.path.basename(t))
    if not ok:
        failed.append(t)
        print("\n".join(r.stderr.strip().splitlines()[-5:]))
print("%d failed" % len(failed) if failed else "all passed")
sys.exit(1 if failed else 0)
