import json,urllib.request,pathlib,zipfile,stat,copy
root=pathlib.Path('/private/tmp/glasscraft-pack-fixtures');root.mkdir(exist_ok=True)
req=urllib.request.Request('https://api.modrinth.com/v2/project/fabric-api/version?game_versions=%5B%221.21.1%22%5D',headers={'User-Agent':'Aaron-CNSD/GlassCraft-tests/0.3'})
with urllib.request.urlopen(req,timeout=30) as r:versions=json.load(r)
f=versions[0]['files'][0]
index={'formatVersion':1,'game':'minecraft','name':'GlassCraft import test','versionId':'test','dependencies':{'minecraft':'1.21.1','fabric-loader':'0.16.14'},'files':[{'path':'mods/fabric-api.jar','hashes':f['hashes'],'downloads':[f['url']],'fileSize':f['size']},{'path':'mods/optional.jar','env':{'client':'optional'},'downloads':['https://invalid.test/file'],'hashes':{}}]}
def make(name,idx,extra=None):
 with zipfile.ZipFile(root/name,'w',zipfile.ZIP_DEFLATED) as z:
  z.writestr('modrinth.index.json',json.dumps(idx))
  z.writestr('overrides/config/check.txt','shared')
  z.writestr('client-overrides/config/check.txt','client')
  if extra:z.writestr(extra,'bad')
make('good.mrpack',index)
bad=copy.deepcopy(index);bad['files'][0]['hashes']={'sha512':'0'*128};make('hash-fail.mrpack',bad)
make('traversal.mrpack',index,'../escape.txt')
bad=copy.deepcopy(index);bad['dependencies']['forge']='47.0.0';make('forge.mrpack',bad)
with zipfile.ZipFile(root/'symlink.mrpack','w') as z:
 z.writestr('modrinth.index.json',json.dumps(index));i=zipfile.ZipInfo('overrides/link');i.create_system=3;i.external_attr=(stat.S_IFLNK|0o777)<<16;z.writestr(i,'/tmp')
print('Generated live Fabric API fixture and failure fixtures')
