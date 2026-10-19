#!/usr/bin/env python3
"""Check actual desktop/Android icon resources inside exported release packages."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
EXPECTED=[16,32,48,64,128,256]


def windows_icon(data):
    assert data[:2]==b'MZ'
    pe=struct.unpack_from('<I',data,0x3c)[0]
    assert data[pe:pe+4]==b'PE\0\0'
    count=struct.unpack_from('<H',data,pe+6)[0]
    optional=pe+24
    size=struct.unpack_from('<H',data,pe+20)[0]
    magic=struct.unpack_from('<H',data,optional)[0]
    directories=optional+(112 if magic==0x20b else 96)
    resource_rva,_=struct.unpack_from('<II',data,directories+16)
    sections=[]
    for index in range(count):
        at=optional+size+index*40
        virtual_size,virtual_address,raw_size,raw=struct.unpack_from('<IIII',data,at+8)
        sections.append((virtual_address,max(virtual_size,raw_size),raw))
    def address(rva):
        for base,length,offset in sections:
            if base<=rva<base+length:return offset+rva-base
        raise AssertionError('PE resource RVA is outside sections')
    resource=address(resource_rva)
    def entries(relative):
        at=resource+relative
        named,ids=struct.unpack_from('<HH',data,at+12)
        assert named+ids<4096
        return [struct.unpack_from('<II',data,at+16+i*8) for i in range(named+ids)]
    def leaves(relative,depth=0):
        assert depth<5
        result=[]
        for _,value in entries(relative):
            if value&0x80000000:result+=leaves(value&0x7fffffff,depth+1)
            else:
                rva,length=struct.unpack_from('<II',data,resource+value)
                at=address(rva);assert at+length<=len(data)
                result.append(data[at:at+length])
        return result
    groups=[]
    icon_images=[]
    for kind,value in entries(0):
        if kind==3:
            assert value&0x80000000
            icon_images+=leaves(value&0x7fffffff)
        if kind==14:
            assert value&0x80000000
            groups+=leaves(value&0x7fffffff)
    sizes=[]
    for group in groups:
        reserved,kind,count=struct.unpack_from('<HHH',group)
        assert reserved==0 and kind==1
        current=[]
        for index in range(count):
            width,height,_,_,planes,bits,_,_=struct.unpack_from('<BBBBHHIH',group,6+index*14)
            assert planes==1 and bits==32 and width==height
            current.append(width or 256)
        if sorted(current)==EXPECTED:sizes=current
    assert sorted(sizes)==EXPECTED,'Windows PE does not contain all six standard authored native sizes'
    hashes={}
    for size in EXPECTED:
        expected=(ROOT/f'assets/exported/branding/desktop-{size}.png').read_bytes()
        assert expected in icon_images,'Windows PE does not contain the authored icon at '+str(size)
        hashes[str(size)]=hashlib.sha256(expected).hexdigest()
    return {'native_sizes':sizes,'group_resources':len(groups),'authored_png_sha256':hashes}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('target',choices=['windows','macos','android','android_aab'])
    parser.add_argument('artifact',type=Path)
    args=parser.parse_args()
    report={'target':args.target,'passed':False,'artifact':args.artifact.name}
    with zipfile.ZipFile(args.artifact) as archive:
        if args.target=='windows':
            report.update(windows_icon(archive.read('pacific-rush.exe')))
        elif args.target=='macos':
            files=[p for p in archive.namelist() if '.app/Contents/Resources/' in p and p.endswith('.icns')]
            expected=hashlib.sha256((ROOT/'assets/exported/branding/app.icns').read_bytes()).hexdigest()
            matches=[p for p in files if hashlib.sha256(archive.read(p)).hexdigest()==expected]
            assert len(matches)==1,'macOS app does not contain the exact authored Retina ICNS'
            report.update(native_icon=matches[0],sha256=expected)
        else:
            prefix='base/' if args.target=='android_aab' else ''
            outputs=[]
            if args.target=='android':
                sdk=Path(os.environ.get('ANDROID_HOME',str(Path.home()/'Library/Android/sdk')))
                aapt=sdk/'build-tools/35.0.1'/('aapt2.exe' if os.name=='nt' else 'aapt2')
                resources=subprocess.check_output([str(aapt),'dump','resources',str(args.artifact)],text=True)
                blocks={}
                for match in re.finditer(r'    resource (0x[0-9a-f]+) (\S+)\n(.*?)(?=    resource |  type |\Z)',resources,re.S):
                    blocks[match.group(2)]=(match.group(1),match.group(3))
                icon_id,icon_block=blocks['mipmap/icon']
                xml=re.findall(r'\(file\) (res/\S+\.xml)',icon_block)
                assert xml,'Adaptive launcher XML missing from actual icon resource'
                ids={name:blocks['mipmap/icon_'+name][0] for name in ['foreground','background','monochrome']}
                manifest=subprocess.check_output([str(aapt),'dump','xmltree',str(args.artifact),'--file','AndroidManifest.xml'],text=True)
                assert re.search(r':icon\(.*?\)=@'+icon_id+r'\b',manifest),'Manifest does not select the authored icon resource'
                for path in xml:
                    outputs.append(subprocess.check_output([str(aapt),'dump','xmltree',str(args.artifact),'--file',path],text=True))
                assert any(all(layer in value for layer in ['adaptive-icon','foreground','background','monochrome']) and all(identifier in value for identifier in ids.values()) for value in outputs),'APK adaptive/themed layer references missing'
                report['layer_resource_ids']=ids
            else:
                # AAB paths may also be shortened. Resource XML is protobuf,
                # preserving UTF-8 element names rather than Android binary XML.
                xml=[p for p in archive.namelist() if p.startswith(prefix+'res/') and p.endswith('.xml') and b'adaptive-icon' in archive.read(p)]
                assert any(all(layer in archive.read(path) for layer in [b'foreground',b'background',b'monochrome']) for path in xml),'AAB adaptive/themed layer references missing'
            report.update(adaptive_xml=xml,foreground=True,background=True,monochrome=True)
    report['passed']=True
    folder=ROOT/'reports/app-icons';folder.mkdir(parents=True,exist_ok=True)
    (folder/('package-'+args.target+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))


if __name__=='__main__':main()
