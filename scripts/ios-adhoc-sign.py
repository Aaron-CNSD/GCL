#!/usr/bin/env python3
# Adapt the upstream ad-hoc signing invocation to Apple's installed codesign.
import sys,subprocess
args=sys.argv[1:]
if not args:print('GCL local codesign adapter');sys.exit(0)
if args==['--version']:print('GCL local codesign adapter');sys.exit(0)
flags=['/usr/bin/codesign','--force','--sign','-']
for arg in args:
 if arg.startswith('-S') and len(arg)>2:flags+=['--entitlements',arg[2:],'--generate-entitlement-der']
files=[arg for arg in args if not arg.startswith('-')]
if not files:sys.exit('Missing signing target')
for file in files:subprocess.run(flags+[file],check=True)
