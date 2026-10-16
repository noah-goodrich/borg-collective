import sys,re,html,subprocess
url,name=sys.argv[1],sys.argv[2]
subprocess.run(['curl','-sL','-A','Mozilla/5.0','--max-time','40',url,'-o',name+'.bin'])
b=open(name+'.bin','rb').read()
if b[:4]==b'%PDF':
    subprocess.run(['pdftotext',name+'.bin',name+'.txt'])
    t=open(name+'.txt',errors='ignore').read()
else:
    t=b.decode('utf8','ignore')
    t=re.sub(r'<script.*?</script>|<style.*?</style>','',t,flags=re.S)
    t=html.unescape(re.sub(r'<[^>]+>',' ',t))
t=re.sub(r'\s+',' ',t)
open(name+'.txt','w').write(t)
print(name,len(t))
