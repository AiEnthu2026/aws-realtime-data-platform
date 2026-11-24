resource "aws_glue_catalog_database" "rtdp" {
  name = replace(local.name_prefix, "-", "_")
}

resource "aws_glue_catalog_table" "vehicle_positions" {
  name          = "vehicle_positions"
  database_name = aws_glue_catalog_database.rtdp.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification                  = "parquet"
    "projection.enabled"            = "true"
    "projection.date.type"          = "date"
    "projection.date.format"        = "yyyy-MM-dd"
    "projection.date.range"         = "2026-11-24,NOW"
    "projection.date.interval"      = "1"
    "projection.date.interval.unit" = "DAYS"
    "projection.hour.type"          = "integer"
    "projection.hour.range"         = "0,23"
    "projection.hour.digits"        = "2"
    "storage.location.template"     = "s3://${aws_s3_bucket.data["curated"].bucket}/vehicle_positions/date=$${date}/hour=$${hour}"
  }

  partition_keys {
    name = "date"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data["curated"].bucket}/vehicle_positions/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name    = "vehicle_id"
      type    = "string"
      comment = "TfNSW vehicle identifier"
    }
    columns {
      name    = "trip_id"
      type    = "string"
      comment = "GTFS trip identifier"
    }
    columns {
      name    = "route_id"
      type    = "string"
      comment = "GTFS route identifier"
    }
    columns {
      name    = "latitude"
      type    = "double"
      comment = "WGS84 latitude"
    }
    columns {
      name    = "longitude"
      type    = "double"
      comment = "WGS84 longitude"
    }
    columns {
      name    = "bearing"
      type    = "float"
      comment = "Heading in degrees"
    }
    columns {
      name    = "speed"
      type    = "float"
      comment = "Speed in metres per second"
    }
    columns {
      name    = "vehicle_ts"
      type    = "bigint"
      comment = "Vehicle position time, Unix seconds UTC"
    }
    columns {
      name    = "feed_ts"
      type    = "bigint"
      comment = "Feed snapshot time, Unix seconds UTC"
    }
  }
}