#!/usr/bin/env python3
"""Strict validator for the deliberately small JSON Schema subset used by content."""
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def validate(value, schema, path='$'):
    supported = {'$schema','title','description','type','const','enum','minimum','maximum','pattern','minLength','maxLength','minItems','maxItems','items','required','properties','additionalProperties'}
    if unknown := set(schema)-supported:
        raise ValueError(f'{path}: unsupported schema keyword {unknown}')
    if 'const' in schema and value != schema['const']:
        raise ValueError(f'{path}: expected constant {schema["const"]!r}')
    if 'enum' in schema and value not in schema['enum']:
        raise ValueError(f'{path}: value is not an allowed enum')
    kind = schema.get('type')
    types = {'object':lambda x:isinstance(x,dict), 'array':lambda x:isinstance(x,list),
             'string':lambda x:isinstance(x,str), 'integer':lambda x:isinstance(x,int) and not isinstance(x,bool),
             'number':lambda x:isinstance(x,(float,int)) and not isinstance(x,bool), 'boolean':lambda x:isinstance(x,bool)}
    if kind and (kind not in types or not types[kind](value)):
        raise ValueError(f'{path}: expected {kind}')
    if isinstance(value,(float,int)) and not isinstance(value,bool):
        if not math.isfinite(value) or value < schema.get('minimum',-math.inf) or value > schema.get('maximum',math.inf):
            raise ValueError(f'{path}: nonfinite or out of numeric range')
    if isinstance(value,str):
        if not schema.get('minLength',0) <= len(value) <= schema.get('maxLength',math.inf):
            raise ValueError(f'{path}: string length outside bounds')
        if 'pattern' in schema and not re.fullmatch(schema['pattern'],value):
            raise ValueError(f'{path}: invalid identifier/path pattern')
    if isinstance(value,list):
        if not schema.get('minItems',0) <= len(value) <= schema.get('maxItems',math.inf):
            raise ValueError(f'{path}: array length outside bounds')
        for index,item in enumerate(value):
            validate(item,schema.get('items',{}),f'{path}[{index}]')
    if isinstance(value,dict):
        if missing := set(schema.get('required',[]))-set(value):
            raise ValueError(f'{path}: missing required fields {sorted(missing)}')
        properties = schema.get('properties',{})
        if schema.get('additionalProperties') is False and (extra := set(value)-set(properties)):
            raise ValueError(f'{path}: unknown fields {sorted(extra)}')
        for key,item in value.items():
            validate(item,properties.get(key,{}),f'{path}.{key}')


def check():
    for name in ('cars','tracks','rules','regions'):
        schema = json.loads((ROOT/f'schemas/{name}.schema.json').read_text())
        value = json.loads((ROOT/f'game/content/{name}.json').read_text())
        validate(value,schema,name)
        if name in ('cars','tracks'):
            ids = [record['id'] for record in value[name]]
            assert len(ids) == len(set(ids)), f'{name}: duplicate IDs'
        if name == 'regions':
            expected = {'us-central':'online.us','europe-west':'online.eu'}
            assert {row['id']:row['name_key'] for row in value['regions']} == expected, 'regions: require both named launch regions exactly once'
        if name == 'tracks':
            for track in value[name]:
                assert track['baked_route_id'] == f'res://game/content/baked/{track["id"]}.json', f'{track["id"]}: mismatched bake ID'
                bake = json.loads((ROOT/track['baked_route_id'].removeprefix('res://')).read_text())
                assert bake['track_id'] == track['id'], f'{track["id"]}: bake belongs to another course'
                for lo,hi,amount in track['bank_intervals']:
                    assert 0 <= lo < hi <= 1 and 0 <= amount <= 8, f'{track["id"]}: invalid bank interval'
                for lo,hi,width in track['width_intervals']:
                    assert 0 <= lo < hi <= 1 and 14 <= width <= 20, f'{track["id"]}: invalid width interval'
        print(f'Validated {name}: strict schema and references')


if __name__ == '__main__':
    check()
