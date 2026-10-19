CREATE TABLE IF NOT EXISTS `len_postjob_stats` (
    `identifier`  VARCHAR(60) NOT NULL,
    `level`       INT NOT NULL DEFAULT 1,
    `xp`          INT NOT NULL DEFAULT 0,
    `deliveries`  INT NOT NULL DEFAULT 0,
    `earned`      BIGINT NOT NULL DEFAULT 0,
    `updated_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `len_postjob_logs` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(60) NOT NULL,
    `cargo`       VARCHAR(32) NOT NULL,
    `amount`      INT NOT NULL,
    `payout`      INT NOT NULL,
    `tip`         INT NOT NULL DEFAULT 0,
    `xp`          INT NOT NULL,
    `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_len_postjob_logs_identifier` (`identifier`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES ('post', 'Post');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
    ('post', 0, 'trainee',     'Trainee Courier',     200, '{}', '{}'),
    ('post', 1, 'junior',      'Junior Courier',      250, '{}', '{}'),
    ('post', 2, 'courier',     'Courier',             300, '{}', '{}'),
    ('post', 3, 'experienced', 'Experienced Courier', 350, '{}', '{}'),
    ('post', 4, 'senior',      'Senior Courier',      400, '{}', '{}'),
    ('post', 5, 'lead',        'Lead Courier',        450, '{}', '{}'),
    ('post', 6, 'master',      'Master Courier',      500, '{}', '{}'),
    ('post', 7, 'chief',       'Chief Courier',       550, '{}', '{}'),
    ('post', 8, 'top',         'Top Courier',         600, '{}', '{}');
