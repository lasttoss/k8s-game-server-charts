# The cache client that was created per match

**Symptom.** At around five thousand concurrent players the game clients started failing with
`read tcp <pod>:7350: i/o timeout` — roughly half of the requests in the window. The server itself
looked healthy: pods `Running`, no restarts, no OOM kill.

**What it was not.** This is the part worth keeping, because the first three suspects were all
innocent, and each one was eliminated with a number rather than an opinion:

- *Not Postgres.* 55 of 300 connections used, zero deadlocks, zero slow queries in the log, and
  `blks_read` flat.
- *Not CPU.* Load average 0.02 over 15 minutes, CPU 96% idle, no throttling in `cpu.stat`. The box
  was bored.
- *Not the network.* conntrack at 13.6k of 262k entries, no drops on the interface.

**What it was.** Redis — Valkey in this deployment. A `PING` answered `ERR max number of clients reached`, and `CLIENT LIST`
explained the rest:

```
10,120 connections to :6379 — all from one pod IP
cmd=keys  × 715          ← the scan operator, on the hot path
```

The application was creating a **new Redis client per match** (and per registry lookup) on the request
path. Each client carries its own connection pool, none of them were ever closed, and the pool
sizes were left at defaults. So the connection count grew with *matches created*, not with pods —
which is exactly the shape of a leak that a "connections per pod" graph drawn by hand will not
show. `KEYS` made it worse: it scans the whole keyspace and blocks a single-threaded server while
it does.

**The fix, in the order that mattered.**

1. One client per `(address, db)`, cached — a singleton per process, not per call site.
2. Bounded pools: `PoolSize`, `MinIdleConns`, `IdleTimeout` set deliberately instead of inherited.
3. `KEYS` replaced by cursor-based `SCAN`.
4. Server side: `maxclients`, `timeout` and `tcp-backlog` raised, and
   `net.core.somaxconn` / `net.ipv4.tcp_max_syn_backlog` raised with them — a client limit is also a
   listen-backlog limit, and raising one without the other just moves the failure.

**What makes it visible next time.** The metric that would have caught this in minutes is
`connected_clients` plotted per pod: it should be a flat line proportional to the number of pods, and
anything that grows with matches or rooms is a leak by construction. Alert on headroom against
`maxclients`, not on the limit itself, and never allow `KEYS` from an application path.

**The transferable lesson.** An unbounded client factory on a hot path is a connection leak with
extra steps, and it fails at the worst moment — under load, when the cache is the thing keeping the
system up. Size the pool, own the lifecycle, and put `connected_clients` on a dashboard before the incident does it for you.
