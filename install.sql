-- ══════════════════════════════════════════════════════════════════
-- JOB MANAGER TABLE
-- ══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `multijobs` (
  `citizenid` varchar(100) NOT NULL,
  `jobdata` text DEFAULT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ══════════════════════════════════════════════════════════════════
-- TIME TRACKING TABLE
-- ══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `y_timeclock` (
  `citizenid` varchar(100) NOT NULL,
  `job` varchar(50) NOT NULL,
  `total_seconds` int(11) DEFAULT 0,
  `weekly_seconds` int(11) DEFAULT 0,
  `week_start` date DEFAULT NULL,
  PRIMARY KEY (`citizenid`, `job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
