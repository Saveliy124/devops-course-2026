#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  [OK]   $desc"; ((PASS++))
  else
    echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
  fi
}
echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"
echo '[1] Служба SSH'
SSH_CONFIG="$(sudo sshd -T)"
check 'Вход root запрещён' no "$(awk '/^permitrootlogin/{print $2}' <<<"$SSH_CONFIG")"
check 'Парольная аутентификация отключена' no "$(awk '/^passwordauthentication/{print $2}' <<<"$SSH_CONFIG")"
port="$(awk '/^port /{print $2}' <<<"$SSH_CONFIG")"
check 'SSH использует нестандартный порт' yes "$(if [[ -n "$port" && "$port" != 22 ]]; then echo yes; else echo no; fi)"
check 'MaxAuthTries равен 3' 3 "$(awk '/^maxauthtries/{print $2}' <<<"$SSH_CONFIG")"
echo '[2] Межсетевой экран'
UFW_STATUS="$(sudo ufw status verbose)"
check 'Межсетевой экран активен' active "$(awk '/^Status:/{print $2}' <<<"$UFW_STATUS")"
check 'Входящий трафик по умолчанию запрещён' deny "$(awk '/^Default:/{print $2}' <<<"$UFW_STATUS")"
echo '[3] Учётные записи'
awk -F: '$3>=1000 && $3<65534 {printf "    %s (uid=%s)\n",$1,$3}' /etc/passwd
echo '[4] Веб-сервер'
check 'Nginx активен' active "$(systemctl is-active nginx)"
sudo nginx -t >/dev/null 2>&1; nginx_rc=$?
check 'Конфигурация Nginx корректна' 0 "$nginx_rc"
cert_seconds="${CERT_MIN_SECONDS:-2592000}"
openssl x509 -checkend "$cert_seconds" -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; cert_rc=$?
check 'Сертификат действителен не менее 30 дней' 0 "$cert_rc"
check 'Нет файлов с записью для всех и ключ имеет права 600' yes "$(if [[ -z "$(find /var/www/devops-site -perm -o+w -print)" && "$(sudo stat -c '%a' /etc/ssl/private/devops.key)" == 600 ]]; then echo yes; else echo no; fi)"

# ADDITIONAL_CHECKS
echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
