# health_mcp_server.py
import os
import duckdb
import json
from mcp import Server, stdio_server
from contextlib import contextmanager

DATA_GLOB = os.environ.get("HEALTH_DATA_GLOB", "data/year=*/month=*/day=*/*.parquet")

server = Server("health-mcp")

@contextmanager
def duck():
  con = duckdb.connect(database=":memory:")
  con.execute(f"""
        CREATE VIEW health_data AS
        SELECT * FROM read_parquet('{DATA_GLOB}', hive_partitioning=1);
    """)
  con.execute("""
              CREATE VIEW health_data_norm AS
              SELECT
                *,
                COALESCE(TRY_CAST(timestamp AS TIMESTAMP),
                         from_iso8601_timestamp(CAST(timestamp AS VARCHAR))) AS ts,
                make_date(year, month, day) AS partition_date
              FROM health_data;
              """)
  try:
    yield con
  finally:
    con.close()

# --- Tool 1: 자유 SQL ---
@server.tool(name="query_duckdb", description="DuckDB에 임의 SQL을 실행하고 상위 N행을 반환")
def query_duckdb(sql: str, limit: int = 200):
  with duck() as con:
    df = con.execute(sql).df()
    if limit and len(df) > limit:
      df = df.head(limit)
    return {"rows": json.loads(df.to_json(orient="records")), "row_count": len(df)}

# --- Tool 2: 일자별 요약 ---
@server.tool(name="daily_agg", description="일자별 집계(steps/kcal/meters/mindful/sleep)를 반환")
def daily_agg(days: int = 30):
  sql = f"""
    SELECT
      partition_date AS date,
      SUM(stepCount)              AS steps,
      SUM(activeEnergyBurned)     AS kcal,
      SUM(distanceWalkingRunning) AS meters,
      SUM(mindfulMinutes)         AS mindful_min,
      SUM(totalSleepMinutes)      AS sleep_min
    FROM health_data_norm
    WHERE partition_date >= current_date - INTERVAL {days} DAY
    GROUP BY 1
    ORDER BY 1;
    """
  with duck() as con:
    df = con.execute(sql).df()
    return {"rows": json.loads(df.to_json(orient="records")), "row_count": len(df)}

# --- Tool 3: 최근 원본 레코드 ---
@server.tool(name="recent_raw", description="최근 날짜 원본 레코드 N개 반환(디버깅용)")
def recent_raw(limit: int = 100):
  sql = f"""
    SELECT *
    FROM health_data_norm
    WHERE partition_date = current_date
    ORDER BY ts
    LIMIT {limit};
    """
  with duck() as con:
    df = con.execute(sql).df()
    return {"rows": json.loads(df.to_json(orient="records")), "row_count": len(df)}

if __name__ == "__main__":
  stdio_server.run(server)
