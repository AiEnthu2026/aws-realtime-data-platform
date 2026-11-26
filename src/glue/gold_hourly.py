import sys

from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession, functions as F

args = getResolvedOptions(sys.argv, ["CURATED_PATH", "GOLD_PATH", "LOOKBACK_DAYS"])
lookback = int(args["LOOKBACK_DAYS"])

spark = (SparkSession.builder
         .config("spark.sql.session.timeZone", "UTC")
         .config("spark.sql.sources.partitionOverwriteMode", "dynamic")
         .getOrCreate())

silver = spark.read.parquet(args["CURATED_PATH"])
window_start = F.date_sub(F.current_date(), lookback)

gold = (silver
        .where(F.col("date") >= window_start)
        .where(F.col("trip_id") != "")
        .withColumn("sydney_ts", F.from_utc_timestamp(F.timestamp_seconds("feed_ts"), "Australia/Sydney"))
        .withColumn("sydney_date", F.to_date("sydney_ts").cast("string"))
        .withColumn("sydney_hour", F.hour("sydney_ts"))
        .where(F.col("sydney_date") > window_start.cast("string"))
        .groupBy("sydney_date", "sydney_hour", "route_id")
        .agg(F.countDistinct("vehicle_id").alias("active_vehicle_runs"),
             F.count("*").alias("positions"),
             F.round(F.avg("speed"), 2).alias("avg_speed_mps")))

(gold.repartition("sydney_date")
     .write.mode("overwrite")
     .partitionBy("sydney_date")
     .parquet(args["GOLD_PATH"]))