# DDL
# USE prismacloud
CREATE DATABASE prismacloud
CREATE RETENTION POLICY raw ON prismacloud duration 3d replication 1
CREATE CONTINUOUS QUERY cq_pcversion ON prismacloud RESAMPLE EVERY 12h BEGIN SELECT * INTO "version" FROM raw.http GROUP BY time(12h) END
