-- SQL for munk-dirt dirt level persistence
CREATE TABLE IF NOT EXISTS munk_dirt (
    plate VARCHAR(32) PRIMARY KEY,
    dirt FLOAT NOT NULL DEFAULT 0
);
