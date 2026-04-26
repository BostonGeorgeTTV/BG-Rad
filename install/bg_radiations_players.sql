CREATE TABLE IF NOT EXISTS `bg_radiations_players` (
    `identifier` VARCHAR(80) NOT NULL,
    `radiation` FLOAT NOT NULL DEFAULT 0,
    `filter_seconds` INT NOT NULL DEFAULT 0,
    `filter_active` TINYINT(1) NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
);
