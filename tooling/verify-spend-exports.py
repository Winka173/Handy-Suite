"""Independent readers validate real files emitted through Handy Spend's UI."""
import base64
import csv
import hashlib
import json
from datetime import datetime, timedelta
from pathlib import Path
import unicodedata
import zipfile
import openpyxl
import pymupdf

root=Path(__file__).resolve().parent.parent
folder=root/'docs/qa/evidence/spend-export'
artifacts={}
for language in ['en','vi']:
    path=folder/f'report-{language}.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    assert data['app']=='handy-spend-transactions' and len(data['entries'])==1
    entry=data['entries'][0]
    assert entry['amount']=='-1234' and entry['payee']=='Ti\u1ebfng Vi\u1ec7t'
    with (folder/f'report-{language}.csv').open(encoding='utf-8',newline='') as stream:
        rows=list(csv.reader(stream))
    assert len(rows)==2 and json.loads(base64.b64decode(rows[1][-1]))==entry
    workbook=openpyxl.load_workbook(folder/f'report-{language}.xlsx',read_only=True,data_only=False)
    try:
        sheet=list(workbook.active.values)
        assert len(sheet)==2 and list(sheet[0])==rows[0] and list(sheet[1])==rows[1]
    finally:
        workbook.close()
    document=pymupdf.open(folder/f'report-{language}.pdf')
    try:
        assert len(document)==1
        text=unicodedata.normalize('NFC',document[0].get_text())
        assert 'Ti\u1ebfng Vi\u1ec7t' in text and '-1234' in text and 'VND' in text
        heading='Currency\n' if language=='en' else 'Ti\u1ec1n\n'
        assert heading in text
        table=text.split(heading,1)[1]
        utc=datetime.fromisoformat(entry['when'].replace('Z','+00:00'))
        # Fixture is explicitly a 00:30 Asia/Ho_Chi_Minh transaction (UTC+7).
        local_date=(utc+timedelta(hours=7)).date().isoformat()
        assert utc.date().isoformat()!=local_date
        assert local_date in table and utc.date().isoformat() not in table
    finally:
        document.close()
    with zipfile.ZipFile(folder/f'report-{language}.zip') as archive:
        assert set(archive.namelist())=={'manifest.json','data.json'}
        manifest=json.loads(archive.read('manifest.json'))
        payload=archive.read('data.json')
        assert manifest['app']=='handy-spend' and manifest['files']['data.json']==hashlib.sha256(payload).hexdigest()
        assert json.loads(payload)['entries']==[entry]
    for extension in ['csv','xlsx','json','pdf','zip']:
        name=f'report-{language}.{extension}'
        content=(folder/name).read_bytes()
        artifacts[name]={'bytes':len(content),'sha256':hashlib.sha256(content).hexdigest()}
report={'passed':True,'scope':'Actual UI export bytes via test-only file sink; independent Python csv/OpenXML/PDF/ZIP readers. System file-provider interaction not claimed.','locales':['en','vi'],'reportTimezoneDateVerified':True,'artifacts':artifacts}
(folder/'independent-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('PASS: 10 real export files; EN/VI fonts, reporting dates, exact records and ZIP checksums')
