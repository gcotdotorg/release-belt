<?php

/**
 * This is an annotated example of a configuration file with default settings (or notes what they are).
 *
 * Copy to `config.php` and customize as needed.
 */

declare(strict_types=1);

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
    $_SERVER['HTTPS'] = 'on';
    $_SERVER['SERVER_PORT'] = '443';
}

/**
 * Use Dotenv to set required environment variables and load .env file in root
 */
$root_dir = dirname(__DIR__);
$dotenv = \Dotenv\Dotenv::createImmutable($root_dir);
if (file_exists($root_dir.'/.env')) {
    $dotenv->load();
    $dotenv->required(['RELEASE_DIR']);
}
return [
    // Enable to put the application into the debug mode with extended error messages.
    'debug'        => true,

    // Customize path to the directory containing release ZIP files.
    'release.dir'  => $_ENV['RELEASE_DIR'],
    's3.accessKey' => $_ENV['S3_ACCESS_KEY'],
    's3.secretKey' => $_ENV['S3_SECRET_KEY'],
    's3.region'    => $_ENV['S3_REGION']
];
