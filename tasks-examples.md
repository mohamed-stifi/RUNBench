

|Scope|Task class|Typical volume driver|Start|Target|Why the target stops there|
|---|---|---|---|---|---|
|**RUN**|Alert triage and enrichment|Every infrastructure alert from Cloudera Manager and the metrics stack|L1|L5|Read-only, high volume, easy to grade against humans|
|**RUN**|Job and DAG failure diagnosis|Airflow task failures, Spark app failures, YARN kills|L1|L4|Evidence-linked diagnosis needed; abstention allowed|
|**RUN**|Data-incident triage and root cause|Qupid.io rule failures and anomalies: freshness, volume, schema|L1|L4|Rule results are ground truth; lineage gives impact|
|**RUN**|Rerun, clear, backfill|Transient failures, late data|L2|L4|Idempotent and reversible when runs are versioned|
|**RUN**|Runaway query control|Impala admission queues, long Hive/Spark jobs|L2|L3|Killing a query has business impact; policy per queue|
|**RUN**|Service role restart and config change|Cloudera Manager health alerts|L2|L3|Restarts cascade; needs maintenance windows and undo|
|**RUN**|Access and policy requests|Ranger policies, Kerberos principals, queue ACLs|L2|L4|Standard patterns autonomous; novel ones stay L2|
|**RUN**|User support (how-to, status, "why is my job slow")|Chat and ticket queue|L1|L5|Already saturated on public benchmarks for scripted flows|
|**RUN**|Housekeeping: small files, compaction, stats, retention|Ozone and Hive table hygiene at PB scale|L2|L4|Deletion is the one irreversible verb; retention stays gated|
|**RUN**|Capacity, queues and cost|YARN queue tuning, admission control, chargeback|L1|L3|FinOps scored 0% on public ops benchmarks; keep a human|


PLATFORM: Cloudera CDP · Airflow · Spark · Impala · Hive · Ozone · Nifi · and other CDP (Hadoop) eco system
END GOAL: Zero humans in the operating loop
Layers: L0 (manual) to L5 (full autonomy)
