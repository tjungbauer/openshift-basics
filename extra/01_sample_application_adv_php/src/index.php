<?php
// config injected at runtime (ConfigMap)
$ini = '/opt/app-root/config/app.ini';
$cfg = @parse_ini_file($ini) ?: [];
$greeting = $cfg['greeting'] ?? 'Hello, World';
$pod = gethostname();
?>
<h1><?= htmlspecialchars($greeting) ?></h1>
<p>Served by pod: <?= htmlspecialchars($pod) ?></p>

