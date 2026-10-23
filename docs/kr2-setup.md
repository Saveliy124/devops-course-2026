# Контрольная работа 2

Кан Савелий Намович, ЭФБО-11-24, номер 14, вариант 2.
Репозиторий: https://github.com/Saveliy124/devops-kr2, ветка kr2/variant-2.
Проект /home/devops/kr2, .env только на сервере с правами 600.
Приложение 127.0.0.1:8002:8002; Redis не публикуется, том kr2_redis_data,
сеть kr2_backend. Имя notes.devops.local сопоставляется на Mac с 192.168.56.2.

Отдельный Nginx sites-available/kr2 и ссылка sites-enabled/kr2,
сертификат /etc/ssl/certs/kr2.crt, ключ /etc/ssl/private/kr2.key (root,600),
SAN DNS:notes.devops.local, 365 дней. Конфигурация devops-site и UFW не меняются.
Снимки 06-before-kr2 и 07-kr2. Аудит содержит раздел [6] с пятью проверками,
на правильной конфигурации 19 OK и код 0; ошибочный bind 8002 даёт код 1.

Доставка rsync -avz --delete --exclude=.env --exclude=.git ./ devops:kr2/
выполняется из репозитория devops-kr2, сначала с --dry-run.
После доставки cd ~/kr2 && docker compose up -d --build.
Не экспортировать REDIS_PASSWORD и не выполнять down -v.
Сертификат копировать по проверенному SSH: scp devops:/etc/ssl/certs/kr2.crt ~/kr2.crt.
