<?php
// Formularz kontaktowy — odbiera JSON z assets/app.js i wysyła wiadomość e-mailem (serwer Hostido, funkcja mail()).
// Zmień adres poniżej, jeśli wiadomości mają trafiać gdzie indziej.
$TO = 'arek.carphotography@gmail.com';

header('Content-Type: application/json; charset=utf-8');
header('X-Robots-Tag: noindex');
function out($code, $msg) { http_response_code($code); echo json_encode(['ok' => $code === 200, 'msg' => $msg]); exit; }

if ($_SERVER['REQUEST_METHOD'] !== 'POST') out(405, 'POST only');

// Tylko z tej samej strony
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$host = $_SERVER['HTTP_HOST'] ?? '';
if ($origin && parse_url($origin, PHP_URL_HOST) !== $host) out(403, 'origin');

$raw = file_get_contents('php://input', false, null, 0, 20000);
$d = json_decode($raw, true);
if (!is_array($d)) $d = $_POST;
if (!empty($d['_gotcha'])) out(200, 'ok'); // pułapka na boty — udajemy sukces

$clean = function ($k, $max = 200) use ($d) {
  $v = trim((string)($d[$k] ?? ''));
  $v = str_replace(["\r", "\0"], '', $v);
  return mb_substr($v, 0, $max);
};
$name = str_replace("\n", ' ', $clean('name', 100));
$email = str_replace("\n", '', $clean('email', 150));
$phone = str_replace("\n", ' ', $clean('phone', 40));
$type = str_replace("\n", ' ', $clean('type', 80));
$date = str_replace("\n", ' ', $clean('date', 40));
$place = str_replace("\n", ' ', $clean('place', 150));
$message = $clean('message', 5000);
$lang = $clean('lang', 5);

if ($name === '' || $message === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) out(400, 'invalid');

// Prosty limit: 1 wiadomość na 30 s z jednego adresu IP
$ip = $_SERVER['REMOTE_ADDR'] ?? 'x';
$lock = sys_get_temp_dir() . '/kontakt_' . md5($ip);
if (file_exists($lock) && time() - filemtime($lock) < 30) out(429, 'slow down');
@touch($lock);

$domain = preg_replace('/^www\./', '', preg_replace('/:\d+$/', '', $host));
$subject = 'Strona: ' . ($type ?: 'wiadomość') . ' — ' . $name;
$body = "Imię i nazwisko: $name\nE-mail: $email\n"
  . ($phone ? "Telefon: $phone\n" : '')
  . ($type ? "Rodzaj: $type\n" : '')
  . ($date ? "Termin: $date\n" : '')
  . ($place ? "Miejsce: $place\n" : '')
  . "Język strony: " . ($lang ?: 'pl') . "\n\n$message\n";

$headers = [
  'From: =?UTF-8?B?' . base64_encode('Formularz — ' . $domain) . '?= <formularz@' . $domain . '>',
  'Reply-To: ' . $email,
  'MIME-Version: 1.0',
  'Content-Type: text/plain; charset=UTF-8',
  'Content-Transfer-Encoding: 8bit',
];
$ok = mail($TO, '=?UTF-8?B?' . base64_encode($subject) . '?=', $body, implode("\r\n", $headers));
$ok ? out(200, 'ok') : out(500, 'mail failed');
