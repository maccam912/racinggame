#!/usr/bin/env python3
"""Apply the authored landscape parcels to course presentation source data."""
import argparse
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def apply(catalog):
    designs=json.loads((ROOT/'assets/source/course_compositions14.json').read_text())
    by_id={row['id']:row for row in designs['courses']}
    assert len(by_id)==34
    for course in catalog['courses']:
        if course['id'] not in by_id: continue
        row=by_id[course['id']]
        course.update(composition_version=14, scenery_regions=row['regions'],
                      landmarks=row['landmarks'], light_sections=row['light_sections'],
                      road_gates=row['road_gates'],
                      service_scenes=row['service_scenes'], preview_u=row['preview_u'])
        for field in ['verge_extent','ground','sun','landform_regions','district','sky_top','horizon','water_color','water_horizon']:
            if field in row: course[field]=row[field]
    return catalog

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    path=ROOT/'assets/source/course_specs.json'
    value=json.dumps(apply(json.loads(path.read_text())),indent=2)+'\n'
    export=ROOT/'assets/exported/scenery/courses.json'
    if args.check:
        assert path.read_text()==value and export.read_text()==value,'Run tools/author_course_compositions.py'
    else:
        path.write_text(value)
        export.write_text(value)
    print('THIRTY_FOUR_AUTHORED_COURSE_COMPOSITIONS')

if __name__=='__main__':main()
