#!/usr/bin/env python3
"""Eight real ENet clients, ten rematches, wire budgets and 5–15 minute RSS.

This is a local automated matrix, not physical controls or the named cloud-host
CPU acceptance. Unique output paths preserve failures and process ownership.
"""
import argparse
import json
import platform
from pathlib import Path
import subprocess
import time
import uuid
from bootstrap import ROOT, engine
from udp_proxy import UDPProxy


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=27410)
    parser.add_argument('--races', type=int, default=10)
    parser.add_argument('--seconds', type=int, default=1800)
    parser.add_argument('--minimum-seconds', type=int, default=960)
    args = parser.parse_args()
    assert 2 <= args.races <= 10 and 0 <= args.minimum_seconds <= args.seconds <= 2400
    folder = ROOT/'reports'/('soak-eight-'+uuid.uuid4().hex[:10])
    folder.mkdir(parents=True)
    command = [str(engine()), '--headless', '--path', str(ROOT)]
    worker_port = args.port + 20
    processes, handles, proxies = [], [], []
    summary = {'passed':False, 'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
               'working_tree_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True)),
               'platform':platform.platform(), 'processor':platform.processor(),
               'races_requested':args.races, 'clients':8, 'one_way_latency_ms':50, 'one_way_jitter_ms':20,
               'independent_datagram_loss':.01, 'transport':'Eight independent real UDP proxies, including ENet ACKs and retransmissions',
               'boundary':'Native automated shared-controller clients on this development computer. No physical controls, target Android thermal test or documented two-vCPU x86-64 host claim.'}
    observations, race_wire, race_begin = [], [], {}
    began = time.monotonic()
    try:
        handle = (folder/'server.log').open('w'); handles.append(handle)
        server = subprocess.Popen([*command, '--', '--server', f'--port={worker_port}', '--network-evidence'], stdout=handle, stderr=subprocess.STDOUT)
        processes.append(server)
        deadline = time.monotonic()+15
        while 'PACIFIC_RUSH_SERVER_READY' not in (folder/'server.log').read_text():
            assert server.poll() is None and time.monotonic() < deadline, 'Authority startup failed'
            time.sleep(.05)
        for index in range(8):
            proxy = UDPProxy(args.port+index, worker_port, 50, 20, .01, seed=94723+101*index)
            proxies.append(proxy); proxy.start()
            handle = (folder/f'client-{index}.log').open('w'); handles.append(handle)
            processes.append(subprocess.Popen([*command, '--script','tests/soak_network_client.gd','--',
                f'--port={args.port+index}',f'--index={index}',f'--races={args.races}',
                f'--seconds={args.seconds}',f'--minimum-seconds={args.minimum_seconds}',
                f'--report={folder/f"client-{index}.json"}'], stdout=handle, stderr=subprocess.STDOUT))
        seen_perf = 0
        last_progress = None
        while True:
            clients_finished = all(child.poll() is not None for child in processes[1:])
            assert clients_finished or server.poll() is None, 'Authority exited before clients finished'
            assert time.monotonic()-began < args.seconds+30, 'Soak timed out'
            logs = [(folder/f'client-{index}.log').read_text() for index in range(8)]
            completed = [text.count('LOBBY_CLIENT_RACE_DONE ') for text in logs]
            progress = min(completed), max(completed)
            if progress != last_progress:
                last_progress = progress
                print(json.dumps({'elapsed':round(time.monotonic()-began,1),'completed_min_max':progress,'folder':str(folder)}),flush=True)
            for race in range(1,args.races+1):
                if race not in race_begin and any(f'LOBBY_CLIENT_RACE_STARTED index={i} race={race}\n' in text for i,text in enumerate(logs)):
                    race_begin[race] = time.monotonic(), [dict(proxy.stats) for proxy in proxies]
                if race in race_begin and all(f'LOBBY_CLIENT_RACE_DONE index={i} race={race}\n' in text for i,text in enumerate(logs)):
                    if any(row['race']==race for row in race_wire): continue
                    at, baseline = race_begin[race]
                    seconds = time.monotonic()-at
                    rates = []
                    for proxy, before in zip(proxies, baseline):
                        delta = {key:value-before[key] for key,value in proxy.stats.items()}
                        # Offered bytes include datagrams later dropped by the
                        # proxy, so loss cannot artificially reduce wire load.
                        rates.append({'udp_payload_up_Bps':delta['offered_upstream_bytes']/seconds,
                                      'udp_payload_down_Bps':delta['offered_downstream_bytes']/seconds,
                                      'ipv4_udp_up_Bps':(delta['offered_upstream_bytes']+28*delta['offered_upstream_packets'])/seconds,
                                      'ipv4_udp_down_Bps':(delta['offered_downstream_bytes']+28*delta['offered_downstream_packets'])/seconds,
                                      'counts':delta})
                    race_wire.append({'race':race,'seconds':seconds,'scope':'First Start to last Results, includes Grid and ENet overhead; excludes handshake. IPv4+UDP adds 28 bytes per observed datagram; no Ethernet/VPN estimate.','clients':rates})
            rows = [json.loads(line.split(' ',1)[1]) for line in (folder/'server.log').read_text().splitlines() if line.startswith('PACIFIC_RUSH_WORKER_PERFORMANCE ')]
            for value in rows[seen_perf:]: observations.append({'elapsed':time.monotonic()-began,**value})
            seen_perf = len(rows)
            if clients_finished: break
            time.sleep(.25)
        reports = [json.loads((folder/f'client-{i}.json').read_text()) for i in range(8)]
        results = reports[0]['results']
        checks = {}
        checks['client_exit'] = all(child.returncode==0 for child in processes[1:])
        checks['identical_standings'] = len(results)==args.races and all(report['results']==results for report in reports)
        identities = {row['id'] for row in results[0]['rows']} if results else set()
        checks['all_finish_same_eight'] = len(identities)==8 and all(len(race['rows'])==8 and {row['id'] for row in race['rows']}==identities and all(not row['dnf'] and not row['bot'] for row in race['rows']) for race in results)
        checks['bounded_racing_control'] = all(report['large_racing_events']==0 for report in reports)
        corrections = [row['clear'] for report in reports for row in report['race_metrics']]
        checks['clear_coverage_500_each'] = len(corrections)==8*args.races and all(row['count']>=500 for row in corrections)
        checks['clear_p95_025m_each'] = bool(corrections) and all(row['p95']<=.25 for row in corrections)
        checks['racing_wire_intervals'] = len(race_wire)==args.races
        checks['wire_budgets'] = bool(race_wire) and all(row['ipv4_udp_up_Bps']<=10000 and row['ipv4_udp_down_Bps']<=40000 for race in race_wire for row in race['clients'])
        memory = {'measured':False}
        if args.minimum_seconds >= 910:
            baseline = next(row for row in observations if row['elapsed']>=300)
            end = next(row for row in observations if row['elapsed']>=900)
            warmup_peak = max(row['rss_bytes'] for row in observations if row['elapsed']<=baseline['elapsed'])
            peak = max(row['rss_bytes'] for row in observations if baseline['elapsed']<=row['elapsed']<=end['elapsed'])
            growth = (peak-warmup_peak)/warmup_peak if warmup_peak else float('inf')
            # Compare the same repeated loading/racing cycle's high water marks,
            # retaining instantaneous baseline/end and all transition peaks.
            memory = {'measured':True,'baseline':baseline,'end':end,'warmup_peak_rss_bytes':warmup_peak,
                      'peak_rss_bytes':peak,'peak_growth_fraction':growth,
                      'retained_growth_fraction':(end['rss_bytes']/baseline['rss_bytes']-1) if baseline['rss_bytes'] else None,
                      'scope':'Peak during repeated loading/racing cycles after five-minute warm-up versus peak through minute five. All transients reported. This is not the continuous worst-track PERF-01 fixture.'}
            checks['rss_growth_005'] = warmup_peak>0 and growth<=.05
            checks['rss_below_256MB'] = all(0<row['rss_bytes']<=256000000 for row in observations)
        checks['engine_logs'] = all(not any(marker in path.read_text() for marker in ('SCRIPT ERROR:','ERROR:','Leaked instance','Unicode parsing error')) for path in folder.glob('*.log'))
        summary.update(checks=checks,passed=all(checks.values()),races=results,finishes=sum(len(race['rows']) for race in results),
                       identical_standings=checks['identical_standings'],
                       max_clear_p95_m=max((row['p95'] for row in corrections),default=None),
                       min_clear_samples=min((row['count'] for row in corrections),default=0),clear_samples=sum(row['count'] for row in corrections),
                       proxy_seeds=[94723+101*index for index in range(8)],
                       driver_fixture='Shared Medium AI with traffic avoidance from received snapshots, excluding own authority state; test-only target speed factors [1,.91,1.04,.94,.88,.97,.85,1.01], four normal car types',
                       clients_reports=reports,memory=memory,racing_wire=race_wire)
        assert summary['passed'], 'Failed checks: '+', '.join(key for key,value in checks.items() if not value)
    except Exception as error:
        summary['failure'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        summary['elapsed_seconds'] = time.monotonic()-began
        summary['worker_observations'] = observations
        summary['wire_totals'] = [dict(proxy.stats) for proxy in proxies]
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        cleanup_issues = []
        for proxy in proxies:
            try: proxy.stop()
            except Exception as error: cleanup_issues.append(str(error))
        summary['cleanup_issues'] = cleanup_issues
        if cleanup_issues: summary['passed'] = False
        for handle in handles: handle.close()
        (folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({'passed':summary['passed'],'report':str(folder/'summary.json'),'failure':summary.get('failure')}),flush=True)


if __name__ == '__main__': main()
