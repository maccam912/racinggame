"""Real UDP impairment proxy: delay/jitter/loss includes ENet handshakes and ACKs."""
import heapq
import random
import selectors
import socket
import threading
import time


class UDPProxy:
    def __init__(self, port, worker_port, latency_ms, jitter_ms, loss, seed=94723):
        self.selector = selectors.DefaultSelector()
        self.front = socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
        self.front.bind(('127.0.0.1',port))
        self.front.setblocking(False)
        self.selector.register(self.front,selectors.EVENT_READ,None)
        self.target = ('127.0.0.1',worker_port)
        self.backends = {}
        self.pending = []
        self.counter = 0
        self.latency,self.jitter,self.loss = latency_ms/1000,jitter_ms/1000,loss
        self.random = random.Random(seed)
        self.stopping = threading.Event()
        self.thread = threading.Thread(target=self._run,daemon=True)
        self.errors = []
        self.stats = {'upstream_bytes':0,'downstream_bytes':0,'upstream_packets':0,'downstream_packets':0,'dropped_packets':0,
                      'offered_upstream_bytes':0,'offered_downstream_bytes':0,'offered_upstream_packets':0,'offered_downstream_packets':0}

    def start(self):
        self.thread.start()

    def _schedule(self, sender, data, destination, direction):
        self.stats['offered_'+direction+'_bytes'] += len(data)
        self.stats['offered_'+direction+'_packets'] += 1
        if self.random.random() < self.loss:
            self.stats['dropped_packets'] += 1
            return
        due = time.monotonic()+max(0,self.latency+self.random.uniform(-self.jitter,self.jitter))
        self.counter += 1
        heapq.heappush(self.pending,(due,self.counter,sender,data,destination,direction))

    def _run(self):
        try:
            while not self.stopping.is_set():
                now = time.monotonic()
                while self.pending and self.pending[0][0] <= now:
                    _,_,sender,data,destination,direction = heapq.heappop(self.pending)
                    sender.sendto(data,destination)
                    self.stats[direction+'_bytes'] += len(data)
                    self.stats[direction+'_packets'] += 1
                timeout = min(.02,max(0,self.pending[0][0]-now)) if self.pending else .02
                for key,_ in self.selector.select(timeout):
                    data,address = key.fileobj.recvfrom(65535)
                    if key.fileobj is self.front:
                        if address not in self.backends:
                            backend = socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
                            backend.bind(('127.0.0.1',0))
                            backend.setblocking(False)
                            self.backends[address] = backend
                            self.selector.register(backend,selectors.EVENT_READ,address)
                        self._schedule(self.backends[address],data,self.target,'upstream')
                    else:
                        self._schedule(self.front,data,key.data,'downstream')
        except Exception as exc:
            self.errors.append(type(exc).__name__+': '+str(exc))

    def stop(self):
        self.stopping.set()
        self.thread.join(timeout=2)
        for sock in [self.front,*self.backends.values()]:
            self.selector.unregister(sock)
            sock.close()
        self.selector.close()
        if self.errors:
            raise RuntimeError('UDP proxy failed: '+'; '.join(self.errors))
