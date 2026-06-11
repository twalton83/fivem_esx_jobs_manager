CREATE TABLE IF NOT EXISTS `jobspanel_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(50) NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `admin` VARCHAR(100) NOT NULL,
  `timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jobspanel_templates` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `description` VARCHAR(255) DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jobspanel_template_ranks` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `template_id` INT NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `level` INT NOT NULL DEFAULT 0,
  `salary` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jobspanel_boss_points` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_boss_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
