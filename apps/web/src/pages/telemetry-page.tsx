import { useCallback, useEffect, useRef, useState } from "react";
import {
  BarChart3, Activity, Cpu, HardDrive, Database,
  RefreshCw, Server, Wifi, Layers,
} from "lucide-react";
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

// ─── Prometheus API ─────────────────────────────────────────────────
const PROM = "https://telemetry.imrnes.team/prometheus/api/v1";
const INST = "100.96.248.86"; // orange VPS

interface PromValue {
  time: string;
  value: number;
}

async function queryRange(query: string, steps = 60): Promise<PromValue[]> {
  const now = Math.floor(Date.now() / 1000);
  const start = now - 3600;
  const q = `query=${encodeURIComponent(query)}&start=${start}&end=${now}&step=${steps}`;
  const res = await fetch(`${PROM}/query_range?${q}`);
  if (!res.ok) throw new Error(`Prometheus: ${res.status}`);
  const data = await res.json();
  const results = data?.data?.result ?? [];
  if (results.length === 0) return [];
  return results[0].values.map((v: [number, string]) => ({
    time: new Date(v[0] * 1000).toISOString(),
    value: parseFloat(v[1]),
  }));
}

async function queryInstant(query: string): Promise<number | null> {
  const res = await fetch(`${PROM}/query?query=${encodeURIComponent(query)}`);
  if (!res.ok) return null;
  const data = await res.json();
  const results = data?.data?.result ?? [];
  if (results.length === 0) return null;
  return parseFloat(results[0].value[1]);
}

// ─── Helpers ─────────────────────────────────────────────────────────
function fmtPct(v: number): string {
  return v.toFixed(1) + "%";
}

function fmtBytes(v: number): string {
  if (v >= 1 << 30) return (v / (1 << 30)).toFixed(1) + " GiB";
  if (v >= 1 << 20) return (v / (1 << 20)).toFixed(1) + " MiB";
  if (v >= 1 << 10) return (v / (1 << 10)).toFixed(1) + " KiB";
  return v.toFixed(0) + " B";
}

// ─── UI Components ──────────────────────────────────────────────────
function StatCard({ icon: Icon, label, value, sub, color }: {
  icon: typeof BarChart3; label: string; value: string; sub?: string; color: string;
}) {
  return (
    <Card className="border-slate-200 shadow-sm">
      <CardHeader className="flex flex-row items-center justify-between pb-2 pt-3 px-4">
        <CardTitle className="text-sm font-medium text-slate-500">{label}</CardTitle>
        <Icon className={`h-4 w-4 ${color}`} />
      </CardHeader>
      <CardContent className="px-4 pb-3">
        <div className="text-2xl font-bold">{value}</div>
        {sub && <p className="text-xs text-slate-400 mt-0.5">{sub}</p>}
      </CardContent>
    </Card>
  );
}

function ChartCard({ title, data, color, unit = "", domain, valueFormatter }: {
  title: string; data: PromValue[]; color: string; unit?: string; domain?: [number, number];
  valueFormatter?: (v: number) => string;
}) {
  if (!data || data.length === 0) {
    return (
      <Card className="border-slate-200 shadow-sm">
        <CardHeader className="pb-2 px-4 pt-3">
          <CardTitle className="text-sm font-medium">{title}</CardTitle>
        </CardHeader>
        <CardContent className="px-4 pb-3">
          <div className="flex items-center justify-center h-28 text-slate-400 text-xs">No data</div>
        </CardContent>
      </Card>
    );
  }
  return (
    <Card className="border-slate-200 shadow-sm">
      <CardHeader className="pb-2 px-4 pt-3">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
      </CardHeader>
      <CardContent className="px-4 pb-3">
        <ResponsiveContainer width="100%" height={120}>
          <AreaChart data={data}>
            <defs>
              <linearGradient id={`g-${title.replace(/\s+/g, "")}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={color} stopOpacity={0.2} />
                <stop offset="95%" stopColor={color} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey="time" tick={{ fontSize: 9 }} hide />
            <YAxis domain={domain ?? ["auto", "auto"]} tick={{ fontSize: 9 }} unit={unit} />
            <Tooltip
              labelFormatter={(v) => new Date(v).toLocaleTimeString()}
              formatter={(val: unknown) => {
                const v = typeof val === "number" ? val : 0;
                return [valueFormatter ? valueFormatter(v) : v.toFixed(2), title];
              }}
            />
            <Area type="monotone" dataKey="value" stroke={color}
              fill={`url(#g-${title.replace(/\s+/g, "")})`} strokeWidth={2} />
          </AreaChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}

function GaugeCard({ label, value, max, unit, color }: {
  label: string; value: number; max: number; unit: string; color: string;
}) {
  const pct = max > 0 ? Math.min((value / max) * 100, 100) : 0;
  return (
    <Card className="border-slate-200 shadow-sm">
      <CardHeader className="pb-1 px-4 pt-3">
        <CardTitle className="text-xs font-medium text-slate-500">{label}</CardTitle>
      </CardHeader>
      <CardContent className="px-4 pb-3">
        <div className="flex items-baseline gap-1.5">
          <span className="text-xl font-bold">{typeof value === "number" ? value.toFixed(1) : "?"}</span>
          <span className="text-xs text-slate-400">{unit}</span>
        </div>
        <div className="mt-1.5 h-1.5 w-full rounded-full bg-slate-100">
          <div className="h-1.5 rounded-full transition-all duration-500" style={{ width: `${pct}%`, backgroundColor: color }} />
        </div>
      </CardContent>
    </Card>
  );
}

// ─── Section Header ─────────────────────────────────────────────────
function SectionTitle({ icon: Icon, title, color }: { icon: typeof Layers; title: string; color?: string }) {
  return (
    <h3 className="text-base font-semibold text-[#214B11] flex items-center gap-2 border-b border-slate-100 pb-2">
      <Icon className={`h-4 w-4 ${color ?? "text-[#48A111]"}`} /> {title}
    </h3>
  );
}

// ─── Main Page ───────────────────────────────────────────────────────
export function TelemetryPage() {
  // System
  const [cpuData, setCpuData] = useState<PromValue[]>([]);
  const [memData, setMemData] = useState<PromValue[]>([]);
  const [diskData, setDiskData] = useState<PromValue[]>([]);
  const [cpuNow, setCpuNow] = useState<number | null>(null);
  const [memNow, setMemNow] = useState<number | null>(null);
  const [diskNow, setDiskNow] = useState<number | null>(null);
  const [loadNow, setLoadNow] = useState<number | null>(null);
  const [netRx, setNetRx] = useState<number | null>(null);
  const [netTx, setNetTx] = useState<number | null>(null);
  const [netRxData, setNetRxData] = useState<PromValue[]>([]);
  const [netTxData, setNetTxData] = useState<PromValue[]>([]);

  // ZeaVis API
  const [apiReqsTotal, setApiReqsTotal] = useState<number | null>(null);
  const [apiReqsActive, setApiReqsActive] = useState<number | null>(null);
  const [apiLatency, setApiLatency] = useState<number | null>(null);
  const [apiReqsData, setApiReqsData] = useState<PromValue[]>([]);
  const [apiLatencyData, setApiLatencyData] = useState<PromValue[]>([]);

  // ML
  const [mlModelLoaded, setMlModelLoaded] = useState<number | null>(null);

  // NodeJS
  const [heapUsed, setHeapUsed] = useState<number | null>(null);
  const [heapTotal, setHeapTotal] = useState<number | null>(null);
  const [eventLoopLag, setEventLoopLag] = useState<number | null>(null);
  const [activeHandles, setActiveHandles] = useState<number | null>(null);
  const [activeRequests, setActiveRequests] = useState<number | null>(null);
  const [heapData, setHeapData] = useState<PromValue[]>([]);
  const [elLagData, setElLagData] = useState<PromValue[]>([]);

  // Process
  const [procCpu, setProcCpu] = useState<number | null>(null);
  const [procMem, setProcMem] = useState<number | null>(null);
  const [procFds, setProcFds] = useState<number | null>(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const intRef = useRef<number>(0);

  const fetchAll = useCallback(async (isRefresh = false) => {
    try {
      if (isRefresh) setRefreshing(true); else setLoading(true);
      setError(null);

      const [
        cpuR, memR, diskR,
        cpuN, memN, diskN, loadN,
        netRxR, netTxR, netRxN, netTxN,
        apiReqsN, apiActiveN, apiLatN, apiReqsR, apiLatR,
        mlN,
        heapN, heapTN, elN, ahN, arN, heapR, elR,
        procCpuN, procMemN, procFdsN,
      ] = await Promise.all([
        // Range queries
        queryRange(`100 - (avg(rate(node_cpu_seconds_total{mode="idle",instance="${INST}:9100"}[5m])) * 100)`, 60),
        queryRange(`(1 - node_memory_MemAvailable_bytes{instance="${INST}:9100"} / node_memory_MemTotal_bytes{instance="${INST}:9100"}) * 100`, 60),
        queryRange(`(1 - node_filesystem_avail_bytes{instance="${INST}:9100",mountpoint="/"} / node_filesystem_size_bytes{instance="${INST}:9100",mountpoint="/"}) * 100`, 60),
        // Instant queries - system
        queryInstant(`100 - (avg(rate(node_cpu_seconds_total{mode="idle",instance="${INST}:9100"}[5m])) * 100)`),
        queryInstant(`(1 - node_memory_MemAvailable_bytes{instance="${INST}:9100"} / node_memory_MemTotal_bytes{instance="${INST}:9100"}) * 100`),
        queryInstant(`(1 - node_filesystem_avail_bytes{instance="${INST}:9100",mountpoint="/"} / node_filesystem_size_bytes{instance="${INST}:9100",mountpoint="/"}) * 100`),
        queryInstant(`node_load15{instance="${INST}:9100"}`),
        // Network
        queryRange(`rate(node_network_receive_bytes_total{instance="${INST}:9100",device="eth0"}[5m])`, 60),
        queryRange(`rate(node_network_transmit_bytes_total{instance="${INST}:9100",device="eth0"}[5m])`, 60),
        queryInstant(`rate(node_network_receive_bytes_total{instance="${INST}:9100",device="eth0"}[5m])`),
        queryInstant(`rate(node_network_transmit_bytes_total{instance="${INST}:9100",device="eth0"}[5m])`),
        // API
        queryInstant(`zeavis_api_http_requests_total{instance="${INST}:4006"}`),
        queryInstant(`zeavis_api_http_requests_active{instance="${INST}:4006"}`),
        queryInstant(`zeavis_api_http_request_duration_seconds_sum{instance="${INST}:4006"} / zeavis_api_http_request_duration_seconds_count{instance="${INST}:4006"}`),
        queryRange(`zeavis_api_http_requests_total{instance="${INST}:4006"}`, 60),
        queryRange(`zeavis_api_http_request_duration_seconds_sum{instance="${INST}:4006"} / zeavis_api_http_request_duration_seconds_count{instance="${INST}:4006"}`, 60),
        // ML
        queryInstant(`zeavis_ml_zeavis_ml_model_load_status{instance="${INST}:8000"}`),
        // NodeJS
        queryInstant(`nodejs_heap_size_used_bytes{instance="${INST}:4006"}`),
        queryInstant(`nodejs_heap_size_total_bytes{instance="${INST}:4006"}`),
        queryInstant(`nodejs_eventloop_lag_seconds{instance="${INST}:4006"}`),
        queryInstant(`nodejs_active_handles_total{instance="${INST}:4006"}`),
        queryInstant(`nodejs_active_requests_total{instance="${INST}:4006"}`),
        queryRange(`nodejs_heap_size_used_bytes{instance="${INST}:4006"}`, 60),
        queryRange(`nodejs_eventloop_lag_seconds{instance="${INST}:4006"}`, 60),
        // Process
        queryInstant(`rate(process_cpu_seconds_total{instance="${INST}:4006"}[5m])`),
        queryInstant(`process_resident_memory_bytes{instance="${INST}:4006"}`),
        queryInstant(`process_open_fds{instance="${INST}:4006"}`),
      ]);

      setCpuData(cpuR); setMemData(memR); setDiskData(diskR);
      setCpuNow(cpuN); setMemNow(memN); setDiskNow(diskN); setLoadNow(loadN);
      setNetRx(netRxN); setNetTx(netTxN); setNetRxData(netRxR); setNetTxData(netTxR);
      setApiReqsTotal(apiReqsN); setApiReqsActive(apiActiveN); setApiLatency(apiLatN);
      setApiReqsData(apiReqsR); setApiLatencyData(apiLatR);
      setMlModelLoaded(mlN);
      setHeapUsed(heapN); setHeapTotal(heapTN); setEventLoopLag(elN);
      setActiveHandles(ahN); setActiveRequests(arN);
      setHeapData(heapR); setElLagData(elR);
      setProcCpu(procCpuN); setProcMem(procMemN); setProcFds(procFdsN);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    fetchAll();
    intRef.current = window.setInterval(() => fetchAll(true), 30_000);
    return () => clearInterval(intRef.current);
  }, [fetchAll]);

  if (loading && cpuNow === null) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center space-y-3">
          <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-[#48A111] border-r-transparent" />
          <p className="text-sm text-muted-foreground">Loading telemetry data...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-emerald-800">
            Telemetry Dashboard
          </h1>
          <p className="text-gray-500 mt-1 text-md">
            Real-time monitoring dari performa sistem dan aplikasi ZeaVis Edu
            {error && <span className="text-amber-600 ml-2">(partial — {error})</span>}
          </p>
        </div>
        <button onClick={() => fetchAll(true)} disabled={refreshing}
          className="inline-flex items-center gap-1 rounded-full border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
        ><RefreshCw className={`h-4 w-4 ${refreshing ? "animate-spin" : ""}`} /> Refresh
        </button>
      </div>

      {/* ===== SYSTEM ===== */}
      <SectionTitle icon={Server} title="System" />
      <div className="grid gap-3 md:grid-cols-4 lg:grid-cols-6">
        <StatCard icon={Cpu} label="CPU" value={cpuNow !== null ? fmtPct(cpuNow) : "N/A"} color="text-blue-600" />
        <StatCard icon={Database} label="Memory" value={memNow !== null ? fmtPct(memNow) : "N/A"} color="text-violet-600" />
        <StatCard icon={HardDrive} label="Disk" value={diskNow !== null ? fmtPct(diskNow) : "N/A"} color="text-amber-600" />
        <StatCard icon={Activity} label="Load (15m)" value={loadNow !== null ? loadNow.toFixed(2) : "N/A"} color="text-rose-600" />
        <StatCard icon={Wifi} label="Net Rx" value={netRx !== null ? fmtBytes(netRx) + "/s" : "N/A"} color="text-cyan-600" />
        <StatCard icon={Wifi} label="Net Tx" value={netTx !== null ? fmtBytes(netTx) + "/s" : "N/A"} color="text-teal-600" />
      </div>
      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-4">
        <ChartCard title="CPU %" data={cpuData} color="#2563eb" unit="%" domain={[0, 100]} />
        <ChartCard title="Memory %" data={memData} color="#8b5cf6" unit="%" domain={[0, 100]} />
        <ChartCard title="Disk %" data={diskData} color="#f59e0b" unit="%" domain={[0, 100]} />
        <ChartCard title="Net Rx" data={netRxData} color="#06b6d4" />
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        <ChartCard title="Net Tx" data={netTxData} color="#14b8a6" />
        <ChartCard title="Disk %" data={diskData} color="#f59e0b" unit="%" domain={[0, 100]} />
      </div>

      {/* ===== APPLICATION ===== */}
      <SectionTitle icon={Server} title="ZeaVis API" />
      <div className="grid gap-3 md:grid-cols-4 lg:grid-cols-5">
        <StatCard icon={Activity} label="Requests Total" value={apiReqsTotal !== null ? apiReqsTotal.toFixed(0) : "N/A"} color="text-emerald-600" />
        <StatCard icon={Activity} label="Active Reqs" value={apiReqsActive !== null ? apiReqsActive.toFixed(0) : "N/A"} color="text-sky-600" />
        <StatCard icon={Activity} label="Avg Latency" value={apiLatency !== null ? (apiLatency * 1000).toFixed(1) + "ms" : "N/A"} color="text-orange-600" />
        <GaugeCard label="Heap Used" value={heapUsed !== null ? heapUsed / 1024 / 1024 : 0} max={heapTotal !== null ? heapTotal / 1024 / 1024 : 100} unit="MiB" color="#8b5cf6" />
        <GaugeCard label="Event Loop Lag" value={eventLoopLag !== null ? eventLoopLag * 1000 : 0} max={50} unit="ms" color="#f59e0b" />
      </div>
      <div className="grid gap-3 md:grid-cols-3">
        <ChartCard title="Requests" data={apiReqsData} color="#10b981" />
        <ChartCard title="Latency (avg)" data={apiLatencyData} color="#f97316" />
        <ChartCard title="Event Loop Lag" data={elLagData} color="#eab308" />
      </div>

      {/* ===== ML SERVICE ===== */}
      <SectionTitle icon={Server} title="ML Service" />
      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-4">
        <StatCard icon={Database} label="Model Status" value={mlModelLoaded !== null ? (mlModelLoaded === 1 ? "Loaded" : "Not Loaded") : "N/A"}
          color={mlModelLoaded === 1 ? "text-green-600" : "text-red-600"} />
        <GaugeCard label="Process CPU" value={procCpu !== null ? procCpu * 100 : 0} max={100} unit="%" color="#2563eb" />
        <GaugeCard label="Process Memory" value={procMem !== null ? procMem / 1024 / 1024 : 0} max={500} unit="MiB" color="#8b5cf6" />
        <StatCard icon={Activity} label="Open FDs" value={procFds !== null ? procFds.toFixed(0) : "N/A"} color="text-amber-600" />
      </div>

      {/* ===== NODEJS DETAIL ===== */}
      <SectionTitle icon={Layers} title="Node.js Runtime" />
      <div className="grid gap-3 md:grid-cols-4 lg:grid-cols-6">
        <GaugeCard label="Heap Used" value={heapUsed !== null ? heapUsed / 1024 / 1024 : 0} max={heapTotal !== null ? heapTotal / 1024 / 1024 : 200} unit="MiB" color="#8b5cf6" />
        <StatCard icon={Database} label="Heap Total" value={heapTotal !== null ? fmtBytes(heapTotal) : "N/A"} color="text-violet-600" />
        <StatCard icon={Activity} label="Active Handles" value={activeHandles !== null ? activeHandles.toFixed(0) : "N/A"} color="text-sky-600" />
        <StatCard icon={Activity} label="Active Req (Node)" value={activeRequests !== null ? activeRequests.toFixed(0) : "N/A"} color="text-teal-600" />
        <StatCard icon={Activity} label="Process CPU (api)" value={procCpu !== null ? fmtPct(procCpu * 100) : "N/A"} color="text-blue-600" />
        <StatCard icon={Activity} label="Process Mem (api)" value={procMem !== null ? fmtBytes(procMem) : "N/A"} color="text-indigo-600" />
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        <ChartCard title="Heap Used" data={heapData} color="#8b5cf6"
          valueFormatter={(v) => (v / 1024 / 1024).toFixed(1) + " MiB"} />
        <ChartCard title="Event Loop Lag" data={elLagData} color="#eab308"
          valueFormatter={(v) => (v * 1000).toFixed(2) + " ms"} />
      </div>
    </div>
  );
}
