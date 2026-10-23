# Конфигурация виртуальной машины devops-vm

Кан Савелий Намович, ЭФБО-11-24. Локальный учебный стенд на Mac Apple Silicon.
Пароли не входят в репозиторий. SSH-ключ devops_vm отделён от ключа GitHub.

## 1. Параметры машины

VirtualBox 7.2.22; Ubuntu Server 24.04.5 LTS ARM64 без графической среды.
2048 МБ RAM, 2 vCPU, динамический VDI 25 ГБ, EFI, VirtioSCSI.
ARM64 выбран по архитектуре Mac; это 64-разрядная Ubuntu Server.

## 2. Сетевые интерфейсы

Адаптер 1 NAT: 10.0.2.15/24, исходящий доступ в Интернет.
Адаптер 2 Host-only devops-hostonly: 192.168.56.2/24, доступ с Mac.
Оба интерфейса используют DHCP; адрес после отката проверять ip -brief address.

На Mac в /etc/hosts: 192.168.56.2 devops.local notes.devops.local.
После изменения сбросить кэш: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder.

## 3. Правило проброса портов

ssh,tcp,127.0.0.1,2222,,2222. На чистой установке гостевой порт 22.
При восстановлении после смены порта поменять правило:

```bash
VBoxManage controlvm devops-vm natpf1 delete ssh
VBoxManage controlvm devops-vm natpf1 'ssh,tcp,127.0.0.1,2222,,2222'
```

## 4. Учётные записи

student — исходная учётная запись установщика, группа sudo.
devops — отдельная административная запись, группы devops,sudo.
SSH после hardening разрешён только devops, по ключу; sudo использует пароль devops.
Пароли student и devops сохранены владельцем стенда вне репозитория.

## 5. Служба SSH

Исходная конфигурация /etc/ssh/sshd_config сохранена как .backup.
Дополнение /etc/ssh/sshd_config.d/99-hardening.conf:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

Файлы в sshd_config.d обрабатываются по алфавиту; первое значение выигрывает.
Закомментировать PasswordAuthentication yes в более раннем cloud-init-файле,
если он существует. Перед применением: sudo sshd -t и sudo sshd -T.
Отключить ssh.socket и включить ssh.service, затем проверить ss -tlnp.
Старую сессию держать открытой до успешного подключения новой.

На Mac ~/.ssh/config:

```text
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```

Права ~/.ssh на сервере 700; authorized_keys 600, владелец devops.
На Mac ключ devops_vm 600. Сверить ключ хоста через консоль и ssh-keygen -lf.

## 6. Правила межсетевого экрана

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable
sudo ufw delete allow 2222/tcp
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw logging medium
sudo ufw status verbose
```

Разрешение SSH создаётся до включения UFW. Не использовать allow ssh,
поскольку /etc/services сопоставляет ssh с 22, а не с нашим портом 2222.
Правило limit ограничивает частые новые соединения. Для работы с большим
числом команд можно использовать SSH ControlMaster, сохраняя одно соединение.

## 7. Снимки состояния

01-clean-install — установка и обновление Ubuntu, до devops и hardening.
02-keys-configured — создан devops, настроен вход по ключу, SSH ещё на 22.
03-ssh-hardened — проверены порт 2222, запрет root и пароля.
Снимки и виртуальную машину после сдачи не удалять.

### Восстановление со снимка 01-clean-install

Сделать это в консоли либо через student@127.0.0.1:2222 (проброс на порт 22).
Не закрывать исходную сессию до проверки нового входа.

```bash
sudo adduser devops
sudo usermod -aG sudo devops
```

С Mac разместить открытый ключ:

```bash
ssh-copy-id -i ~/.ssh/devops_vm.pub -p 2222 devops@127.0.0.1
ssh -i ~/.ssh/devops_vm -p 2222 devops@127.0.0.1
```

Затем через student или devops выполнить:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
# Вставить все директивы из раздела 5 в 99-hardening.conf
sudoedit /etc/ssh/sshd_config.d/99-hardening.conf
sudo grep -r PasswordAuthentication /etc/ssh/sshd_config.d /etc/ssh/sshd_config
# Закомментировать конфликтующую директиву из cloud-init при её наличии
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|maxauthtries|allowusers)'
sudo systemctl disable --now ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh
sudo ss -tlnp | grep sshd
```

На Mac изменить гостевой порт проброса, проверить ssh devops. Выполнить
правила UFW из раздела 6, проверить второе соединение. Завершить:

```bash
sudo hostnamectl set-hostname devops-vm
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 devops-vm.devops.local devops-vm/' /etc/hosts
hostname -f
```

Скопировать scripts/audit.sh из репозитория и запустить от имени devops:
все шесть проверок ПР5 должны пройти, код возврата 0. Для испытания временно
заменить MaxAuthTries на 10, получить код 1 и вернуть 3, проверив sshd -t.

В репозитории есть scripts/restore-base.sh, реализующий те же команды. Для запуска
нужно доставить репозиторий и открытый ключ devops_vm.pub на чистую VM,
выполнить bash scripts/restore-base.sh /путь/devops_vm.pub и задать пароль нового
пользователя. Это исполняемое приложение к инструкции, не замена описанию.

### Уточнение сети на macOS

Host-only DHCP этого стенда выдал ошибочный default route через адрес самого
гостя и нерабочий DNS. Перед 01-clean-install исправлен netplan:

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: true
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      dhcp4-overrides:
        use-dns: false
        route-metric: 100
    enp0s9:
      dhcp4: true
      accept-ra: false
      dhcp4-overrides:
        use-dns: false
        use-routes: false
```

Файл /etc/netplan/50-cloud-init.yaml, права 600; применить sudo netplan generate
&& sudo netplan apply. Маршрут по умолчанию только через 10.0.2.2.
Исходящий Интернет проверен обновлением apt. Адрес Host-only остаётся
192.168.56.2, адрес Mac 192.168.56.1.

## 8. Веб-сервер

Пакеты: nginx и rsync из Ubuntu. Конфигурация ресурса:
/etc/nginx/sites-available/devops-site; активная символическая ссылка
/etc/nginx/sites-enabled/devops-site. Стандартная ссылка default удалена,
исходный файл sites-available/default сохранён.

Каталог /var/www/devops-site принадлежит devops:devops. Каталоги 755,
файлы 644; www-data читает и не может писать. Логи:
/var/log/nginx/devops-site.access.log и devops-site.error.log.

Создание сертификата (365 дней):

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt \
 -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
sudo chown root:root /etc/ssl/private/devops.key /etc/ssl/certs/devops.crt
```

Закрытый ключ остаётся на сервере. На Mac копируется только сертификат:
scp devops:/etc/ssl/certs/devops.crt ~/devops.crt. Проверка:
curl --cacert ~/devops.crt https://devops.local.
Конфигурация размещена в config/nginx-devops-site.conf.
HTTP перенаправляется кодом 301 на HTTPS; TLSv1.2 и TLSv1.3, SAN devops.local,
HSTS не задаётся. Все изменения: sudo nginx -t && sudo systemctl reload nginx.
Снимок 04-nginx-https создаётся после проверки TLS.

Доставка: scripts/deploy.sh либо scripts/deploy.sh --dry-run.
Сценарий находит корень по собственному пути, проверяет index.html и чистоту
Git, rsync приводит каталог назначения к site/ и задаёт D755,F644. curl -f
с --cacert проверяет результат. SSH BatchMode исключает интерактивный запрос.
Один вызов rsync использует одно SSH-соединение. Выполненные аварийные
испытания восстановлены штатной доставкой.

Если запись hosts на Mac ещё не внесена, для технической проверки допустим
CURL_RESOLVE=devops.local:443:192.168.56.2 scripts/deploy.sh. Это задаёт адрес
только curl, сохраняет проверку SAN и подписи и не заменяет требуемый шаг
настройки /etc/hosts. После настройки hosts переменная не нужна.

На macOS 27 системный openrsync отвергает числовой параметр --chmod=D755,F644.
Установлен GNU rsync 3.5.1 командой brew install rsync. Сценарий deploy.sh
использует /opt/homebrew/bin/rsync на Mac, если он установлен; на Ubuntu — rsync
из PATH. Запуски из подкаталога docs и проверка изменений в индексе также пройдены.
